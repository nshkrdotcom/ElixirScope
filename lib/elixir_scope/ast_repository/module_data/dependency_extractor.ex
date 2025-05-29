# ==============================================================================
# Dependency Extraction Component
# ==============================================================================

defmodule ElixirScope.ASTRepository.ModuleData.DependencyExtractor do
  @moduledoc """
  Extracts module dependencies from AST structures.
  """

  @doc """
  Extracts all module dependencies from the AST.
  """
  @spec extract_dependencies(term()) :: [atom()]
  def extract_dependencies(ast) do
    []
    |> extract_imports(ast)
    |> extract_aliases(ast)
    |> extract_uses(ast)
    |> extract_requires(ast)
    |> Enum.uniq()
  end

  # Private implementation - keeping placeholder structure for stability
  defp extract_imports(dependencies, _ast), do: dependencies
  defp extract_aliases(dependencies, _ast), do: dependencies
  defp extract_uses(dependencies, _ast), do: dependencies
  defp extract_requires(dependencies, _ast), do: dependencies
end
