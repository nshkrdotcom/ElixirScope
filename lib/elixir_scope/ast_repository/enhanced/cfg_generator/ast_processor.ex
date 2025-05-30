defmodule ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTProcessor do
  @moduledoc """
  Main AST processing functions for the CFG generator.
  """

  @behaviour ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTProcessorBehaviour

  alias ElixirScope.ASTRepository.Enhanced.{CFGNode, CFGEdge, ScopeInfo}
  alias ElixirScope.ASTRepository.Enhanced.CFGGenerator.{
    StateManager, ASTUtilities, ControlFlowProcessors, ExpressionProcessors
  }

  @doc """
  Processes a function body AST and returns CFG components.
  """
  @impl ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTProcessorBehaviour
  def process_function_body({:def, meta, [head, [do: body]]}, state) do
    process_function_body({:defp, meta, [head, [do: body]]}, state)
  end

  @impl ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTProcessorBehaviour
  def process_function_body({:defp, meta, [head, [do: body]]}, state) do
    line = ASTUtilities.get_line_number(meta)

    # Extract function parameters and check for guards
    {function_params, guard_ast} = case head do
      {:when, _, [func_head, guard]} ->
        # Function has a guard
        {ASTUtilities.extract_function_parameters(func_head), guard}
      func_head ->
        # No guard
        {ASTUtilities.extract_function_parameters(func_head), nil}
    end

    # Create function scope
    function_scope = %ScopeInfo{
      id: state.current_scope,
      type: :function,
      parent_scope: nil,
      child_scopes: [],
      variables: function_params,
      ast_node_id: ASTUtilities.get_ast_node_id(meta),
      entry_points: [state.entry_node],
      exit_points: [],
      metadata: %{function_head: head, guard: guard_ast}
    }

    # Create entry node
    entry_node = %CFGNode{
      id: state.entry_node,
      type: :entry,
      ast_node_id: ASTUtilities.get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: head,
      predecessors: [],
      successors: [],
      metadata: %{function_head: head, guard: guard_ast}
    }

    initial_state = %{state | nodes: %{state.entry_node => entry_node}}

    # Process guard if present
    {guard_nodes, guard_edges, guard_exits, guard_scopes, guard_state} =
      if guard_ast do
        process_ast_node(guard_ast, initial_state)
      else
        {%{}, [], [state.entry_node], %{}, initial_state}
      end

    # Process function body
    {body_nodes, body_edges, body_exits, body_scopes, updated_state} =
      process_ast_node(body, guard_state)

    # Connect entry to guard (if present) or directly to body
    entry_connections = build_entry_connections(state.entry_node, guard_ast, guard_nodes, body_nodes)

    # Connect guard to body (if guard exists)
    guard_to_body_edges = build_guard_to_body_connections(guard_ast, guard_exits, body_nodes)

    # Create exit node
    {exit_node_id, final_state} = StateManager.generate_node_id("exit", updated_state)
    exit_node = %CFGNode{
      id: exit_node_id,
      type: :exit,
      ast_node_id: nil,
      line: line,
      scope_id: state.current_scope,
      expression: nil,
      predecessors: body_exits,
      successors: [],
      metadata: %{}
    }

    # Connect body exits to function exit
    exit_edges = build_exit_connections(body_exits, exit_node_id)

    # Handle empty function body case
    direct_entry_to_exit_edges = build_direct_entry_to_exit_connections(
      body_exits, guard_exits, state.entry_node, exit_node_id
    )

    all_nodes = guard_nodes
    |> Map.merge(body_nodes)
    |> Map.put(state.entry_node, entry_node)
    |> Map.put(exit_node_id, exit_node)

    all_edges = entry_connections ++ guard_edges ++ guard_to_body_edges ++
                body_edges ++ exit_edges ++ direct_entry_to_exit_edges
    all_scopes = Map.merge(guard_scopes, body_scopes)
    |> Map.put(state.current_scope, function_scope)

    {all_nodes, all_edges, [exit_node_id], all_scopes, final_state}
  end

  def process_function_body(malformed_ast, _state) do
    # Handle any malformed or unexpected AST structure
    {:error, {:cfg_generation_failed, "Invalid AST structure: #{inspect(malformed_ast)}"}}
  end

  @doc """
  Main AST node processing dispatcher.
  """
  @impl ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTProcessorBehaviour
  def process_ast_node(ast, state) do
    case ast do
      # Block of statements - put this FIRST to ensure it matches before function call pattern
      {:__block__, meta, statements} ->
        ExpressionProcessors.process_statement_sequence(statements, meta, state)

      # Assignment with pattern matching - put this early to ensure it matches
      {:=, meta, [pattern, expression]} ->
        ExpressionProcessors.process_assignment(pattern, expression, meta, state)

      # Comprehensions - put this FIRST to ensure it matches
      {:for, meta, clauses} ->
        ExpressionProcessors.process_comprehension(clauses, meta, state)

      # Case statement - Elixir's primary pattern matching construct
      {:case, meta, [condition, [do: clauses]]} ->
        ControlFlowProcessors.process_case_statement(condition, clauses, meta, state)

      # If statement with optional else
      {:if, meta, [condition, clauses]} when is_list(clauses) ->
        then_branch = Keyword.get(clauses, :do)
        else_clause = case Keyword.get(clauses, :else) do
          nil -> []
          else_branch -> [else: else_branch]
        end
        ControlFlowProcessors.process_if_statement(condition, then_branch, else_clause, meta, state)

      # Cond statement - multiple conditions
      {:cond, meta, [[do: clauses]]} ->
        ControlFlowProcessors.process_cond_statement(clauses, meta, state)

      # Try-catch-rescue-after
      {:try, meta, blocks} ->
        ControlFlowProcessors.process_try_statement(blocks, meta, state)

      # With statement - error handling pipeline
      {:with, meta, clauses} ->
        ControlFlowProcessors.process_with_statement(clauses, meta, state)

      # Pipe operation - data transformation pipeline
      {:|>, meta, [left, right]} ->
        ExpressionProcessors.process_pipe_operation(left, right, meta, state)

      # Function call with module
      {{:., meta1, [module, func_name]}, meta2, args} ->
        ExpressionProcessors.process_module_function_call(module, func_name, args, meta1, meta2, state)

      # Function call
      {func_name, meta, args} when is_atom(func_name) ->
        ExpressionProcessors.process_function_call(func_name, args, meta, state)

      # Receive statement
      {:receive, meta, clauses} ->
        ControlFlowProcessors.process_receive_statement(clauses, meta, state)

      # Unless statement (negative conditional)
      {:unless, meta, [condition, clauses]} when is_list(clauses) ->
        ControlFlowProcessors.process_unless_statement(condition, clauses, meta, state)

      # When guard expressions
      {:when, meta, [expr, guard]} ->
        ExpressionProcessors.process_when_guard(expr, guard, meta, state)

      # Anonymous function
      {:fn, meta, clauses} ->
        ExpressionProcessors.process_anonymous_function(clauses, meta, state)

      # Exception handling
      {:raise, meta, args} ->
        ExpressionProcessors.process_raise_statement(args, meta, state)

      {:throw, meta, [value]} ->
        ExpressionProcessors.process_throw_statement(value, meta, state)

      {:exit, meta, [reason]} ->
        ExpressionProcessors.process_exit_statement(reason, meta, state)

      # Concurrency
      {:spawn, meta, args} ->
        ExpressionProcessors.process_spawn_statement(args, meta, state)

      {:send, meta, [pid, message]} ->
        ExpressionProcessors.process_send_statement(pid, message, meta, state)

      # Binary operations
      {op, meta, [left, right]} when op in [:+, :-, :*, :/, :==, :!=, :<, :>, :<=, :>=, :and, :or, :&&, :||] ->
        ExpressionProcessors.process_binary_operation(op, left, right, meta, state)

      # Unary operations
      {op, meta, [operand]} when op in [:not, :!, :+, :-] ->
        ExpressionProcessors.process_unary_operation(op, operand, meta, state)

      # Variable reference
      {var_name, meta, nil} when is_atom(var_name) ->
        ExpressionProcessors.process_variable_reference(var_name, meta, state)

      # Literal values
      literal when is_atom(literal) or is_number(literal) or is_binary(literal) or is_list(literal) ->
        ExpressionProcessors.process_literal_value(literal, state)

      # Handle nil (empty function body)
      nil ->
        # Empty function body - return empty results
        {%{}, [], [], %{}, state}

      # Data structures
      {:{}, meta, elements} ->
        ExpressionProcessors.process_tuple_construction(elements, meta, state)

      list when is_list(list) ->
        ExpressionProcessors.process_list_construction(list, state)

      {:%{}, meta, pairs} ->
        ExpressionProcessors.process_map_construction(pairs, meta, state)

      {:%{}, meta, [map | updates]} ->
        ExpressionProcessors.process_map_update(map, updates, meta, state)

      {:%, meta, [struct_name, fields]} ->
        ExpressionProcessors.process_struct_construction(struct_name, fields, meta, state)

      # Access operation
      {{:., meta1, [Access, :get]}, meta2, [container, key]} ->
        ExpressionProcessors.process_access_operation(container, key, meta1, meta2, state)

      # Attribute access
      {:@, meta, [attr]} ->
        ExpressionProcessors.process_attribute_access(attr, meta, state)

      # Simple expression fallback
      _ ->
        ExpressionProcessors.process_simple_expression(ast, state)
    end
  end

  # Helper functions for building connections

  defp build_entry_connections(entry_node_id, guard_ast, guard_nodes, body_nodes) do
    if guard_ast do
      # Connect entry to guard
      guard_entry_nodes = get_entry_nodes(guard_nodes)
      Enum.map(guard_entry_nodes, fn node_id ->
        %CFGEdge{
          from_node_id: entry_node_id,
          to_node_id: node_id,
          type: :sequential,
          condition: nil,
          probability: 1.0,
          metadata: %{connection: :entry_to_guard}
        }
      end)
    else
      # Connect entry directly to body
      body_entry_nodes = get_entry_nodes(body_nodes)
      if body_entry_nodes == [] do
        # Empty function body - no body nodes to connect to
        []
      else
        Enum.map(body_entry_nodes, fn node_id ->
          %CFGEdge{
            from_node_id: entry_node_id,
            to_node_id: node_id,
            type: :sequential,
            condition: nil,
            probability: 1.0,
            metadata: %{connection: :entry_to_body}
          }
        end)
      end
    end
  end

  defp build_guard_to_body_connections(guard_ast, guard_exits, body_nodes) do
    if guard_ast do
      body_entry_nodes = get_entry_nodes(body_nodes)
      Enum.flat_map(guard_exits, fn guard_exit ->
        Enum.map(body_entry_nodes, fn body_entry ->
          %CFGEdge{
            from_node_id: guard_exit,
            to_node_id: body_entry,
            type: :sequential,
            condition: nil,
            probability: 1.0,
            metadata: %{connection: :guard_to_body}
          }
        end)
      end)
    else
      []
    end
  end

  defp build_exit_connections(body_exits, exit_node_id) do
    Enum.map(body_exits, fn exit_id ->
      %CFGEdge{
        from_node_id: exit_id,
        to_node_id: exit_node_id,
        type: :sequential,
        condition: nil,
        probability: 1.0,
        metadata: %{}
      }
    end)
  end

  defp build_direct_entry_to_exit_connections(body_exits, guard_exits, entry_node_id, exit_node_id) do
    if body_exits == [] and guard_exits == [entry_node_id] do
      # Empty function body with no guard, or guard that doesn't produce nodes
      [%CFGEdge{
        from_node_id: entry_node_id,
        to_node_id: exit_node_id,
        type: :sequential,
        condition: nil,
        probability: 1.0,
        metadata: %{connection: :entry_to_exit_direct}
      }]
    else
      []
    end
  end

  defp get_entry_nodes(nodes) when map_size(nodes) == 0, do: []
  defp get_entry_nodes(nodes) do
    # Find nodes with no predecessors
    nodes
    |> Map.values()
    |> Enum.filter(fn node -> length(node.predecessors) == 0 end)
    |> Enum.map(& &1.id)
    |> case do
      [] -> [nodes |> Map.keys() |> List.first()]  # Fallback to first node
      entry_nodes -> entry_nodes
    end
  end
end
