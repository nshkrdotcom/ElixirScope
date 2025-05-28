defmodule ElixirScope.QueryEngine.ASTExtensions do
  @moduledoc """
  Extends the ElixirScope Query Engine with capabilities to query
  the Enhanced AST Repository (including CPG data).

  This module defines:
  - New query types specific to static code analysis.
  - Integration points with `ElixirScope.ASTRepository.Repository`.
  - Methods to combine AST query results with runtime event data.
  """

  alias ElixirScope.ASTRepository.Repository
  alias ElixirScope.ASTRepository.CPGData # And CPGNode, CPGEdge
  alias ElixirScope.QueryEngine # Access to existing query functions if needed

  # --- New Query Types for AST/CPG ---

  @type ast_query_type ::
          :find_functions_by_complexity |
          :find_functions_calling_mfa |
          :find_callers_of_mfa |
          :find_modules_with_behaviour |
          :find_nodes_by_ast_pattern | # Using a simplified pattern matcher or CPG query
          :get_cpg_for_function |
          :trace_data_flow_for_variable | # DFG-based
          :get_control_flow_path # CFG-based

  @type ast_query :: %{
    type: ast_query_type(),
    params: map(), # Query-specific parameters
    opts: keyword() # Options like limit, sort, cache control
  }

  @doc """
  Executes a static analysis query against the AST Repository.
  """
  @spec execute_ast_query(query :: ast_query()) ::
          {:ok, results :: list() | map() | CPGData.t()} | {:error, term()}
  def execute_ast_query(%{type: query_type, params: params, opts: opts} = query) do
    # Assuming ASTRepository.Repository is a GenServer, get its pid
    # For simplicity, directly calling Repository functions here.
    # In a real system, might go through a central Query.Engine dispatcher.
    repo_pid = Process.whereis(ElixirScope.ASTRepository.Repository) || ElixirScope.ASTRepository.Repository # Fallback if not named

    case query_type do
      :find_functions_by_complexity ->
        # Params: %{min_complexity: integer(), max_complexity: integer() | nil, metric: atom()}
        # Metric could be :cyclomatic, :cognitive, etc.
        # This would internally call `Repository.query_functions` with appropriate filters.
        # Repository.query_functions(repo_pid, build_complexity_query_spec(params, opts))
        mock_static_query_result(query, [%{name: :foo, complexity: 12}, %{name: :bar, complexity: 15}]) # Placeholder

      :find_functions_calling_mfa ->
        # Params: %{target_mfa: {module, fun, arity}}
        # Repository.find_functions_calling(repo_pid, params.target_mfa, opts)
        mock_static_query_result(query, [%{caller: :ModuleA, function: :func_a, calls: params.target_mfa}])

      :find_callers_of_mfa ->
        # Params: %{target_mfa: {module, fun, arity}}
        # Repository.find_references(repo_pid, elem(params.target_mfa,0), elem(params.target_mfa,1), elem(params.target_mfa,2))
        mock_static_query_result(query, [%{caller: :ModuleB, function: :func_b, line: 10}])

      :find_modules_with_behaviour ->
        # Params: %{behaviour_module: atom()}
        # Repository.query_modules(repo_pid, %{implements_behaviour: params.behaviour_module})
        mock_static_query_result(query, [%{module: :MyGenServer, behaviour: params.behaviour_module}])

      :find_nodes_by_ast_pattern ->
        # Params: %{ast_pattern: "quoted_expr_or_pattern_string", scope_mfa: {m,f,a} | nil}
        # This is complex. Could use CPGBuilder.find_pattern or a dedicated AST search.
        # Repository.query_cpg_pattern(repo_pid, params.ast_pattern, params.scope_mfa, opts)
        mock_static_query_result(query, [%{ast_node_id: "...", matched_code: Macro.to_string(params.ast_pattern)}])

      :get_cpg_for_function ->
        # Params: %{function_key: {module, fun, arity}}
        # Needs to fetch EnhancedFunctionData then build/fetch CPG
        with {:ok, func_data} <- Repository.get_function(repo_pid, elem(params.function_key,0), elem(params.function_key,1), elem(params.function_key,2)),
             {:ok, cpg_data} <- ElixirScope.ASTRepository.CPGBuilder.build_cpg(func_data) do
          {:ok, cpg_data}
        else
          {:error, reason} -> {:error, reason}
          _ -> {:error, :cpg_fetch_or_build_failed}
        end

      :trace_data_flow_for_variable ->
        # Params: %{function_key: {m,f,a}, variable_name: atom(), ast_node_id_context: string()}
        # This would involve getting DFG from EnhancedFunctionData and tracing.
        # EnhancedFunctionData -> DFGGenerator.trace_variable(dfg, var_name)
        mock_static_query_result(query, [%{step: :definition, var: params.variable_name, line: 5}, %{step: :use, var: params.variable_name, line: 10}])

      :get_control_flow_path ->
        # Params: %{function_key: {m,f,a}, from_ast_node_id: string(), to_ast_node_id: string()}
        # EnhancedFunctionData -> CFGGenerator.find_paths(cfg, from_node_id, to_node_id)
        mock_static_query_result(query, [%{path_nodes: ["node1", "node2", "node3"]}])

      _ ->
        {:error, :unsupported_ast_query_type}
    end
  end

  defp mock_static_query_result(query, data) do # Helper for now
    {:ok, %{query: query, results: data, source: :static_ast_repository}}
  end


  # --- Combining AST Queries with Runtime Event Queries ---

  @doc """
  Executes a correlated query that combines static AST information with runtime events.
  Example: "Find all runtime errors that occurred in functions with cyclomatic complexity > 10."
  """
  @spec execute_correlated_query(static_query :: ast_query(), runtime_query_template :: map(), join_key :: atom()) ::
          {:ok, correlated_results :: list(map())} | {:error, term()}
  def execute_correlated_query(static_query, runtime_query_template, join_key \\ :ast_node_id) do
    with {:ok, static_results_wrapper} <- execute_ast_query(static_query),
         static_results = static_results_wrapper.results do

      # Extract join keys from static results (e.g., list of ast_node_ids or function_keys)
      # This depends on the structure of static_results
      join_values = extract_join_values(static_results, static_query.type, join_key)

      if Enum.empty?(join_values) do
        {:ok, []} # No static matches, so no correlated results
      else
        # Build and execute runtime queries based on these join_values
        # This part is highly dependent on the existing QueryEngine capabilities
        # For example, if join_key is :ast_node_id:
        # runtime_query = %{runtime_query_template | filters: [{:ast_node_id, :in, join_values}]}
        # {:ok, runtime_events} = ElixirScope.QueryEngine.execute_event_query(runtime_query)

        # For now, let's mock fetching runtime events
        runtime_events = mock_fetch_runtime_events_for_join_values(join_values, runtime_query_template, join_key)

        # Correlate/join results
        correlated = join_static_and_runtime(static_results, runtime_events, static_query.type, join_key)
        {:ok, correlated}
      end
    else
      error -> error
    end
  end

  defp extract_join_values(static_results, static_query_type, join_key) do
    # Example extraction logic; needs to be robust based on actual static_results structure
    case {static_query_type, join_key} do
      # If static_results are list of functions, and join_key is :function_key
      (_, :function_key) when is_list(static_results) ->
        Enum.map(static_results, fn res_map ->
          # Assuming res_map has :module, :name, :arity or similar
          res_map.function_key || {res_map.module, res_map.name, res_map.arity}
        end)
      # If static_results are list of AST nodes, and join_key is :ast_node_id
      (_, :ast_node_id) when is_list(static_results) ->
        Enum.map(static_results, &(&1.ast_node_id || &1.id)) # Assuming node has id or ast_node_id
      _ ->
        [] # Default or unsupported
    end
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp mock_fetch_runtime_events_for_join_values(join_values, runtime_query_template, join_key) do
    # Simulate fetching runtime events that match one of the join_values
    Enum.flat_map(join_values, fn val ->
      # Simulate some events for this join value
      [
        %{event_type: :function_entry, (join_key) => val, timestamp: DateTime.utc_now(), value: "data1"},
        if(rem(elem(DateTime.now_utc(),2),2) == 0, do: %{event_type: :error, (join_key) => val, timestamp: DateTime.utc_now(), error: :badarg}, else: nil)
      ]
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(fn event -> match_runtime_template?(event, runtime_query_template) end)
  end

  defp match_runtime_template?(event, template) do
    Enum.all?(template, fn {key, value} ->
      Map.get(event, key) == value
    end)
  end

  defp join_static_and_runtime(static_results, runtime_events, static_query_type, join_key) do
    # Example join logic; this can be complex (one-to-many, many-to-many)
    # Group runtime_events by join_key for efficient lookup
    runtime_events_by_join_val = Enum.group_by(runtime_events, &Map.get(&1, join_key))

    Enum.map(static_results, fn static_item ->
      join_val = case {static_query_type, join_key} do
        (_, :function_key) -> static_item.function_key || {static_item.module, static_item.name, static_item.arity}
        (_, :ast_node_id) -> static_item.ast_node_id || static_item.id
        _ -> nil
      end

      matching_runtime_events = Map.get(runtime_events_by_join_val, join_val, [])
      Map.put(static_item, :runtime_events, matching_runtime_events)
    end)
  end

  # --- Query Optimization Considerations ---

  @doc """
  Strategies for optimizing AST/CPG queries:
  """
  def query_optimization_strategies do
    [
      %{
        strategy: "Index Utilization (AST Repository)",
        description: "ASTRepository should maintain indexes on CPG node properties (type, labels, line numbers) and edge types. Queries should leverage these indexes."
      },
      %{
        strategy: "Lazy Loading & Traversal Limits",
        description: "For deep graph traversals (e.g., data flow, call chains), implement lazy loading of connected nodes and configurable depth limits to prevent excessive computation."
      },
      %{
        strategy: "Caching of Static Analysis Results",
        description: "Cache results of expensive static analyses (e.g., full CPG generation, complex pattern searches) in ASTRepository. Invalidate cache on code changes."
      },
      %{
        strategy: "Query Planning for Correlated Queries",
        description: "For queries joining static and runtime data, the QueryEngine should estimate cardinalities and choose an optimal join order (e.g., filter by rare static pattern first, then query runtime events)."
      },
      %{
        strategy: "Pre-materialized Views / Summaries",
        description: "For common correlated queries (e.g., error rates for complex functions), ASTRepository or QueryEngine could maintain pre-calculated summaries."
      }
    ]
  end

  # --- Integration with AI Components ---
  @doc """
  How AI components will use these extended query capabilities:
  """
  def ai_integration_points do
    %{
      "AI.CodeAnalyzer / AI.PatternRecognizer" => """
      - Use `execute_ast_query(%{type: :find_nodes_by_ast_pattern, ...})` to find specific code structures.
      - Use `execute_ast_query(%{type: :get_cpg_for_function, ...})` to get rich graph context for deeper analysis.
      """,
      "AI.PredictiveAnalyzer" => """
      - Example: To predict hotspots:
        1. `execute_ast_query(%{type: :find_functions_by_complexity, params: %{min_complexity: X}})` to get complex functions.
        2. For each complex function, `execute_correlated_query` with a runtime query template for execution counts or durations, joining on `:function_key`.
        3. Feed results (static complexity + runtime frequency/duration) into an ML model.
      """,
      "AI.ASTEmbeddings" => """
      - Fetch CPGs/ASTs using `execute_ast_query` to generate embeddings for functions or code snippets.
      - Store embeddings, possibly indexed by CPG node ID or function_key.
      - Similarity search can then be another query type: `%{type: :find_similar_by_embedding, params: %{source_node_id: "id", top_n: 5}}`
      """
    }
  end

  # --- Example Advanced Queries ---
  def example_advanced_queries do
    [
      %{
        description: "Find GenServer handle_call clauses that directly call an Ecto Repo function and have a cyclomatic complexity > 5.",
        steps: [
          "AST Query 1: Find all GenServer modules (`:find_modules_with_behaviour`).",
          "AST Query 2: For these modules, find `handle_call/3` functions (`:find_functions_by_name_arity`).",
          "AST Query 3: For these functions, get CPGs (`:get_cpg_for_function`).",
          "CPG Query: Within each CPG, find call paths from `handle_call` entry to Ecto.Repo calls, and check complexity of `handle_call` CPG node."
        ]
      },
      %{
        description: "Show the data flow for a specific variable from its definition in a controller action, through several function calls, to where it's used in a Phoenix template rendering.",
        steps: [
          "AST Query: Get CPG for controller action.",
          "CPG/DFG Query: Trace variable data flow (`:trace_data_flow_for_variable`) within the action and across called functions (inter-procedural DFG needed here, which is advanced)."
        ]
      },
      %{
        description: "List functions that were frequently executed last hour (runtime) AND contain a specific deprecated API call (static).",
        static_query: %{type: :find_functions_calling_mfa, params: %{target_mfa: {:OldModule, :deprecated_fun, 0}}},
        runtime_query_template: %{event_type: :function_entry, time_range: :last_hour, min_execution_count: 100},
        join_key: :function_key,
        action: "execute_correlated_query(static_q, runtime_q_template, :function_key)"
      }
    ]
  end
end
