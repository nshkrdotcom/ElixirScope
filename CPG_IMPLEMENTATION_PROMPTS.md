# CPG Implementation Prompts for Cursor

**`CPG_IMPLEMENTATION_PROMPTS.MD`**

This document provides a series of prompts intended for an AI coding assistant like Cursor to guide the implementation of the CPG Algorithmic Enhancement Layer within the ElixirScope project. These prompts reference the newly created documentation (`CPG_ALGORITHMS_OVERVIEW.MD`, `CPG_MATH_API.MD`, `CPG_SEMANTICS_API.MD`, `CPG_QUERY_ENHANCEMENTS.MD`, `CPG_PATTERN_DETECTION_ADVANCED.MD`, `CPG_OPTIMIZATION_STRATEGIES.MD`, `CPG_AI_ML_FEATURES.MD`) and existing ElixirScope code.

**General Instructions for Cursor:**
*   Assume all referenced `.MD` files are available in the current project's root directory.
*   When implementing new modules, include a `@moduledoc` based on the descriptions in the relevant `.MD` files.
*   Prioritize functional correctness first. Performance optimizations can be addressed in subsequent prompts if not explicitly part of the current one.
*   Use existing ElixirScope data structures like `CPGData.t()`, `CPGNode.t()`, `CPGEdge.t()` found in `elixir_scope/ast_repository/enhanced/cpg_data.ex` as the basis for CPG operations.
*   New algorithmic modules should reside in `elixir_scope/ast_repository/enhanced/`.
*   For complex algorithms, you can outline the steps or ask for a specific well-known algorithm (e.g., "Implement Tarjan's algorithm for SCCs").

---

## Section 1: Implement `CPGMath` - Foundational Graph Algorithms

**Prompt 1.1: Create `CPGMath` Module Structure and Basic Helpers**
"Create a new module `ElixirScope.ASTRepository.Enhanced.CPGMath` in the file `elixir_scope/ast_repository/enhanced/cpg_math.ex`.
1.  Add a `@moduledoc` based on `CPG_MATH_API.MD`, section 1.
2.  Implement the `get_neighbors(cpg, node_id, direction \\ :out)` function as described in `CPG_MATH_API.MD`, section 8. It should iterate `cpg.edges` to find neighbors. `direction` can be `:in`, `:out`, or `:both`. Return `{:ok, [neighbor_node_ids]}` or `{:error, :node_not_found}`.
3.  Implement `get_edges(cpg, node_id, direction \\ :out)` similarly, returning `{:ok, [CPGEdge.t()]}` or `{:error, :node_not_found}`.
4.  Create stubs for all other public functions listed in `CPG_MATH_API.MD` (e.g., `shortest_path/4`, `strongly_connected_components/1`, `degree_centrality/2`, etc.). Each stub should take `cpg :: CPGData.t()` as its first argument, an optional `opts :: keyword()` as its last, and return `{:error, :not_implemented_yet}` for now."

**Prompt 1.2: Implement `CPGMath.strongly_connected_components/1`**
"In `ElixirScope.ASTRepository.Enhanced.CPGMath`, implement the `strongly_connected_components/1` function.
1.  Use Tarjan's algorithm or Kosaraju's algorithm.
2.  The graph is defined by `cpg.nodes` (a map of `node_id => CPGNode.t()`) and `cpg.edges` (a list of `CPGEdge.t()`). You will need to use `get_neighbors/3` or iterate `cpg.edges` for traversal.
3.  The function should return `{:ok, sccs :: [[node_id()]]}`, where each inner list contains node IDs belonging to one SCC.
Refer to `CPG_MATH_API.MD`, section 4.1 for details."

**Prompt 1.3: Implement `CPGMath.degree_centrality/2`**
"Implement the `degree_centrality/2` function in `ElixirScope.ASTRepository.Enhanced.CPGMath`.
1.  It should calculate in-degree, out-degree, or total degree for each node in `cpg.nodes` based on `cpg.edges`.
2.  Support the `opts` keyword arguments:
    *   `:direction` (`:in`, `:out`, or `:total` - default `:total`).
    *   `:normalize` (`boolean()` - default `true`). If true, divide degree by `(map_size(cpg.nodes) - 1)` if `map_size(cpg.nodes) > 1`, else degree is 0.
