## Comprehensive Test List for CPG Enhancement Layer

### CPGMath Algorithm Tests
- `test "all_paths/4 returns empty list when start equals end node for acyclic graph"`
- `test "all_paths/4 handles self-loops correctly returning single-node cycles"`
- `test "topological_sort/1 returns valid ordering where all edges point forward"`
- `test "topological_sort/1 handles multiple valid orderings deterministically"`
- `test "betweenness_centrality/2 returns zero for leaf nodes in tree structures"`
- `test "betweenness_centrality/2 handles disconnected graphs with multiple components"`
- `test "betweenness_centrality/2 with weighted edges uses weight function correctly"`
- `test "closeness_centrality/2 handles infinite distances for disconnected nodes"`
- `test "closeness_centrality/2 returns reciprocal of average distance when normalized"`
- `test "eigenvector_centrality/2 converges within max_iterations or returns partial result"`
- `test "eigenvector_centrality/2 handles graphs with multiple eigenvector solutions"`
- `test "pagerank_centrality/2 sums to 1.0 across all nodes when normalized"`
- `test "pagerank_centrality/2 respects damping factor alpha parameter correctly"`
- `test "pagerank_centrality/2 handles dangling nodes (no outgoing edges) properly"`
- `test "community_louvain/2 maximizes modularity score for detected communities"`
- `test "community_louvain/2 respects resolution parameter for community granularity"`
- `test "community_louvain/2 handles weighted edges in modularity calculation"`
- `test "community_label_propagation/2 produces stable communities for deterministic graphs"`
- `test "community_label_propagation/2 handles ties in label frequency correctly"`
- `test "density/1 returns 1.0 for complete graphs and 0.0 for empty graphs"`
- `test "density/1 handles directed vs undirected graph density calculations"`
- `test "diameter/2 returns infinity for disconnected graphs"`
- `test "diameter/2 uses weight function for weighted diameter calculation"`
- `test "shortest_path/4 handles negative edge weights with Bellman-Ford"`
- `test "shortest_path/4 detects negative cycles and returns appropriate error"`

### CPGSemantics Analysis Tests
- `test "calculate_semantic_edge_weight/3 applies node type penalties multiplicatively"`
- `test "calculate_semantic_edge_weight/3 considers edge direction in weight calculation"`
- `test "semantic_critical_path/4 finds maximum cost path for risk analysis"`
- `test "semantic_critical_path/4 filters edges by path_type before pathfinding"`
- `test "semantic_critical_path/4 returns top k paths when return_count specified"`
- `test "trace_data_flow_semantic/4 tracks variable transformations along path"`
- `test "trace_data_flow_semantic/4 includes control flow conditions for each path"`
- `test "trace_data_flow_semantic/4 handles phi nodes at control flow joins"`
- `test "dependency_impact_analysis/3 calculates transitive closure up to depth"`
- `test "dependency_impact_analysis/3 identifies affected communities correctly"`
- `test "dependency_impact_analysis/3 excludes node types specified in options"`
- `test "identify_coupling/4 measures bidirectional coupling strength"`
- `test "identify_coupling/4 distinguishes coupling types (call, data, shared state)"`
- `test "detect_architectural_smells/2 uses percentile thresholds for god objects"`
- `test "detect_architectural_smells/2 identifies feature envy from coupling patterns"`
- `test "detect_architectural_smells/2 detects shotgun surgery from impact radius"`
- `test "analyze_module_cohesion/3 uses internal vs external edge ratio"`
- `test "analyze_module_cohesion/3 calculates LCOM variants for CPG"`
- `test "identify_code_communities/2 enriches communities with dominant node types"`
- `test "identify_code_communities/2 generates meaningful description summaries"`
- `test "identify_code_communities/2 calculates inter-community edge counts"`

### Query Enhancement Tests
- `test "QueryBuilder.valid_condition?/1 accepts new CPG metric fields"`
- `test "QueryBuilder.valid_condition?/1 validates percentile operators correctly"`
- `test "QueryBuilder allows FROM :cpg_nodes as valid query target"`
- `test "QueryBuilder allows FROM :communities as valid query target"`
- `test "QueryBuilder.evaluate_condition_internal/2 handles :has_smell operator"`
- `test "QueryBuilder.evaluate_condition_internal/2 handles :in_community_with operator"`
- `test "QueryBuilder.evaluate_condition_internal/2 handles :path_contains_node_type"`
- `test "QueryBuilder supports centrality score filtering with all operators"`
- `test "QueryBuilder supports community_id in WHERE and SELECT clauses"`
- `test "QueryBuilder.build_query/1 estimates cost for CPG-heavy queries"`
- `test "QueryExecutor triggers CPGMath computation for missing metrics"`
- `test "QueryExecutor caches computed metrics in CPGData.unified_analysis"`
- `test "QueryExecutor persists updated CPG metrics to repository"`
- `test "QueryExecutor handles :impact_analysis query type"`
- `test "QueryExecutor handles :architectural_smells_detection query type"`
- `test "QueryExecutor handles :critical_path_finding query type"`
- `test "QueryExecutor handles :community_detection query type"`
- `test "QueryExecutor uses CPGOptimizer for query plan selection"`
- `test "QueryExecutor respects freshness requirements for cached metrics"`

