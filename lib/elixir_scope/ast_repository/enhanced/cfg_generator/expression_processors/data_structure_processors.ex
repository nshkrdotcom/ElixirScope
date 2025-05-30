defmodule ElixirScope.ASTRepository.Enhanced.CFGGenerator.ExpressionProcessors.DataStructureProcessors do
  @moduledoc """
  Processors for data structure construction and manipulation (tuples, lists, maps, structs, access).
  """

  alias ElixirScope.ASTRepository.Enhanced.CFGNode

  # Get dependencies from application config for testability
  defp state_manager do
    Application.get_env(:elixir_scope, :state_manager,
      ElixirScope.ASTRepository.Enhanced.CFGGenerator.StateManager)
  end

  defp ast_utilities do
    Application.get_env(:elixir_scope, :ast_utilities,
      ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTUtilities)
  end

  @doc """
  Processes tuple construction.
  """
  def process_tuple_construction(elements, meta, state) do
    {tuple_id, updated_state} = state_manager().generate_node_id("tuple", state)

    tuple_node = %CFGNode{
      id: tuple_id,
      type: :tuple,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: ast_utilities().get_line_number(meta),
      scope_id: state.current_scope,
      expression: {:{}, meta, elements},
      predecessors: [],
      successors: [],
      metadata: %{elements: elements, size: length(elements)}
    }

    nodes = %{tuple_id => tuple_node}
    {nodes, [], [tuple_id], %{}, updated_state}
  end

  @doc """
  Processes list construction.
  """
  def process_list_construction(list, state) do
    {list_id, updated_state} = state_manager().generate_node_id("list", state)

    list_node = %CFGNode{
      id: list_id,
      type: :list,
      ast_node_id: nil,
      line: 1,
      scope_id: state.current_scope,
      expression: list,
      predecessors: [],
      successors: [],
      metadata: %{elements: list, size: length(list)}
    }

    nodes = %{list_id => list_node}
    {nodes, [], [list_id], %{}, updated_state}
  end

  @doc """
  Processes map construction.
  """
  def process_map_construction(pairs, meta, state) do
    {map_id, updated_state} = state_manager().generate_node_id("map", state)

    map_node = %CFGNode{
      id: map_id,
      type: :map,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: ast_utilities().get_line_number(meta),
      scope_id: state.current_scope,
      expression: {:%{}, meta, pairs},
      predecessors: [],
      successors: [],
      metadata: %{pairs: pairs, size: length(pairs)}
    }

    nodes = %{map_id => map_node}
    {nodes, [], [map_id], %{}, updated_state}
  end

  @doc """
  Processes map update.
  """
  def process_map_update(map, updates, meta, state) do
    {update_id, updated_state} = state_manager().generate_node_id("map_update", state)

    update_node = %CFGNode{
      id: update_id,
      type: :map_update,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: ast_utilities().get_line_number(meta),
      scope_id: state.current_scope,
      expression: {:%{}, meta, [map | updates]},
      predecessors: [],
      successors: [],
      metadata: %{map: map, updates: updates}
    }

    nodes = %{update_id => update_node}
    {nodes, [], [update_id], %{}, updated_state}
  end

  @doc """
  Processes struct construction.
  """
  def process_struct_construction(struct_name, fields, meta, state) do
    {struct_id, updated_state} = state_manager().generate_node_id("struct", state)

    struct_node = %CFGNode{
      id: struct_id,
      type: :struct,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: ast_utilities().get_line_number(meta),
      scope_id: state.current_scope,
      expression: {:%, meta, [struct_name, fields]},
      predecessors: [],
      successors: [],
      metadata: %{struct_name: struct_name, fields: fields}
    }

    nodes = %{struct_id => struct_node}
    {nodes, [], [struct_id], %{}, updated_state}
  end

  @doc """
  Processes access operation.
  """
  def process_access_operation(container, key, meta1, meta2, state) do
    {access_id, updated_state} = state_manager().generate_node_id("access", state)

    access_node = %CFGNode{
      id: access_id,
      type: :access,
      ast_node_id: ast_utilities().get_ast_node_id(meta2),
      line: ast_utilities().get_line_number(meta2),
      scope_id: state.current_scope,
      expression: {{:., meta1, [Access, :get]}, meta2, [container, key]},
      predecessors: [],
      successors: [],
      metadata: %{container: container, key: key}
    }

    nodes = %{access_id => access_node}
    {nodes, [], [access_id], %{}, updated_state}
  end

  @doc """
  Processes attribute access.
  """
  def process_attribute_access(attr, meta, state) do
    {attr_id, updated_state} = state_manager().generate_node_id("attribute", state)

    attr_node = %CFGNode{
      id: attr_id,
      type: :attribute,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: ast_utilities().get_line_number(meta),
      scope_id: state.current_scope,
      expression: {:@, meta, [attr]},
      predecessors: [],
      successors: [],
      metadata: %{attribute: attr}
    }

    nodes = %{attr_id => attr_node}
    {nodes, [], [attr_id], %{}, updated_state}
  end
end
