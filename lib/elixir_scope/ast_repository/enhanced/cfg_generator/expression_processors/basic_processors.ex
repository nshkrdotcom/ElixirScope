defmodule ElixirScope.ASTRepository.Enhanced.CFGGenerator.ExpressionProcessors.BasicProcessors do
  @moduledoc """
  Processors for basic expressions like variables, literals, operations, and statement sequences.
  """

  alias ElixirScope.ASTRepository.Enhanced.{CFGNode, CFGEdge}

  # Get dependencies from application config for testability
  defp state_manager do
    Application.get_env(:elixir_scope, :state_manager,
      ElixirScope.ASTRepository.Enhanced.CFGGenerator.StateManager)
  end

  defp ast_utilities do
    Application.get_env(:elixir_scope, :ast_utilities,
      ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTUtilities)
  end

  defp ast_processor do
    Application.get_env(:elixir_scope, :ast_processor,
      ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTProcessor)
  end

  @doc """
  Processes a statement sequence (block).
  """
  def process_statement_sequence(statements, _meta, state) do
    # Process statements sequentially, connecting them in order
    {all_nodes, all_edges, final_exits, all_scopes, final_state} =
      Enum.reduce(statements, {%{}, [], [], %{}, state}, fn stmt, {nodes, edges, prev_exits, scopes, acc_state} ->
        {stmt_nodes, stmt_edges, stmt_exits, stmt_scopes, new_state} =
          ast_processor().process_ast_node(stmt, acc_state)

        # Connect previous statement exits to current statement entries
        connection_edges = if prev_exits == [] do
          # For the first statement, we'll connect it later in process_function_body
          []
        else
          stmt_entry_nodes = get_entry_nodes(stmt_nodes)
          if stmt_entry_nodes == [] do
            # If no entry nodes, create a direct connection from prev exits to stmt exits
            []
          else
            Enum.flat_map(prev_exits, fn prev_exit ->
              Enum.map(stmt_entry_nodes, fn stmt_entry ->
                %CFGEdge{
                  from_node_id: prev_exit,
                  to_node_id: stmt_entry,
                  type: :sequential,
                  condition: nil,
                  probability: 1.0,
                  metadata: %{}
                }
              end)
            end)
          end
        end

        merged_nodes = Map.merge(nodes, stmt_nodes)
        merged_edges = edges ++ stmt_edges ++ connection_edges
        merged_scopes = Map.merge(scopes, stmt_scopes)

        # Use stmt_exits as the new prev_exits for the next iteration
        new_prev_exits = if stmt_exits == [], do: prev_exits, else: stmt_exits

        {merged_nodes, merged_edges, new_prev_exits, merged_scopes, new_state}
      end)

    {all_nodes, all_edges, final_exits, all_scopes, final_state}
  end

  @doc """
  Processes a binary operation.
  """
  def process_binary_operation(op, left, right, meta, state) do
    {op_id, updated_state} = state_manager().generate_node_id("binary_op", state)

    # Process left operand first
    {left_nodes, left_edges, left_exits, left_scopes, left_state} =
      ast_processor().process_ast_node(left, updated_state)

    # Process right operand
    {right_nodes, right_edges, right_exits, right_scopes, right_state} =
      ast_processor().process_ast_node(right, left_state)

    # Create binary operation node
    op_node = %CFGNode{
      id: op_id,
      type: :binary_operation,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: ast_utilities().get_line_number(meta),
      scope_id: state.current_scope,
      expression: {op, meta, [left, right]},
      predecessors: left_exits ++ right_exits,
      successors: [],
      metadata: %{operator: op, left: left, right: right}
    }

    # Create edges from operands to operation
    operand_edges = (Enum.map(left_exits, fn exit_id ->
      %CFGEdge{
        from_node_id: exit_id,
        to_node_id: op_id,
        type: :sequential,
        condition: nil,
        probability: 1.0,
        metadata: %{operand: :left}
      }
    end) ++ Enum.map(right_exits, fn exit_id ->
      %CFGEdge{
        from_node_id: exit_id,
        to_node_id: op_id,
        type: :sequential,
        condition: nil,
        probability: 1.0,
        metadata: %{operand: :right}
      }
    end))

    all_nodes = left_nodes
    |> Map.merge(right_nodes)
    |> Map.put(op_id, op_node)

    all_edges = left_edges ++ right_edges ++ operand_edges
    all_scopes = Map.merge(left_scopes, right_scopes)

    {all_nodes, all_edges, [op_id], all_scopes, right_state}
  end

  @doc """
  Processes a unary operation.
  """
  def process_unary_operation(op, operand, meta, state) do
    {op_id, updated_state} = state_manager().generate_node_id("unary_op", state)

    op_node = %CFGNode{
      id: op_id,
      type: :unary_operation,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: ast_utilities().get_line_number(meta),
      scope_id: state.current_scope,
      expression: {op, meta, [operand]},
      predecessors: [],
      successors: [],
      metadata: %{operator: op, operand: operand}
    }

    nodes = %{op_id => op_node}
    {nodes, [], [op_id], %{}, updated_state}
  end

  @doc """
  Processes a variable reference.
  """
  def process_variable_reference(var_name, meta, state) do
    {var_id, updated_state} = state_manager().generate_node_id("variable", state)

    var_node = %CFGNode{
      id: var_id,
      type: :variable,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: ast_utilities().get_line_number(meta),
      scope_id: state.current_scope,
      expression: {var_name, meta, nil},
      predecessors: [],
      successors: [],
      metadata: %{variable: var_name}
    }

    nodes = %{var_id => var_node}
    {nodes, [], [var_id], %{}, updated_state}
  end

  @doc """
  Processes a literal value.
  """
  def process_literal_value(literal, state) do
    {literal_id, updated_state} = state_manager().generate_node_id("literal", state)

    literal_node = %CFGNode{
      id: literal_id,
      type: :literal,
      ast_node_id: nil,
      line: 1,
      scope_id: state.current_scope,
      expression: literal,
      predecessors: [],
      successors: [],
      metadata: %{value: literal, type: ast_utilities().get_literal_type(literal)}
    }

    nodes = %{literal_id => literal_node}
    {nodes, [], [literal_id], %{}, updated_state}
  end

  @doc """
  Processes a simple expression (fallback).
  """
  def process_simple_expression(ast, state) do
    {expr_id, updated_state} = state_manager().generate_node_id("expression", state)

    # Determine the expression type based on the AST structure
    expr_type = case ast do
      {:=, _, _} -> :assignment  # Assignment that didn't match the specific pattern
      {op, _, _} when op in [:+, :-, :*, :/, :==, :!=, :<, :>, :<=, :>=] -> :binary_operation
      {var, _, nil} when is_atom(var) -> :variable_reference
      _ -> :expression
    end

    expr_node = %CFGNode{
      id: expr_id,
      type: expr_type,
      ast_node_id: nil,
      line: 1,
      scope_id: state.current_scope,
      expression: ast,
      predecessors: [],
      successors: [],
      metadata: %{expression: ast, fallback: true}
    }

    nodes = %{expr_id => expr_node}
    {nodes, [], [expr_id], %{}, updated_state}
  end

  # Private helper functions

  defp get_entry_nodes(nodes) when map_size(nodes) == 0, do: []
  defp get_entry_nodes(nodes) do
    nodes
    |> Map.values()
    |> Enum.filter(fn node -> length(node.predecessors) == 0 end)
    |> Enum.map(& &1.id)
    |> case do
      [] -> [nodes |> Map.keys() |> List.first()]
      entry_nodes -> entry_nodes
    end
  end
end
