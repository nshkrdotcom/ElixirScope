defmodule ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTUtilitiesBehaviour do
  @moduledoc """
  Behaviour for utility functions for working with AST nodes.
  """

  @type meta :: keyword()
  @type literal :: atom() | number() | binary() | list()
  @type pattern :: term()
  @type function_head :: {atom(), meta(), list() | nil}
  @type comprehension_clauses :: list(term())

  @doc """
  Extracts AST node ID from metadata.
  """
  @callback get_ast_node_id(meta :: meta()) :: String.t() | nil

  @doc """
  Extracts line number from metadata.
  """
  @callback get_line_number(meta :: meta()) :: non_neg_integer()

  @doc """
  Extracts function parameters from function head.
  """
  @callback extract_function_parameters(head :: function_head()) :: [String.t()]

  @doc """
  Extracts variable names from a pattern.
  """
  @callback extract_pattern_variables(pattern :: pattern()) :: [String.t()]

  @doc """
  Calculates pattern matching probability (simplified).
  """
  @callback calculate_pattern_probability(pattern :: pattern()) :: float()

  @doc """
  Determines the type of a literal value.
  """
  @callback get_literal_type(literal :: literal()) :: atom()

  @doc """
  Analyzes comprehension clauses to separate generators and filters.
  """
  @callback analyze_comprehension_clauses(clauses :: comprehension_clauses()) ::
    {generators :: list(term()), filters :: list(term())}
end
