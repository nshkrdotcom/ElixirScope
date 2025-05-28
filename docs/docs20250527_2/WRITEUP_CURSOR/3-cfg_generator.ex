defmodule ElixirScope.ASTRepository.CFGGenerator do
  @moduledoc """
  Enhanced Control Flow Graph generator for Elixir functions.

  Handles Elixir-specific constructs with proper complexity calculation
  based on decision points rather than decision edges.
  """

  alias ElixirScope.ASTRepository.{CFGData, CFGNode, CFGEdge, ComplexityMetrics}

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
      {nodes, edges, exit_nodes} = process_function_body(function_ast, state)

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
        scopes: state.scopes,
        complexity_metrics: complexity,
        path_analysis: path_analysis,
        metadata: %{
          generation_time: System.monotonic_time(:millisecond),
          options: opts
        }
      }

      {:ok, cfg}
    rescue
      error -> {:error, {:cfg_generation_failed, error}}
    end
  end

  # Private implementation

  defp initialize_cfg_state(function_ast, opts) do
    entry_node_id = generate_node_id("entry")

    %{
      entry_node: entry_node_id,
      next_node_id: 1,
      nodes: %{},
      edges: [],
      scopes: %{},
      current_scope: :function_scope,
      options: opts
    }
  end

  defp process_function_body({:def, _meta, [_head, [do: body]]}, state) do
    # Create entry node
    entry_node = %CFGNode{
      id: state.entry_node,
      type: :entry,
      ast_node_id: nil,
      line: 0,
      scope_id: :function_scope,
      expression: nil,
      predecessors: [],
      successors: [],
      metadata: %{}
    }

    # Process function body
    {body_nodes, body_edges, body_exits, _state} = process_ast_node(body, state)

    # Connect entry to body
    entry_edges = Enum.map(get_entry_nodes(body_nodes), fn node_id ->
      %CFGEdge{
        from_node_id: state.entry_node,
        to_node_id: node_id,
        type: :sequential,
        condition: nil,
        probability: 1.0,
        metadata: %{}
      }
    end)

    all_nodes = Map.put(body_nodes, state.entry_node, entry_node)
    all_edges = entry_edges ++ body_edges

    {all_nodes, all_edges, body_exits}
  end

  defp process_ast_node(ast, state) do
    case ast do
      # Case statement - multiple branches
      {:case, meta, [condition | clauses]} ->
        process_case_statement(condition, clauses, meta, state)

      # If statement
      {:if, meta, [condition, [do: then_branch, else: else_branch]]} ->
        process_if_statement(condition, then_branch, else_branch, meta, state)

      # Cond statement
      {:cond, meta, [[do: clauses]]} ->
        process_cond_statement(clauses, meta, state)

      # Try-catch-rescue
      {:try, meta, try_clauses} ->
        process_try_statement(try_clauses, meta, state)

      # Pipe operation
      {:|>, meta, [left, right]} ->
        process_pipe_operation(left, right, meta, state)

      # Function call
      {func_name, meta, args} when is_atom(func_name) ->
        process_function_call(func_name, args, meta, state)

      # Block of statements
      {:__block__, _meta, statements} ->
        process_statement_sequence(statements, state)

      # Simple expression
      _ ->
        process_simple_expression(ast, state)
    end
  end

  defp process_case_statement(condition, clauses, meta, state) do
    case_entry_id = generate_node_id("case_entry", state)

    # Create case entry node
    case_entry = %CFGNode{
      id: case_entry_id,
      type: :case_entry,
      ast_node_id: get_ast_node_id(meta),
      line: get_line_number(meta),
      scope_id: state.current_scope,
      expression: condition,
      predecessors: [],
      successors: [],
      metadata: %{condition: condition}
    }

    # Process each case clause
    {clause_nodes, clause_edges, clause_exits, updated_state} =
      process_case_clauses(clauses, case_entry_id, state)

    all_nodes = Map.put(clause_nodes, case_entry_id, case_entry)

    {all_nodes, clause_edges, clause_exits, updated_state}
  end

  defp process_case_clauses(clauses, entry_node_id, state) do
    {all_nodes, all_edges, all_exits, final_state} =
      Enum.reduce(clauses, {%{}, [], [], state}, fn clause, {nodes, edges, exits, acc_state} ->
        {clause_nodes, clause_edges, clause_exits, new_state} =
          process_case_clause(clause, entry_node_id, acc_state)

        merged_nodes = Map.merge(nodes, clause_nodes)
        merged_edges = edges ++ clause_edges
        merged_exits = exits ++ clause_exits

        {merged_nodes, merged_edges, merged_exits, new_state}
      end)

    {all_nodes, all_edges, all_exits, final_state}
  end

  defp process_case_clause({:->, _meta, [pattern, body]}, entry_node_id, state) do
    clause_id = generate_node_id("case_clause", state)

    # Create clause node for pattern matching
    clause_node = %CFGNode{
      id: clause_id,
      type: :case_clause,
      ast_node_id: nil,
      line: 0,
      scope_id: create_scope_id("case_clause", state),
      expression: pattern,
      predecessors: [entry_node_id],
      successors: [],
      metadata: %{pattern: pattern}
    }

    # Edge from case entry to this clause
    entry_edge = %CFGEdge{
      from_node_id: entry_node_id,
      to_node_id: clause_id,
      type: :pattern_match,
      condition: pattern,
      probability: calculate_pattern_probability(pattern),
      metadata: %{pattern: pattern}
    }

    # Process clause body
    {body_nodes, body_edges, body_exits, updated_state} = process_ast_node(body, state)

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

    {all_nodes, all_edges, body_exits, updated_state}
  end

  defp calculate_complexity_metrics(nodes, edges) do
    # Count decision POINTS, not decision EDGES
    decision_points = count_decision_points(nodes)

    # Calculate cyclomatic complexity: M = E - N + 2P
    # Where E = edges, N = nodes, P = connected components (usually 1)
    num_edges = length(edges)
    num_nodes = map_size(nodes)
    cyclomatic = num_edges - num_nodes + 2

    # Alternative: Use decision points method (more accurate for Elixir)
    cyclomatic_decision_based = decision_points + 1

    # Calculate cognitive complexity (readability-focused)
    cognitive = calculate_cognitive_complexity(nodes)

    # Calculate nesting depth
    nesting_depth = calculate_nesting_depth(nodes)

    %ComplexityMetrics{
      cyclomatic_complexity: cyclomatic_decision_based,
      essential_complexity: calculate_essential_complexity(nodes, edges),
      cognitive_complexity: cognitive,
      pattern_complexity: count_pattern_matches(nodes),
      guard_complexity: count_guards(nodes),
      pipe_chain_length: calculate_max_pipe_chain(nodes),
      nesting_depth: nesting_depth,
      total_paths: calculate_total_paths(nodes, edges),
      unreachable_paths: find_unreachable_paths(nodes, edges),
      critical_path_length: find_critical_path_length(nodes, edges),
      error_prone_patterns: detect_error_prone_patterns(nodes),
      performance_risks: detect_performance_risks(nodes),
      maintainability_score: calculate_maintainability_score(cyclomatic_decision_based, cognitive, nesting_depth)
    }
  end

  defp count_decision_points(nodes) do
    nodes
    |> Map.values()
    |> Enum.count(fn node ->
      node.type in [
        :case_entry,      # case statements
        :if_condition,    # if statements
        :cond_entry,      # cond statements
        :guard_check,     # guard clauses
        :pattern_match,   # pattern matches with multiple clauses
        :try_entry        # try-catch blocks
      ]
    end)
  end

  defp calculate_cognitive_complexity(nodes) do
    nodes
    |> Map.values()
    |> Enum.reduce(0, fn node, acc ->
      base_increment = case node.type do
        :case_entry -> 1      # case adds cognitive load
        :if_condition -> 1    # if adds cognitive load
        :cond_entry -> 1      # cond adds cognitive load
        :guard_check -> 1     # guards add cognitive load
        :try_entry -> 1       # try-catch adds cognitive load
        _ -> 0
      end

      # Add nesting penalty
      nesting_penalty = get_nesting_level(node) * 0.5

      acc + base_increment + nesting_penalty
    end)
  end

  # Utility functions

  defp generate_node_id(prefix, state \\ nil) do
    id = if state do
      "#{prefix}_#{state.next_node_id}"
    else
      "#{prefix}_#{:erlang.unique_integer([:positive])}"
    end
    id
  end

  defp get_ast_node_id(meta) do
    Keyword.get(meta, :ast_node_id)
  end

  defp get_line_number(meta) do
    Keyword.get(meta, :line, 0)
  end

  defp create_scope_id(prefix, _state) do
    "#{prefix}_#{:erlang.unique_integer([:positive])}"
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

  defp calculate_pattern_probability(_pattern) do
    # Simplified probability calculation
    # In practice, this could be more sophisticated
    0.5
  end

  defp extract_function_key({:def, _meta, [{name, _meta2, args} | _]}) do
    arity = if is_list(args), do: length(args), else: 0
    {UnknownModule, name, arity}  # Module would be provided by caller
  end

  defp extract_function_key(_), do: {UnknownModule, :unknown, 0}

  # Placeholder implementations for remaining complexity calculations
  defp calculate_essential_complexity(_nodes, _edges), do: 1
  defp count_pattern_matches(nodes), do: Enum.count(nodes, fn {_k, v} -> v.type == :pattern_match end)
  defp count_guards(nodes), do: Enum.count(nodes, fn {_k, v} -> v.type == :guard_check end)
  defp calculate_max_pipe_chain(_nodes), do: 0
  defp calculate_nesting_depth(_nodes), do: 1
  defp calculate_total_paths(_nodes, _edges), do: 1
  defp find_unreachable_paths(_nodes, _edges), do: 0
  defp find_critical_path_length(_nodes, _edges), do: 1
  defp detect_error_prone_patterns(_nodes), do: 0
  defp detect_performance_risks(_nodes), do: 0
  defp calculate_maintainability_score(cyclomatic, cognitive, nesting) do
    # Simple maintainability score (0-100)
    max(0, 100 - (cyclomatic * 5) - (cognitive * 3) - (nesting * 2))
  end
  defp get_nesting_level(_node), do: 0
  defp analyze_paths(_nodes, _edges, _entry), do: %{}

  # Placeholder implementations for other AST processing functions
  defp process_if_statement(_condition, _then_branch, _else_branch, _meta, state) do
    {%{}, [], [], state}
  end

  defp process_cond_statement(_clauses, _meta, state) do
    {%{}, [], [], state}
  end

  defp process_try_statement(_try_clauses, _meta, state) do
    {%{}, [], [], state}
  end

  defp process_pipe_operation(_left, _right, _meta, state) do
    {%{}, [], [], state}
  end

  defp process_function_call(_func_name, _args, _meta, state) do
    {%{}, [], [], state}
  end

  defp process_statement_sequence(_statements, state) do
    {%{}, [], [], state}
  end

  defp process_simple_expression(_ast, state) do
    {%{}, [], [], state}
  end
end
