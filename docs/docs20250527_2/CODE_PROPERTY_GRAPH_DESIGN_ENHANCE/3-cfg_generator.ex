## === 3.ex ===
defmodule ElixirScope.ASTRepository.CFGGenerator do
  @moduledoc """
  Enhanced Control Flow Graph generator for Elixir functions.

  Handles Elixir-specific constructs with proper complexity calculation
  based on decision points rather than decision edges.
  """

  alias ElixirScope.ASTRepository.{CFGData, CFGNode, CFGEdge, ComplexityMetrics, ScopeInfo}

  @doc """
  Generates a Control Flow Graph for an Elixir function.

  ## Parameters
  - function_ast: The AST of the function to analyze
  - opts: Options for CFG generation

  ## Returns
  {:ok, CFGData.t()} | {:error, term()}
  """
  @spec generate_cfg(Macro.t(), keyword()) :: {:ok, CFGData.t()} | {:error, term()}
  def generate_cfg(function_ast, opts \\ []) do
    try do
      state = initialize_cfg_state(function_ast, opts)

      # Generate nodes and edges
      {nodes, edges, exit_nodes, _final_state} = process_function_body(function_ast, state) # Capture final_state

      # Calculate complexity metrics
      complexity = calculate_complexity_metrics(nodes, edges)

      # Perform path analysis
      path_analysis = analyze_paths(nodes, edges, state.entry_node)

      cfg = %CFGData{
        function_key: extract_function_key(function_ast),
        entry_node: state.entry_node,
        exit_nodes: exit_nodes,
        nodes: nodes,
        edges: edges,
        scopes: state.scopes, # Ensure scopes are populated in state
        complexity_metrics: complexity,
        path_analysis: path_analysis,
        metadata: %{
          generation_time: System.monotonic_time(:millisecond) - state.start_time, # Calculate duration
          options: opts,
          node_count: map_size(nodes),
          edge_count: length(edges)
        }
      }

      {:ok, cfg}
    rescue
      error -> {:error, {:cfg_generation_failed, error, __STACKTRACE__}}
    end
  end

  # Private implementation

  defp initialize_cfg_state(function_ast, opts) do
    entry_node_id = generate_node_id("entry", %{next_node_id: 0}) # Pass a minimal state for ID generation
    function_scope_id = create_scope_id("function", 0, nil)

    %{
      entry_node: entry_node_id,
      next_node_id: 1,
      nodes: %{},
      edges: [],
      scopes: %{function_scope_id => %ScopeInfo{id: function_scope_id, type: :function, parent_scope: nil, child_scopes: [], variables: [], ast_node_id: get_ast_node_id_from_ast(function_ast)}},
      current_scope: function_scope_id,
      scope_id_counter: 1, # For generating unique scope IDs
      options: opts,
      start_time: System.monotonic_time(:millisecond) # For timing
    }
  end

  defp process_function_body({:def, meta, [_head, [do: body]]}, state) do
    entry_node = %CFGNode{
      id: state.entry_node,
      type: :entry,
      ast_node_id: get_ast_node_id(meta), # Use def meta for ast_node_id
      line: get_line_number(meta),       # Use def meta for line
      scope_id: state.current_scope,
      expression: nil, # Or perhaps the function head AST?
      predecessors: [],
      successors: [],
      metadata: %{function_signature: _head}
    }

    # Process function body
    {body_nodes, body_edges, body_exits, final_state} = process_ast_node(body, state)

    # Connect entry to body entries
    entry_edges =
      get_entry_nodes(body_nodes)
      |> Enum.map(fn body_entry_node_id ->
        %CFGEdge{
          from_node_id: state.entry_node,
          to_node_id: body_entry_node_id,
          type: :sequential,
          condition: nil,
          probability: 1.0,
          metadata: %{}
        }
      end)

    all_nodes = Map.put(body_nodes, state.entry_node, entry_node)
    all_edges = entry_edges ++ body_edges

    {all_nodes, all_edges, body_exits, final_state}
  end
  defp process_function_body({:defp, meta, [_head, [do: body]]}, state), do: process_function_body({:def, meta, [_head, [do: body]]}, state)
  defp process_function_body({:defmacro, meta, [_head, [do: body]]}, state), do: process_function_body({:def, meta, [_head, [do: body]]}, state)
  defp process_function_body({:defmacrop, meta, [_head, [do: body]]}, state), do: process_function_body({:def, meta, [_head, [do: body]]}, state)


  defp process_ast_node(ast, state) do
    state = %{state | next_node_id: state.next_node_id + 1}
    unique_id_base = state.next_node_id # For consistent ID generation within this node processing

    case ast do
      # Case statement
      {:case, meta, [condition_ast | clauses_ast]} ->
        process_case_statement(condition_ast, clauses_ast, meta, state, unique_id_base)

      # If statement
      {:if, meta, [condition_ast, [do: then_branch, else: else_branch]]} ->
        process_if_statement(condition_ast, then_branch, else_branch, meta, state, unique_id_base)
      {:if, meta, [condition_ast, [do: then_branch]]} -> # if without else
        process_if_statement(condition_ast, then_branch, nil, meta, state, unique_id_base)

      # Cond statement
      {:cond, meta, [[do: clauses_ast]]} ->
        process_cond_statement(clauses_ast, meta, state, unique_id_base)

      # Try-catch-rescue-after
      {:try, meta, try_clauses_ast} ->
        process_try_statement(try_clauses_ast, meta, state, unique_id_base)

      # Pipe operation
      {:|>, meta, [left_ast, right_ast]} ->
        process_pipe_operation(left_ast, right_ast, meta, state) # Pipes are generally sequential

      # Function call
      {func_name, meta, args_ast} when is_atom(func_name) and is_list(args_ast) ->
        process_function_call(ast, meta, state, unique_id_base) # Pass full ast for expression

      # Block of statements
      {:__block__, meta, statements_ast} ->
        process_statement_sequence(statements_ast, meta, state)

      # Anonymous function
      {:fn, meta, clauses_ast} ->
        process_anonymous_function(clauses_ast, meta, state, unique_id_base)

      # Assignment
      {:=, meta, [_left, _right]} -> # Treat as simple expression for CFG
        process_simple_expression(ast, meta, state, unique_id_base)

      # Literals and simple variables (often part of larger expressions)
      _ when is_atom(ast) or is_number(ast) or is_binary(ast) or is_list(ast) or is_tuple(ast) ->
         # If it's a standalone literal, it's a simple expression. If part of larger, parent handles.
        process_simple_expression(ast, extract_meta(ast, state), state, unique_id_base)

      # Default for other expressions
      {_op, meta, _args} when is_list(meta) ->
        process_simple_expression(ast, meta, state, unique_id_base)
      _ -> # Unhandled AST, create a generic node
        process_simple_expression(ast, %{}, state, unique_id_base) # No meta available
    end
  end

  defp process_case_statement(condition_ast, clauses_ast, meta, state, id_base) do
    # 1. Process condition
    {cond_nodes, cond_edges, cond_exits, state_after_cond} = process_ast_node(condition_ast, state)
    case_entry_id = generate_node_id("case_entry_#{id_base}", state_after_cond) # Use unique_id_base

    case_entry_node = %CFGNode{
      id: case_entry_id, type: :case_entry, ast_node_id: get_ast_node_id(meta),
      line: get_line_number(meta), scope_id: state.current_scope, expression: condition_ast,
      predecessors: cond_exits, successors: [], metadata: %{condition_expr: condition_ast}
    }
    updated_nodes = Map.merge(cond_nodes, %{case_entry_id => case_entry_node})
    updated_edges = cond_edges ++ connect_nodes(cond_exits, case_entry_id, :sequential)

    # 2. Process each clause
    # Each clause is a branch from the case_entry_node
    # All clause exits will merge eventually (or be function exits)
    merge_node_id = generate_node_id("case_merge_#{id_base}", state_after_cond)
    merge_node = %CFGNode{id: merge_node_id, type: :statement, expression: "case_merge"} # Generic merge

    {all_clause_nodes, all_clause_edges, all_clause_exits, state_after_clauses} =
      Enum.reduce(clauses_ast, {updated_nodes, updated_edges, [], state_after_cond},
        fn clause_ast, {acc_nodes, acc_edges, acc_exits, current_state} ->
          # Process the clause_ast {:->, clause_meta, [pattern_ast, body_ast]}
          {:->, clause_meta, [pattern_ast, body_ast]} = clause_ast
          clause_node_id = generate_node_id("case_clause_#{id_base}", current_state)
          clause_node = %CFGNode{
            id: clause_node_id, type: :case_clause, ast_node_id: get_ast_node_id(clause_meta),
            line: get_line_number(clause_meta), scope_id: create_scoped_block("case", current_state),
            expression: pattern_ast, predecessors: [case_entry_id], successors: []
          }

          pattern_edge = %CFGEdge{from_node_id: case_entry_id, to_node_id: clause_node_id, type: :pattern_match, condition: pattern_ast}

          {body_nodes, body_edges, body_exit_ids, state_after_body} = process_ast_node(body_ast, enter_scope(current_state, clause_node.scope_id))
          state_after_body = exit_scope(state_after_body) # Exit the clause scope

          clause_body_entry_ids = get_entry_nodes(body_nodes)
          connect_clause_to_body_edges = connect_nodes([clause_node_id], clause_body_entry_ids, :sequential)

          {
            acc_nodes |> Map.merge(body_nodes) |> Map.put(clause_node_id, clause_node),
            acc_edges ++ [pattern_edge] ++ connect_clause_to_body_edges ++ body_edges,
            acc_exits ++ body_exit_ids,
            state_after_body
          }
      end)

    # Connect all clause exits to the merge node
    merge_edges = connect_nodes(all_clause_exits, merge_node_id, :sequential)
    final_nodes = Map.put(all_clause_nodes, merge_node_id, merge_node)

    # What if a clause doesn't match? Need a fallthrough path for `case` if no clause matches (runtime error or next statement)
    # For CFG, assume one clause matches or it's an error. Simpler: merge to a single exit.
    {final_nodes, all_clause_edges ++ merge_edges, [merge_node_id], state_after_clauses}
  end

  defp process_if_statement(condition_ast, then_branch_ast, else_branch_ast, meta, state, id_base) do
    # 1. Condition node
    {cond_nodes, cond_edges, cond_exits, state_after_cond} = process_ast_node(condition_ast, state)
    if_node_id = generate_node_id("if_cond_#{id_base}", state_after_cond)
    if_node = %CFGNode{
      id: if_node_id, type: :if_condition, ast_node_id: get_ast_node_id(meta),
      line: get_line_number(meta), scope_id: state.current_scope, expression: condition_ast,
      predecessors: cond_exits, successors: []
    }
    current_nodes = Map.merge(cond_nodes, %{if_node_id => if_node})
    current_edges = cond_edges ++ connect_nodes(cond_exits, if_node_id, :sequential)

    # 2. Then branch
    then_scope_id = create_scoped_block("if_then", state_after_cond)
    {then_nodes, then_edges, then_exits, state_after_then} = process_ast_node(then_branch_ast, enter_scope(state_after_cond, then_scope_id))
    state_after_then = exit_scope(state_after_then)
    then_entry_nodes = get_entry_nodes(then_nodes)
    true_edges = connect_nodes([if_node_id], then_entry_nodes, :conditional, "true")
    current_nodes = Map.merge(current_nodes, then_nodes)
    current_edges = current_edges ++ true_edges ++ then_edges

    # 3. Else branch (if exists)
    {else_nodes, else_edges, else_exits, state_after_else} =
      if else_branch_ast do
        else_scope_id = create_scoped_block("if_else", state_after_then)
        {nodes, edges, exits, st} = process_ast_node(else_branch_ast, enter_scope(state_after_then, else_scope_id))
        st = exit_scope(st)
        else_entry_nodes = get_entry_nodes(nodes)
        false_edges = connect_nodes([if_node_id], else_entry_nodes, :conditional, "false")
        current_nodes = Map.merge(current_nodes, nodes)
        current_edges = current_edges ++ false_edges ++ edges
        {nodes, edges, exits, st} # We care about exits from this block
      else
        # No else branch, flow continues from if_node_id if condition is false
        {%{}, [], [if_node_id], state_after_then} # Use if_node_id as exit if no else
      end

    # 4. Merge node
    merge_node_id = generate_node_id("if_merge_#{id_base}", state_after_else)
    merge_node = %CFGNode{id: merge_node_id, type: :statement, expression: "if_merge"}
    final_nodes = Map.put(current_nodes, merge_node_id, merge_node)

    merge_from_then_edges = connect_nodes(then_exits, merge_node_id, :sequential)
    merge_from_else_edges = if else_branch_ast, do: connect_nodes(else_exits, merge_node_id, :sequential), else: []

    final_edges = current_edges ++ merge_from_then_edges ++ merge_from_else_edges
    # If no else, the "false" branch effectively goes from `if_node` to `merge_node`
    final_edges = if !else_branch_ast do
      final_edges ++ connect_nodes([if_node_id], [merge_node_id], :conditional, "false (implicit)")
    else
      final_edges
    end

    {final_nodes, final_edges, [merge_node_id], state_after_else}
  end


  defp process_cond_statement(clauses_ast, meta, state, id_base) do
    cond_entry_id = generate_node_id("cond_entry_#{id_base}", state)
    cond_entry_node = %CFGNode{
      id: cond_entry_id, type: :cond_entry, ast_node_id: get_ast_node_id(meta),
      line: get_line_number(meta), scope_id: state.current_scope, expression: "cond"
    }

    merge_node_id = generate_node_id("cond_merge_#{id_base}", state)
    merge_node = %CFGNode{id: merge_node_id, type: :statement, expression: "cond_merge"}

    {all_clause_nodes, all_clause_edges, _last_clause_exit, final_state} =
      Enum.reduce(clauses_ast, {%{cond_entry_id => cond_entry_node}, [], [cond_entry_id], state},
        fn clause_ast, {acc_nodes, acc_edges, prev_clause_failure_exits, current_state} ->
          {:->, clause_meta, [condition_ast, body_ast]} = clause_ast
          clause_cond_id = generate_node_id("cond_clause_cond_#{id_base}", current_state)
          clause_cond_node = %CFGNode{
            id: clause_cond_id, type: :cond_clause, ast_node_id: get_ast_node_id(clause_meta),
            line: get_line_number(clause_meta), scope_id: current_state.current_scope, expression: condition_ast
          }

          # Edges from previous clause failures (or cond_entry) to this condition check
          cond_check_edges = connect_nodes(prev_clause_failure_exits, clause_cond_id, :sequential)

          # Process body
          clause_scope_id = create_scoped_block("cond_clause", current_state)
          {body_nodes, body_edges, body_exit_ids, state_after_body} = process_ast_node(body_ast, enter_scope(current_state, clause_scope_id))
          state_after_body = exit_scope(state_after_body)

          body_entry_ids = get_entry_nodes(body_nodes)
          success_edges = connect_nodes([clause_cond_id], body_entry_ids, :conditional, "true") # Edge if condition true
          # Body exits go to merge_node
          to_merge_edges = connect_nodes(body_exit_ids, merge_node_id, :sequential)

          {
            acc_nodes |> Map.merge(body_nodes) |> Map.put(clause_cond_id, clause_cond_node),
            acc_edges ++ cond_check_edges ++ success_edges ++ body_edges ++ to_merge_edges,
            [clause_cond_id], # If this condition fails, flow goes to next clause_cond_id (or final exit)
            state_after_body
          }
        end)

    # If the last clause condition is `true` or if all conditions fail, where does it go?
    # For `cond`, if all conditions are false, it's a runtime error.
    # Here, we assume the last `prev_clause_failure_exits` (which is `[clause_cond_id]` of the last clause)
    # might implicitly go to the merge if we consider `true` as a catch-all.
    # If the last clause condition can fail, its failure path should also go to merge_node (or represent error).
    # For simplicity, we make the final failure path go to the merge node.
    # The `_last_clause_exit` contains the ID of the last condition check node.
    # If it's not a `true` condition, its "false" path needs to be handled.
    # This depends on whether the last clause is `true -> ...`.
    # Let's assume a "fallthrough" to merge if all fail (simplification).

    # Check if the last clause is `true`. If not, its failure path should also go to the merge node.
    last_clause_failure_edge =
      case List.last(clauses_ast) do
        {:->, _, [{:true, _, _} | _]} -> [] # `true` condition, no "false" path from it.
        {:->, _, _} -> connect_nodes(_last_clause_exit, merge_node_id, :conditional, "false (fallthrough)")
        _ -> []
      end

    final_nodes = Map.put(all_clause_nodes, merge_node_id, merge_node)
    final_edges = all_clause_edges ++ last_clause_failure_edge

    {final_nodes, final_edges, [merge_node_id], final_state}
  end

  defp process_try_statement(try_clauses_ast, meta, state, id_base) do
    # :try block, :catch clauses, :rescue clauses, :after clause
    # {:try, meta, [main_block, rescue_clauses, catch_clauses, after_block]}
    # The structure of try_clauses_ast can vary.
    # A common structure from Macro.expand is [[do: try_block], [rescue: rescue_list], [after: after_block]]

    try_entry_id = generate_node_id("try_entry_#{id_base}", state)
    try_entry_node = %CFGNode{id: try_entry_id, type: :try_entry, ast_node_id: get_ast_node_id(meta), line: get_line_number(meta)}

    do_block_ast = Keyword.get(try_clauses_ast, :do)
    rescue_clauses_ast = Keyword.get(try_clauses_ast, :rescue, []) # list of {:->, ...}
    catch_clauses_ast = Keyword.get(try_clauses_ast, :catch, []) # list of {:->, ...}
    after_block_ast = Keyword.get(try_clauses_ast, :after)

    all_nodes = %{try_entry_id => try_entry_node}
    all_edges = []
    current_exits = [try_entry_id]
    current_state = state

    # Process :do block
    {do_nodes, do_edges, do_exits, state_after_do} = if do_block_ast do
      process_ast_node(do_block_ast, current_state)
    else
      {%{}, [], [try_entry_id], current_state} # If no do block, flow is just from try_entry
    end
    all_nodes = Map.merge(all_nodes, do_nodes)
    all_edges = all_edges ++ do_edges ++ connect_nodes(current_exits, get_entry_nodes(do_nodes), :sequential)
    normal_flow_exits = do_exits # Exits if no exception
    current_state = state_after_do

    # Process :rescue clauses
    # Rescue clauses are alternative paths from anywhere within the :do block (conceptually)
    # or from the do_block's normal exit if an error is propagated.
    # For CFG, we simplify: an edge from try_entry to each rescue clause check.
    rescue_exit_points = []
    {rescue_nodes_acc, rescue_edges_acc, state_after_rescues} =
      Enum.reduce(rescue_clauses_ast, {%{}, [], current_state},
        fn rescue_clause, {nodes, edges, st} ->
          # rescue_clause is {:->, rescue_meta, [exception_pattern, body_ast]}
          {:->, r_meta, [exc_pattern, r_body_ast]} = rescue_clause
          rescue_node_id = generate_node_id("rescue_clause_#{id_base}", st)
          rescue_node = %CFGNode{
            id: rescue_node_id, type: :rescue_clause, ast_node_id: get_ast_node_id(r_meta),
            line: get_line_number(r_meta), expression: exc_pattern,
            scope_id: create_scoped_block("rescue", st)
          }
          # Edge from try_entry (representing potential exception) to this rescue handler
          exc_edge = %CFGEdge{from_node_id: try_entry_id, to_node_id: rescue_node_id, type: :exception}

          {r_body_nodes, r_body_edges, r_body_exits, st_after_r_body} = process_ast_node(r_body_ast, enter_scope(st, rescue_node.scope_id))
          st_after_r_body = exit_scope(st_after_r_body)
          rescue_exit_points = rescue_exit_points ++ r_body_exits

          connect_rescue_to_body = connect_nodes([rescue_node_id], get_entry_nodes(r_body_nodes), :sequential)
          {
            nodes |> Map.merge(r_body_nodes) |> Map.put(rescue_node_id, rescue_node),
            edges ++ [exc_edge] ++ connect_rescue_to_body ++ r_body_edges,
            st_after_r_body
          }
      end)
    all_nodes = Map.merge(all_nodes, rescue_nodes_acc)
    all_edges = all_edges ++ rescue_edges_acc
    current_state = state_after_rescues

    # Process :catch clauses (similar to rescue)
    catch_exit_points = []
    # ... (similar logic for catch clauses, type :catch_clause) ...
    # For brevity, skipping full catch implementation, but it's symmetric to rescue

    # Process :after block (if exists)
    # The :after block is executed regardless of exceptions.
    # So, normal_flow_exits, rescue_exit_points, catch_exit_points all go to :after block entry.
    final_exits_before_after = normal_flow_exits ++ rescue_exit_points ++ catch_exit_points
    {after_nodes, after_edges, after_exits, state_after_after} = if after_block_ast do
      after_node_id = generate_node_id("after_clause_#{id_base}", current_state)
      after_node_entry = %CFGNode{
          id: after_node_id, type: :after_clause, expression: "after_block_entry",
          scope_id: create_scoped_block("after", current_state)
      }
      after_entry_edge = connect_nodes(List.flatten(final_exits_before_after) |> Enum.uniq(), after_node_id, :sequential)

      {body_nodes, body_edges, body_exits, st_after_ab} = process_ast_node(after_block_ast, enter_scope(current_state, after_node_entry.scope_id))
      st_after_ab = exit_scope(st_after_ab)
      connect_after_to_body = connect_nodes([after_node_id], get_entry_nodes(body_nodes), :sequential)

      { Map.merge(%{after_node_id => after_node_entry}, body_nodes),
        after_entry_edge ++ connect_after_to_body ++ body_edges,
        body_exits,
        st_after_ab
      }
    else
      {%{}, [], final_exits_before_after, current_state} # If no after, exits are combined previous exits
    end
    all_nodes = Map.merge(all_nodes, after_nodes)
    all_edges = all_edges ++ after_edges

    {all_nodes, all_edges, after_exits, state_after_after}
  end

  defp process_pipe_operation(left_ast, right_ast, meta, state) do
    # A |> B. Process A, then connect its exit to B's entry.
    {left_nodes, left_edges, left_exits, state_after_left} = process_ast_node(left_ast, state)
    # The right side is often a function call {func, meta, [arg1, ...]} where arg1 is implicit result of left
    # Or it could be an anonymous function.
    # For CFG, right_ast is a node.
    {right_nodes, right_edges, right_exits, state_after_right} = process_ast_node(right_ast, state_after_left)

    pipe_edges = connect_nodes(left_exits, get_entry_nodes(right_nodes), :sequential)

    all_nodes = Map.merge(left_nodes, right_nodes)
    all_edges = left_edges ++ pipe_edges ++ right_edges
    {all_nodes, all_edges, right_exits, state_after_right}
  end

  defp process_function_call(call_ast, meta, state, id_base) do
    # call_ast is like {func_name, meta, args_ast}
    # First, process arguments as they might involve computations / other calls
    args_ast = case call_ast do
      {_func_name, _m, args} when is_list(args) -> args
      _ -> []
    end

    {args_nodes_acc, args_edges_acc, last_arg_exits, state_after_args} =
      Enum.reduce(args_ast, {%{}, [], [], state}, fn arg_expr, {nodes, edges, prev_exits, st} ->
        {arg_nodes, arg_edges, arg_exits, st_after_arg} = process_ast_node(arg_expr, st)
        connect_edges = if prev_exits != [], do: connect_nodes(prev_exits, get_entry_nodes(arg_nodes), :sequential), else: []
        {
          Map.merge(nodes, arg_nodes),
          edges ++ connect_edges ++ arg_edges,
          arg_exits, # Current arg exits become prev_exits for next
          st_after_arg
        }
      end)

    # Then create the call node itself
    call_node_id = generate_node_id("call_#{id_base}", state_after_args)
    call_node = %CFGNode{
      id: call_node_id, type: :function_call, ast_node_id: get_ast_node_id(meta),
      line: get_line_number(meta), scope_id: state.current_scope, expression: call_ast,
      predecessors: last_arg_exits, successors: []
    }
    call_edges = if last_arg_exits != [], do: connect_nodes(last_arg_exits, call_node_id, :sequential), else: []

    # If no args, last_arg_exits is empty. The call_node's predecessors will be set by its caller.
    # The call_node is an exit point itself.
    all_nodes = Map.put(args_nodes_acc, call_node_id, call_node)
    all_edges = args_edges_acc ++ call_edges
    {all_nodes, all_edges, [call_node_id], state_after_args}
  end

  defp process_statement_sequence(statements_ast, meta, state) do
    # Process list of statements sequentially
    {nodes, edges, last_exits, final_state} =
      Enum.reduce(statements_ast, {%{}, [], [], state},
        fn stmt_ast, {acc_nodes, acc_edges, prev_exits, current_state} ->
          {stmt_nodes, stmt_edges, stmt_exits, state_after_stmt} = process_ast_node(stmt_ast, current_state)
          # Connect previous exits to current statement entries
          connect_prev_to_curr_edges = if prev_exits != [] do
            connect_nodes(prev_exits, get_entry_nodes(stmt_nodes), :sequential)
          else
            [] # First statement in block
          end
          {
            Map.merge(acc_nodes, stmt_nodes),
            acc_edges ++ connect_prev_to_curr_edges ++ stmt_edges,
            stmt_exits, # Current exits become prev_exits for next
            state_after_stmt
          }
        end)
    {nodes, edges, last_exits, final_state}
  end

  defp process_anonymous_function(clauses_ast, meta, state, id_base) do
    # Create a single node representing the anonymous function definition.
    # The internal CFG of the anonymous function is separate.
    # Here, we are interested in the point where `fn ... end` is defined.
    fn_node_id = generate_node_id("anon_fn_def_#{id_base}", state)
    fn_node = %CFGNode{
      id: fn_node_id, type: :anonymous_function, ast_node_id: get_ast_node_id(meta),
      line: get_line_number(meta), scope_id: state.current_scope,
      expression: {:fn, meta, clauses_ast}, predecessors: [], successors: []
    }
    # Optionally, trigger a separate CFG generation for the fn body here if needed.
    # For this CFG, the `fn` definition is just one statement.
    {%{fn_node_id => fn_node}, [], [fn_node_id], state}
  end

  defp process_simple_expression(ast, meta, state, id_base) do
    # For any other simple expression or unhandled AST
    node_id = generate_node_id("expr_#{id_base}", state)
    node = %CFGNode{
      id: node_id, type: :statement, ast_node_id: get_ast_node_id(meta),
      line: get_line_number(meta), scope_id: state.current_scope, expression: ast,
      predecessors: [], successors: []
    }
    {%{node_id => node}, [], [node_id], state}
  end


  defp calculate_complexity_metrics(nodes, edges) do
    decision_points = count_decision_points(nodes)
    cyclomatic_decision_based = decision_points + 1
    cognitive = calculate_cognitive_complexity(nodes, edges) # Pass edges for context if needed
    nesting_depth = calculate_nesting_depth(nodes)

    %ComplexityMetrics{
      cyclomatic_complexity: cyclomatic_decision_based,
      essential_complexity: calculate_essential_complexity(nodes, edges),
      cognitive_complexity: cognitive,
      pattern_complexity: count_pattern_matches(nodes),
      guard_complexity: count_guards(nodes),
      pipe_chain_length: calculate_max_pipe_chain(nodes, edges),
      nesting_depth: nesting_depth,
      total_paths: calculate_total_paths(nodes, edges, get_entry_node_id(nodes)),
      unreachable_paths: find_unreachable_paths(nodes, edges, get_entry_node_id(nodes)),
      critical_path_length: find_critical_path_length(nodes, edges, get_entry_node_id(nodes)),
      error_prone_patterns: detect_error_prone_patterns(nodes, edges),
      performance_risks: detect_performance_risks(nodes, edges),
      maintainability_score: calculate_maintainability_score(cyclomatic_decision_based, cognitive, nesting_depth)
    }
  end

  defp count_decision_points(nodes) do
    nodes
    |> Map.values()
    |> Enum.count(fn node ->
      node.type in [
        :case_entry, :if_condition, :cond_clause, # cond_clause is a decision
        :guard_check, # Assuming guard_check nodes are created
        # :pattern_match (if a single pattern match can lead to multiple paths based on success/failure)
        :try_entry # try can be considered a decision point due to exception paths
      ]
    end)
  end

  defp calculate_cognitive_complexity(nodes, _edges) do # edges might be useful for some heuristics
    # Simplified cognitive complexity: increment for branching and nesting
    nodes
    |> Map.values()
    |> Enum.reduce(0, fn node, acc ->
      branch_increment = case node.type do
        :case_entry | :if_condition | :cond_entry | :cond_clause | :guard_check | :try_entry -> 1
        # Loops (not explicitly handled yet, but would add here)
        _ -> 0
      end
      # Nesting penalty - requires tracking nesting level during CFG construction
      nesting_penalty = get_nesting_level_for_node(node, nodes) # Needs implementation
      acc + branch_increment + nesting_penalty
    end)
  end

  # Utility functions

  defp generate_node_id(prefix, state) do
    # Ensure state.next_node_id is part of the unique key if prefix is not unique enough per call
    id = "#{prefix}_#{state.next_node_id}"
    id
  end

  defp get_ast_node_id(meta) when is_list(meta), do: Keyword.get(meta, :ast_node_id) # Standard Elixir AST meta
  defp get_ast_node_id(_), do: nil # Fallback

  defp get_ast_node_id_from_ast({_op, meta, _args}) when is_list(meta), do: get_ast_node_id(meta)
  defp get_ast_node_id_from_ast(_), do: nil

  defp get_line_number(meta) when is_list(meta), do: Keyword.get(meta, :line, 0)
  defp get_line_number(_), do: 0

  defp extract_meta(ast_node, default_meta \\ %{}) do
    case ast_node do
      {_, meta, _} when is_list(meta) -> meta
      _ -> default_meta
    end
  end


  defp create_scoped_block(type_prefix, state) do
    new_scope_id_val = state.scope_id_counter + 1
    new_scope_id = create_scope_id(type_prefix, new_scope_id_val, state.current_scope)
    new_scope_info = %ScopeInfo{id: new_scope_id, type: String.to_atom(type_prefix), parent_scope: state.current_scope, child_scopes: [], variables: []}

    # Update parent's child_scopes (if parent exists)
    updated_parent_scopes =
      if parent_scope_info = state.scopes[state.current_scope] do
        Map.put(state.scopes, state.current_scope, %{parent_scope_info | child_scopes: [new_scope_id | parent_scope_info.child_scopes]})
      else
        state.scopes # Should not happen if current_scope is always valid
      end

    %{state |
        scopes: Map.put(updated_parent_scopes, new_scope_id, new_scope_info),
        scope_id_counter: new_scope_id_val
     }, new_scope_id
  end
  # Overload for initial state where state.scope_id_counter might not exist
  defp create_scope_id(prefix, id_val, parent_id) do
    "#{prefix}_#{id_val}_parent_#{parent_id}"
  end

  defp enter_scope(state, scope_id) do
    %{state | current_scope: scope_id}
  end

  defp exit_scope(state) do
    parent_scope_id = state.scopes[state.current_scope].parent_scope
    %{state | current_scope: parent_scope_id}
  end


  defp get_entry_nodes(nodes_map) when map_size(nodes_map) == 0, do: []
  defp get_entry_nodes(nodes_map) do
    all_node_ids = Map.keys(nodes_map)
    nodes_with_predecessors = nodes_map
      |> Map.values()
      |> Enum.flat_map(&(&1.predecessors)) # Get all predecessor IDs mentioned
      |> MapSet.new()

    all_node_ids
    |> Enum.reject(& MapSet.member?(nodes_with_predecessors, &1)) # Nodes not mentioned as predecessors
    |> case do # Ensure it's not empty, pick first if all have predecessors (e.g. loop)
        [] -> if all_node_ids == [], do: [], else: [List.first(all_node_ids)]
        entries -> entries
      end
  end

  defp connect_nodes([], _to_node_ids, _type, _cond \\ nil), do: []
  defp connect_nodes(_from_node_ids, [], _type, _cond \\ nil), do: []
  defp connect_nodes(from_node_ids, to_node_ids, type, condition \\ nil) when is_list(from_node_ids) and is_list(to_node_ids) do
    for from_id <- from_node_ids, to_id <- to_node_ids do
      %CFGEdge{
        from_node_id: from_id,
        to_node_id: to_id,
        type: type,
        condition: condition,
        probability: if(type == :conditional, do: 0.5, else: 1.0), # Simplified
        metadata: %{}
      }
    end
  end
  defp connect_nodes(from_node_id, to_node_id, type, condition \\ nil) do
    connect_nodes([from_node_id], [to_node_id], type, condition)
  end


  defp calculate_pattern_probability(_pattern) do
    0.5 # Placeholder
  end

  defp extract_function_key({:def, _meta, [{name, _meta2, args} | _]}) do
    arity = if is_list(args), do: length(args), else: 0
    module_name = _meta2[:module] || UnknownModule # Try to get module from context if available
    {module_name, name, arity}
  end
  defp extract_function_key(_), do: {UnknownModule, :unknown, 0}


  # Placeholder/Simplified implementations for remaining complexity calculations
  defp calculate_essential_complexity(_nodes, _edges), do: 0 # Placeholder
  defp count_pattern_matches(nodes) do
    Enum.count(Map.values(nodes), fn node -> node.type == :pattern_match or node.type == :case_clause end)
  end
  defp count_guards(nodes) do
    Enum.count(Map.values(nodes), fn node -> node.type == :guard_check end) # Assuming :guard_check nodes
  end
  defp calculate_max_pipe_chain(_nodes, _edges) do
    # Needs to trace :pipe_operation sequences
    0 # Placeholder
  end
  defp calculate_nesting_depth(nodes) do
    # This requires analyzing scope hierarchy or AST depth related to control structures
    # For now, a simple placeholder.
    nodes
    |> Map.values()
    |> Enum.map(&get_nesting_level_for_node(&1, nodes))
    |> Enum.max(default: 0)
  end
  defp get_nesting_level_for_node(node, all_nodes) do
    # A proper implementation would traverse parent scopes or AST structure.
    # Simplified: count parent control structure nodes if CFG nodes are nested.
    # This is a very rough estimate based on node types.
    # True nesting requires scope analysis or AST analysis tied to CFG nodes.
    # For now, return 0 or a very simple heuristic.
    case node.type do
      :if_then | :if_else | :case_clause | :cond_clause | :rescue_clause | :catch_clause -> 1 # Each nested block
      _ -> 0
    end
    # A better approach would be to pass the current nesting depth down during CFG construction.
  end

  defp calculate_total_paths(_nodes, _edges, _entry_node_id), do: 0 # Placeholder - requires path traversal alg
  defp find_unreachable_paths(_nodes, _edges, _entry_node_id), do: 0 # Placeholder - requires traversal from entry
  defp find_critical_path_length(_nodes, _edges, _entry_node_id), do: 0 # Placeholder - requires weighted path alg
  defp detect_error_prone_patterns(_nodes, _edges), do: 0 # Placeholder - specific pattern matching logic
  defp detect_performance_risks(_nodes, _edges), do: 0 # Placeholder - specific pattern matching logic
  defp calculate_maintainability_score(cyclomatic, cognitive, nesting) do
    max(0, 100 - (cyclomatic * 2) - (cognitive * 1) - (nesting * 5)) # Adjusted weights
  end

  defp analyze_paths(_nodes, _edges, _entry_node_id) do
    # Placeholder for PathAnalysis.t()
    # This would involve algorithms like finding all simple paths, dominators, etc.
    %{
      # Example fields (currently not defined in PathAnalysis.t struct)
      # dominator_tree: %{},
      # post_dominator_tree: %{},
      # loops_detected: []
    }
  end

  defp get_entry_node_id(nodes) do
    # Simplified: find the node with type :entry or the first node if not found
    nodes
    |> Map.values()
    |> Enum.find(&(&1.type == :entry))
    |> case do
      nil -> if map_size(nodes) > 0, do: (nodes |> Map.keys() |> List.first()), else: nil
      entry_node -> entry_node.id
    end
  end

end
