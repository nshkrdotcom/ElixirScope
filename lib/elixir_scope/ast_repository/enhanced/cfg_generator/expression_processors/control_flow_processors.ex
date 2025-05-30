defmodule ElixirScope.ASTRepository.Enhanced.CFGGenerator.ExpressionProcessors.ControlFlowProcessors do
  @moduledoc """
  Processors for control flow constructs like comprehensions, pipes, and process-related operations.
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
  Processes a comprehension (for).
  """
  def process_comprehension(clauses, meta, state) do
    {comp_id, updated_state} = state_manager().generate_node_id("comprehension", state)

    # Count generators and filters for complexity
    {generators, filters} = ast_utilities().analyze_comprehension_clauses(clauses)

    # Comprehensions always add at least 1 complexity point due to iteration + filtering
    complexity_contribution = max(length(generators) + length(filters), 1)

    # Create comprehension node (decision point for filtering)
    comp_node = %CFGNode{
      id: comp_id,
      type: :comprehension,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: ast_utilities().get_line_number(meta),
      scope_id: state.current_scope,
      expression: clauses,
      predecessors: [],
      successors: [],
      metadata: %{
        clauses: clauses,
        generators: generators,
        filters: filters,
        complexity_contribution: complexity_contribution
      }
    }

    nodes = %{comp_id => comp_node}
    {nodes, [], [comp_id], %{}, updated_state}
  end

  @doc """
  Processes a pipe operation.
  """
  def process_pipe_operation(left, right, meta, state) do
    line = ast_utilities().get_line_number(meta)
    {pipe_id, updated_state} = state_manager().generate_node_id("pipe", state)

    # Process left side of pipe first
    {left_nodes, left_edges, left_exits, left_scopes, left_state} =
      ast_processor().process_ast_node(left, updated_state)

    # Process right side of pipe
    {right_nodes, right_edges, right_exits, right_scopes, right_state} =
      ast_processor().process_ast_node(right, left_state)

    # Create pipe operation node
    pipe_node = %CFGNode{
      id: pipe_id,
      type: :pipe_operation,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: {:|>, meta, [left, right]},
      predecessors: left_exits,
      successors: right_exits,
      metadata: %{left: left, right: right}
    }

    # Create edges: left -> pipe -> right
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

    pipe_to_right_edges = Enum.map(right_exits, fn exit_id ->
      %CFGEdge{
        from_node_id: pipe_id,
        to_node_id: exit_id,
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

    {all_nodes, all_edges, right_exits, all_scopes, right_state}
  end

  @doc """
  Processes a raise statement.
  """
  def process_raise_statement(args, meta, state) do
    line = ast_utilities().get_line_number(meta)
    {raise_id, updated_state} = state_manager().generate_node_id("raise", state)

    raise_node = %CFGNode{
      id: raise_id,
      type: :raise,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: {:raise, meta, args},
      predecessors: [],
      successors: [],
      metadata: %{args: args}
    }

    nodes = %{raise_id => raise_node}
    {nodes, [], [raise_id], %{}, updated_state}
  end

  @doc """
  Processes a throw statement.
  """
  def process_throw_statement(value, meta, state) do
    line = ast_utilities().get_line_number(meta)
    {throw_id, updated_state} = state_manager().generate_node_id("throw", state)

    throw_node = %CFGNode{
      id: throw_id,
      type: :throw,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: {:throw, meta, [value]},
      predecessors: [],
      successors: [],
      metadata: %{value: value}
    }

    nodes = %{throw_id => throw_node}
    {nodes, [], [throw_id], %{}, updated_state}
  end

  @doc """
  Processes an exit statement.
  """
  def process_exit_statement(reason, meta, state) do
    line = ast_utilities().get_line_number(meta)
    {exit_id, updated_state} = state_manager().generate_node_id("exit", state)

    exit_node = %CFGNode{
      id: exit_id,
      type: :exit_call,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: {:exit, meta, [reason]},
      predecessors: [],
      successors: [],
      metadata: %{reason: reason}
    }

    nodes = %{exit_id => exit_node}
    {nodes, [], [exit_id], %{}, updated_state}
  end

  @doc """
  Processes a spawn statement.
  """
  def process_spawn_statement(args, meta, state) do
    line = ast_utilities().get_line_number(meta)
    {spawn_id, updated_state} = state_manager().generate_node_id("spawn", state)

    spawn_node = %CFGNode{
      id: spawn_id,
      type: :spawn,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: {:spawn, meta, args},
      predecessors: [],
      successors: [],
      metadata: %{args: args}
    }

    nodes = %{spawn_id => spawn_node}
    {nodes, [], [spawn_id], %{}, updated_state}
  end

  @doc """
  Processes a send statement.
  """
  def process_send_statement(pid, message, meta, state) do
    line = ast_utilities().get_line_number(meta)
    {send_id, updated_state} = state_manager().generate_node_id("send", state)

    send_node = %CFGNode{
      id: send_id,
      type: :send,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: {:send, meta, [pid, message]},
      predecessors: [],
      successors: [],
      metadata: %{pid: pid, message: message}
    }

    nodes = %{send_id => send_node}
    {nodes, [], [send_id], %{}, updated_state}
  end
end
