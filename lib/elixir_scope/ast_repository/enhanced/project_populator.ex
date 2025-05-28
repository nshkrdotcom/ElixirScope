defmodule ElixirScope.ASTRepository.Enhanced.ProjectPopulator do
  @moduledoc """
  Enhanced project populator for comprehensive AST analysis and repository population.
  
  Provides functionality to:
  - Discover and parse all Elixir files in a project
  - Generate enhanced module and function data with CFG/DFG/CPG analysis
  - Populate the enhanced repository with analyzed data
  - Track dependencies and build project-wide analysis
  - Support parallel processing for large projects
  """
  
  require Logger
  
  alias ElixirScope.ASTRepository.Enhanced.{
    Repository,
    EnhancedModuleData,
    EnhancedFunctionData,
    CFGGenerator,
    DFGGenerator,
    CPGBuilder
  }
  
  @default_opts [
    include_patterns: ["**/*.ex", "**/*.exs"],
    exclude_patterns: ["**/deps/**", "**/build/**", "**/_build/**", "**/node_modules/**"],
    max_file_size: 1_000_000,  # 1MB
    parallel_processing: true,
    max_concurrency: System.schedulers_online(),
    timeout: 30_000,
    generate_cfg: true,
    generate_dfg: true,
    generate_cpg: false,  # CPG is expensive, opt-in
    validate_syntax: true,
    track_dependencies: true
  ]
  
  @doc """
  Populates the repository with all Elixir files in a project.
  
  Returns {:ok, results} or {:error, reason}
  """
  def populate_project(repo, project_path, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)
    
    Logger.info("Starting project population for: #{project_path}")
    start_time = System.monotonic_time(:microsecond)
    
    try do
      with {:ok, files} <- discover_elixir_files(project_path, opts),
           {:ok, parsed_files} <- parse_files(files, opts),
           {:ok, analyzed_modules} <- analyze_modules(parsed_files, opts),
           {:ok, dependency_graph} <- build_dependency_graph(analyzed_modules, opts) do
        
        # Store modules in repository
        try do
          Enum.each(analyzed_modules, fn {_module_name, module_data} ->
            Repository.store_module(repo, module_data)
            
            # Store functions
            Enum.each(module_data.functions, fn {_key, function_data} ->
              Repository.store_function(repo, function_data)
            end)
          end)
        rescue
          e ->
            Logger.error("Failed to store modules in repository: #{Exception.message(e)}")
            raise {:repository_storage_failed, Exception.message(e)}
        catch
          :exit, reason ->
            Logger.error("Repository process exited during storage: #{inspect(reason)}")
            raise {:repository_unavailable, reason}
        end
        
        end_time = System.monotonic_time(:microsecond)
        duration = end_time - start_time
        
        results = %{
          project_path: project_path,
          files_discovered: length(files),
          files_parsed: length(parsed_files),
          modules: analyzed_modules,
          total_functions: count_total_functions(analyzed_modules),
          dependency_graph: dependency_graph,
          duration_microseconds: duration,
          performance_metrics: calculate_performance_metrics(parsed_files, analyzed_modules, duration)
        }
        
        Logger.info("Project population completed: #{length(analyzed_modules)} modules, #{results.total_functions} functions in #{duration / 1000}ms")
        {:ok, results}
      else
        {:error, reason} = error ->
          Logger.error("Project population failed: #{inspect(reason)}")
          error
      end
    rescue
      e ->
        Logger.error("Project population crashed: #{Exception.message(e)}")
        {:error, {:population_crashed, Exception.message(e)}}
    end
  end
  

  
  @doc """
  Parses and analyzes a single file (used by Synchronizer).
  """
  def parse_and_analyze_file(file_path) do
    try do
      with {:ok, parsed_file} <- parse_single_file(file_path, true, 30_000),
           {:ok, {_module_name, module_data}} <- analyze_single_module(parsed_file, true, true, false, 30_000) do
        {:ok, module_data}
      else
        {:error, reason} -> {:error, reason}
      end
    rescue
      e ->
        {:error, {:parse_and_analyze_failed, Exception.message(e)}}
    end
  end
  
  @doc """
  Discovers all Elixir files in a project directory.
  """
  def discover_elixir_files(project_path, opts \\ []) do
    include_patterns = Keyword.get(opts, :include_patterns, ["**/*.ex", "**/*.exs"])
    exclude_patterns = Keyword.get(opts, :exclude_patterns, [])
    max_file_size = Keyword.get(opts, :max_file_size, 1_000_000)
    
    # Check if directory exists
    if not (File.exists?(project_path) and File.dir?(project_path)) do
      {:error, :directory_not_found}
    else
      try do
      files = include_patterns
      |> Enum.flat_map(fn pattern ->
        Path.wildcard(Path.join(project_path, pattern))
      end)
      |> Enum.uniq()
      |> Enum.reject(fn file ->
        Enum.any?(exclude_patterns, fn pattern ->
          String.contains?(file, pattern)
        end)
      end)
      |> Enum.filter(fn file ->
        case File.stat(file) do
          {:ok, %{size: size}} when size <= max_file_size -> true
          _ -> false
        end
      end)
      |> Enum.sort()
      
      Logger.debug("Discovered #{length(files)} Elixir files")
      {:ok, files}
          rescue
        e ->
          {:error, {:file_discovery_failed, Exception.message(e)}}
      end
    end
  end
  
  @doc """
  Parses AST from discovered files.
  """
  def parse_files(files, opts \\ []) do
    parallel = Keyword.get(opts, :parallel_processing, true)
    max_concurrency = Keyword.get(opts, :max_concurrency, System.schedulers_online())
    validate_syntax = Keyword.get(opts, :validate_syntax, true)
    timeout = Keyword.get(opts, :timeout, 30_000)
    
    parse_function = fn file ->
      parse_single_file(file, validate_syntax, timeout)
    end
    
    try do
      parsed_files = if parallel do
        files
        |> Task.async_stream(parse_function, 
           max_concurrency: max_concurrency,
           timeout: timeout,
           on_timeout: :kill_task)
        |> Enum.reduce([], fn
          {:ok, {:ok, parsed_file}}, acc -> [parsed_file | acc]
          {:ok, {:error, reason}}, acc -> 
            Logger.warning("Failed to parse file: #{inspect(reason)}")
            acc
          {:exit, reason}, acc ->
            Logger.warning("File parsing timed out: #{inspect(reason)}")
            acc
        end)
        |> Enum.reverse()
      else
        Enum.reduce(files, [], fn file, acc ->
          case parse_function.(file) do
            {:ok, parsed_file} -> [parsed_file | acc]
            {:error, reason} ->
              Logger.warning("Failed to parse #{file}: #{inspect(reason)}")
              acc
          end
        end)
        |> Enum.reverse()
      end
      
      Logger.debug("Successfully parsed #{length(parsed_files)} files")
      {:ok, parsed_files}
    rescue
      e ->
        {:error, {:file_parsing_failed, Exception.message(e)}}
    end
  end
  
  @doc """
  Analyzes parsed modules with enhanced analysis.
  """
  def analyze_modules(parsed_files, opts \\ []) do
    generate_cfg = Keyword.get(opts, :generate_cfg, true)
    generate_dfg = Keyword.get(opts, :generate_dfg, true)
    generate_cpg = Keyword.get(opts, :generate_cpg, false)
    parallel = Keyword.get(opts, :parallel_processing, true)
    max_concurrency = Keyword.get(opts, :max_concurrency, System.schedulers_online())
    timeout = Keyword.get(opts, :timeout, 30_000)
    
    analysis_function = fn parsed_file ->
      analyze_single_module(parsed_file, generate_cfg, generate_dfg, generate_cpg, timeout)
    end
    
    try do
      analyzed_modules = if parallel do
        parsed_files
        |> Task.async_stream(analysis_function,
           max_concurrency: max_concurrency,
           timeout: timeout,
           on_timeout: :kill_task)
        |> Enum.reduce(%{}, fn
          {:ok, {:ok, {module_name, module_data}}}, acc -> Map.put(acc, module_name, module_data)
          {:ok, {:error, reason}}, acc ->
            Logger.warning("Failed to analyze module: #{inspect(reason)}")
            acc
          {:exit, reason}, acc ->
            Logger.warning("Module analysis timed out: #{inspect(reason)}")
            acc
        end)
      else
        Enum.reduce(parsed_files, %{}, fn parsed_file, acc ->
          case analysis_function.(parsed_file) do
            {:ok, {module_name, module_data}} -> Map.put(acc, module_name, module_data)
            {:error, reason} ->
              Logger.warning("Failed to analyze #{parsed_file.file_path}: #{inspect(reason)}")
              acc
          end
        end)
      end
      
      Logger.debug("Successfully analyzed #{map_size(analyzed_modules)} modules")
      {:ok, analyzed_modules}
    rescue
      e ->
        {:error, {:module_analysis_failed, Exception.message(e)}}
    end
  end
  
  @doc """
  Builds dependency graph from analyzed modules.
  """
  def build_dependency_graph(analyzed_modules, opts \\ []) do
    track_dependencies = Keyword.get(opts, :track_dependencies, true)
    
    if track_dependencies do
      try do
        dependency_graph = %{
          nodes: Map.keys(analyzed_modules),
          edges: extract_dependency_edges(analyzed_modules),
          cycles: detect_dependency_cycles(analyzed_modules),
          levels: calculate_dependency_levels(analyzed_modules)
        }
        
        {:ok, dependency_graph}
      rescue
        e ->
          Logger.warning("Failed to build dependency graph: #{Exception.message(e)}")
          {:ok, %{nodes: [], edges: [], cycles: [], levels: %{}}}
      end
    else
      {:ok, %{nodes: [], edges: [], cycles: [], levels: %{}}}
    end
  end
  
  # Private implementation functions
  
  defp parse_single_file(file_path, validate_syntax, _timeout) do
    start_time = System.monotonic_time(:microsecond)
    
    try do
      case File.read(file_path) do
        {:ok, content} ->
          case Code.string_to_quoted(content, file: file_path) do
            {:ok, ast} ->
              if validate_syntax do
                case validate_ast_syntax(ast) do
                  :ok ->
                    end_time = System.monotonic_time(:microsecond)
                    parsed_file = %{
                      file_path: file_path,
                      content: content,
                      ast: ast,
                      module_name: extract_module_name(ast),
                      parse_time: end_time - start_time,
                      file_size: byte_size(content),
                      line_count: count_lines(content)
                    }
                    {:ok, parsed_file}
                  
                  {:error, reason} ->
                    {:error, {:syntax_validation_failed, file_path, reason}}
                end
              else
                end_time = System.monotonic_time(:microsecond)
                parsed_file = %{
                  file_path: file_path,
                  content: content,
                  ast: ast,
                  module_name: extract_module_name(ast),
                  parse_time: end_time - start_time,
                  file_size: byte_size(content),
                  line_count: count_lines(content)
                }
                {:ok, parsed_file}
              end
            
            {:error, reason} ->
              {:error, {:ast_parsing_failed, file_path, reason}}
          end
        
        {:error, reason} ->
          {:error, {:file_read_failed, file_path, reason}}
      end
    rescue
      e ->
        {:error, {:file_processing_crashed, file_path, Exception.message(e)}}
    end
  end
  
  defp analyze_single_module(parsed_file, generate_cfg, generate_dfg, generate_cpg, _timeout) do
    start_time = System.monotonic_time(:microsecond)
    
    try do
      module_name = parsed_file.module_name
      
      if module_name do
        # Extract functions from module
        functions = extract_functions_from_module(parsed_file.ast)
        
        # Analyze each function
        analyzed_functions = Enum.reduce(functions, %{}, fn {func_name, arity, func_ast}, acc ->
          case analyze_single_function(module_name, func_name, arity, func_ast, 
                                     generate_cfg, generate_dfg, generate_cpg) do
            {:ok, function_data} ->
              Map.put(acc, {func_name, arity}, function_data)
            
            {:error, reason} ->
              Logger.warning("Failed to analyze function #{module_name}.#{func_name}/#{arity}: #{inspect(reason)}")
              acc
          end
        end)
        
        # Create enhanced module data
        enhanced_module = %EnhancedModuleData{
          module_name: module_name,
          file_path: parsed_file.file_path,
          ast: parsed_file.ast,
          functions: analyzed_functions,
          dependencies: extract_module_dependencies(parsed_file.ast),
          exports: extract_module_exports(parsed_file.ast),
          attributes: extract_module_attributes(parsed_file.ast),
          complexity_metrics: calculate_module_complexity_metrics(parsed_file.ast, analyzed_functions),
          quality_metrics: calculate_module_quality_metrics(parsed_file.ast, analyzed_functions),
          security_analysis: perform_module_security_analysis(parsed_file.ast, analyzed_functions),
          performance_hints: generate_module_performance_hints(parsed_file.ast, analyzed_functions),
          file_size: parsed_file.file_size,
          line_count: parsed_file.line_count,
          created_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }
        
        end_time = System.monotonic_time(:microsecond)
        Logger.debug("Analyzed module #{module_name} in #{(end_time - start_time) / 1000}ms")
        
        {:ok, {module_name, enhanced_module}}
      else
        {:error, {:no_module_found, parsed_file.file_path}}
      end
    rescue
      e ->
        {:error, {:module_analysis_crashed, parsed_file.file_path, Exception.message(e)}}
    end
  end
  
  defp analyze_single_function(module_name, func_name, arity, func_ast, generate_cfg, generate_dfg, generate_cpg) do
    try do
      # Generate CFG if requested
      cfg_data = if generate_cfg do
        case CFGGenerator.generate_cfg(func_ast) do
          {:ok, cfg} -> cfg
          {:error, reason} -> 
            Logger.warning("CFG generation failed for #{func_name}/#{arity}: #{inspect(reason)}")
            nil
        end
      else
        nil
      end
      
      # Generate DFG if requested
      dfg_data = if generate_dfg do
        case DFGGenerator.generate_dfg(func_ast) do
          {:ok, dfg} -> dfg
          {:error, reason} -> 
            Logger.warning("DFG generation failed for #{func_name}/#{arity}: #{inspect(reason)}")
            nil
        end
      else
        nil
      end
      
      # Generate CPG if requested
      cpg_data = if generate_cpg do
        case CPGBuilder.build_cpg(func_ast) do
          {:ok, cpg} -> cpg
          {:error, reason} -> 
            Logger.warning("CPG generation failed for #{func_name}/#{arity}: #{inspect(reason)}")
            nil
        end
      else
        nil
      end
      
      # Create enhanced function data
      enhanced_function = %EnhancedFunctionData{
        module_name: module_name,
        function_name: func_name,
        arity: arity,
        ast: func_ast,
        cfg_data: cfg_data,
        dfg_data: dfg_data,
        cpg_data: cpg_data,
        complexity_metrics: calculate_function_complexity_metrics(func_ast, cfg_data, dfg_data),
        performance_analysis: analyze_function_performance_characteristics(func_ast, cfg_data, dfg_data),
        security_analysis: analyze_function_security_characteristics(func_ast, cpg_data),
        optimization_hints: generate_function_optimization_hints(func_ast, cfg_data, dfg_data),
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
      
      {:ok, enhanced_function}
    rescue
      e ->
        Logger.error("Function analysis crashed for #{func_name}/#{arity}: #{Exception.message(e)}")
        {:error, {:function_analysis_crashed, Exception.message(e)}}
    end
  end
  
  # AST extraction and analysis helpers
  
  defp extract_module_name(ast) do
    case ast do
      {:defmodule, _, [module_alias, _body]} ->
        case module_alias do
          {:__aliases__, _, parts} -> Module.concat(parts)
          atom when is_atom(atom) -> atom
          _ -> nil
        end
      _ -> nil
    end
  end
  
  defp extract_functions_from_module(ast) do
    case ast do
      {:defmodule, _, [_module_name, [do: body]]} ->
        extract_functions_from_body(body, [])
      _ -> []
    end
  end
  
  defp extract_functions_from_body({:__block__, _, statements}, acc) do
    Enum.reduce(statements, acc, &extract_function_from_statement/2)
  end
  defp extract_functions_from_body(statement, acc) do
    extract_function_from_statement(statement, acc)
  end
  
  defp extract_function_from_statement({:def, meta, [{:when, _, [{name, _, args}, _guard]}, body]}, acc) do
    arity = if is_list(args), do: length(args), else: 0
    [{name, arity, {:def, meta, [{name, [], args || []}, body]}} | acc]
  end
  defp extract_function_from_statement({:defp, meta, [{:when, _, [{name, _, args}, _guard]}, body]}, acc) do
    arity = if is_list(args), do: length(args), else: 0
    [{name, arity, {:defp, meta, [{name, [], args || []}, body]}} | acc]
  end
  defp extract_function_from_statement({:def, meta, [{name, _, args}, body]}, acc) do
    arity = if is_list(args), do: length(args), else: 0
    [{name, arity, {:def, meta, [{name, [], args || []}, body]}} | acc]
  end
  defp extract_function_from_statement({:defp, meta, [{name, _, args}, body]}, acc) do
    arity = if is_list(args), do: length(args), else: 0
    [{name, arity, {:defp, meta, [{name, [], args || []}, body]}} | acc]
  end
  defp extract_function_from_statement(_, acc), do: acc
  
  defp extract_module_dependencies(_ast) do
    # Extract alias, import, use, and require statements
    dependencies = []
    
    # This would be a more sophisticated implementation
    # For now, return empty list
    dependencies
  end
  
  defp extract_module_exports(_ast) do
    # Extract @spec and public function definitions
    exports = []
    
    # This would be a more sophisticated implementation
    # For now, return empty list
    exports
  end
  
  defp extract_module_attributes(_ast) do
    # Extract module attributes like @moduledoc, @doc, @spec, etc.
    attributes = %{}
    
    # This would be a more sophisticated implementation
    # For now, return empty map
    attributes
  end
  
  # Complexity and quality analysis
  
  defp calculate_module_complexity_metrics(ast, functions) do
    function_complexities = functions
    |> Map.values()
    |> Enum.map(fn func -> func.complexity_metrics.combined_complexity || 1.0 end)
    
    %{
      combined_complexity: Enum.sum(function_complexities),
      average_function_complexity: if(length(function_complexities) > 0, do: Enum.sum(function_complexities) / length(function_complexities), else: 1.0),
      max_function_complexity: Enum.max(function_complexities ++ [1.0]),
      function_count: map_size(functions),
      lines_of_code: count_ast_lines(ast)
    }
  end
  
  defp calculate_module_quality_metrics(ast, functions) do
    %{
      maintainability_index: 85.0,  # Simplified calculation
      test_coverage: 0.0,  # Would need test analysis
      documentation_coverage: calculate_documentation_coverage(ast, functions),
      code_duplication: 0.0  # Would need duplication analysis
    }
  end
  
  defp perform_module_security_analysis(_ast, functions) do
    function_issues = functions
    |> Map.values()
    |> Enum.flat_map(fn func -> func.security_analysis.issues || [] end)
    
    %{
      has_vulnerabilities: length(function_issues) > 0,
      issues: function_issues,
      security_score: if(length(function_issues) == 0, do: 100.0, else: max(0.0, 100.0 - length(function_issues) * 10))
    }
  end
  
  defp generate_module_performance_hints(_ast, functions) do
    function_hints = functions
    |> Map.values()
    |> Enum.flat_map(fn func -> func.optimization_hints || [] end)
    
    function_hints
  end
  
  defp calculate_function_complexity_metrics(func_ast, cfg_data, dfg_data) do
    cfg_complexity = if cfg_data, do: cfg_data.complexity_metrics.cyclomatic || 1, else: 1
    # DFG doesn't have complexity metrics, calculate based on data flow complexity
    dfg_complexity = if dfg_data do
      # Calculate data flow complexity based on number of variables and flows
      # Handle both map and list formats for variables (defensive programming)
      variable_count = case dfg_data.variables do
        variables when is_map(variables) -> map_size(variables)
        variables when is_list(variables) -> length(variables)
        nil -> 0
        _ -> 0
      end
      flow_count = length(dfg_data.data_flows || [])
      max(1, variable_count + flow_count)
    else
      1
    end
    
    %{
      combined_complexity: Float.round(cfg_complexity * 0.7 + dfg_complexity * 0.3, 2),
      cyclomatic_complexity: cfg_complexity,
      data_flow_complexity: dfg_complexity,
      cognitive_complexity: calculate_cognitive_complexity(func_ast),
      nesting_depth: calculate_nesting_depth(func_ast)
    }
  end
  
  defp analyze_function_performance_characteristics(func_ast, cfg_data, _dfg_data) do
    # Simplified performance analysis
    has_loops = detect_loops_in_ast(func_ast)
    has_recursion = detect_recursion_in_ast(func_ast)
    complexity = if cfg_data, do: cfg_data.complexity_metrics.cyclomatic || 1, else: 1
    
    %{
      has_issues: complexity > 10 or has_loops or has_recursion,
      bottlenecks: [],
      performance_score: max(0.0, 100.0 - complexity * 5),
      optimization_potential: if(complexity > 5, do: :high, else: :low)
    }
  end
  
  defp analyze_function_security_characteristics(_func_ast, _cpg_data) do
    # Simplified security analysis
    %{
      has_vulnerabilities: false,
      issues: [],
      security_score: 100.0
    }
  end
  
  defp generate_function_optimization_hints(func_ast, cfg_data, _dfg_data) do
    hints = []
    
    # Check for high complexity
    complexity = if cfg_data, do: cfg_data.complexity_metrics.cyclomatic || 1, else: 1
    hints = if complexity > 10 do
      [%{type: :high_complexity, message: "Consider breaking down this function", severity: :warning} | hints]
    else
      hints
    end
    
    # Check for deep nesting
    nesting = calculate_nesting_depth(func_ast)
    hints = if nesting > 4 do
      [%{type: :deep_nesting, message: "Consider reducing nesting depth", severity: :info} | hints]
    else
      hints
    end
    
    hints
  end
  
  # Dependency analysis
  
  defp extract_dependency_edges(analyzed_modules) do
    # Extract module-to-module dependencies
    Enum.flat_map(analyzed_modules, fn {module_name, module_data} ->
      Enum.map(module_data.dependencies, fn dep ->
        {module_name, dep}
      end)
    end)
  end
  
  defp detect_dependency_cycles(_analyzed_modules) do
    # Simplified cycle detection
    # In a real implementation, this would use graph algorithms
    []
  end
  
  defp calculate_dependency_levels(analyzed_modules) do
    # Calculate dependency levels for topological ordering
    # Simplified implementation
    analyzed_modules
    |> Map.keys()
    |> Enum.with_index()
    |> Enum.into(%{}, fn {module, index} -> {module, index} end)
  end
  
  # Utility functions
  
  defp validate_ast_syntax(ast) do
    # Basic AST validation
    case ast do
      nil -> {:error, :nil_ast}
      {:__block__, _, []} -> {:error, :empty_block}
      _ -> :ok
    end
  end
  
  defp count_lines(content) do
    content
    |> String.split("\n")
    |> length()
  end
  
  defp count_ast_lines(ast) do
    # Simplified line counting from AST
    # In practice, this would traverse the AST and count unique line numbers
    50  # Placeholder
  end
  
  defp calculate_documentation_coverage(_ast, _functions) do
    # Simplified documentation coverage calculation
    75.0  # Placeholder
  end
  
  defp calculate_cognitive_complexity(_ast) do
    # Simplified cognitive complexity calculation
    5  # Placeholder
  end
  
  defp calculate_nesting_depth(ast) do
    # Simplified nesting depth calculation
    calculate_nesting_recursive(ast, 0)
  end
  
  defp calculate_nesting_recursive(ast, current_depth) do
    case ast do
      {:if, _, _} -> current_depth + 1
      {:case, _, _} -> current_depth + 1
      {:cond, _, _} -> current_depth + 1
      {:try, _, _} -> current_depth + 1
      {:with, _, _} -> current_depth + 1
      {:for, _, _} -> current_depth + 1
      {:__block__, _, statements} ->
        Enum.map(statements, &calculate_nesting_recursive(&1, current_depth))
        |> Enum.max(fn -> current_depth end)
      {_, _, children} when is_list(children) ->
        Enum.map(children, &calculate_nesting_recursive(&1, current_depth))
        |> Enum.max(fn -> current_depth end)
      _ -> current_depth
    end
  end
  
  defp detect_loops_in_ast(ast) do
    # Simplified loop detection
    case ast do
      {:for, _, _} -> true
      {:while, _, _} -> true
      {:__block__, _, statements} -> Enum.any?(statements, &detect_loops_in_ast/1)
      {_, _, children} when is_list(children) -> Enum.any?(children, &detect_loops_in_ast/1)
      _ -> false
    end
  end
  
  defp detect_recursion_in_ast(ast) do
    # Simplified recursion detection
    # In practice, this would analyze function calls
    false
  end
  
  defp count_total_functions(analyzed_modules) do
    analyzed_modules
    |> Map.values()
    |> Enum.map(fn module -> map_size(module.functions) end)
    |> Enum.sum()
  end
  
  defp calculate_performance_metrics(parsed_files, analyzed_modules, total_duration) do
    file_count = length(parsed_files)
    module_count = map_size(analyzed_modules)
    duration_seconds = total_duration / 1_000_000
    
    %{
      total_duration_ms: total_duration / 1000,
      avg_parse_time_ms: if(file_count > 0, do: (Enum.sum(Enum.map(parsed_files, & &1.parse_time)) / file_count) / 1000, else: 0.0),
      files_per_second: if(duration_seconds > 0, do: file_count / duration_seconds, else: 0.0),
      modules_per_second: if(duration_seconds > 0, do: module_count / duration_seconds, else: 0.0),
      total_file_size: Enum.sum(Enum.map(parsed_files, & &1.file_size)),
      total_lines: Enum.sum(Enum.map(parsed_files, & &1.line_count))
    }
  end
end 