3.  Return `{:ok, centrality_map :: %{node_id() => float()}}`.
Refer to `CPG_MATH_API.MD`, section 5.1."

**Prompt 1.4: Implement `CPGMath.shortest_path/4`**
"Implement `shortest_path/4` in `ElixirScope.ASTRepository.Enhanced.CPGMath` using Dijkstra's algorithm.
1.  Use the provided `opts[:weight_function]` (defaulting to `fn _edge, _cpg -> 1 end`) to determine edge costs. The weight function receives `(CPGEdge.t(), CPGData.t())`.
2.  Handle `opts[:max_depth]` by stopping exploration if path length exceeds this.
3.  Return `{:ok, path :: [node_id()]}` or an appropriate error tuple (`:no_path_found`, `:invalid_nodes`, `:max_depth_reached`). The path should include start and end nodes.
Refer to `CPG_MATH_API.MD`, section 3.1."

**(Continue with prompts for `all_paths/4`, `topological_sort/1`, `betweenness_centrality/2`, `closeness_centrality/2`, `eigenvector_centrality/2`, `pagerank_centrality/2`, `community_louvain/2`, `community_label_propagation/2`, `density/1`, `diameter/2` from `CPG_MATH_API.MD`.)**

---

## Section 2: Implement `CPGSemantics` - Code-Aware Algorithms

**Prompt 2.1: Create `CPGSemantics` Module Structure**
"Create a new module `ElixirScope.ASTRepository.Enhanced.CPGSemantics` in `elixir_scope/ast_repository/enhanced/cpg_semantics.ex`.
1.  Add a `@moduledoc` based on `CPG_SEMANTICS_API.MD`, section 1.
2.  Implement stubs for the public functions: `semantic_critical_path/4`, `trace_data_flow_semantic/4`, `dependency_impact_analysis/3`, `identify_coupling/4`, `detect_architectural_smells/2`, `analyze_module_cohesion/3`, and `identify_code_communities/2`. Each stub should return `{:error, :not_implemented_yet}`."

**Prompt 2.2: Implement Internal Semantic Edge Weight Calculation in `CPGSemantics`**
"Within `ElixirScope.ASTRepository.Enhanced.CPGSemantics`, create a private helper function `calculate_semantic_edge_weight(edge :: CPGEdge.t(), cpg :: CPGData.t(), context_opts :: map()) :: float()`.
1.  `context_opts` will guide weighting, e.g., `%{goal: :performance_impact, weights: %{node_type_penalties: %{io_call: 5.0}, edge_type_costs: %{message_send: 0.5}}}`.
2.  The function should consider `edge.type`, `edge.subtype`, and properties of the source/target CPG nodes (fetched from `cpg.nodes` using `edge.from_node_id` and `edge.to_node_id`).
    *   Node properties to consider: `cpg_node.ast_type` (e.g., from `cpg_node.cfg_node.type` or `cpg_node.dfg_node.type` if those fields exist on the CPG node, or directly `cpg_node.metadata.ast_type`), associated complexity scores if available (e.g., from `cpg.complexity_metrics[node_id]` or `cpg.nodes[node_id].metadata.complexity_score`).
3.  Return a float weight. For example, if `context_opts.goal == :performance_impact`, an edge leading to a CPG node representing an I/O operation (`ast_type == :io_operation`) should get a higher weight based on `context_opts.weights.node_type_penalties.io_operation`.
Refer to `CPG_SEMANTICS_API.MD`, section 6.1."

