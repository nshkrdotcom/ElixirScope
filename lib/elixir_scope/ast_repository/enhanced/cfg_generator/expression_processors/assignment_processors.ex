defmodule ElixirScope.ASTRepository.Enhanced.CFGGenerator.ExpressionProcessors.AssignmentProcessors do
  @moduledoc """
  Processors for assignment operations.
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
  Processes an assignment operation.
  """
  def process_assignment(pattern, expression, meta, state) do
    {assign_id, updated_state} = state_manager().generate_node_id("assignment", state)

    # Create assignment node
    assign_node = %CFGNode{
      id: assign_id,
      type: :assignment,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: ast_utilities().get_line_number(meta),
      scope_id: state.current_scope,
      expression: {:=, meta, [pattern, expression]},
      predecessors: [],
      successors: [],
      metadata: %{pattern: pattern, expression: expression}
    }

    # Process the expression being assigned first
    {expr_nodes, expr_edges, expr_exits, expr_scopes, expr_state} =
      ast_processor().process_ast_node(expression, updated_state)

    # If expression processing returned empty results, create a simple expression node
    {final_expr_nodes, final_expr_edges, final_expr_exits, final_expr_scopes, final_expr_state} =
      if map_size(expr_nodes) == 0 do
        # Create a simple expression node for the right-hand side
        {expr_node_id, expr_node_state} = state_manager().generate_node_id("expression", expr_state)
        expr_node = %CFGNode{
          id: expr_node_id,
          type: :expression,
          ast_node_id: ast_utilities().get_ast_node_id(meta),
          line: ast_utilities().get_line_number(meta),
          scope_id: state.current_scope,
          expression: expression,
          predecessors: [],
          successors: [],
          metadata: %{expression: expression}
        }
        {%{expr_node_id => expr_node}, [], [expr_node_id], %{}, expr_node_state}
      else
        {expr_nodes, expr_edges, expr_exits, expr_scopes, expr_state}
      end

    # Connect expression exits to assignment node
    expr_to_assign_edges = Enum.map(final_expr_exits, fn exit_id ->
      %CFGEdge{
        from_node_id: exit_id,
        to_node_id: assign_id,
        type: :sequential,
        condition: nil,
        probability: 1.0,
        metadata: %{}
      }
    end)

    all_nodes = Map.put(final_expr_nodes, assign_id, assign_node)
    all_edges = final_expr_edges ++ expr_to_assign_edges

    {all_nodes, all_edges, [assign_id], final_expr_scopes, final_expr_state}
  end
end
