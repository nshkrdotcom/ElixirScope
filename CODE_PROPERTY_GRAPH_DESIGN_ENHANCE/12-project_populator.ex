defmodule ElixirScope.ASTRepository.ProjectPopulator do
  @moduledoc """
  Populates the AST Repository by discovering, parsing, and analyzing
  all relevant Elixir files within a given project path.

  It orchestrates the use of `ASTAnalyzer` and stores results via
  `ASTRepository.Repository`.
  """

  alias ElixirScope.ASTRepository.Repository
  alias ElixirScope.ASTRepository.ASTAnalyzer
  alias ElixirScope.ASTRepository.EnhancedModuleData # For type hint

  @type population_options :: [
    {:include_deps, boolean()} |
    {:include_test_files, boolean()} |
    {:file_patterns, [String.t()]} | # Glob patterns for files to include
    {:ignore_patterns, [String.t()]} | # Glob patterns for files/dirs to ignore
    {:parallel_workers, pos_integer()} |
    {:progress_callback, (map() -> any())} | # %{processed_files: N, total_files: M, current_file: path}
    {:error_handler, (term() -> any())} # Callback for non-fatal errors during parsing/analysis
  ]

  @type population_result :: %{
    status: :ok | :partial_ok | :error,
    total_files_discovered: non_neg_integer(),
    files_processed: non_neg_integer(),
    modules_added: non_neg_integer(),
    functions_analyzed: non_neg_integer(),
    errors: [%{file: String.t(), reason: term()}],
    duration_ms: non_neg_integer(),
    memory_impact_mb: float() # Approximate memory increase in repository
  }

  # Default ignore patterns
  @default_ignore_patterns ["_build/**", "deps/**", "cover/**", ".git/**", "priv/static/**"]
  @default_file_patterns ["lib/**/*.ex", "test/**/*.exs", "web/**/*.ex", "app/**/*.ex"] # Common Elixir project structures

  @doc """
  Populates the AST repository with data from an entire Elixir project.

  Discovers all Elixir source files in the given `project_path`,
  parses them, analyzes them using `ASTAnalyzer`, and stores the
  `EnhancedModuleData` (which includes `EnhancedFunctionData`)
  into the `ASTRepository.Repository`.
  """
  @spec populate_project(project_path :: String.t(), opts :: population_options()) ::
          {:ok, population_result()} | {:error, term()}
  def populate_project(project_path, opts \\ []) do
    start_time = System.monotonic_time()
    repo_pid = Process.whereis(Repository) || Repository # Assuming default name

    # Consolidate options
    include_deps = Keyword.get(opts, :include_deps, false) # Typically false
    include_tests = Keyword.get(opts, :include_test_files, true)
    file_patterns = Keyword.get(opts, :file_patterns, @default_file_patterns)
    ignore_patterns = Keyword.get(opts, :ignore_patterns, @default_ignore_patterns) ++
                      (if include_deps, do: [], else: ["deps/**"]) ++
                      (if include_tests, do: [], else: ["test/**"])

    parallel_workers = Keyword.get(opts, :parallel_workers, System.schedulers_online())
    progress_callback = Keyword.get(opts, :progress_callback)
    error_handler = Keyword.get(opts, :error_handler, fn err -> Logger.error("Error during population: #{inspect(err)}") end)

    initial_repo_memory = get_repo_memory_usage(repo_pid)

    case discover_elixir_files(project_path, file_patterns, ignore_patterns) do
      {:ok, files_to_process} ->
        total_files = length(files_to_process)
        update_progress(progress_callback, 0, total_files, nil)

        # Process files in parallel
        results = files_to_process
        |> Task.async_stream(&process_single_file(&1, repo_pid, error_handler),
            max_concurrency: parallel_workers,
            ordered: false,
            on_timeout: :kill_task, # Or :exit_process
            timeout: Keyword.get(opts, :file_processing_timeout_ms, 60_000) # 60s per file
        )
        |> Enum.reduce(%{processed: 0, modules: 0, functions: 0, errors: []}, fn
          {:ok, {:ok, file_result}}, acc ->
            update_progress(progress_callback, acc.processed + 1, total_files, file_result.file_path)
            %{acc |
              processed: acc.processed + 1,
              modules: acc.modules + (if file_result.module_data, do: 1, else: 0),
              functions: acc.functions + (file_result.module_data && length(file_result.module_data.functions) || 0)
            }
          {:ok, {:error, file_path, reason}}, acc ->
            update_progress(progress_callback, acc.processed + 1, total_files, file_path)
            error_handler.({:file_error, file_path, reason})
            %{acc | processed: acc.processed + 1, errors: [%{file: file_path, reason: reason} | acc.errors]}
          {:exit, reason}, acc ->
            # Handle task crash - this file path might be lost unless passed in task args
            error_handler.({:task_exit, reason})
            %{acc | errors: [%{file: :unknown_crashed_task, reason: reason} | acc.errors]} # Mark as processed with error
        end)

        final_repo_memory = get_repo_memory_usage(repo_pid)
        duration_ms = System.monotonic_time() - start_time |> System.convert_time_unit(:native, :millisecond)

        population_result = %{
          status: if(Enum.empty?(results.errors), do: :ok, else: :partial_ok),
          total_files_discovered: total_files,
          files_processed: results.processed,
          modules_added: results.modules,
          functions_analyzed: results.functions,
          errors: Enum.reverse(results.errors),
          duration_ms: duration_ms,
          memory_impact_mb: Float.round((final_repo_memory - initial_repo_memory) / (1024 * 1024), 2)
        }
        {:ok, population_result}

      {:error, reason} ->
        {:error, {:discovery_failed, reason}}
    end
  end

  defp process_single_file(file_path, repo_pid, error_handler) do
    try do
      content = File.read!(file_path)
      # We need to determine the module name. This is tricky without full compilation.
      # We can parse to find `defmodule` or use file path conventions.
      # For now, `ASTAnalyzer.analyze_module_ast` takes it as an argument.
      # Let's assume a helper `extract_module_name_from_ast_or_path`.
      {:ok, quoted_ast} = Code.string_to_quoted(content, path: file_path, trimmer: &(&1))

      module_name = extract_module_name_from_ast(quoted_ast) || module_name_from_path(file_path)

      if module_name do
        case ASTAnalyzer.analyze_module_ast(quoted_ast, module_name, file_path) do
          {:ok, %EnhancedModuleData{} = enhanced_module_data} ->
            case Repository.store_module(repo_pid, enhanced_module_data) do
              :ok -> {:ok, %{file_path: file_path, module_data: enhanced_module_data, status: :processed}}
              {:error, store_reason} ->
                error_handler.({:store_error, file_path, module_name, store_reason})
                {:error, file_path, {:store_failed, store_reason}}
            end
          {:error, analysis_reason} ->
            error_handler.({:analysis_error, file_path, module_name, analysis_reason})
            {:error, file_path, {:analysis_failed, analysis_reason}}
        end
      else
        # Could not determine module name, skip or log as unhandled file
        error_handler.({:module_name_extraction_failed, file_path})
        {:error, file_path, :module_name_extraction_failed}
      end
    rescue
      File.Error -> {:error, file_path, :file_read_error}
      TokenMissingError -> {:error, file_path, :parsing_error_token}
      CompileError -> {:error, file_path, :parsing_error_compile}
      exception ->
        error_handler.({:unexpected_error, file_path, exception, __STACKTRACE__})
        {:error, file_path, {:unexpected_exception, exception}}
    end
  end


  @doc """
  Discovers Elixir source files (.ex, .exs) in a project directory.
  Respects ignore patterns.
  """
  @spec discover_elixir_files(project_path :: String.t(), file_patterns :: [String.t()], ignore_patterns :: [String.t()]) ::
          {:ok, [String.t()]} | {:error, term()}
  def discover_elixir_files(project_path, file_patterns, ignore_patterns) do
    unless File.dir?(project_path) do
      {:error, {:invalid_project_path, project_path}}
    else
      # Create a combined glob pattern for matching, then filter with ignore patterns
      # This is a simplified approach. A more robust solution might involve
      # iterating through `file_patterns` and then applying `ignore_patterns`.
      all_files = file_patterns
                  |> Enum.flat_map(&Path.join(project_path, &1) |> Path.wildcard())
                  |> Enum.uniq()
                  |> Enum.filter(&File.regular?(&1)) # Ensure they are files

      # Filter out ignored files
      # This requires a glob matching utility for ignore_patterns against absolute paths
      filtered_files = Enum.reject(all_files, fn file_path ->
        Enum.any?(ignore_patterns, &matches_ignore_pattern?(file_path, Path.join(project_path, &1)))
      end)

      {:ok, filtered_files}
    end
  end

  defp matches_ignore_pattern?(file_path, ignore_glob) do
    # Simple prefix match for directory ignores, or full glob match.
    # `File.fnmatch` could be used, but it's for basenames.
    # A more robust glob library might be needed for complex ignore patterns like `**/*.tmp`.
    # For "deps/**", check if file_path starts with the expanded ignore_glob.
    expanded_ignore_dir = String.trim_trailing(ignore_glob, "/**")
    if String.ends_with?(ignore_glob, "/**") do
      String.starts_with?(file_path, expanded_ignore_dir <> "/")
    else # Assume it's a file glob pattern for now, this part is tricky
      File.fnmatch?(ignore_glob, Path.basename(file_path)) || # Match basename
      File.fnmatch?(ignore_glob, file_path) # Match full path relative to project root (if glob is relative)
      # This glob matching for ignore is simplified.
    end
  end

  defp update_progress(nil, _processed, _total, _current_file), do: :ok
  defp update_progress(callback_fun, processed, total, current_file) when is_function(callback_fun, 1) do
    try do
      callback_fun.(%{
        processed_files: processed,
        total_files: total,
        percent: if(total > 0, do: Float.round(processed / total * 100, 1), else: 0.0),
        current_file: current_file
      })
    rescue
      _ -> :ok # Don't let progress callback crash the population
    end
  end


  defp get_repo_memory_usage(repo_pid) do
    # A more accurate way would be to sum memory of all ETS tables managed by the repo
    # For now, using process info as a rough proxy.
    if Process.alive?(repo_pid) do
      case Process.info(repo_pid, :memory) do
        {:memory, bytes} -> bytes
        _ -> 0
      end
    else
      0
    end
  end

  # --- Module Name Extraction Helpers (Simplified) ---
  defp extract_module_name_from_ast({:defmodule, _, [{:__aliases__, _, parts} | _]}) do
    Module.concat(parts) # parts is like [:MyApp, :MyModule]
  end
  defp extract_module_name_from_ast(_), do: nil

  defp module_name_from_path(file_path) do
    # Very simplified: lib/my_app/my_module.ex -> MyApp.MyModule
    # This doesn't handle all project structures or naming conventions.
    file_path
    |> Path.relative_to_cwd() # Or relative to project root
    |> String.replace(~r/^(lib|test|web|app)\//, "") # Remove common top dirs
    |> Path.rootname() # Remove .ex/.exs
    |> String.split("/")
    |> Enum.map(&Macro.camelize/1)
    |> Enum.map(&String.to_atom/1) # Module.concat needs atoms for older Elixirs
    |> then(&if Enum.empty?(&1), do: nil, else: Module.concat(&1))
  catch
    _ -> nil # Path operations can fail
  end

end
