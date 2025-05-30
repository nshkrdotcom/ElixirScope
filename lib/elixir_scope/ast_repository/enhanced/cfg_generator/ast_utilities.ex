defmodule ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTUtilities do
  @moduledoc """
  Utility functions for working with AST nodes.
  """

  @behaviour ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTUtilitiesBehaviour

  @doc """
  Extracts AST node ID from metadata.
  """
  @impl ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTUtilitiesBehaviour
  def get_ast_node_id(meta) do
    Keyword.get(meta, :ast_node_id)
  end

  @doc """
  Extracts line number from metadata.
  """
  @impl ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTUtilitiesBehaviour
  def get_line_number(meta) do
    Keyword.get(meta, :line, 1)
  end

  @doc """
  Extracts function parameters from function head.
  """
  @impl ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTUtilitiesBehaviour
  def extract_function_parameters({_name, _meta, args}) when is_list(args) do
    Enum.map(args, fn
      {var, _meta, nil} when is_atom(var) -> Atom.to_string(var)
      _ -> "unknown_param"
    end)
  end

  def extract_function_parameters(_), do: []

  @doc """
  Extracts variable names from a pattern.
  """
  @impl ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTUtilitiesBehaviour
  def extract_pattern_variables(pattern) do
    case pattern do
      {var, _meta, nil} when is_atom(var) -> [Atom.to_string(var)]
      {_constructor, _meta, args} when is_list(args) ->
        Enum.flat_map(args, &extract_pattern_variables/1)
      _ -> []
    end
  end

  @doc """
  Calculates pattern matching probability (simplified).
  """
  @impl ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTUtilitiesBehaviour
  def calculate_pattern_probability(_pattern) do
    # Simplified probability - could be more sophisticated
    0.5
  end

  @doc """
  Determines the type of a literal value.
  """
  @impl ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTUtilitiesBehaviour
  def get_literal_type(literal) do
    cond do
      is_atom(literal) -> :atom
      is_number(literal) -> :number
      is_binary(literal) -> :string
      is_list(literal) -> :list
      true -> :unknown
    end
  end

  @doc """
  Analyzes comprehension clauses to separate generators and filters.
  """
  @impl ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTUtilitiesBehaviour
  def analyze_comprehension_clauses(clauses) do
    Enum.reduce(clauses, {[], []}, fn clause, {generators, filters} ->
      case clause do
        {:<-, _, [_pattern, _enumerable]} ->
          # Generator clause
          {[clause | generators], filters}
        [do: _body] ->
          # Body clause - not a decision point
          {generators, filters}
        _ ->
          # Filter clause (any other expression)
          {generators, [clause | filters]}
      end
    end)
  end
end
