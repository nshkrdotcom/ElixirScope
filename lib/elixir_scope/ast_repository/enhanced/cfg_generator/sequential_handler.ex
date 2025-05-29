defmodule ElixirScope.ASTRepository.Enhanced.CFGGenerator.SequentialHandler do
  @moduledoc """
  Handles sequential AST nodes (blocks, assignments, pipes) for CFG generation.
  """

  alias ElixirScope.ASTRepository.Enhanced.{
    CFGNode,
    CFGEdge,
    # ScopeInfo, # Not directly used here
    CFGGenerator.Utils
  }

  @doc """
  Processes a block of statements (statement sequence).
  `ast_processor_func` is `ASTProcessor.process_ast_node/2`.
  """
  def handle_statement_sequence(statements, _meta, state, ast_processor_func) do
    Enum.reduce(statements, {%{}, [], [], %{}, state}, fn stmt, {nodes, edges, prev_exits, scopes, acc_state} ->
      {stmt_nodes, stmt_edges, stmt_exits, stmt_scopes, new_state} =
        ast_processor_func.(stmt, acc_state)

      connection_edges = if prev_exits == [] do
        []
      else
        stmt_entry_nodes = Utils.get_entry_nodes(stmt_nodes)
        if stmt_entry_nodes == [] do
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

      new_prev_exits = if stmt_exits == [], do: prev_exits, else: stmt_exits

      {merged_nodes, merged_edges, new_prev_exits, merged_scopes, new_state}
    end)
  end

  @doc """
  Processes an assignment operation.
  `ast_processor_func` is `ASTProcessor.process_ast_node/2`.
  """
  def handle_assignment(pattern, expression, meta, state, ast_processor_func) do
    {assign_id, updated_state} = Utils.generate_node_id("assignment", state)

    assign_node = %CFGNode{
      id: assign_id,
      type: :assignment,
      ast_node_id: Utils.get_ast_node_id(meta),
      line: Utils.get_line_number(meta),
      scope_id: state.current_scope,
      expression: {:=, meta, [pattern, expression]},
      predecessors: [],
      successors: [],
      metadata: %{pattern: pattern, expression: expression}
    }

    {expr_nodes, expr_edges, expr_exits, expr_scopes, expr_state} =
      ast_processor_func.(expression, updated_state)

    {final_expr_nodes, final_expr_edges, final_expr_exits, final_expr_scopes, final_expr_state} =
      if map_size(expr_nodes) == 0 do
        {expr_node_id, expr_node_state} = Utils.generate_node_id("expression", expr_state)
        expr_node = %CFGNode{
          id: expr_node_id,
          type: :expression,
          ast_node_id: Utils.get_ast_node_id(meta), # Attempt to get meta from assignment for RHS expression line
          line: Utils.get_line_number(meta),
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

  @doc """
  Processes a pipe operation.
  `ast_processor_func` is `ASTProcessor.process_ast_node/2`.
  """
  def handle_pipe_operation(left, right, meta, state, ast_processor_func) do
    line = Utils.get_line_number(meta)
    {pipe_id, updated_state} = Utils.generate_node_id("pipe", state)

    {left_nodes, left_edges, left_exits, left_scopes, left_state} =
      ast_processor_func.(left, updated_state)

    {right_nodes, right_edges, right_exits, right_scopes, right_state} =
      ast_processor_func.(right, left_state)

    pipe_node = %CFGNode{
      id: pipe_id,
      type: :pipe_operation,
      ast_node_id: Utils.get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: {:|>, meta, [left, right]},
      predecessors: left_exits, # Corrected: pipe node input from left exits
      successors: [], # Corrected: pipe node output to right entries (handled by edges below)
      metadata: %{left: left, right: right}
    }

    left_to_pipe_edges = Enum.map(left_exits, fn exit_id ->
      %CFGEdge{
        from_node_id: exit_id,
        to_node_id: pipe_id,
        type: :sequential,
        condition: nil,
        probability: 1.0,
        metadata: %{pipe_stage: :input}
      }
    end)

    # Connect pipe node to the entry points of the right-hand side processing
    right_entry_nodes = Utils.get_entry_nodes(right_nodes)
    pipe_to_right_edges = Enum.map(right_entry_nodes, fn entry_id ->
      %CFGEdge{
        from_node_id: pipe_id,
        to_node_id: entry_id,
        type: :sequential,
        condition: nil,
        probability: 1.0,
        metadata: %{pipe_stage: :output}
      }
    end)

    all_nodes = left_nodes
    |> Map.merge(right_nodes)
    |> Map.put(pipe_id, pipe_node)

    all_edges = left_edges ++ right_edges ++ left_to_pipe_edges ++ pipe_to_right_edges
    all_scopes = Map.merge(left_scopes, right_scopes)

    # The exits of the pipe operation are the exits of the right-hand side
    {all_nodes, all_edges, right_exits, all_scopes, right_state}
  end
end 