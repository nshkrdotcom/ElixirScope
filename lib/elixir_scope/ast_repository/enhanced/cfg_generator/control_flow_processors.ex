defmodule ElixirScope.ASTRepository.Enhanced.CFGGenerator.ControlFlowProcessors do
  @moduledoc """
  Processors for control flow constructs (case, if, try, etc.).
  """

  alias ElixirScope.ASTRepository.Enhanced.{CFGNode, CFGEdge, ScopeInfo}
  alias ElixirScope.ASTRepository.Enhanced.CFGGenerator.{
    StateManager, ASTUtilities, ASTProcessor
  }

  @doc """
  Processes a case statement.
  """
  def process_case_statement(condition, clauses, meta, state) do
    line = ASTUtilities.get_line_number(meta)
    {case_entry_id, updated_state} = StateManager.generate_node_id("case_entry", state)

    # Create case entry node (decision point) - use :case type for test compatibility
    case_entry = %CFGNode{
      id: case_entry_id,
      type: :case,  # Changed from :case_entry to :case for test compatibility
      ast_node_id: ASTUtilities.get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: condition,
      predecessors: [],
      successors: [],
      metadata: %{condition: condition, clause_count: length(clauses)}
    }

    # Process condition expression first
    {cond_nodes, cond_edges, cond_exits, cond_scopes, cond_state} =
      ASTProcessor.process_ast_node(condition, updated_state)

    # Connect condition exits to case entry
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

    # Process each case clause
    {clause_nodes, clause_edges, clause_exits, clause_scopes, final_state} =
      process_case_clauses(clauses, case_entry_id, cond_state)

    all_nodes = cond_nodes
    |> Map.merge(clause_nodes)
    |> Map.put(case_entry_id, case_entry)

    all_edges = cond_edges ++ cond_to_case_edges ++ clause_edges
    all_scopes = Map.merge(cond_scopes, clause_scopes)

    {all_nodes, all_edges, clause_exits, all_scopes, final_state}
  end

  @doc """
  Processes an if statement.
  """
  def process_if_statement(condition, then_branch, else_clause, meta, state) do
    line = ASTUtilities.get_line_number(meta)
    {if_id, updated_state} = StateManager.generate_node_id("if_condition", state)

    # Create if condition node (decision point)
    if_node = %CFGNode{
      id: if_id,
      type: :conditional,  # Changed from :if_condition to :conditional for test compatibility
      ast_node_id: ASTUtilities.get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: condition,
      predecessors: [],
      successors: [],
      metadata: %{condition: condition}
    }

    # Process condition
    {cond_nodes, cond_edges, cond_exits, cond_scopes, cond_state} =
      ASTProcessor.process_ast_node(condition, updated_state)

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
    then_scope_id = StateManager.generate_scope_id("if_then", cond_state)
    then_scope = %ScopeInfo{
      id: then_scope_id,
      type: :if_then,
      parent_scope: cond_state.current_scope,
      child_scopes: [],
      variables: [],
      ast_node_id: ASTUtilities.get_ast_node_id(meta),
      entry_points: [],
      exit_points: [],
      metadata: %{condition: condition}
    }

    # Process then branch in new scope
    then_state_with_scope = %{cond_state | current_scope: then_scope_id, scope_counter: cond_state.scope_counter + 1}
    {then_nodes, then_edges, then_exits, then_scopes_inner, then_state} =
      ASTProcessor.process_ast_node(then_branch, then_state_with_scope)

    then_scopes = Map.put(then_scopes_inner, then_scope_id, then_scope)

    # Connect if to then branch
    then_entry_nodes = get_entry_nodes(then_nodes)
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
        else_scope_id = StateManager.generate_scope_id("if_else", then_state)
        else_scope = %ScopeInfo{
          id: else_scope_id,
          type: :if_else,
          parent_scope: cond_state.current_scope,
          child_scopes: [],
          variables: [],
          ast_node_id: ASTUtilities.get_ast_node_id(meta),
          entry_points: [],
          exit_points: [],
          metadata: %{condition: condition}
        }

        # Process else branch in new scope
        else_state_with_scope = %{then_state | current_scope: else_scope_id, scope_counter: then_state.scope_counter + 1}
        {else_nodes_inner, else_edges_inner, else_exits_inner, else_scopes_inner, final_state_inner} =
          ASTProcessor.process_ast_node(else_branch, else_state_with_scope)

        else_scopes_final = Map.put(else_scopes_inner, else_scope_id, else_scope)
        {else_nodes_inner, else_edges_inner, else_exits_inner, else_scopes_final, final_state_inner}
      [] ->
        # No else clause - if can flow directly to exit
        {%{}, [], [if_id], %{}, then_state}
    end

    # Connect if to else branch (if exists)
    if_to_else_edges = case else_clause do
      [else: _] ->
        else_entry_nodes = get_entry_nodes(else_nodes)
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
  Processes a try statement.
  """
  def process_try_statement(blocks, meta, state) do
    line = ASTUtilities.get_line_number(meta)
    {try_id, updated_state} = StateManager.generate_node_id("try_entry", state)

    # Create try entry node (decision point) - use :try type for test compatibility
    try_node = %CFGNode{
      id: try_id,
      type: :try,  # Changed from :try_entry to :try for test compatibility
      ast_node_id: ASTUtilities.get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: blocks,
      predecessors: [],
      successors: [],
      metadata: %{blocks: blocks}
    }

    # Process try body
    try_body = Keyword.get(blocks, :do)
    {body_nodes, body_edges, body_exits, body_scopes, body_state} =
      if try_body do
        ASTProcessor.process_ast_node(try_body, updated_state)
      else
        {%{}, [], [], %{}, updated_state}
      end

    # Process rescue clauses
    {rescue_nodes, rescue_edges, rescue_exits, rescue_scopes, rescue_state} =
      case Keyword.get(blocks, :rescue) do
        nil -> {%{}, [], [], %{}, body_state}
        rescue_clauses ->
          Enum.reduce(rescue_clauses, {%{}, [], [], %{}, body_state}, fn clause, {nodes, edges, exits, scopes, acc_state} ->
            {clause_nodes, clause_edges, clause_exits, clause_scopes, new_state} =
              process_rescue_clause(clause, try_id, acc_state)

            merged_nodes = Map.merge(nodes, clause_nodes)
            merged_edges = edges ++ clause_edges
            merged_exits = exits ++ clause_exits
            merged_scopes = Map.merge(scopes, clause_scopes)

            {merged_nodes, merged_edges, merged_exits, merged_scopes, new_state}
          end)
      end

    # Process catch clauses
    {catch_nodes, catch_edges, catch_exits, catch_scopes, catch_state} =
      case Keyword.get(blocks, :catch) do
        nil -> {%{}, [], [], %{}, rescue_state}
        catch_clauses ->
          Enum.reduce(catch_clauses, {%{}, [], [], %{}, rescue_state}, fn clause, {nodes, edges, exits, scopes, acc_state} ->
            {clause_nodes, clause_edges, clause_exits, clause_scopes, new_state} =
              process_catch_clause(clause, try_id, acc_state)

            merged_nodes = Map.merge(nodes, clause_nodes)
            merged_edges = edges ++ clause_edges
            merged_exits = exits ++ clause_exits
            merged_scopes = Map.merge(scopes, clause_scopes)

            {merged_nodes, merged_edges, merged_exits, merged_scopes, new_state}
          end)
      end

    # Connect try entry to body
    body_entry_nodes = get_entry_nodes(body_nodes)
    try_to_body_edges = Enum.map(body_entry_nodes, fn node_id ->
      %CFGEdge{
        from_node_id: try_id,
        to_node_id: node_id,
        type: :sequential,
        condition: nil,
        probability: 1.0,
        metadata: %{}
      }
    end)

    # Connect try to rescue/catch clauses
    try_to_rescue_edges = if map_size(rescue_nodes) > 0 do
      rescue_entry_nodes = get_entry_nodes(rescue_nodes)
      Enum.map(rescue_entry_nodes, fn node_id ->
        %CFGEdge{
          from_node_id: try_id,
          to_node_id: node_id,
          type: :exception,
          condition: :rescue,
          probability: 0.1,
          metadata: %{exception_type: :rescue}
        }
      end)
    else
      []
    end

    try_to_catch_edges = if map_size(catch_nodes) > 0 do
      catch_entry_nodes = get_entry_nodes(catch_nodes)
      Enum.map(catch_entry_nodes, fn node_id ->
        %CFGEdge{
          from_node_id: try_id,
          to_node_id: node_id,
          type: :exception,
          condition: :catch,
          probability: 0.1,
          metadata: %{exception_type: :catch}
        }
      end)
    else
      []
    end

    all_nodes = body_nodes
    |> Map.merge(rescue_nodes)
    |> Map.merge(catch_nodes)
    |> Map.put(try_id, try_node)

    all_edges = body_edges ++ rescue_edges ++ catch_edges ++ try_to_body_edges ++ try_to_rescue_edges ++ try_to_catch_edges
    all_scopes = Map.merge(body_scopes, Map.merge(rescue_scopes, catch_scopes))
    all_exits = body_exits ++ rescue_exits ++ catch_exits

    {all_nodes, all_edges, all_exits, all_scopes, catch_state}
  end

  @doc """
  Processes an unless statement.
  """
  def process_unless_statement(condition, clauses, meta, state) do
    # Unless is equivalent to if not condition
    then_branch = Keyword.get(clauses, :do)
    else_clause = case Keyword.get(clauses, :else) do
      nil -> []
      else_branch -> [else: else_branch]
    end

    # Process as inverted if statement
    process_if_statement({:not, [], [condition]}, then_branch, else_clause, meta, state)
  end

  # Placeholder implementations for other constructs
  def process_cond_statement(_clauses, _meta, state), do: {%{}, [], [], %{}, state}
  def process_with_statement(_clauses, _meta, state), do: {%{}, [], [], %{}, state}
  def process_receive_statement(_clauses, _meta, state), do: {%{}, [], [], %{}, state}

  # Private helper functions

  defp process_case_clauses(clauses, entry_node_id, state) do
    {all_nodes, all_edges, all_exits, all_scopes, final_state} =
      Enum.reduce(clauses, {%{}, [], [], %{}, state}, fn clause, {nodes, edges, exits, scopes, acc_state} ->
        {clause_nodes, clause_edges, clause_exits, clause_scopes, new_state} =
          process_case_clause(clause, entry_node_id, acc_state)

        merged_nodes = Map.merge(nodes, clause_nodes)
        merged_edges = edges ++ clause_edges
        merged_exits = exits ++ clause_exits
        merged_scopes = Map.merge(scopes, clause_scopes)

        {merged_nodes, merged_edges, merged_exits, merged_scopes, new_state}
      end)

    {all_nodes, all_edges, all_exits, all_scopes, final_state}
  end

  defp process_case_clause({:->, meta, [pattern, body]}, entry_node_id, state) do
    line = ASTUtilities.get_line_number(meta)
    {clause_id, updated_state} = StateManager.generate_node_id("case_clause", state)
    clause_scope_id = StateManager.generate_scope_id("case_clause", updated_state)

    # Create clause scope for pattern-bound variables
    clause_scope = %ScopeInfo{
      id: clause_scope_id,
      type: :case_clause,
      parent_scope: state.current_scope,
      child_scopes: [],
      variables: ASTUtilities.extract_pattern_variables(pattern),
      ast_node_id: ASTUtilities.get_ast_node_id(meta),
      entry_points: [clause_id],
      exit_points: [],
      metadata: %{pattern: pattern}
    }

    # Create clause node for pattern matching
    clause_node = %CFGNode{
      id: clause_id,
      type: :case_clause,
      ast_node_id: ASTUtilities.get_ast_node_id(meta),
      line: line,
      scope_id: clause_scope_id,
      expression: pattern,
      predecessors: [entry_node_id],
      successors: [],
      metadata: %{pattern: pattern}
    }

    # Edge from case entry to this clause (pattern match edge)
    entry_edge = %CFGEdge{
      from_node_id: entry_node_id,
      to_node_id: clause_id,
      type: :pattern_match,
      condition: pattern,
      probability: ASTUtilities.calculate_pattern_probability(pattern),
      metadata: %{pattern: pattern}
    }

    # Process clause body in new scope
    clause_state = %{updated_state | current_scope: clause_scope_id, scope_counter: updated_state.scope_counter + 1}
    {body_nodes, body_edges, body_exits, body_scopes, final_state} =
      ASTProcessor.process_ast_node(body, clause_state)

    # Connect clause to body
    body_entry_nodes = get_entry_nodes(body_nodes)
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

  defp process_rescue_clause({:->, meta, [pattern, body]}, try_node_id, state) do
    line = ASTUtilities.get_line_number(meta)
    {rescue_id, updated_state} = StateManager.generate_node_id("rescue", state)

    rescue_node = %CFGNode{
      id: rescue_id,
      type: :rescue,
      ast_node_id: ASTUtilities.get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: pattern,
      predecessors: [try_node_id],
      successors: [],
      metadata: %{pattern: pattern}
    }

    # Process rescue body
    {body_nodes, body_edges, body_exits, body_scopes, final_state} =
      ASTProcessor.process_ast_node(body, updated_state)

    # Connect rescue to body
    body_entry_nodes = get_entry_nodes(body_nodes)
    rescue_to_body_edges = Enum.map(body_entry_nodes, fn node_id ->
      %CFGEdge{
        from_node_id: rescue_id,
        to_node_id: node_id,
        type: :sequential,
        condition: nil,
        probability: 1.0,
        metadata: %{}
      }
    end)

    all_nodes = Map.put(body_nodes, rescue_id, rescue_node)
    all_edges = body_edges ++ rescue_to_body_edges

    {all_nodes, all_edges, body_exits, body_scopes, final_state}
  end

  defp process_catch_clause({:->, meta, [pattern, body]}, try_node_id, state) do
    line = ASTUtilities.get_line_number(meta)
    {catch_id, updated_state} = StateManager.generate_node_id("catch", state)

    catch_node = %CFGNode{
      id: catch_id,
      type: :catch,
      ast_node_id: ASTUtilities.get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: pattern,
      predecessors: [try_node_id],
      successors: [],
      metadata: %{pattern: pattern}
    }

    # Process catch body
    {body_nodes, body_edges, body_exits, body_scopes, final_state} =
      ASTProcessor.process_ast_node(body, updated_state)

    # Connect catch to body
    body_entry_nodes = get_entry_nodes(body_nodes)
    catch_to_body_edges = Enum.map(body_entry_nodes, fn node_id ->
      %CFGEdge{
        from_node_id: catch_id,
        to_node_id: node_id,
        type: :sequential,
        condition: nil,
        probability: 1.0,
        metadata: %{}
      }
    end)

    all_nodes = Map.put(body_nodes, catch_id, catch_node)
    all_edges = body_edges ++ catch_to_body_edges

    {all_nodes, all_edges, body_exits, body_scopes, final_state}
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
