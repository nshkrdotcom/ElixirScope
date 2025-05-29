defmodule ElixirScope.ASTRepository.Enhanced.DFGGenerator.StateManager do
  @moduledoc """
  Manages state transitions and scope handling for DFG generation.
  """

  @doc """
  Initializes the initial state for DFG generation.
  """
  def initialize_state(opts \\ []) do
    %{
      nodes: %{},
      edges: [],
      variables: %{},
      captures: [],
      mutations: [],
      shadowing_info: [],
      current_scope: :global,
      scope_stack: [:global],
      node_counter: 0,
      edge_counter: 0,
      unused_variables: [],
      opts: opts
    }
  end

  @doc """
  Enters a new scope.
  """
  def enter_scope(state, scope_type) do
    new_scope = {scope_type, System.unique_integer([:positive])}
    %{
      state |
      scope_stack: [state.current_scope | state.scope_stack],
      current_scope: new_scope
    }
  end

  @doc """
  Exits the current scope.
  """
  def exit_scope(state) do
    case state.scope_stack do
      [parent_scope | rest] ->
        %{state | current_scope: parent_scope, scope_stack: rest}
      [] ->
        %{state | current_scope: :global}
    end
  end

  @doc """
  Converts scope to string representation.
  """
  def scope_to_string({:global, _id}), do: "global"
  def scope_to_string({type, _id}), do: to_string(type)
  def scope_to_string(:global), do: "global"
  def scope_to_string(other), do: to_string(other)

  @doc """
  Gets variables in a specific scope.
  """
  def get_variables_in_scope(scope, variables) do
    variables
    |> Enum.filter(fn {{_var_name, var_scope}, _var_info} -> var_scope == scope end)
    |> Enum.into(%{}, fn {{var_name, _scope}, var_info} -> {var_name, var_info} end)
  end

  @doc """
  Calculates scope depth.
  """
  def scope_depth(scope) do
    case scope do
      :global -> 0
      {_type, _id} -> 1  # Simplified
    end
  end
end