### Pattern Matcher Enhancement Tests
- `test "PatternMatcher evaluates :cpg_node_metric rule type correctly"`
- `test "PatternMatcher evaluates :cpg_graph_metric rule type correctly"`
- `test "PatternMatcher evaluates :cpg_path_check rule type correctly"`
- `test "PatternMatcher evaluates :custom_cpg_function rule type correctly"`
- `test "PatternMatcher handles percentile operators in CPG rules"`
- `test "PatternMatcher fetches CPGData for module being analyzed"`
- `test "PatternMatcher triggers metric computation when not cached"`
- `test "PatternMatcher combines AST and CPG rules for confidence scoring"`
- `test "PatternMatcher detects god objects using centrality thresholds"`
- `test "PatternMatcher detects shotgun surgery using impact analysis"`
- `test "PatternMatcher detects feature envy using coupling analysis"`
- `test "PatternMatcher detects circular dependencies using SCCs"`
- `test "PatternMatcher identifies unstable abstractions using betweenness"`
- `test "PatternMatcher detects data sinks without sanitization"`
- `test "PatternMatcher caches pattern matching results with CPG version"`

### Performance Optimization Tests
- `test "CPGBuilder.update_cpg/2 handles function deletion incrementally"`
- `test "CPGBuilder.update_cpg/2 handles function addition incrementally"`
- `test "CPGBuilder.update_cpg/2 handles function modification incrementally"`
- `test "CPGBuilder.update_cpg/2 updates inter-procedural edges correctly"`
- `test "CPGBuilder.update_cpg/2 increments CPG version on change"`
- `test "CPGBuilder.update_cpg/2 invalidates cached metrics on structure change"`
- `test "CPGOptimizer selects index-first strategy when applicable"`
- `test "CPGOptimizer reorders filters by selectivity estimates"`
- `test "CPGOptimizer chooses appropriate graph traversal algorithm"`
- `test "CPGOptimizer estimates costs based on CPG structure statistics"`
- `test "MemoryManager compresses CPG data for infrequently accessed modules"`
- `test "MemoryManager implements string interning for CPG properties"`
- `test "MemoryManager supports lazy loading of detailed CPG components"`
- `test "MemoryManager evicts CPG algorithm caches under memory pressure"`
- `test "CPG operations measure and report performance metrics"`
- `test "Incremental CPG updates are faster than full rebuilds"`

### AI/ML Feature Extraction Tests
- `test "AI.Bridge.get_cpg_node_features_for_ai/3 extracts direct properties"`
- `test "AI.Bridge.get_cpg_node_features_for_ai/3 computes missing metrics"`
- `test "AI.Bridge.get_cpg_node_features_for_ai/3 handles unknown features gracefully"`
- `test "AI.Bridge.get_function_cpg_with_algorithms_for_ai/2 returns full CPG"`
- `test "AI.Bridge.find_cpg_nodes_for_ai_pattern/3 matches structural patterns"`
- `test "AI.Bridge.get_correlated_features_for_ai/5 combines static and dynamic"`
- `test "IntelligentCodeAnalyzer uses CPG centrality for complexity refinement"`
- `test "IntelligentCodeAnalyzer suggests refactoring based on communities"`
- `test "ExecutionPredictor uses semantic paths for prediction features"`
- `test "ExecutionPredictor considers CPG node types along paths"`
- `test "LLM prompts include CPG context for code analysis requests"`
- `test "LLM receives impact analysis for refactoring suggestions"`

### Integration and Edge Case Tests
- `test "CPGMath handles empty graphs without errors"`
- `test "CPGMath handles single-node graphs correctly"`
- `test "CPGMath handles very large graphs (1000+ nodes) within performance targets"`
- `test "CPGSemantics handles missing node metadata gracefully"`
- `test "CPGSemantics handles malformed CPG structures with errors"`
- `test "Query system handles CPG metrics for non-existent nodes"`
- `test "Pattern matcher handles incomplete CPG data appropriately"`
- `test "Incremental updates handle concurrent modifications safely"`
- `test "Cache invalidation cascades through dependent computations"`
- `test "Memory pressure triggers appropriate CPG data eviction"`
- `test "CPG version conflicts are detected and handled"`
- `test "Circular dependency in incremental updates is detected"`
- `test "String interning handles unicode and special characters"`
- `test "Lazy loading doesn't cause infinite loops on circular references"`
- `test "AI feature extraction handles partial CPG data"`

### Property-Based Tests
- `test "property: shortest path is actually shortest for any graph"`
- `test "property: SCCs partition the graph completely"`
- `test "property: centrality scores maintain relative ordering"`
- `test "property: communities have higher internal than external density"`
- `test "property: incremental updates produce same result as full rebuild"`
- `test "property: cached results match freshly computed results"`
- `test "property: semantic weights are always positive"`
- `test "property: impact analysis finds all reachable nodes"`

### Performance Benchmark Tests
- `test "benchmark: SCC computation scales linearly with edges"`
- `test "benchmark: centrality computation meets performance targets"`
- `test "benchmark: pathfinding scales appropriately with graph size"`
- `test "benchmark: community detection handles large graphs efficiently"`
- `test "benchmark: incremental updates are 10x faster than rebuild"`
- `test "benchmark: query caching improves performance by 50%+"`
- `test "benchmark: memory usage stays within configured limits"`
- `test "benchmark: pattern matching with CPG rules scales linearly"`