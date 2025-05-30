defmodule ElixirScope.ASTRepository.Enhanced.ProjectPopulator.OptimizationHints do
  @moduledoc """
  Generates optimization hints for modules and functions.

  Provides functionality to:
  - Generate performance hints
  - Identify optimization opportunities
  - Suggest code improvements
  - Analyze bottlenecks
  """

  @doc """
  Generates performance hints for a module.
  """
  def generate_module_performance_hints(_ast, functions) do
    function_hints = functions
    |> Map.values()
    |> Enum.flat_map(fn func -> func.optimization_hints || [] end)

    function_hints
  end

  @doc """
  Generates optimization hints for a function.
  """
  def generate_function_optimization_hints(func_ast, cfg_data, _dfg_data) do
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

  # Private functions

  defp calculate_nesting_depth(ast) do
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
end
