Okay, I will now merge the essential "happy path" and foundational tests from your (Gemini's) initial list into Claude's comprehensive list. The goal is to ensure we don't lose the simple, direct TDD entry points while adopting the greater depth and breadth.

I'll mark additions clearly.

---

## Comprehensive Merged Test List for CPG Enhancement Layer

### I. CPG Data Structure & Basic CPG Construction Tests (New Section - from Gemini's initial thoughts, ensuring foundation)
    *   `test "CPGData struct can be initialized with nodes, edges, version, and metadata"`
    *   `test "CPGNode struct can be initialized with id, ast_type, ast_node_id, and metadata"`
    *   `test "CPGEdge struct can be initialized with id, from_node_id, to_node_id, type, subtype, and metadata"`
    *   `test "EnhancedRepository stores and retrieves CPGData associated with a function/module"` (Basic check before specific get_cpg tests)
    *   `test "EnhancedRepository associates CPGData version with stored CPG"`
    *   `test "EnhancedRepository gracefully handles requests for CPG of non-existent module/function"`

### II. CPGMath Algorithm Tests (Claude's list with Gemini's foundational tests integrated/ensured)
    *   **Helpers (Essential, from Gemini)**
        *   `test "get_neighbors/3 returns correct outgoing nodes"`
        *   `test "get_neighbors/3 returns correct incoming nodes"`
        *   `test "get_neighbors/3 returns correct bidirectional nodes"`
        *   `test "get_neighbors/3 on isolated node returns empty list"`
        *   `test "get_neighbors/3 for non-existent node returns error"`
        *   `test "get_edges/3 returns correct outgoing edges"`
        *   `test "get_edges/3 returns correct incoming edges"`
        *   `test "get_edges/3 returns correct bidirectional edges"`
        *   `test "get_edges/3 on isolated node returns empty list"`
        *   `test "get_edges/3 for non-existent node returns error"`
    *   **Pathfinding**
        *   `test "shortest_path/4 finds path in simple graph unweighted (happy path)"` **(Gemini Core)**
        *   `test "shortest_path/4 uses weight function correctly to alter path"` **(Gemini Core)**
        *   `test "shortest_path/4 returns error if no path exists"` **(Gemini Core)**
        *   `test "shortest_path/4 handles disconnected nodes"` **(Gemini Core)**
        *   `test "shortest_path/4 respects max_depth option"` **(Gemini Core)**
        *   `test "shortest_path/4 handles negative edge weights with Bellman-Ford or SPFA"` **(Claude Detail)**
        *   `test "shortest_path/4 detects negative cycles and returns appropriate error"` **(Claude Detail)**
        *   `test "all_paths/4 finds multiple paths in graph with branches"` **(Gemini Core)**
        *   `test "all_paths/4 respects max_paths and max_depth"` **(Gemini Core)**
        *   `test "all_paths/4 returns empty list when start equals end node for acyclic graph"` **(Claude Detail)**
        *   `test "all_paths/4 handles self-loops correctly returning single-node cycles"` **(Claude Detail)**
        *   `test "all_paths/4 handles cycles correctly within max_depth"` **(Gemini Core)**
        *   `test "all_paths/4 returns empty_list if no_path_exists"` **(Gemini Core)**
    *   **Connectivity**
        *   `test "strongly_connected_components/1 on empty graph returns empty list"` **(Gemini Core)**
        *   `test "strongly_connected_components/1 on DAG returns each node as a distinct SCC"` **(Gemini Core)**
        *   `test "strongly_connected_components/1 identifies single multi-node cycle"` **(Gemini Core)**
        *   `test "strongly_connected_components/1 identifies multiple disjoint SCCs"` **(Gemini Core)**
        *   `test "strongly_connected_components/1 handles complex graph with overlapping cycles correctly"` **(Claude Detail)**
        *   `test "topological_sort/1 on DAG returns a valid order"` **(Gemini Core)**
        *   `test "topological_sort/1 on cyclic graph returns error"` **(Gemini Core)**
        *   `test "topological_sort/1 on empty graph returns empty list"` **(Gemini Core)**
        *   `test "topological_sort/1 returns valid ordering where all edges point forward"` **(Claude Detail)**
        *   `test "topological_sort/1 handles multiple valid orderings deterministically (if applicable)"` **(Claude Detail)**
    *   **Centrality Measures**
        *   `test "degree_centrality/2 on empty graph returns empty map"` **(Gemini Core)**
        *   `test "degree_centrality/2 on single node graph"` **(Gemini Core)**
        *   `test "degree_centrality/2 on simple known graph structure produces expected scores (happy path)"` **(Gemini Core)**
        *   `test "degree_centrality/2 handles direction option (:in, :out, :total) correctly"` **(Gemini Core)**
        *   `test "degree_centrality/2 handles normalize option correctly"` **(Gemini Core)**
        *   `test "betweenness_centrality/2 on empty graph returns empty map"` **(Gemini Core - implied)**
        *   `test "betweenness_centrality/2 on simple known graph structure"` **(Gemini Core - implied)**
        *   `test "betweenness_centrality/2 returns zero for leaf nodes in tree structures"` **(Claude Detail)**
        *   `test "betweenness_centrality/2 handles disconnected graphs with multiple components"` **(Claude Detail)**
        *   `test "betweenness_centrality/2 with weighted edges uses weight function correctly"` **(Claude Detail)**
        *   `test "closeness_centrality/2 on empty graph returns empty map"` **(Gemini Core - implied)**
        *   `test "closeness_centrality/2 on simple known graph structure"` **(Gemini Core - implied)**
        *   `test "closeness_centrality/2 handles infinite distances for disconnected nodes (e.g., returns 0 or specific error/value)"` **(Claude Detail)**
        *   `test "closeness_centrality/2 returns reciprocal of average distance when normalized (or other standard definition)"` **(Claude Detail)**
        *   `test "eigenvector_centrality/2 converges within max_iterations or returns partial result/error"` **(Claude Detail)**
        *   `test "eigenvector_centrality/2 handles graphs with multiple eigenvector solutions (if applicable to implementation)"` **(Claude Detail)**
        *   `test "pagerank_centrality/2 sums to 1.0 across all nodes when normalized (or close to it due to precision)"` **(Claude Detail)**
        *   `test "pagerank_centrality/2 respects damping factor alpha parameter correctly"` **(Claude Detail)**
        *   `test "pagerank_centrality/2 handles dangling nodes (no outgoing edges) properly"` **(Claude Detail)**
    *   **Community Detection**
        *   `test "community_louvain/2 on empty graph"` **(Gemini Core - implied)**
        *   `test "community_louvain/2 on graph with clear clusters identifies them"` **(Gemini Core - implied)**
        *   `test "community_louvain/2 maximizes modularity score for detected communities (verify relative quality)"` **(Claude Detail)**
        *   `test "community_louvain/2 respects resolution parameter for community granularity"` **(Claude Detail)**
        *   `test "community_louvain/2 handles weighted edges in modularity calculation"` **(Claude Detail)**
        *   `test "community_label_propagation/2 produces stable communities for deterministic graphs"` **(Claude Detail)**
        *   `test "community_label_propagation/2 handles ties in label frequency correctly (if deterministic strategy exists)"` **(Claude Detail)**
    *   **Graph Metrics**
        *   `test "density/1 on empty graph is zero_or_nan"` **(Gemini Core)**
        *   `test "density/1 returns 1.0 for complete graphs and 0.0 for graph with no edges"` **(Claude/Gemini Core)**
        *   `test "density/1 on sparse graph is_low"` **(Gemini Core)**
        *   `test "density/1 handles directed vs undirected graph density calculations (if CPG can be considered as such)"` **(Claude Detail)**
        *   `test "diameter/2 on simple line graph"` **(Gemini Core)**
        *   `test "diameter/2 returns infinity or error for disconnected graphs"` **(Claude/Gemini Core)**
        *   `test "diameter/2 uses weight function for weighted diameter calculation"` **(Claude Detail)**

### III. CPGSemantics Analysis Tests (Claude's list with Gemini's foundational tests integrated/ensured)
    *   `test "calculate_semantic_edge_weight/3 applies node type penalties correctly (multiplicatively or additively as designed)"` **(Claude/Gemini Core)**
    *   `test "calculate_semantic_edge_weight/3 considers edge direction in weight calculation if relevant for semantics"` **(Claude Detail)**
    *   `test "semantic_critical_path/4 finds path based on cost_factors (happy path)"` **(Gemini Core)**
    *   `test "semantic_critical_path/4 returns details with cost and risk"` **(Gemini Core)**
    *   `test "semantic_critical_path/4 finds maximum cost path for risk analysis (if cost is inverted risk)"` **(Claude Detail)**
    *   `test "semantic_critical_path/4 filters edges by path_type before pathfinding"` **(Claude Detail)**
    *   `test "semantic_critical_path/4 returns top k paths when return_count specified"` **(Claude Detail)**
    *   `test "trace_data_flow_semantic/4 identifies direct flow_path"` **(Gemini Core)**
    *   `test "trace_data_flow_semantic/4 identifies transformations and conditions on path"` **(Gemini Core)**
    *   `test "trace_data_flow_semantic/4 handles no flow_found"` **(Gemini Core)**
    *   `test "trace_data_flow_semantic/4 tracks variable transformations along path"` **(Claude Detail)**
    *   `test "trace_data_flow_semantic/4 includes control flow conditions for each path"` **(Claude Detail)**
    *   `test "trace_data_flow_semantic/4 handles phi nodes at control flow joins (if DFG uses SSA)"` **(Claude Detail)**
    *   `test "dependency_impact_analysis/3 identifies direct downstream callers/data_dependencies"` **(Gemini Core)**
    *   `test "dependency_impact_analysis/3 respects depth and dependency_types options"` **(Gemini Core)**
    *   `test "dependency_impact_analysis/3 calculates impact_scores"` **(Gemini Core)**
    *   `test "dependency_impact_analysis/3 calculates transitive closure up to depth"` **(Claude Detail)**
    *   `test "dependency_impact_analysis/3 identifies affected communities correctly"` **(Claude Detail)**
    *   `test "dependency_impact_analysis/3 excludes node types specified in options"` **(Claude Detail)**
    *   `test "identify_coupling/4 between two directly calling functions"` **(Gemini Core)**
    *   `test "identify_coupling/4 based on shared data access nodes in CPG"` **(Gemini Core)**
    *   `test "identify_coupling/4 returns strength and types"` **(Gemini Core)**
    *   `test "identify_coupling/4 measures bidirectional coupling strength"` **(Claude Detail)**
    *   `test "identify_coupling/4 distinguishes coupling types (call, data, shared state) based on CPG edge types"` **(Claude Detail)**
    *   `test "detect_architectural_smells/2 identifies god_object using centrality and size heuristics (basic)"` **(Gemini Core)**
    *   `test "detect_architectural_smells/2 identifies cyclic_dependencies using SCC results (basic)"` **(Gemini Core)**
    *   `test "detect_architectural_smells/2 respects smells_to_detect option"` **(Gemini Core)**
    *   `test "detect_architectural_smells/2 uses percentile thresholds for god objects"` **(Claude Detail)**
    *   `test "detect_architectural_smells/2 identifies feature envy from coupling patterns"` **(Claude Detail)**
    *   `test "detect_architectural_smells/2 detects shotgun surgery from impact radius"` **(Claude Detail)**
    *   `test "analyze_module_cohesion/3 for highly cohesive module CPG returns high score"` **(Gemini Core)**
    *   `test "analyze_module_cohesion/3 for poorly cohesive module CPG returns low score"` **(Gemini Core)**
    *   `test "analyze_module_cohesion/3 uses internal vs external edge ratio of CPG edges"` **(Claude Detail)**
    *   `test "analyze_module_cohesion/3 calculates LCOM variants adapted for CPG (e.g., based on shared function calls/data nodes within module CPG)"` **(Claude Detail)**
    *   `test "identify_code_communities/2 enriches CPGMath communities with semantic descriptions (e.g. dominant AST types)"` **(Gemini Core)**
    *   `test "identify_code_communities/2 generates meaningful description summaries (simple heuristic for now)"` **(Claude Detail)**
    *   `test "identify_code_communities/2 calculates inter-community CPG edge counts"` **(Claude Detail)**

### IV. EnhancedRepository CPG Lifecycle Tests (New Section - from Gemini's focus on integration)
    *   `test "store_enhanced_module with CPG generation enabled creates and links CPGData"`
    *   `test "store_enhanced_function with CPG generation enabled creates and links function-specific CPGData"`
    *   `test "get_cpg/3 retrieves correct CPG for a specific function"`
    *   `test "get_cpg/3 triggers on-demand CPG generation if not present and persists it"`
    *   `test "get_cpg/3 returns error if AST for function not found for generation"`
    *   `test "update_enhanced_module changing AST triggers CPG regeneration or update"`
    *   `test "delete_enhanced_module removes associated CPG data"`
    *   `test "CPG generation failure during store_enhanced_module is logged and does not prevent AST storage"`
    *   `test "CPGData.version is initialized and updated correctly by EnhancedRepository"`

### V. Query Enhancement Tests (Claude's list with Gemini's foundational tests integrated/ensured)
    *   `test "QueryBuilder.valid_condition?/1 accepts new CPG metric fields (e.g., :centrality_degree, :community_id)"` **(Claude/Gemini Core)**
    *   `test "QueryBuilder.valid_condition?/1 validates percentile operators correctly (e.g., :gt_percentile)"` **(Claude Detail)**
    *   `test "QueryBuilder.valid_condition?/1 accepts new CPG operators (e.g., :has_smell, :in_community_with)"` **(Gemini Core)**
    *   `test "QueryBuilder allows FROM :cpg_nodes (or similar for querying CPG directly) as valid query target"` **(Claude Detail)**
    *   `test "QueryBuilder allows FROM :communities (or similar) as valid query target"` **(Claude Detail)**
    *   `test "QueryBuilder.evaluate_condition_internal/2 handles :has_smell operator based on CPG analysis results"` **(Claude Detail)**
    *   `test "QueryBuilder.evaluate_condition_internal/2 handles :in_community_with operator based on CPG analysis results"` **(Claude Detail)**
    *   `test "QueryBuilder.evaluate_condition_internal/2 handles :path_contains_node_type (for path query results)"` **(Claude Detail)**
    *   `test "QueryBuilder supports centrality score filtering with all standard operators (gt, lt, eq)"` **(Claude Detail)**
    *   `test "QueryBuilder supports community_id in WHERE and SELECT clauses"` **(Claude Detail)**
    *   `test "QueryBuilder.build_query/1 correctly includes CPG fields in SELECT list"` **(Gemini Core)**
    *   `test "QueryBuilder.build_query/1 estimates cost for CPG-heavy queries (higher cost than non-CPG queries)"` **(Claude Detail)**
    *   `test "QueryExecutor executes query for functions with high PageRank"` **(Gemini Core)**
    *   `test "QueryExecutor executes query for modules in specific community"` **(Gemini Core)**
    *   `test "QueryExecutor triggers CPGMath/CPGSemantics computation for missing metrics needed by query"` **(Claude Detail)**
    *   `test "QueryExecutor uses cached CPG algorithmic results if available and fresh (version match)"` **(Gemini Core)**
    *   `test "QueryExecutor caches newly computed CPG metrics in CPGData.unified_analysis (or similar structure)"` **(Claude Detail)**
    *   `test "QueryExecutor persists updated CPG metrics (with CPGData version) to repository via EnhancedRepository"` **(Claude Detail)**
    *   `test "QueryExecutor handles :impact_analysis query type by calling CPGSemantics"` **(Claude/Gemini Core)**
    *   `test "QueryExecutor handles :architectural_smells_detection query type by calling CPGSemantics"` **(Claude/Gemini Core)**
    *   `test "QueryExecutor handles :critical_path_finding query type by calling CPGSemantics"` **(Claude/Gemini Core)**
    *   `test "QueryExecutor handles :community_detection query type by calling CPGSemantics"` **(Claude/Gemini Core)**
    *   `test "QueryExecutor uses CPGOptimizer for query plan selection (mock optimizer choice or observe behavior)"` **(Claude Detail)**
    *   `test "QueryExecutor respects freshness requirements for cached metrics (e.g., query option to force recompute)"` **(Claude Detail)**

### VI. Pattern Matcher Enhancement Tests (Claude's list with Gemini's foundational tests integrated/ensured)
    *   `test "PatternMatcher loads patterns with new :cpg_node_metric rule type"` **(Gemini Core)**
    *   `test "PatternMatcher evaluates :cpg_node_metric rule type correctly using precomputed CPG centrality"` **(Gemini Core)**
    *   `test "PatternMatcher evaluates :cpg_graph_metric rule type correctly (e.g., graph density)"` **(Claude Detail)**
    *   `test "PatternMatcher evaluates :cpg_path_check rule type correctly (e.g., data flow path exists)"` **(Claude Detail)**
    *   `test "PatternMatcher evaluates :custom_cpg_function rule type correctly"` **(Claude Detail)**
    *   `test "PatternMatcher handles percentile operators in CPG rules"` **(Claude Detail)**
    *   `test "PatternMatcher fetches CPGData for module/function being analyzed"` **(Claude Detail)**
    *   `test "PatternMatcher triggers CPG metric computation (and persistence) when not cached for a rule"` **(Claude Detail)**
    *   `test "PatternMatcher combines AST and CPG rules for refined confidence scoring"` **(Claude Detail)**
    *   `test "PatternMatcher detects god objects using CPG centrality thresholds and module/function size"` **(Claude/Gemini Core)**
    *   `test "PatternMatcher detects shotgun surgery using CPG impact analysis (affected communities/nodes)"` **(Claude Detail)**
    *   `test "PatternMatcher detects feature envy using CPG coupling analysis results"` **(Claude Detail)**
    *   `test "PatternMatcher detects circular dependencies using CPG SCCs results"` **(Claude/Gemini Core)**
    *   `test "PatternMatcher identifies unstable abstractions using CPG betweenness and other factors (e.g., churn - if mockable)"` **(Claude Detail)**
    *   `test "PatternMatcher detects data sinks without sanitization using CPG data flow tracing"` **(Claude/Gemini Core)**
    *   `test "PatternMatcher caches pattern matching results keyed by CPG version"` **(Claude Detail)**

### VII. Performance Optimization Tests (Claude's list with Gemini's foundational tests integrated/ensured)
    *   **Incremental CPG Updates**
        *   `test "CPGBuilder.update_cpg/2 handles function deletion incrementally, removing relevant CPG nodes/edges"` **(Claude Detail)**
        *   `test "CPGBuilder.update_cpg/2 handles function addition incrementally, adding new CPG subgraph"` **(Claude Detail)**
        *   `test "CPGBuilder.update_cpg/2 handles function modification (body change) incrementally, updating CPG subgraph"` **(Claude Detail)**
        *   `test "CPGBuilder.update_cpg/2 handles function modification (signature change) updating call sites"` **(Gemini Core - implied)**
        *   `test "CPGBuilder.update_cpg/2 updates inter-procedural CPG edges correctly after local changes"` **(Claude Detail)**
        *   `test "CPGBuilder.update_cpg/2 increments CPGData.version on structural change"` **(Claude Detail)**
        *   `test "CPGBuilder.update_cpg/2 invalidates/clears cached CPG algorithmic metrics in CPGData on structure change"` **(Claude Detail)**
    *   **CPG Query Optimizer (Conceptual)**
        *   `test "CPGOptimizer (mocked) selects index-first strategy when CPG index available for filter"` **(Claude Detail)**
        *   `test "CPGOptimizer (mocked) reorders filters by estimated selectivity (e.g., CPG property vs expensive algorithm)"` **(Claude Detail)**
        *   `test "CPGOptimizer (mocked) chooses appropriate graph traversal algorithm for path queries"` **(Claude Detail)**
        *   `test "CPGOptimizer (mocked) estimates costs based on CPG structure statistics (e.g. node counts, edge density)"` **(Claude Detail)**
    *   **Memory Management**
        *   `test "MemoryManager compresses CPGData for infrequently accessed modules (verify interaction with EnhancedRepository)"` **(Claude Detail)**
        *   `test "MemoryManager initiates string interning for CPG properties (verify via reduced size or mock interner)"` **(Claude Detail)**
        *   `test "MemoryManager supports lazy loading of detailed CPG components (verify via staged loading)"` **(Claude Detail)**
        *   `test "MemoryManager evicts CPG algorithm caches from its ETS tables under memory pressure"` **(Claude Detail)**
    *   **Monitoring & Benchmarking**
        *   `test "CPG operations (generation, query, algorithm) measure and report performance metrics via Utils.measure/telemetry"` **(Claude Detail)**
        *   `test "Incremental CPG updates are demonstrably faster than full rebuilds for localized changes"` **(Claude/Gemini Core)**

### VIII. AI/ML Feature Extraction Tests (Claude's list with Gemini's foundational tests integrated/ensured)
    *   `test "AI.Bridge.get_cpg_node_features_for_ai/3 extracts direct CPGNode properties (ast_type, metadata)"` **(Claude Detail)**
    *   `test "AI.Bridge.get_cpg_node_features_for_ai/3 computes (and caches/persists) missing CPG algorithmic metrics"` **(Claude/Gemini Core)**
    *   `test "AI.Bridge.get_cpg_node_features_for_ai/3 handles requests for unknown features gracefully (e.g. returns nil or error)"` **(Claude Detail)**
    *   `test "AI.Bridge.get_function_cpg_with_algorithms_for_ai/2 returns full CPGData with relevant precomputed metrics"` **(Claude Detail)**
    *   `test "AI.Bridge.find_cpg_nodes_for_ai_pattern/3 matches basic structural CPG patterns"` **(Claude Detail)**
    *   `test "AI.Bridge.get_correlated_features_for_ai/5 correctly combines static CPG features with mock runtime data"` **(Claude Detail)**
    *   `test "IntelligentCodeAnalyzer uses CPG centrality and community data for complexity and quality refinement"` **(Claude/Gemini Core)**
    *   `test "IntelligentCodeAnalyzer suggests refactoring based on CPG community analysis and coupling metrics"` **(Claude/Gemini Core)**
    *   `test "ExecutionPredictor uses semantic CPG paths and node properties as features for prediction"` **(Claude/Gemini Core)**
    *   `test "ExecutionPredictor considers CPG node types (e.g., I/O, CPU-bound) along paths for resource prediction"` **(Claude Detail)**
    *   `test "LLM prompts generated for code analysis include relevant CPG context (centrality, community, dependencies)"` **(Claude Detail)**
    *   `test "LLM prompts for refactoring suggestions receive CPG impact analysis summary"` **(Claude Detail)**

### IX. Integration and Edge Case Tests (Essential, from Claude's list)
    *   `test "CPGMath handles empty graphs without errors for all algorithms"`
    *   `test "CPGMath handles single-node graphs correctly for all algorithms"`
    *   `test "CPGMath handles very large graphs (e.g., 1000+ nodes, 5000+ edges) within defined performance targets"` (May be a benchmark)
    *   `test "CPGSemantics handles missing CPG node metadata gracefully (e.g., no complexity score)"`
    *   `test "CPGSemantics handles malformed CPG structures (e.g., edge to non-existent node) with errors"`
    *   `test "Query system handles requests for CPG metrics for non-existent CPG nodes gracefully"`
    *   `test "Pattern matcher handles incomplete CPG data (e.g., missing algorithmic results) by skipping relevant rules or defaulting"`
    *   `test "Incremental CPG updates handle concurrent modifications to the same module safely (e.g., using GenServer state or locks)"` (Challenging, important)
    *   `test "Cache invalidation (CPGData version change) correctly cascades through dependent computations and caches"`
    *   `test "Memory pressure handling in MemoryManager correctly triggers CPG data eviction/compression"`
    *   `test "CPG version conflicts during distributed scenarios are detected and handled (if applicable in future)"`
    *   `test "Circular dependency in incremental update logic itself is prevented or detected (e.g., update A triggers update B triggers update A)"`
    *   `test "String interning handles unicode and special characters correctly"`
    *   `test "Lazy loading of CPG components doesn't cause infinite loops on circular CPG references"`
    *   `test "AI feature extraction gracefully handles partial or missing CPG data"`

### X. Property-Based Tests (Essential for algorithmic robustness, from Claude's list)
    *   `test "property: shortest path length is always less than or equal to any other path length between two nodes"`
    *   `test "property: nodes in an SCC are mutually reachable; nodes in different DAG-ordered SCCs are not mutually reachable backward"`
    *   `test "property: centrality scores (e.g., degree) are non-negative"`
    *   `test "property: removing an edge never increases degree centrality"`
    *   `test "property: (Louvain) communities partition all nodes in the graph"`
    *   `test "property: (Louvain) modularity of found partition is positive for graphs with community structure"`
    *   `test "property: incremental CPG update on an unchanged AST results in an identical CPG (or semantically equivalent)"`
    *   `test "property: cached CPG algorithmic results match freshly computed results given the same CPG version"`
    *   `test "property: semantic weights calculated by CPGSemantics are always non-negative (or follow defined constraints)"`
    *   `test "property: dependency impact analysis always finds a superset of direct dependencies for increased depth"`

### XI. Performance Benchmark Tests (Essential for NFRs, from Claude's list)
    *   `test "benchmark: SCC computation scales (e.g., O(V+E))"`
    *   `test "benchmark: Betweenness centrality computation meets performance targets for various graph sizes"`
    *   `test "benchmark: Shortest pathfinding scales appropriately with graph size and edge density"`
    *   `test "benchmark: Louvain community detection handles large graphs efficiently"`
    *   `test "benchmark: Incremental CPG update for single function change is at least N times faster than full rebuild (N > 5)"`
    *   `test "benchmark: Query caching for CPG metrics improves average query response time by X%+"`
    *   `test "benchmark: Overall CPG memory usage stays within X MB per Y modules/LOC under typical analysis"`
    *   `test "benchmark: Pattern matching with CPG rules scales acceptably with number of rules and CPG size"`

---

This merged list is now much more robust. It retains the initial TDD-friendly core functional tests and significantly expands into detailed algorithmic validation, edge case handling, system integration, non-functional requirements, and advanced testing methodologies like property-based testing. This provides a very strong target for Claude to work towards.