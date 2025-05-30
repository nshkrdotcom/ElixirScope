defmodule ElixirScope.ASTRepository.Enhanced.CFGGenerator.State do
  @moduledoc """
  State structure used throughout the CFG generation process.
  """

  @type t :: %{
    entry_node: String.t(),
    next_node_id: non_neg_integer(),
    nodes: %{String.t() => CFGNode.t()},
    edges: [CFGEdge.t()],
    scopes: %{String.t() => ScopeInfo.t()},
    current_scope: String.t(),
    scope_counter: non_neg_integer(),
    options: keyword(),
    function_key: {module() | :unknown_module_placeholder, atom(), non_neg_integer()}
  }

  alias ElixirScope.ASTRepository.Enhanced.{CFGNode, CFGEdge, ScopeInfo}
end
