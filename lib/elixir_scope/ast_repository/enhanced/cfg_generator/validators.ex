defmodule ElixirScope.ASTRepository.Enhanced.CFGGenerator.Validators do
  @moduledoc """
  AST validation functions for the CFG generator.
  """

  @doc """
  Validates the structure of the AST to ensure it's a valid function definition.
  """
  @spec validate_ast_structure(Macro.t()) :: :ok | {:error, atom()}
  def validate_ast_structure(ast) do
    case ast do
      {:def, _meta, [_head, [do: _body]]} -> :ok
      {:defp, _meta, [_head, [do: _body]]} -> :ok
      _ -> {:error, :invalid_ast_structure}
    end
  end
end
