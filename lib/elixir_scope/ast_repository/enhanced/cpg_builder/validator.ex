defmodule ElixirScope.ASTRepository.Enhanced.CPGBuilder.Validator do
  @moduledoc """
  AST validation and analysis for CPG building.

  Handles validation of AST structures, detection of problematic constructs,
  and interprocedural analysis checks.
  """

  @doc """
  Validates AST structure for CPG generation.

  Returns :ok or {:error, reason}
  """
  def validate_ast({:invalid, :ast, :structure}), do: {:error, :invalid_ast}
  def validate_ast(nil), do: {:error, :nil_ast}
  def validate_ast(ast) do
    case contains_invalid_construct(ast) do
      true -> {:error, :cfg_generation_failed}
      false -> :ok
    end
  end

  @doc """
  Checks if AST contains multiple function definitions (interprocedural).

  Returns true if interprocedural analysis is needed, false otherwise.
  """
  def check_for_interprocedural_analysis(ast) do
    case ast do
      {:__block__, _, exprs} when is_list(exprs) ->
        function_count = Enum.count(exprs, fn expr ->
          case expr do
            {:def, _, _} -> true
            {:defp, _, _} -> true
            _ -> false
          end
        end)
        function_count > 1

      _ -> false
    end
  end

  @doc """
  Checks for DFG-specific issues that would cause generation to fail.

  Returns true if DFG issues are detected, false otherwise.
  """
  def check_for_dfg_issues(ast) do
    case ast do
      {:def, _, [{:dfg_problematic, _, _}, _]} -> true
      {:def, _, [{name, _, _}, _]} when name in [:problematic_function, :circular_dependency] -> true
      _ -> contains_invalid_construct(ast)
    end
  end

  # Private implementation

  defp contains_invalid_construct(ast) do
    case ast do
      {:invalid_construct, _, _} -> true
      {_, _, args} when is_list(args) ->
        Enum.any?(args, &contains_invalid_construct/1)
      {:__block__, _, exprs} when is_list(exprs) ->
        Enum.any?(exprs, &contains_invalid_construct/1)
      {:def, _, [_head, [do: body]]} ->
        contains_invalid_construct(body)
      {:defp, _, [_head, [do: body]]} ->
        contains_invalid_construct(body)
      [do: body] ->
        contains_invalid_construct(body)
      list when is_list(list) ->
        Enum.any?(list, &contains_invalid_construct/1)
      _ -> false
    end
  end
end
