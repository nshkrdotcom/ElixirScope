defmodule ElixirScope.ASTRepository.Enhanced.CFGGenerator.ExceptionHandler do
  @moduledoc """
  Handles exception-related control flow AST nodes (try, with) for CFG generation.
  """

  alias ElixirScope.ASTRepository.Enhanced.{
    CFGNode,
    CFGEdge,
    # ScopeInfo, # Not directly used here, but might be needed if extended
    CFGGenerator.Utils
  }

  @doc """
  Processes a try statement.
  `ast_processor_func` is `ASTProcessor.process_ast_node/2`.
  """
  def handle_try_statement(blocks, meta, state, ast_processor_func) do
    line = Utils.get_line_number(meta)
    {try_id, updated_state} = Utils.generate_node_id("try_entry", state)

    try_node = %CFGNode{
      id: try_id,
      type: :try,
      ast_node_id: Utils.get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: blocks,
      predecessors: [],
      successors: [],
      metadata: %{blocks: blocks}
    }

    try_body = Keyword.get(blocks, :do)
    {body_nodes, body_edges, body_exits, body_scopes, body_state} =
      if try_body do
        ast_processor_func.(try_body, updated_state)
      else
        {%{}, [], [], %{}, updated_state}
      end

    {rescue_nodes, rescue_edges, rescue_exits, rescue_scopes, rescue_state} =
      case Keyword.get(blocks, :rescue) do
        nil -> {%{}, [], [], %{}, body_state}
        rescue_clauses ->
          Enum.reduce(rescue_clauses, {%{}, [], [], %{}, body_state}, fn clause, {nodes, edges, exits, scopes, acc_state} ->
            {clause_nodes, clause_edges, clause_exits, clause_scopes, new_state} =
              process_rescue_clause(clause, try_id, acc_state, ast_processor_func)

            merged_nodes = Map.merge(nodes, clause_nodes)
            merged_edges = edges ++ clause_edges
            merged_exits = exits ++ clause_exits
            merged_scopes = Map.merge(scopes, clause_scopes)

            {merged_nodes, merged_edges, merged_exits, merged_scopes, new_state}
          end)
      end

    {catch_nodes, catch_edges, catch_exits, catch_scopes, catch_state} =
      case Keyword.get(blocks, :catch) do
        nil -> {%{}, [], [], %{}, rescue_state}
        catch_clauses ->
          Enum.reduce(catch_clauses, {%{}, [], [], %{}, rescue_state}, fn clause, {nodes, edges, exits, scopes, acc_state} ->
            {clause_nodes, clause_edges, clause_exits, clause_scopes, new_state} =
              process_catch_clause(clause, try_id, acc_state, ast_processor_func)

            merged_nodes = Map.merge(nodes, clause_nodes)
            merged_edges = edges ++ clause_edges
            merged_exits = exits ++ clause_exits
            merged_scopes = Map.merge(scopes, clause_scopes)

            {merged_nodes, merged_edges, merged_exits, merged_scopes, new_state}
          end)
      end

    body_entry_nodes = Utils.get_entry_nodes(body_nodes)
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

    try_to_rescue_edges = if map_size(rescue_nodes) > 0 do
      rescue_entry_nodes = Utils.get_entry_nodes(rescue_nodes)
      # Connect from try_id to each rescue clause's entry node
      # The actual entry node of a rescue clause is the rescue_node itself, not its body's entry.
      # We need to find the actual CFGNode for the rescue clause start.
      # This requires a bit of rework or assuming process_rescue_clause returns the rescue node ID as part of its exits.
      # For now, assuming the first node in rescue_nodes is the one to connect to.
      # This part might need adjustment based on how process_rescue_clause structures its output.
      Enum.map(Map.keys(rescue_nodes), fn rescue_clause_node_id ->
         # We assume the rescue_clause_node_id is the node for the rescue pattern itself.
        if rescue_nodes[rescue_clause_node_id].type == :rescue do
          %CFGEdge{
            from_node_id: try_id,
            to_node_id: rescue_clause_node_id, # Connect to the rescue pattern node
            type: :exception,
            condition: :rescue,
            probability: 0.1, # Default probability
            metadata: %{exception_type: :rescue}
          }
        else
          nil # Should not happen if rescue_nodes are structured correctly
        end
      end) |> Enum.reject(&is_nil(&1))
    else
      []
    end

    try_to_catch_edges = if map_size(catch_nodes) > 0 do
      # Similar logic for catch clauses as for rescue clauses
      Enum.map(Map.keys(catch_nodes), fn catch_clause_node_id ->
        if catch_nodes[catch_clause_node_id].type == :catch do
          %CFGEdge{
            from_node_id: try_id,
            to_node_id: catch_clause_node_id, # Connect to the catch pattern node
            type: :exception,
            condition: :catch,
            probability: 0.1, # Default probability
            metadata: %{exception_type: :catch}
          }
        else
          nil
        end
      end) |> Enum.reject(&is_nil(&1))
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

  defp process_rescue_clause({:->, meta, [pattern, body]}, try_node_id, state, ast_processor_func) do
    line = Utils.get_line_number(meta)
    {rescue_id, updated_state} = Utils.generate_node_id("rescue", state)

    rescue_node = %CFGNode{
      id: rescue_id,
      type: :rescue,
      ast_node_id: Utils.get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: pattern,
      predecessors: [try_node_id], # Connects from the main try node
      successors: [],
      metadata: %{pattern: pattern}
    }

    {body_nodes, body_edges, body_exits, body_scopes, final_state} =
      ast_processor_func.(body, updated_state)

    body_entry_nodes = Utils.get_entry_nodes(body_nodes)
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

    # Exits from this clause are the body_exits. The rescue_id itself is an entry to this clause.
    {all_nodes, all_edges, body_exits, body_scopes, final_state}
  end

  defp process_catch_clause({:->, meta, [pattern, body]}, try_node_id, state, ast_processor_func) do
    line = Utils.get_line_number(meta)
    {catch_id, updated_state} = Utils.generate_node_id("catch", state)

    catch_node = %CFGNode{
      id: catch_id,
      type: :catch,
      ast_node_id: Utils.get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: pattern,
      predecessors: [try_node_id], # Connects from the main try node
      successors: [],
      metadata: %{pattern: pattern}
    }

    {body_nodes, body_edges, body_exits, body_scopes, final_state} =
      ast_processor_func.(body, updated_state)

    body_entry_nodes = Utils.get_entry_nodes(body_nodes)
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

  @doc """
  Processes a with statement (placeholder).
  `ast_processor_func` is `ASTProcessor.process_ast_node/2`.
  """
  def handle_with_statement(_clauses, _meta, state, _ast_processor_func) do
    # Placeholder implementation
    {%{}, [], [], %{}, state}
  end
end 