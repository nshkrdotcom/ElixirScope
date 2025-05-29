defmodule ElixirScope.ASTRepository.Enhanced.CFGGenerator.ConditionalHandler do
  @moduledoc """
  Handles conditional control flow AST nodes (if, unless, case, cond) for CFG generation.
  """

  alias ElixirScope.ASTRepository.Enhanced.{
    CFGNode,
    CFGEdge,
    ScopeInfo,
    CFGGenerator.Utils
  }

  @doc """
  Processes an if statement.
  `ast_processor_func` is `ASTProcessor.process_ast_node/2`.
  """
  def handle_if_statement(condition, then_branch, else_clause, meta, state, ast_processor_func) do
    line = Utils.get_line_number(meta)
    {if_id, updated_state} = Utils.generate_node_id("if_condition", state)

    # Create if condition node (decision point)
    if_node = %CFGNode{
      id: if_id,
      type: :conditional,
      ast_node_id: Utils.get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: condition,
      predecessors: [],
      successors: [],
      metadata: %{condition: condition}
    }

    # Process condition
    {cond_nodes, cond_edges, cond_exits, cond_scopes, cond_state} =
      ast_processor_func.(condition, updated_state)

    # Connect condition to if node
    cond_to_if_edges = Enum.map(cond_exits, fn exit_id ->
      %CFGEdge{
        from_node_id: exit_id,
        to_node_id: if_id,
        type: :sequential,
        condition: nil,
        probability: 1.0,
        metadata: %{}
      }
    end)

    # Create scope for then branch
    then_scope_id = Utils.generate_scope_id("if_then", cond_state)
    then_scope = %ScopeInfo{
      id: then_scope_id,
      type: :if_then,
      parent_scope: cond_state.current_scope,
      child_scopes: [],
      variables: [],
      ast_node_id: Utils.get_ast_node_id(meta),
      entry_points: [],
      exit_points: [],
      metadata: %{condition: condition}
    }

    # Process then branch in new scope
    then_state_with_scope = %{cond_state | current_scope: then_scope_id, scope_counter: cond_state.scope_counter + 1}
    {then_nodes, then_edges, then_exits, then_scopes_inner, then_state} =
      ast_processor_func.(then_branch, then_state_with_scope)

    then_scopes = Map.put(then_scopes_inner, then_scope_id, then_scope)

    # Connect if to then branch
    then_entry_nodes = Utils.get_entry_nodes(then_nodes)
    if_to_then_edges = Enum.map(then_entry_nodes, fn node_id ->
      %CFGEdge{
        from_node_id: if_id,
        to_node_id: node_id,
        type: :conditional,
        condition: {:true_branch, condition},
        probability: 0.5,
        metadata: %{branch: :then}
      }
    end)

    # Process else branch
    {else_nodes, else_edges, else_exits, else_scopes, final_state} = case else_clause do
      [else: else_branch] ->
        # Create scope for else branch
        else_scope_id = Utils.generate_scope_id("if_else", then_state)
        else_scope = %ScopeInfo{
          id: else_scope_id,
          type: :if_else,
          parent_scope: cond_state.current_scope,
          child_scopes: [],
          variables: [],
          ast_node_id: Utils.get_ast_node_id(meta),
          entry_points: [],
          exit_points: [],
          metadata: %{condition: condition}
        }

        # Process else branch in new scope
        else_state_with_scope = %{then_state | current_scope: else_scope_id, scope_counter: then_state.scope_counter + 1}
        {else_nodes_inner, else_edges_inner, else_exits_inner, else_scopes_inner, final_state_inner} =
          ast_processor_func.(else_branch, else_state_with_scope)

        else_scopes_final = Map.put(else_scopes_inner, else_scope_id, else_scope)
        {else_nodes_inner, else_edges_inner, else_exits_inner, else_scopes_final, final_state_inner}
      [] ->
        # No else clause - if can flow directly to exit
        {%{}, [], [if_id], %{}, then_state}
    end

    # Connect if to else branch (if exists)
    if_to_else_edges = case else_clause do
      [else: _] ->
        else_entry_nodes = Utils.get_entry_nodes(else_nodes)
        Enum.map(else_entry_nodes, fn node_id ->
          %CFGEdge{
            from_node_id: if_id,
            to_node_id: node_id,
            type: :conditional,
            condition: {:false_branch, condition},
            probability: 0.5,
            metadata: %{branch: :else}
          }
        end)
      [] ->
        []
    end

    all_nodes = cond_nodes
    |> Map.merge(then_nodes)
    |> Map.merge(else_nodes)
    |> Map.put(if_id, if_node)

    all_edges = cond_edges ++ cond_to_if_edges ++ then_edges ++ if_to_then_edges ++ else_edges ++ if_to_else_edges
    all_scopes = Map.merge(cond_scopes, Map.merge(then_scopes, else_scopes))
    all_exits = then_exits ++ else_exits

    {all_nodes, all_edges, all_exits, all_scopes, final_state}
  end

  @doc """
  Processes an unless statement.
  `ast_processor_func` is `ASTProcessor.process_ast_node/2`.
  """
  def handle_unless_statement(condition, clauses, meta, state, ast_processor_func) do
    # Unless is equivalent to if not condition
    then_branch = Keyword.get(clauses, :do)
    else_clause = case Keyword.get(clauses, :else) do
      nil -> []
      else_branch -> [else: else_branch]
    end

    # Process as inverted if statement
    handle_if_statement({:not, [], [condition]}, then_branch, else_clause, meta, state, ast_processor_func)
  end

  @doc """
  Processes a case statement.
  `ast_processor_func` is `ASTProcessor.process_ast_node/2`.
  """
  def handle_case_statement(condition, clauses, meta, state, ast_processor_func) do
    line = Utils.get_line_number(meta)
    {case_entry_id, updated_state} = Utils.generate_node_id("case_entry", state)

    case_entry = %CFGNode{
      id: case_entry_id,
      type: :case,
      ast_node_id: Utils.get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: condition,
      predecessors: [],
      successors: [],
      metadata: %{condition: condition, clause_count: length(clauses)}
    }

    {cond_nodes, cond_edges, cond_exits, cond_scopes, cond_state} =
      ast_processor_func.(condition, updated_state)

    cond_to_case_edges = Enum.map(cond_exits, fn exit_id ->
      %CFGEdge{
        from_node_id: exit_id,
        to_node_id: case_entry_id,
        type: :sequential,
        condition: nil,
        probability: 1.0,
        metadata: %{}
      }
    end)

    {clause_nodes, clause_edges, clause_exits, clause_scopes, final_state} =
      process_case_clauses(clauses, case_entry_id, cond_state, ast_processor_func)

    all_nodes = cond_nodes
    |> Map.merge(clause_nodes)
    |> Map.put(case_entry_id, case_entry)

    all_edges = cond_edges ++ cond_to_case_edges ++ clause_edges
    all_scopes = Map.merge(cond_scopes, clause_scopes)

    {all_nodes, all_edges, clause_exits, all_scopes, final_state}
  end

  defp process_case_clauses(clauses, entry_node_id, state, ast_processor_func) do
    Enum.reduce(clauses, {%{}, [], [], %{}, state}, fn clause, {nodes, edges, exits, scopes, acc_state} ->
      {clause_nodes, clause_edges, clause_exits, clause_scopes, new_state} =
        process_case_clause(clause, entry_node_id, acc_state, ast_processor_func)

      merged_nodes = Map.merge(nodes, clause_nodes)
      merged_edges = edges ++ clause_edges
      merged_exits = exits ++ clause_exits
      merged_scopes = Map.merge(scopes, clause_scopes)

      {merged_nodes, merged_edges, merged_exits, merged_scopes, new_state}
    end)
  end

  defp process_case_clause({:->, meta, [pattern, body]}, entry_node_id, state, ast_processor_func) do
    line = Utils.get_line_number(meta)
    {clause_id, updated_state} = Utils.generate_node_id("case_clause", state)
    clause_scope_id = Utils.generate_scope_id("case_clause", updated_state)

    clause_scope = %ScopeInfo{
      id: clause_scope_id,
      type: :case_clause,
      parent_scope: state.current_scope,
      child_scopes: [],
      variables: Utils.extract_pattern_variables(pattern),
      ast_node_id: Utils.get_ast_node_id(meta),
      entry_points: [clause_id],
      exit_points: [],
      metadata: %{pattern: pattern}
    }

    clause_node = %CFGNode{
      id: clause_id,
      type: :case_clause,
      ast_node_id: Utils.get_ast_node_id(meta),
      line: line,
      scope_id: clause_scope_id,
      expression: pattern,
      predecessors: [entry_node_id],
      successors: [],
      metadata: %{pattern: pattern}
    }

    entry_edge = %CFGEdge{
      from_node_id: entry_node_id,
      to_node_id: clause_id,
      type: :pattern_match,
      condition: pattern,
      probability: Utils.calculate_pattern_probability(pattern),
      metadata: %{pattern: pattern}
    }

    clause_state = %{updated_state | current_scope: clause_scope_id, scope_counter: updated_state.scope_counter + 1}
    {body_nodes, body_edges, body_exits, body_scopes, final_state} =
      ast_processor_func.(body, clause_state)

    body_entry_nodes = Utils.get_entry_nodes(body_nodes)
    clause_to_body_edges = Enum.map(body_entry_nodes, fn node_id ->
      %CFGEdge{
        from_node_id: clause_id,
        to_node_id: node_id,
        type: :sequential,
        condition: nil,
        probability: 1.0,
        metadata: %{}
      }
    end)

    all_nodes = Map.put(body_nodes, clause_id, clause_node)
    all_edges = [entry_edge] ++ clause_to_body_edges ++ body_edges
    all_scopes = Map.put(body_scopes, clause_scope_id, clause_scope)

    {all_nodes, all_edges, body_exits, all_scopes, final_state}
  end

  @doc """
  Processes a cond statement (placeholder).
  `ast_processor_func` is `ASTProcessor.process_ast_node/2`.
  """
  def handle_cond_statement(_clauses, _meta, state, _ast_processor_func) do
    # Placeholder implementation
    {%{}, [], [], %{}, state}
  end
end 