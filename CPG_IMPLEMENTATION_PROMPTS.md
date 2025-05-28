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

## Section 5: Implement CPG Performance & Memory Optimizations

**Prompt 5.1: Design and Implement Incremental CPG Updates in `CPGBuilder`**
"In `ElixirScope.ASTRepository.Enhanced.CPGBuilder`:
1.  Define and implement `update_cpg(existing_cpg :: CPGData.t(), changes :: map()) :: {:ok, CPGData.t()}`.
    The `changes` map will detail modifications, e.g., `%{modified_functions: [%{function_key: {:my_mod, :f1, 1}, new_ast: ..., old_cpg_nodes_range: {start_id, end_id}}], deleted_functions: [%{function_key: {:my_mod, :f2, 0}, cpg_nodes_range: {start_id, end_id}}], added_functions: [%{function_key: {:my_mod, :f3, 0}, ast: ...}]}`.
2.  **Deletion:** For `deleted_functions`, remove all CPG nodes and incident edges within their `cpg_nodes_range` (or identified by their function key) from `existing_cpg.nodes` and `existing_cpg.edges`. Update inter-procedural edges.
3.  **Modification:** For `modified_functions`:
    a.  (Simpler initial approach) Remove their old CPG subgraph (nodes/edges).
    b.  Generate a new CPG subgraph for `new_ast` using existing `CPGBuilder` logic, ensuring new node IDs are unique within the overall CPG.
    c.  Merge the new subgraph's nodes and edges into `existing_cpg`. Update inter-procedural edges.
4.  **Addition:** For `added_functions`, generate their CPG subgraphs and merge.
5.  **Versioning & Cache Invalidation:** Increment `existing_cpg.version` (add this field to `CPGData` if not present, integer default 1). Clear any algorithm-specific caches in `existing_cpg.metadata` or `existing_cpg.unified_analysis` (e.g., set `centrality_scores` to `nil` or an empty map). This signals that algorithmic results are stale.
Refer to `CPG_OPTIMIZATION_STRATEGIES.MD`, section 2."

**Prompt 5.2: Implement Algorithmic Result Caching in `CPGSemantics` and Persistence in `EnhancedRepository`**
"1. Modify functions in `ElixirScope.ASTRepository.Enhanced.CPGSemantics` (e.g., `dependency_impact_analysis`, `detect_architectural_smells`, `community_louvain`).
    a.  Before computation on `cpg :: CPGData.t()`, check if a valid (version-matching) result is in `cpg.unified_analysis` (e.g., `cpg.unified_analysis.complexity_analysis.centrality_scores` if the `cpg.version` matches a stored `version_for_centrality_scores`).
    b.  If cached and valid, return it.
    c.  Otherwise, compute. After computation, store the result in the appropriate field within `cpg.unified_analysis`, along with the `cpg.version` at which it was computed.
    d.  These functions should now return `{:ok, %{cpg | unified_analysis: updated_ua}, specific_result_for_query}`.
2.  Modify `ElixirScope.ASTRepository.Enhanced.Repository`. When its functions (like query handlers) call these `CPGSemantics` functions and receive an `updated_cpg_with_cache`, the `Repository` must persist this updated `CPGData.t()` (specifically its `unified_analysis` and new `version`) back to ETS. This might involve adding a new internal function like `EnhancedRepository.update_cpg_analysis_data(function_key_or_module_name, new_analysis_data, new_version)`.
Refer to `CPG_OPTIMIZATION_STRATEGIES.MD`, section 5."

**Prompt 5.3: Add `:version` field to `CPGData` and relevant sub-structs in `UnifiedAnalysis`**
"In `elixir_scope/ast_repository/enhanced/cpg_data.ex`:
1.  Add a `:version, default: 1` field to the `CPGData.t()` struct definition.
2.  In `UnifiedAnalysis.t()` and its sub-structs (e.g., `ComplexityAnalysis.t()`, `PatternAnalysis.t()`), consider adding a `:computed_at_cpg_version` field alongside cached results like `centrality_scores` or `community_assignments`. This will help validate cache freshness against the main `CPGData.version`.
    *Example for `ComplexityAnalysis` in `cpg_data.ex` (or its own file if it's separate):*
    ```elixir
    defmodule ElixirScope.ASTRepository.Enhanced.ComplexityAnalysis do
      defstruct [:unified_complexity, :complexity_distribution, :hotspots, :trends, 
                 :centrality_scores, :centrality_scores_version, # New
                 :community_assignments, :community_assignments_version] # New
      # ... typespec ...
    end
    ```
This `:version` field is crucial for cache invalidation as described in `CPG_OPTIMIZATION_STRATEGIES.MD`, section 5.3."

---

## Section 6: Enhancing AI Bridge for CPG Features

**Prompt 6.1: Implement `AI.Bridge.get_cpg_node_features_for_ai/3`**
"Create/Update `ElixirScope.AI.Bridge` (e.g., in `elixir_scope/ai/bridge.ex`).
Implement `get_cpg_node_features_for_ai(cpg_node_id :: String.t(), requested_features :: list(atom()), repo_pid \\ ElixirScope.ASTRepository.Enhanced.Repository)`.
1.  Determine the `function_key` or `module_name` from `cpg_node_id` (assume a parsable format like `Module.FunctionArity:NodeType:Instance` or that the caller provides the parent key). Fetch the relevant `CPGData.t()` using `EnhancedRepository.get_cpg/3` or `EnhancedRepository.get_enhanced_module/1` (if it's a module-level CPG node).
2.  For the specific `cpg_node_id` within the fetched `cpg_data`:
    a.  Iterate `requested_features`. For each feature atom:
        *   If it's a direct property of `CPGNode.t()` (e.g., `:ast_type`, `:line_number`), extract it from `cpg_data.nodes[cpg_node_id]`.
        *   If it's an CPG algorithmic metric (e.g., `:centrality_betweenness`, `:community_id`):
            i.   Check if it's cached in `cpg_data.unified_analysis` (e.g., `cpg_data.unified_analysis.complexity_analysis.centrality_scores[cpg_node_id].betweenness`). Verify cache freshness using version numbers.
            ii.  If not cached or stale, call the appropriate `CPGMath` or `CPGSemantics` function to compute it for the *entire* `cpg_data`.
            iii. Store the full set of computed metrics back into `cpg_data.unified_analysis` along with the current `cpg_data.version`, and trigger persistence of the updated `CPGData` via `EnhancedRepository`.
            iv.  Extract the specific metric for the target `cpg_node_id`.
3.  Return `{:ok, feature_map :: map()}` where keys are feature atoms and values are their computed values.
Refer to `CPG_AI_ML_FEATURES.MD`, section 2.1 and section 5."