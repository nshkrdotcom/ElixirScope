defmodule Mix.Tasks.Compile.ElixirScope do
  @moduledoc """
  Mix compiler that transforms Elixir ASTs to inject ElixirScope instrumentation.

  This compiler:
  1. Runs before the standard Elixir compiler
  2. Transforms ASTs based on AI-generated instrumentation plans
  3. Preserves original code semantics and metadata
  4. Injects calls to ElixirScope.Capture.InstrumentationRuntime
  """

  use Mix.Task.Compiler

  alias ElixirScope.AST.Transformer
  alias ElixirScope.AI.Orchestrator

  @impl true
  def run(argv) do
    config = parse_argv(argv)

    # Ensure ElixirScope is started for orchestrator access
    ensure_elixir_scope_started()

    # Get instrumentation plan from AI
    case get_or_create_instrumentation_plan(config) do
      {:ok, plan} ->
        case transform_project(plan, config) do
          :ok -> {:ok, []}
          {:error, reason} -> {:error, [reason]}
        end

      {:error, reason} ->
        Mix.shell().error("ElixirScope instrumentation failed: #{inspect(reason)}")
        {:error, [reason]}
    end
  rescue
    error ->
      Mix.shell().error("ElixirScope compiler crashed: #{Exception.format(:error, error, __STACKTRACE__)}")
      {:error, [error]}
  end

  @doc """
  Transforms an AST directly with a given plan (used by tests).
  """
  def transform_ast(ast, plan) do
    Transformer.transform_function(ast, plan)
  end

  defp transform_project(plan, config) do
    # Find all .ex files in the project
    elixir_files = find_elixir_files(config.source_paths)
    
    if length(elixir_files) == 0 do
      Mix.shell().info("ElixirScope: No Elixir files found to instrument")
      :ok
    else
      # Create output directory structure
      ensure_output_directories(config)
      
      # Transform each file
      {success_count, failed_files} = 
        elixir_files
        |> Enum.map(&transform_file(&1, plan, config))
        |> Enum.reduce({0, []}, fn
          :ok, {success, failed} -> {success + 1, failed}
          {:error, {file, reason}}, {success, failed} -> {success, [{file, reason} | failed]}
        end)

      if length(failed_files) == 0 do
        Mix.shell().info("ElixirScope: Successfully instrumented #{success_count} files")
        :ok
      else
        Mix.shell().error("ElixirScope: Failed to instrument #{length(failed_files)} files:")
        Enum.each(failed_files, fn {file, reason} ->
          Mix.shell().error("  #{file}: #{inspect(reason)}")
        end)
        {:error, {:transformation_failed, failed_files}}
      end
    end
  end

  defp transform_file(file_path, plan, config) do
    try do
      # Read and parse the file
      source = File.read!(file_path)
      
      case Code.string_to_quoted(source, file: file_path, line: 1, column: 1) do
        {:ok, ast} ->
          # Check if this file should be instrumented
          if should_instrument_file?(file_path, ast, plan) do

            # Get module-specific instrumentation plan
            module_plan = extract_module_plan(ast, plan)

            # Transform the AST
            transformed_ast = Transformer.transform_module(ast, module_plan)

            # Generate output path and ensure directory exists
            output_path = generate_output_path(file_path, config)
            ensure_directory_exists(Path.dirname(output_path))

            # Write transformed code with proper formatting
            transformed_code = format_transformed_code(transformed_ast, file_path)
            File.write!(output_path, transformed_code)
            
            if config.debug do
              Mix.shell().info("ElixirScope: Transformed #{Path.relative_to_cwd(file_path)}")
            end
            
            :ok
          else
            # File doesn't need instrumentation, skip it
            :ok
          end
          
        {:error, {line, error_message, token}} ->
          {:error, {file_path, "Parse error at line #{line}: #{inspect(error_message)} near #{inspect(token)}"}}
          
        {:error, reason} ->
          {:error, {file_path, "Parse error: #{inspect(reason)}"}}
      end
    rescue
      error ->
        {:error, {file_path, Exception.format(:error, error, __STACKTRACE__)}}
    end
  end

  # Implementation details for file handling, path management, etc.
  defp find_elixir_files(source_paths) do
    source_paths
    |> Enum.flat_map(fn path ->
      if File.exists?(path) do
        Path.wildcard(Path.join(path, "**/*.ex"))
      else
        []
      end
    end)
    |> Enum.reject(&String.contains?(&1, "/_build/"))
    |> Enum.reject(&String.contains?(&1, "/deps/"))
    |> Enum.filter(&File.exists?/1)
  end

  defp should_instrument_file?(file_path, ast, plan) do
    # Skip test files unless explicitly configured
    if String.contains?(file_path, "/test/") and not plan[:instrument_tests] do
      false
    else
      # Check if the module should be instrumented
      module_name = extract_module_name(ast)
      case module_name do
        :unknown -> false
        module -> 
          # Check if module is explicitly excluded
          if module_excluded?(module, plan) do
            false
          else
            # If there's a modules plan and it's not empty, only instrument modules in the plan
            modules_plan = plan[:modules] || %{}
            if Enum.empty?(modules_plan) do
              # No specific modules plan, instrument all non-excluded files
              true
            else
              # Only instrument modules that are in the plan
              Map.has_key?(modules_plan, module)
            end
          end
      end
    end
  end

  defp module_excluded?(module_name, plan) do
    excluded_modules = plan[:excluded_modules] || []
    
    # Check exact module name or pattern matches
    Enum.any?(excluded_modules, fn pattern ->
      case pattern do
        ^module_name -> true
        pattern when is_binary(pattern) -> 
          module_string = to_string(module_name)
          String.contains?(module_string, pattern)
        _ -> false
      end
    end)
  end

  defp extract_module_plan(ast, global_plan) do
    module_name = extract_module_name(ast)
    modules_plan = global_plan[:modules] || %{}
    Map.get(modules_plan, module_name, %{})
  end

  defp generate_output_path(input_path, config) do
    # Generate path in _build directory to avoid overwriting source
    # Use current working directory instead of stored project_root to handle test scenarios
    current_root = File.cwd!()
    relative_path = Path.relative_to(input_path, current_root)
    Path.join([to_string(config.build_path), to_string(config.target_env), "elixir_scope", relative_path])
  end

  defp ensure_output_directories(config) do
    output_dir = Path.join([to_string(config.build_path), to_string(config.target_env), "elixir_scope"])
    File.mkdir_p!(output_dir)
  end

  defp ensure_directory_exists(dir_path) do
    File.mkdir_p!(dir_path)
  end

  defp format_transformed_code(ast, original_file) do
    try do
      # Try to format with proper line breaks and indentation
      code = Macro.to_string(ast)
      
      # Add file header comment to track transformation
      header = """
      # This file was automatically instrumented by ElixirScope
      # Original: #{Path.relative_to_cwd(original_file)}
      # Generated: #{DateTime.utc_now() |> DateTime.to_iso8601()}

      """
      
      header <> code
    rescue
      _error ->
        # Fallback to basic conversion if formatting fails
        Macro.to_string(ast)
    end
  end

  # Helper functions for Mix.Task.Compiler behavior

  defp ensure_elixir_scope_started do
    case Application.ensure_all_started(:elixir_scope) do
      {:ok, _} -> :ok
      {:error, reason} -> 
        Mix.shell().error("Failed to start ElixirScope: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp get_or_create_instrumentation_plan(config) do
    case Orchestrator.get_instrumentation_plan() do
      {:ok, plan} ->
        {:ok, plan}

      {:error, :no_plan} ->
        # Generate plan if none exists
        Mix.shell().info("ElixirScope: Generating instrumentation plan...")
        case Orchestrator.analyze_and_plan(config.project_root) do
          {:ok, plan} -> 
            Mix.shell().info("ElixirScope: Plan generated successfully")
            {:ok, plan}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_argv(argv) do
    {opts, _args, _invalid} = OptionParser.parse(argv, 
      switches: [
        force: :boolean,
        debug: :boolean,
        minimal: :boolean,
        full_trace: :boolean
      ],
      aliases: [
        f: :force,
        d: :debug
      ]
    )

    project = Mix.Project.config()
    
    %{
      source_paths: project[:elixirc_paths] || ["lib"],
      build_path: project[:build_path] || "_build",
      project_root: File.cwd!(),
      force: opts[:force] || false,
      debug: opts[:debug] || false,
      strategy: determine_strategy(opts),
      target_env: Mix.env()
    }
  end

  defp determine_strategy(opts) do
    cond do
      opts[:minimal] -> :minimal
      opts[:full_trace] -> :full_trace
      true -> :balanced  # Default strategy
    end
  end

  defp extract_module_name(ast) do
    case ast do
      {:defmodule, _, [{:__aliases__, _, module_parts}, _]} ->
        Module.concat(module_parts)
      {:defmodule, _, [module_name, _]} when is_atom(module_name) ->
        module_name
      _ ->
        :unknown
    end
  end
end

# Backwards compatibility alias for tests
defmodule ElixirScope.Compiler.MixTask do
  defdelegate transform_ast(ast, plan), to: Mix.Tasks.Compile.ElixirScope
end
