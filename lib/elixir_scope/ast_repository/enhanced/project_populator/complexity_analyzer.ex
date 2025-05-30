defmodule ElixirScope.ASTRepository.Enhanced.ProjectPopulator.ComplexityAnalyzer do
  @moduledoc """
  Analyzes complexity metrics for modules and functions.

  Provides functionality to:
  - Calculate module complexity metrics
  - Calculate function complexity metrics
  - Analyze performance characteristics
  - Detect complexity patterns
  """

  @doc """
  Calculates complexity metrics for a module.
  """
  def calculate_module_complexity_metrics(ast, functions) do
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

  @doc """
  Calculates complexity metrics for a function.
  """
  def calculate_function_complexity_metrics(func_ast, cfg_data, dfg_data) do
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

  @doc """
  Analyzes performance characteristics of a function.
  """
  def analyze_function_performance_characteristics(func_ast, cfg_data, _dfg_data) do
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

  # Private functions

  defp count_ast_lines(ast) do
    # Simplified line counting from AST
    # In practice, this would traverse the AST and count unique line numbers
    50  # Placeholder
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
end
