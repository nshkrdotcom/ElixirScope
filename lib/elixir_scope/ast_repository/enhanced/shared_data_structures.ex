defmodule ElixirScope.ASTRepository.Enhanced.SharedDataStructures do
  @moduledoc """
  Shared data structures used across CFG, DFG, and CPG components.
  
  This module contains common structures to avoid duplication and ensure consistency.
  """

  # Re-export all shared structures
  defdelegate scope_types(), to: ScopeInfo
  defdelegate complexity_metrics_fields(), to: ComplexityMetrics
end

defmodule ElixirScope.ASTRepository.Enhanced.ScopeInfo do
  @moduledoc """
  Information about variable scopes in Elixir.
  Shared between CFG and DFG analysis.
  """

  defstruct [
    :id,                    # Unique scope identifier
    :type,                  # Scope type (see @scope_types)
    :parent_scope,          # Parent scope ID
    :child_scopes,          # [scope_id] - Child scopes
    :variables,             # [variable_name] - Variables in scope (CFG) or [VariableVersion.t()] (DFG)
    :ast_node_id,           # AST node that creates this scope
    :entry_points,          # [ast_node_id] - Ways to enter scope
    :exit_points,           # [ast_node_id] - Ways to exit scope
    :metadata               # Additional metadata
  ]

  @type t :: %__MODULE__{
    id: String.t(),
    type: atom(),
    parent_scope: String.t() | nil,
    child_scopes: [String.t()],
    variables: [String.t()] | [term()], # Flexible to handle both CFG and DFG usage
    ast_node_id: String.t(),
    entry_points: [String.t()],
    exit_points: [String.t()],
    metadata: map()
  }

  @scope_types [
    :function,              # Function scope
    :case_clause,           # Case clause scope
    :if_branch,             # If/else branch scope
    :try_block,             # Try block scope
    :catch_clause,          # Catch/rescue clause scope
    :comprehension,         # Comprehension scope
    :receive_clause,        # Receive clause scope
    :anonymous_function,    # Anonymous function scope
    :module                 # Module scope
  ]

  def scope_types, do: @scope_types
end

# ComplexityMetrics is defined in complexity_metrics.ex
# We just re-export it here for convenience
alias ElixirScope.ASTRepository.Enhanced.ComplexityMetrics 