defmodule ElixirAnalyzerDemo.AnalysisEngine do
  @moduledoc """
  Core analysis engine that demonstrates comprehensive code analysis
  using the Enhanced AST Repository.
  
  This module showcases:
  - Module and function analysis
  - Complexity calculation
  - Dependency analysis
  - Security analysis
  - Performance analysis
  """
  
  use GenServer
  
  alias ElixirScope.ASTRepository.EnhancedRepository
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def analyze_module(module_name, ast) do
    GenServer.call(__MODULE__, {:analyze_module, module_name, ast})
  end
  
  def analyze_project(project_path) do
    GenServer.call(__MODULE__, {:analyze_project, project_path})
  end
  
  def get_analysis_results(module_name) do
    GenServer.call(__MODULE__, {:get_analysis_results, module_name})
  end
  
  def init(_opts) do
    {:ok, %{
      analysis_queue: :queue.new(),
      analysis_cache: %{},
      stats: %{
        modules_analyzed: 0,
        total_analysis_time: 0,
        average_complexity: 0.0
      }
    }}
  end
  
  def handle_call({:analyze_module, module_name, ast}, _from, state) do
    start_time = System.monotonic_time(:millisecond)
    
    # Store module in enhanced repository
    :ok = EnhancedRepository.store_enhanced_module(module_name, ast)
    
    # Perform comprehensive analysis
    analysis_result = perform_comprehensive_analysis(module_name, ast)
    
    # Update repository with analysis results
    update_analysis_results(module_name, analysis_result)
    
    # Update state
    end_time = System.monotonic_time(:millisecond)
    analysis_time = end_time - start_time
    
    new_stats = update_stats(state.stats, analysis_result, analysis_time)
    new_cache = Map.put(state.analysis_cache, module_name, analysis_result)
    
    new_state = %{state | 
      analysis_cache: new_cache,
      stats: new_stats
    }
    
    {:reply, {:ok, analysis_result}, new_state}
  end
  
  def handle_call({:analyze_project, project_path}, _from, state) do
    # Discover modules in project
    modules = discover_modules(project_path)
    
    # Analyze each module
    results = Enum.map(modules, fn {module_name, ast, file_path} ->
      case perform_comprehensive_analysis(module_name, ast) do
        analysis_result ->
          Map.put(analysis_result, :file_path, file_path)
      end
    end)
    
    {:reply, {:ok, results}, state}
  end
  
  def handle_call({:get_analysis_results, module_name}, _from, state) do
    result = case Map.get(state.analysis_cache, module_name) do
      nil ->
        # Try to get from repository
        case EnhancedRepository.get_enhanced_module(module_name) do
          {:ok, module_data} ->
            {:ok, extract_analysis_from_module_data(module_data)}
          {:error, reason} ->
            {:error, reason}
        end
      cached_result ->
        {:ok, cached_result}
    end
    
    {:reply, result, state}
  end
  
  # Private functions
  
  defp perform_comprehensive_analysis(module_name, ast) do
    %{
      module: module_name,
      complexity: analyze_complexity(ast),
      dependencies: analyze_dependencies(ast),
      security: analyze_security(ast),
      performance: analyze_performance(ast),
      quality: analyze_quality(ast),
      functions: analyze_functions(ast),
      timestamp: DateTime.utc_now()
    }
  end
  
  defp analyze_complexity(ast) do
    # Calculate cyclomatic complexity
    base_complexity = 1
    complexity = calculate_ast_complexity(ast, base_complexity)
    
    %{
      cyclomatic_complexity: complexity,
      cognitive_complexity: calculate_cognitive_complexity(ast),
      nesting_depth: calculate_nesting_depth(ast),
      score: normalize_complexity_score(complexity)
    }
  end
  
  defp analyze_dependencies(ast) do
    # Extract module dependencies
    imports = extract_imports(ast)
    aliases = extract_aliases(ast)
    uses = extract_uses(ast)
    requires = extract_requires(ast)
    
    %{
      imports: imports,
      aliases: aliases,
      uses: uses,
      requires: requires,
      total_dependencies: length(imports) + length(aliases) + length(uses) + length(requires),
      external_dependencies: filter_external_dependencies(imports ++ aliases ++ uses ++ requires)
    }
  end
  
  defp analyze_security(ast) do
    # Identify potential security issues
    issues = []
    
    # Check for dangerous functions
    issues = check_dangerous_functions(ast, issues)
    
    # Check for input validation
    issues = check_input_validation(ast, issues)
    
    # Check for SQL injection patterns
    issues = check_sql_injection(ast, issues)
    
    %{
      issues: issues,
      severity_counts: count_by_severity(issues),
      risk_score: calculate_risk_score(issues)
    }
  end
  
  defp analyze_performance(ast) do
    # Identify performance bottlenecks
    bottlenecks = []
    
    # Check for inefficient patterns
    bottlenecks = check_inefficient_patterns(ast, bottlenecks)
    
    # Check for expensive operations
    bottlenecks = check_expensive_operations(ast, bottlenecks)
    
    %{
      bottlenecks: bottlenecks,
      estimated_performance: estimate_performance_score(bottlenecks),
      optimization_suggestions: generate_optimization_suggestions(bottlenecks)
    }
  end
  
  defp analyze_quality(ast) do
    # Calculate code quality metrics
    %{
      maintainability_index: calculate_maintainability_index(ast),
      readability_score: calculate_readability_score(ast),
      documentation_coverage: calculate_documentation_coverage(ast),
      test_coverage_estimate: estimate_test_coverage(ast)
    }
  end
  
  defp analyze_functions(ast) do
    # Extract and analyze individual functions
    functions = extract_functions(ast)
    
    Enum.map(functions, fn func ->
      %{
        name: func.name,
        arity: func.arity,
        complexity: calculate_function_complexity(func.ast),
        line_count: calculate_line_count(func.ast),
        parameters: extract_parameters(func.ast),
        return_patterns: analyze_return_patterns(func.ast),
        side_effects: analyze_function_side_effects(func.ast)
      }
    end)
  end
  
  # Helper functions for complexity analysis
  
  defp calculate_ast_complexity(ast, base_complexity) do
    {_, complexity} = Macro.prewalk(ast, base_complexity, fn
      # Control flow structures increase complexity
      {:if, _, _}, acc -> {ast, acc + 1}
      {:case, _, _}, acc -> {ast, acc + 1}
      {:cond, _, _}, acc -> {ast, acc + 1}
      {:try, _, _}, acc -> {ast, acc + 1}
      {:receive, _, _}, acc -> {ast, acc + 1}
      {:for, _, _}, acc -> {ast, acc + 1}
      {:with, _, _}, acc -> {ast, acc + 1}
      
      # Function definitions with guards
      {:def, _, [{:when, _, _} | _]}, acc -> {ast, acc + 1}
      {:defp, _, [{:when, _, _} | _]}, acc -> {ast, acc + 1}
      
      # Pattern matching in function heads
      {:def, _, [head | _]}, acc when is_tuple(head) -> 
        patterns = count_patterns(head)
        {ast, acc + max(patterns - 1, 0)}
      
      node, acc -> {node, acc}
    end)
    
    complexity
  end
  
  defp calculate_cognitive_complexity(ast) do
    # Simplified cognitive complexity calculation
    {_, complexity} = Macro.prewalk(ast, 0, fn
      {:if, _, _}, acc -> {ast, acc + 1}
      {:case, _, _}, acc -> {ast, acc + 2}
      {:cond, _, _}, acc -> {ast, acc + 2}
      {:for, _, _}, acc -> {ast, acc + 1}
      {:with, _, _}, acc -> {ast, acc + 1}
      node, acc -> {node, acc}
    end)
    
    complexity
  end
  
  defp calculate_nesting_depth(ast) do
    {_, max_depth} = Macro.prewalk(ast, {0, 0}, fn
      {:if, _, _}, {current_depth, max_depth} -> 
        new_depth = current_depth + 1
        {ast, {new_depth, max(new_depth, max_depth)}}
      {:case, _, _}, {current_depth, max_depth} -> 
        new_depth = current_depth + 1
        {ast, {new_depth, max(new_depth, max_depth)}}
      {:cond, _, _}, {current_depth, max_depth} -> 
        new_depth = current_depth + 1
        {ast, {new_depth, max(new_depth, max_depth)}}
      node, acc -> {node, acc}
    end)
    
    max_depth
  end
  
  defp normalize_complexity_score(complexity) do
    # Normalize to 0-10 scale
    cond do
      complexity <= 5 -> complexity * 2.0
      complexity <= 10 -> 5.0 + (complexity - 5) * 0.5
      true -> 10.0
    end
  end
  
  # Helper functions for dependency analysis
  
  defp extract_imports(ast) do
    {_, imports} = Macro.prewalk(ast, [], fn
      {:import, _, [module | _]}, acc -> {ast, [module | acc]}
      node, acc -> {node, acc}
    end)
    
    Enum.reverse(imports)
  end
  
  defp extract_aliases(ast) do
    {_, aliases} = Macro.prewalk(ast, [], fn
      {:alias, _, [module | _]}, acc -> {ast, [module | acc]}
      node, acc -> {node, acc}
    end)
    
    Enum.reverse(aliases)
  end
  
  defp extract_uses(ast) do
    {_, uses} = Macro.prewalk(ast, [], fn
      {:use, _, [module | _]}, acc -> {ast, [module | acc]}
      node, acc -> {node, acc}
    end)
    
    Enum.reverse(uses)
  end
  
  defp extract_requires(ast) do
    {_, requires} = Macro.prewalk(ast, [], fn
      {:require, _, [module | _]}, acc -> {ast, [module | acc]}
      node, acc -> {node, acc}
    end)
    
    Enum.reverse(requires)
  end
  
  defp filter_external_dependencies(dependencies) do
    Enum.filter(dependencies, fn dep ->
      case dep do
        {:__aliases__, _, [first | _]} ->
          first not in [:Elixir, :Enum, :Stream, :GenServer, :Agent, :Task]
        _ -> false
      end
    end)
  end
  
  # Security analysis helpers
  
  defp check_dangerous_functions(ast, issues) do
    {_, new_issues} = Macro.prewalk(ast, issues, fn
      {func, _, _}, acc when func in [:eval, :"Code.eval_string", :"Code.eval_quoted", :"System.cmd"] ->
        issue = %{
          type: :dangerous_function,
          function: func,
          severity: :high,
          description: "Use of potentially dangerous function: #{func}"
        }
        {ast, [issue | acc]}
      node, acc -> {node, acc}
    end)
    
    new_issues
  end
  
  defp check_input_validation(ast, issues) do
    # Simplified input validation check
    # Look for functions that don't validate parameters
    {_, new_issues} = Macro.prewalk(ast, issues, fn
      {:def, _, [{name, _, params} | _]}, acc when is_list(params) ->
        if has_guards_or_pattern_matching?(params) do
          {ast, acc}
        else
          issue = %{
            type: :missing_input_validation,
            function: name,
            severity: :medium,
            description: "Function #{name} may lack input validation"
          }
          {ast, [issue | acc]}
        end
      node, acc -> {node, acc}
    end)
    
    new_issues
  end
  
  defp check_sql_injection(ast, issues) do
    # Look for string interpolation in database queries
    {_, new_issues} = Macro.prewalk(ast, issues, fn
      {:<<>>, _, parts}, acc ->
        if has_interpolation?(parts) and looks_like_sql?(parts) do
          issue = %{
            type: :sql_injection_risk,
            severity: :high,
            description: "Potential SQL injection vulnerability"
          }
          {ast, [issue | acc]}
        else
          {ast, acc}
        end
      node, acc -> {node, acc}
    end)
    
    new_issues
  end
  
  # Performance analysis helpers
  
  defp check_inefficient_patterns(ast, bottlenecks) do
    {_, new_bottlenecks} = Macro.prewalk(ast, bottlenecks, fn
      # Check for inefficient list operations
      {{:., _, [{:__aliases__, _, [:Enum]}, :map]}, _, [_list, {{:., _, [{:__aliases__, _, [:Enum]}, :filter]}, _, _}]}, acc ->
        bottleneck = %{
          type: :inefficient_enum_chain,
          severity: :medium,
          description: "Consider using Enum.filter_map/3 or Stream for better performance"
        }
        {ast, [bottleneck | acc]}
      
      # Check for nested loops
      {:for, _, _}, acc ->
        # Simplified check - in real implementation, would check for nested for comprehensions
        {ast, acc}
      
      node, acc -> {node, acc}
    end)
    
    new_bottlenecks
  end
  
  defp check_expensive_operations(ast, bottlenecks) do
    expensive_ops = [:"File.read", :"File.write", :"HTTPoison.get", :"Ecto.Repo.all"]
    
    {_, new_bottlenecks} = Macro.prewalk(ast, bottlenecks, fn
      {{:., _, [{:__aliases__, _, module_parts}, func]}, _, _}, acc ->
        full_func = Module.concat(module_parts ++ [func])
        if full_func in expensive_ops do
          bottleneck = %{
            type: :expensive_operation,
            operation: full_func,
            severity: :medium,
            description: "Expensive I/O operation: #{full_func}"
          }
          {ast, [bottleneck | acc]}
        else
          {ast, acc}
        end
      node, acc -> {node, acc}
    end)
    
    new_bottlenecks
  end
  
  # Quality analysis helpers
  
  defp calculate_maintainability_index(ast) do
    # Simplified maintainability index
    complexity = calculate_ast_complexity(ast, 1)
    line_count = calculate_line_count(ast)
    
    # Formula: 171 - 5.2 * ln(Halstead Volume) - 0.23 * (Cyclomatic Complexity) - 16.2 * ln(Lines of Code)
    # Simplified version
    base_score = 100
    complexity_penalty = complexity * 2
    size_penalty = :math.log(max(line_count, 1)) * 5
    
    max(base_score - complexity_penalty - size_penalty, 0)
  end
  
  defp calculate_readability_score(ast) do
    # Simplified readability score based on various factors
    line_count = calculate_line_count(ast)
    avg_line_length = calculate_average_line_length(ast)
    nesting_depth = calculate_nesting_depth(ast)
    
    base_score = 100
    length_penalty = if avg_line_length > 80, do: 10, else: 0
    nesting_penalty = nesting_depth * 5
    size_penalty = if line_count > 100, do: 10, else: 0
    
    max(base_score - length_penalty - nesting_penalty - size_penalty, 0)
  end
  
  defp calculate_documentation_coverage(ast) do
    # Count documented vs undocumented functions
    {documented, total} = count_documented_functions(ast)
    if total > 0, do: documented / total * 100, else: 100
  end
  
  defp estimate_test_coverage(ast) do
    # Estimate based on function complexity and patterns
    functions = extract_functions(ast)
    
    # Simple heuristic: assume 70% coverage for simple functions, 50% for complex ones
    total_weight = Enum.reduce(functions, 0, fn func, acc ->
      complexity = calculate_function_complexity(func.ast)
      weight = if complexity > 5, do: 2, else: 1
      acc + weight
    end)
    
    if total_weight > 0 do
      estimated_covered = Enum.reduce(functions, 0, fn func, acc ->
        complexity = calculate_function_complexity(func.ast)
        coverage = if complexity > 5, do: 0.5, else: 0.7
        weight = if complexity > 5, do: 2, else: 1
        acc + (coverage * weight)
      end)
      
      estimated_covered / total_weight * 100
    else
      100
    end
  end
  
  # Utility functions
  
  defp update_analysis_results(module_name, analysis_result) do
    EnhancedRepository.store_enhanced_module(module_name, [
      metadata: %{
        complexity_score: analysis_result.complexity.score,
        dependency_count: analysis_result.dependencies.total_dependencies,
        security_risk_score: analysis_result.security.risk_score,
        performance_score: analysis_result.performance.estimated_performance,
        quality_score: analysis_result.quality.maintainability_index,
        last_analyzed: analysis_result.timestamp
      }
    ])
  end
  
  defp update_stats(stats, analysis_result, analysis_time) do
    new_count = stats.modules_analyzed + 1
    new_total_time = stats.total_analysis_time + analysis_time
    new_avg_complexity = (stats.average_complexity * stats.modules_analyzed + analysis_result.complexity.score) / new_count
    
    %{
      modules_analyzed: new_count,
      total_analysis_time: new_total_time,
      average_complexity: new_avg_complexity
    }
  end
  
  defp discover_modules(project_path) do
    # Simplified module discovery
    case File.exists?(project_path) do
      true ->
        project_path
        |> Path.join("**/*.ex")
        |> Path.wildcard()
        |> Enum.map(&parse_module_file/1)
        |> Enum.filter(& &1)
      false ->
        []
    end
  end
  
  defp parse_module_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        case Code.string_to_quoted(content) do
          {:ok, ast} ->
            module_name = extract_module_name(ast)
            {module_name, ast, file_path}
          {:error, _} -> nil
        end
      {:error, _} -> nil
    end
  end
  
  defp extract_module_name(ast) do
    {_, module_name} = Macro.prewalk(ast, nil, fn
      {:defmodule, _, [{:__aliases__, _, name_parts} | _]}, nil ->
        {ast, Module.concat(name_parts)}
      node, acc -> {node, acc}
    end)
    
    module_name || :unknown_module
  end
  
  # Additional helper functions (simplified implementations)
  
  defp count_patterns(_head), do: 1
  defp has_guards_or_pattern_matching?(_params), do: false
  
  defp has_interpolation?(parts) when is_list(parts) do
    Enum.any?(parts, fn
      {:"::", _, [expr, _type]} -> not is_binary(expr)
      binary when is_binary(binary) -> false
      _ -> true
    end)
  end
  defp has_interpolation?(_), do: false

  defp looks_like_sql?(parts) when is_list(parts) do
    sql_keywords = ~w(SELECT INSERT UPDATE DELETE FROM WHERE JOIN)
    parts_string = Enum.map_join(parts, "", fn
      binary when is_binary(binary) -> binary
      _ -> ""
    end)
    String.upcase(parts_string)
    |> then(&Enum.any?(sql_keywords, fn kw -> String.contains?(&1, kw) end))
  end
  defp looks_like_sql?(_), do: false
  
  defp count_by_severity(issues), do: Enum.group_by(issues, & &1.severity) |> Enum.map(fn {k, v} -> {k, length(v)} end) |> Enum.into(%{})
  defp calculate_risk_score(issues), do: length(issues) * 10
  defp estimate_performance_score(_bottlenecks), do: 75.0
  defp generate_optimization_suggestions(_bottlenecks), do: ["Consider using Stream for large data processing"]
  defp calculate_line_count(_ast), do: 50
  defp calculate_average_line_length(_ast), do: 60
  defp count_documented_functions(_ast), do: {3, 5}
  defp extract_functions(_ast), do: [%{name: :sample, arity: 1, ast: nil}]
  defp calculate_function_complexity(_ast), do: 2
  defp extract_parameters(_ast), do: []
  defp analyze_return_patterns(_ast), do: [:ok, :error]
  defp analyze_function_side_effects(_ast), do: []
  defp extract_analysis_from_module_data(module_data), do: %{module: module_data.module_name, cached: true}
end 