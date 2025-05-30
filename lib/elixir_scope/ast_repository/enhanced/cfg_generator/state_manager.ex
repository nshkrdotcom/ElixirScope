defmodule ElixirScope.ASTRepository.Enhanced.CFGGenerator.StateManager do
  @moduledoc """
  State management functions for the CFG generator.
  """

  @behaviour ElixirScope.ASTRepository.Enhanced.CFGGenerator.StateManagerBehaviour

  alias ElixirScope.ASTRepository.Enhanced.CFGGenerator.State

  @doc """
  Initializes the initial state for CFG generation.
  """
  @impl ElixirScope.ASTRepository.Enhanced.CFGGenerator.StateManagerBehaviour
  def initialize_state(function_ast, opts) do
    entry_node_id = generate_node_id("entry")

    %{
      entry_node: entry_node_id,
      next_node_id: 1,
      nodes: %{},
      edges: [],
      scopes: %{},
      current_scope: "function_scope",
      scope_counter: 1,
      options: opts,
      function_key: Keyword.get(opts, :function_key, extract_function_key(function_ast))
    }
  end

  @doc """
  Generates a unique node ID with optional state update.
  """
  @impl ElixirScope.ASTRepository.Enhanced.CFGGenerator.StateManagerBehaviour
  def generate_node_id(prefix, state \\ nil) do
    if state do
      id = "#{prefix}_#{state.next_node_id}"
      {id, %{state | next_node_id: state.next_node_id + 1}}
    else
      "#{prefix}_#{:erlang.unique_integer([:positive])}"
    end
  end

  @doc """
  Generates a unique scope ID.
  """
  @impl ElixirScope.ASTRepository.Enhanced.CFGGenerator.StateManagerBehaviour
  def generate_scope_id(prefix, state) do
    "#{prefix}_#{state.scope_counter + 1}"
  end

  # Helper functions
  defp extract_function_key({:def, _meta, [{name, _meta2, args} | _]}) do
    arity = if is_list(args), do: length(args), else: 0
    {:unknown_module_placeholder, name, arity}
  end

  defp extract_function_key({:defp, _meta, [{name, _meta2, args} | _]}) do
    arity = if is_list(args), do: length(args), else: 0
    {:unknown_module_placeholder, name, arity}
  end

  defp extract_function_key(_), do: {:unknown_module_placeholder, :unknown, 0}
end
