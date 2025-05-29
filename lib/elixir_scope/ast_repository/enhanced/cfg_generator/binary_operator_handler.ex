defmodule ElixirScope.ASTRepository.Enhanced.CFGGenerator.BinaryOperatorHandler do
  @moduledoc """
  Handles binary operations for CFG generation.
  """

  alias ElixirScope.ASTRepository.Enhanced.{
    CFGNode,
    CFGEdge,
    CFGGenerator.Utils
  }

  @doc """
  Processes a binary operation.
  `ast_processor_func` is `ASTProcessor.process_ast_node/2`.
  """
  def handle_binary_operation(op, left, right, meta, state, ast_processor_func) do
    {op_id, updated_state} = Utils.generate_node_id("binary_op", state)
    line = Utils.get_line_number(meta)

    {left_nodes, left_edges, left_exits, left_scopes, left_state} =
      ast_processor_func.(left, updated_state)

    {right_nodes, right_edges, right_exits, right_scopes, right_state} =
      ast_processor_func.(right, left_state)

    op_node = %CFGNode{
      id: op_id,
      type: :binary_operation,
      ast_node_id: Utils.get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: {op, meta, [left, right]},
      # Predecessors are the exits of both left and right operand processing
      predecessors: left_exits ++ right_exits, 
      successors: [], # Successor is the op_node itself, handled by return
      metadata: %{operator: op, left: left, right: right}
    }

    operand_edges = 
      (Enum.map(left_exits, fn exit_id ->
        %CFGEdge{
          from_node_id: exit_id,
          to_node_id: op_id,
          type: :sequential,
          condition: nil,
          probability: 1.0,
          metadata: %{operand: :left}
        }
      end) ++
      Enum.map(right_exits, fn exit_id ->
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
end 