**Prompt 2.3: Implement `CPGSemantics.semantic_critical_path/4`**
"Implement `semantic_critical_path/4` in `ElixirScope.ASTRepository.Enhanced.CPGSemantics`.
1.  This function should find the 'heaviest' path(s) between `start_node_id` and `end_node_id` based on semantic costs.
2.  Use a shortest path algorithm (like Dijkstra's from `CPGMath.shortest_path/4` or implement one here if more control over cost accumulation is needed) by defining a 'cost' that you want to *maximize* (e.g., by using negative weights if the algorithm minimizes, or adapting for maximization).
3.  The `opts[:cost_factors]` map will guide how the `calculate_semantic_edge_weight/3` helper (and potentially node weights/penalties) contribute to this 'criticality cost'.
4.  The `opts[:path_type]` (`:execution`, `:data_dependency`, `:call_chain`) will determine which types of `CPGEdge.t().type` or `CPGEdge.t().subtype` are primarily considered for traversal.
5.  Return `{:ok, paths_with_details :: [map()]}` as specified in `CPG_SEMANTICS_API.MD`, section 3.1. The `details` map should include `total_cost`, `risk_score` (if applicable), and `contributing_factors` (a summary of what made the path critical). If `opts[:return_count]` is specified, return that many top paths.
*Hint: If finding the "longest" path in terms of cost, ensure the graph is a DAG or use an algorithm suitable for paths in graphs with cycles if `max_depth` is not strictly limiting. For multiple paths, Yen's K-shortest paths algorithm, adapted for cost, could be a reference.*"

**(Prompts for `dependency_impact_analysis` (using BFS/DFS from `CPGMath`), `detect_architectural_smells` (using `CPGMath` centrality/SCCs and semantic interpretation), `identify_code_communities` (calling `CPGMath` community functions then enriching results), `trace_data_flow_semantic`, `identify_coupling`, `analyze_module_cohesion` would follow, instructing Cursor to use `CPGMath` functions and then layer semantic interpretations or post-processing based on `CPG_SEMANTICS_API.MD`.)**

---

## Section 3: Enhance Querying (`QueryBuilder`, `EnhancedRepository`/`QueryExecutor`)

**Prompt 3.1: Update `QueryBuilder.valid_condition?/1` for Algorithmic Filters**
"In `elixir_scope/ast_repository/query_builder.ex`, modify the `valid_condition?/1` private helper function.
1.  Add support for new filter fields related to CPG algorithmic results: `:centrality_degree`, `:centrality_betweenness`, `:centrality_closeness`, `:centrality_pagerank`, `:community_id`, `:path_length`, `:path_semantic_cost`, `:downstream_impact_count`, `:coupling_strength_with`. These typically use operators like `:gt`, `:lt`, `:eq`.
2.  Add support for new operators: `:has_smell` (e.g., `{:has_smell, :god_object}`), `:in_community_with` (e.g., `{:in_community_with, "other_node_id"}`), `:path_contains_node_type` (e.g., `{:path_contains_node_type, :io_call}`).
Refer to `CPG_QUERY_ENHANCEMENTS.MD`, section 2.2."

**Prompt 3.2: Update `QueryBuilder.evaluate_condition_internal/2` for Algorithmic Filters**
"In `elixir_scope/ast_repository/query_builder.ex`, extend the `evaluate_condition_internal/2` private helper (or the main `evaluate_conditions/2` dispatcher).
1.  Add clauses to handle the new filter fields and operators from Prompt 3.1.
2.  When evaluating a condition based on an algorithmic metric (e.g., `{:centrality_betweenness, :gt, 0.5}`), the `item` (a module/function map) should be checked for this metric. Assume the metric might be nested, e.g., `item.cpg_analysis_results.centrality.betweenness`.
3.  Implement logic for new operators:
    *   `{:has_smell, smell_type}`: Check if `item.cpg_analysis_results.architectural_smells` (or a similar path) contains the `smell_type`.
    *   `{:in_community_with, other_node_id_str}`: This might be complex for `QueryBuilder` alone. For now, it can be stubbed to return `false` or assume `item.cpg_analysis_results.community.id` and compare with a pre-fetched community ID for `other_node_id_str`. The full logic might reside in the `QueryExecutor`.
Refer to `CPG_QUERY_ENHANCEMENTS.MD`, section 2.2."

**Prompt 3.3: Extend `QueryEngine.ASTExtensions.execute_ast_query/2` (or `EnhancedRepository`'s query handler)**
"Modify the main query execution dispatch logic (e.g., in `ElixirScope.QueryEngine.ASTExtensions` or `ElixirScope.ASTRepository.Enhanced.Repository`'s `handle_call({:query_analysis, ...})` clause).
1.  Add dispatch logic for new top-level query types as defined in `CPG_QUERY_ENHANCEMENTS.MD`, section 2.4: `:impact_analysis`, `:architectural_smells_detection`, `:critical_path_finding`, `:community_detection`.
2.  These clauses should:
    *   Extract parameters from `query.params`.
    *   Fetch the relevant `CPGData.t()` from `EnhancedRepository` for the target module/function specified in `query.params`.
    *   Call the corresponding function in `ElixirScope.ASTRepository.Enhanced.CPGSemantics` (e.g., `CPGSemantics.dependency_impact_analysis(cpg_data, params.target_node_id, params.opts)`)."

**Prompt 3.4: Implement On-Demand Algorithmic Computation in Query Execution**
"Enhance the query execution logic (e.g., `ElixirScope.ASTRepository.QueryExecutor` or the part of `EnhancedRepository` that processes `WHERE` clauses for `FROM :functions` or `FROM :modules`).
When processing a query that filters or selects based on a CPG algorithmic metric (e.g., `:centrality_betweenness` for a function):
1.  For each item (e.g., `EnhancedFunctionData.t()` map) being considered:
    a.  Fetch its full `CPGData.t()` from `EnhancedRepository` (e.g., `EnhancedRepository.get_cpg(item.module_name, item.function_name, item.arity)`).
    b.  Check if the required metric (e.g., betweenness for the function's main CPG node) is already cached in `cpg_data.unified_analysis.complexity_analysis.centrality_scores` or `cpg_data.metadata`.
    c.  If the metric is not cached in the `CPGData.t()`:
        i.  Call the relevant `CPGMath` or `CPGSemantics` function to compute the metric for the *entire* `CPGData.t()` (e.g., compute all centrality scores for all nodes in this function's CPG).
        ii. Update the in-memory `CPGData.t()` struct with this new set of metrics (e.g., `updated_cpg_data = %{cpg_data | unified_analysis: %{... updated centrality ...}}`).
        iii. **Persist the update:** Call a function like `EnhancedRepository.update_cpg_analysis_results(function_key, updated_cpg_data.unified_analysis)` to save these computed metrics. This function needs to be added to `EnhancedRepository` and should update the stored `EnhancedFunctionData`'s CPG-related analysis fields.
    d.  Use the specific metric for the current item (function) for filtering or selection.
Refer to `CPG_QUERY_ENHANCEMENTS.MD`, section 3, and `CPG_OPTIMIZATION_STRATEGIES.MD`, section 5."

---

## Section 4: Enhance `PatternMatcher`

**Prompt 4.1: Update `PatternMatcher` to Fetch and Use CPGs**
"In `elixir_scope/ast_repository/pattern_matcher.ex`, modify the `match_behavioral_pattern_internal/3` and `match_anti_pattern_internal/3` functions.
1.  These functions receive a `repo` PID (for `EnhancedRepository`).
2.  When processing a module (`module_data :: EnhancedModuleData.t()`) or a function (`function_data :: EnhancedFunctionData.t()`):
    *   If analyzing a function, fetch its `CPGData.t()` using `EnhancedRepository.get_cpg(function_data.module_name, function_data.function_name, function_data.arity)`.
    *   If analyzing a module (for module-level patterns), a module-level CPG might need to be fetched or constructed (this might be complex; assume for now that module-level patterns might operate on an aggregation of function CPGs or specific module-representative CPG nodes).
3.  Pass the fetched `CPGData.t()` and the specific CPG node ID (if applicable, e.g., function's entry node ID) as part of a `cpg_context` map to the rule evaluation logic.
Refer to `CPG_PATTERN_DETECTION_ADVANCED.MD`, section 5."

**Prompt 4.2: Implement CPG-Based Rule Evaluation in `PatternMatcher`**
"In `elixir_scope/ast_repository/pattern_matcher.ex`, extend the rule evaluation logic for patterns in `@pattern_library`.
1.  Modify pattern definitions to accept new rule types as tuples: `{:cpg_node_metric, property_path, operator, value, options}` or `{:custom_cpg_function, &custom_fun/3}` (as described in `CPG_PATTERN_DETECTION_ADVANCED.MD`, section 3). The `options` map can include `applies_to: :module_root_node | :function_entry_node | :specific_node_type`.
2.  When evaluating these CPG rules against an entity (e.g., a function and its `function_cpg_node_id` within its `cpg_data`):
    a.  For a `:cpg_node_metric` rule:
        i.   Determine the target CPG node ID based on `options.applies_to`.
        ii.  Retrieve the metric from `cpg_data.unified_analysis` (e.g., `cpg_data.unified_analysis.complexity_analysis.centrality_scores[target_cpg_node_id].betweenness`) or `cpg_data.metadata`.
        iii. If not pre-computed, call the appropriate `CPGMath` or `CPGSemantics` function (e.g., `CPGMath.betweenness_centrality(cpg_data)`), get the score for the target CPG node, and **cache the full set of scores** back into `cpg_data.unified_analysis` (and trigger persistence via `EnhancedRepository`).
        iv.  Evaluate using the `operator` and `value`. Percentile operators (`:gt_percentile`, `:lt_percentile`) require comparing the node's score against the distribution of that metric across all similar node types within the `cpg_data`.
    b.  For `:custom_cpg_function`, call the function with `(target_cpg_node_id_or_data, cpg_data, rule_options_from_pattern_def)`.
Refer to `CPG_PATTERN_DETECTION_ADVANCED.MD`, section 5."

**Prompt 4.3: Implement "God Object/Module" Anti-Pattern using CPG Rules**
"In `elixir_scope/ast_repository/pattern_matcher.ex`:
1.  Update the definition for the `:god_function` (or create a new `:god_module`) anti-pattern in `load_anti_patterns/0`.
2.  Its `rules` list should include CPG-based checks as per `CPG_PATTERN_DETECTION_ADVANCED.MD`, section 4.1:
    *   `{:cpg_node_metric, [:centrality, :degree_total], :gt_percentile, 95, applies_to: :module_root_node}` (for God Module) or `applies_to: :function_entry_node}` (for God Function).
    *   `{:cpg_node_metric, [:centrality, :betweenness_score], :gt_percentile, 95, applies_to: :module_root_node_or_function_entry_node}`.
    *   Optionally, add an AST-based rule for LoC/number of functions via existing mechanisms if these are not part of `CPGNode` properties directly.
    *   (Advanced) If module cohesion is available in `cpg_data.unified_analysis.quality_analysis.cohesion_score`: `{:cpg_node_metric, [:quality, :cohesion_score], :lt, 0.3, applies_to: :module_root_node}`.
Ensure the `applies_to:` option correctly targets the CPG node type intended for evaluation."

---

## Enhanced Implementation Strategy

**Before implementing CPG algorithms, understand the existing foundation:**

1. **Study `ElixirScope.ASTRepository.Enhanced.Repository`** - This is your CPG persistence layer
2. **Examine `CPGData.t()` structure** - This is your in-memory CPG representation
3. **Review ETS table patterns** - Follow established serialization/deserialization patterns

**Modified Implementation Order:**

1. **Enhance `CPGData.t()` structure** (Week 1)
   - Add `version` field for cache invalidation
   - Extend `unified_analysis` for algorithmic results
   - Ensure ETS serialization compatibility

2. **Implement `CPGMath` algorithms** (Week 2)
   - Operate on in-memory `CPGData.t()` structs
   - No direct ETS interaction - leave that to Repository
   - Focus on correctness first, optimization later

3. **Enhance `EnhancedRepository`** (Week 3)
   - Add ETS storage patterns for algorithmic results
   - Implement cache invalidation on CPG version changes
   - Add query methods for CPG metrics

4. **Update Query Layer** (Week 4)
   - Extend `QueryBuilder` for CPG-aware queries
   - Leverage existing ETS query patterns
   - Add on-demand computation with caching









   
### Update `CPG_IMPLEMENTATION_PROMPTS.MD` - Production-Ready Implementation

Add comprehensive implementation guidance that reflects the ETS architecture insights:

```markdown
## Section 7: Production-Ready Implementation Prompts

**Prompt 7.1: Implement ETS-Optimized CPG Storage in EnhancedRepository**
"Enhance `ElixirScope.ASTRepository.Enhanced.Repository` to support CPG data storage:

1. Add new ETS tables following existing patterns in the module:
   ```elixir
   @cpg_nodes_table :cpg_nodes
   @cpg_edges_table :cpg_edges  
   @cpg_analysis_cache :cpg_analysis_results
   ```

2. Implement CPG storage functions following the existing `store_enhanced_module/2` pattern:
   ```elixir
   def store_cpg_data(module_name, function_key, cpg_data) do
     # Serialize CPGData similar to existing EnhancedModuleData.to_ets_format/1
     # Store nodes and edges in separate tables for query optimization
     # Update unified_analysis cache with any pre-computed results
   end
   ```

3. Add retrieval functions following existing `get_enhanced_module/1` pattern:
   ```elixir
   def get_cpg_data(module_name, function_key) do
     # Reconstruct CPGData.t() from ETS tables
     # Apply lazy loading for large analysis results
     # Handle missing or partial CPG data gracefully
   end
   ```

4. Ensure all new functions follow the existing GenServer call/cast patterns and error handling."

**Prompt 7.2: Implement CPG Version Management and Cache Invalidation**
"Add version management to CPG data following ElixirScope's existing patterns:

1. Enhance the `CPGData.t()` struct in `cpg_data.ex`:
   ```elixir
   defstruct [
     # ... existing fields ...
     version: 1,
     last_updated: nil,
     cache_validity: %{}
   ]
   ```

2. Implement cache invalidation in `EnhancedRepository`:
   ```elixir
   def invalidate_cpg_cache(module_name, function_key, reason) do
     # Follow existing cache invalidation patterns
     # Update version numbers
     # Clear dependent analysis results
     # Log invalidation events for monitoring
   end
   ```

3. Add version checking to all CPG algorithm functions:
   ```elixir
   def get_cached_or_compute(cpg_data, algorithm, opts) do
     cache_key = {algorithm, hash_opts(opts)}
     case get_cached_result(cpg_data, cache_key) do
       {:ok, result, cached_version} when cached_version == cpg_data.version ->
         {:ok, result}
       _ ->
         compute_and_cache(cpg_data, algorithm, opts)
     end
   end
   ```"

**Prompt 7.3: Implement Production Monitoring Integration**
"Add comprehensive monitoring to CPG operations following ElixirScope's telemetry patterns:

1. Add telemetry events for CPG operations:
   ```elixir
   def execute_cpg_algorithm(algorithm, cpg_data, opts) do
     :telemetry.span([:elixir_scope, :cpg, :algorithm], %{algorithm: algorithm}, fn ->
       result = apply(CPGMath, algorithm, [cpg_data, opts])
       {result, %{nodes_processed: map_size(cpg_data.nodes)}}
     end)
   end
   ```

2. Add ETS table monitoring:
   ```elixir
   def report_ets_metrics() do
     tables = [@cpg_nodes_table, @cpg_edges_table, @cpg_analysis_cache]
     Enum.each(tables, fn table ->
       info = :ets.info(table)
       :telemetry.execute([:elixir_scope, :cpg, :ets, :size], 
         %{size: info[:size], memory: info[:memory]}, 
         %{table: table})
     end)
   end
   ```

3. Add query performance tracking following existing patterns in QueryBuilder."

**Prompt 7.4: Implement Graceful Error Handling and Fallbacks**
"Add comprehensive error handling to CPG operations:

1. Implement circuit breaker pattern for expensive CPG computations:
   ```elixir
   defmodule CPGCircuitBreaker do
     # Prevent expensive operations from overwhelming the system
     def execute_with_circuit_breaker(operation, opts \\ []) do
       case get_circuit_state() do
         :closed -> execute_operation(operation)
         :open -> {:error, :circuit_breaker_open}
         :half_open -> try_operation_with_monitoring(operation)
       end
     end
   end
   ```

2. Add fallback mechanisms for CPG queries:
   ```elixir
   def execute_cpg_query_with_fallback(query_spec) do
     case execute_cpg_query(query_spec) do
       {:ok, result} -> {:ok, result}
       {:error, :cpg_not_available} -> execute_ast_only_query(query_spec)
       {:error, :timeout} -> execute_simplified_cpg_query(query_spec)
       {:error, reason} -> {:error, {:cpg_fallback, reason}}
     end
   end
   ```

3. Ensure all CPG failures are logged appropriately and don't crash the main process."
```

## Comprehensive Testing Framework Enhancement

### Update Test Infrastructure for Production Readiness

Create `test/support/cpg_production_helpers.ex`:

```elixir
defmodule ElixirScope.CPGProductionHelpers do
  @moduledoc """
  Production-focused test helpers for CPG functionality.
  Simulates realistic production scenarios and loads.
  """
  
  def setup_production_ets_config do
    # Configure ETS tables with production-like settings
    Application.put_env(:elixir_scope, :cpg_ets_config, [
      read_concurrency: true,
      write_concurrency: true,
      decentralized_counters: true
    ])
  end
  
  def generate_realistic_project_cpg(module_count \\ 100) do
    # Generate CPG data that resembles real-world Elixir projects
    modules = generate_realistic_modules(module_count)
    
    # Create realistic inter-module dependencies
    dependencies = generate_realistic_dependencies(modules)
    
    # Build comprehensive CPG
    build_realistic_cpg(modules, dependencies)
  end
  
  def simulate_production_load(duration_ms \\ 30_000) do
    # Simulate realistic query patterns
    query_patterns = [
      {:frequent, &execute_common_queries/0, 0.6},
      {:moderate, &execute_analysis_queries/0, 0.3},
      {:rare, &execute_complex_queries/0, 0.1}
    ]
    
    # Simulate concurrent access patterns
    concurrent_users = 10
    
    spawn_load_simulation(query_patterns, concurrent_users, duration_ms)
  end
  
  def assert_production_performance(metrics) do
    # Assert production-level performance requirements
    assert metrics.avg_query_time_ms < 100
    assert metrics.p95_query_time_ms < 500
    assert metrics.error_rate < 0.01
    assert metrics.memory_usage_mb < 1000
    assert metrics.cache_hit_rate > 0.80
  end
  
  def measure_memory_impact(fun) do
    # Measure actual memory usage of CPG operations
    {:reductions, reductions_before} = Process.info(self(), :reductions)
    memory_before = :erlang.memory()
    
    result = fun.()
    
    memory_after = :erlang.memory()
    {:reductions, reductions_after} = Process.info(self(), :reductions)
    
    memory_delta = calculate_memory_delta(memory_before, memory_after)
    reductions_used = reductions_after - reductions_before
    
    {result, %{memory_delta: memory_delta, reductions: reductions_used}}
  end
  
  defp generate_realistic_modules(count) do
    # Generate modules with realistic size distributions
    # - 70% small modules (5-15 functions)
    # - 25% medium modules (15-50 functions)  
    # - 5% large modules (50+ functions)
    
    Enum.map(1..count, fn i ->
      size_category = choose_module_size_category()
      function_count = choose_function_count(size_category)
      
      %{
        name: :"TestModule#{i}",
        functions: generate_realistic_functions(function_count),
        complexity: calculate_module_complexity(function_count)
      }
    end)
  end
  
  defp generate_realistic_dependencies(modules) do
    # Create realistic dependency patterns:
    # - Core utility modules have high in-degree
    # - Application modules have moderate coupling
    # - Some circular dependencies (realistic anti-patterns)
    
    core_modules = Enum.take(modules, div(length(modules), 10))
    
    Enum.flat_map(modules, fn module ->
      dependency_count = choose_dependency_count(module.complexity)
      
      Enum.map(1..dependency_count, fn _ ->
        target = if :rand.uniform() < 0.3 do
          Enum.random(core_modules)
        else
          Enum.random(modules -- [module])
        end
        
        {module.name, target.name, choose_dependency_type()}
      end)
    end)
  end
end
```



