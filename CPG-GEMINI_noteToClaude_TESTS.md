## Test Implementation Guide for ElixirScope CPG Enhancement Layer

**To:** Claude (AI Coding Assistant)
**From:** Your ElixirScope Design Partner
**Date:** May 28, 2025
**Subject:** Detailed Guidance for Building Comprehensive CPG Enhancement Tests

This document provides guidance for implementing the comprehensive test list for ElixirScope's CPG Algorithmic Enhancement Layer. My focus here is to give you concise, actionable insights that leverage a deep understanding of how these CPG features are intended to work and interact, so you can create a truly robust test suite.

Refer to the previously generated test list (`CPG-OPUS_TESTLIST.md`) and the API/design documents (`CPG_MATH_API.MD`, `CPG_SEMANTICS_API.MD`, etc.).

### I. General Principles for Test Construction

1.  **Isolate and Mock Strategically:**
    *   When testing `CPGMath`, provide pure `CPGData.t()` structures. No need to mock `EnhancedRepository` here.
    *   When testing `CPGSemantics`, you might provide `CPGData.t()` but could mock specific `CPGMath` calls if you want to test the semantic layer's logic independently of a complex `CPGMath` algorithm's full execution (e.g., mock `CPGMath.betweenness_centrality/2` to return predefined scores, then test how `CPGSemantics.detect_architectural_smells/2` uses those scores for "God Object" detection).
    *   When testing `QueryExecutor` or `PatternMatcher` integration with CPG metrics, you might mock `EnhancedRepository.get_cpg/3` to return pre-cooked `CPGData.t()` structs that already contain (or lack) specific algorithmic results to test caching and on-demand computation paths.

2.  **Focus on "Semantic Contracts":**
    *   For `CPGSemantics`, tests should verify that the *interpretation* of `CPGMath` results makes sense in a code context. E.g., for `dependency_impact_analysis`, don't just test reachability; test that the "types" of impact (call, data) are correctly distinguished and that `affected_communities` reflect a meaningful spread if the CPG is structured that way.

3.  **Data-Driven Test Setups:**
    *   Create helper functions (e.g., in `test/support/cpg_test_helpers.ex`) to generate diverse `CPGData.t()` fixtures:
        *   `build_cpg_with_known_centrality_hotspot(hotspot_node_id, type: :betweenness)`
        *   `build_cpg_with_clear_communities(num_communities, intra_community_density, inter_community_density)`
        *   `build_cpg_with_specific_architectural_smell(smell_type: :god_module)`
        *   `build_cpg_with_data_flow_path(source_type, sink_type, has_sanitizer_node_on_path?: boolean)`
    *   This makes tests more readable and focused on the logic being tested rather than CPG setup.

4.  **Test Algorithmic Parameter Sensitivity:**
    *   For algorithms in `CPGMath` and `CPGSemantics` that take options (e.g., `alpha` for PageRank, `resolution` for Louvain, `cost_factors` for semantic paths), include tests that vary these parameters and assert that the output changes in an expected way.

5.  **Verify Cache Behavior Explicitly:**
    *   For tests involving caching of algorithmic results (in `CPGData.metadata`, `CPGData.unified_analysis`, or `MemoryManager`):
        1.  Call the function/query once (trigger computation).
        2.  Verify the result.
        3.  *Assert that the cache now contains the expected data (e.g., by inspecting `CPGData.unified_analysis.complexity_analysis.centrality_scores_version` or mocking `MemoryManager.cache_get/3` to see if it's called or not on the second attempt).*
        4.  Call the function/query again with the same inputs.
        5.  Verify the result is the same and (if possible) that the computation path was shorter (e.g., by observing logs/telemetry if implemented, or by timing if significant).
        6.  Test cache invalidation: modify the underlying CPG (e.g., simulate a file change updating the CPG version), then call again and ensure re-computation occurs.

### II. Specific Guidance for Test Categories

#### A. `CPGMath` Algorithm Tests

*   **Key Focus:** Mathematical correctness and robustness against diverse graph topologies.
*   **Shortest Path (`shortest_path/4`):**
    *   For negative edge weights, you *must* implement/use Bellman-Ford or SPFA. Dijkstra's won't work. Test detection of negative cycles.
*   **Centrality Measures:**
    *   **Normalization:** When testing `normalize: true`, ensure that for a graph with N nodes, degree centrality is `degree / (N-1)`. Closeness is often `(N-1) / sum_of_shortest_paths`.
    *   **Eigenvector/PageRank Convergence:** Test that they do converge and that `max_iter` acts as a stop-gap. Consider a test where convergence is *not* reached within `max_iter` to check for partial result handling (if applicable by design).
    *   **PageRank Dangling Nodes:** Implement the common strategy of redistributing their rank mass equally among all other nodes or to a specific sink. Test this behavior.
*   **Community Detection:**
    *   **Modularity Maximization (Louvain):** While hard to assert exact max modularity, provide graphs with obvious community structures and ensure the algorithm finds them. Test how the `resolution` parameter merges or splits communities.
    *   **Label Propagation Stability:** For a deterministic graph, repeated runs should yield the same community structure. Test tie-breaking if your implementation has a specific strategy.
*   **Property-Based Tests are Highly Valuable Here:**
    *   "For any graph, the shortest path between A and B is never longer than any other path between A and B."
    *   "For any graph, SCCs form a partition of the nodes (if considering unreachable nodes as single-node SCCs)."
    *   "For any graph and any node, degree centrality is always non-negative."

#### B. `CPGSemantics` Analysis Tests

*   **Key Focus:** Correct application of code-specific logic and heuristics on top of `CPGMath` results.
*   **`calculate_semantic_edge_weight/3` (Test via its effect on `semantic_critical_path`):**
    *   Design CPGs where one path is arithmetically shorter (fewer hops) but semantically "more expensive" due to node types (e.g., I/O call, complex regex node) or edge types (e.g., cross-module data flow). Verify `semantic_critical_path` picks the arithmetically longer but semantically "cheaper" path, or vice-versa if finding "most critical/risky."
*   **`semantic_critical_path/4`:**
    *   Test `path_type` filtering thoroughly. Create a CPG with overlapping call, data, and control flow edges. Ensure queries for `:execution` paths only follow CFG-derived edges, `:data_dependency` only DFG-derived, etc.
*   **`trace_data_flow_semantic/4`:**
    *   **Phi Nodes:** If your DFG (and thus CPG) represents SSA form with phi nodes, test that data flow tracing correctly identifies the merging of values at control flow joins. The CPG node for a phi function should link to its inputs.
    *   **Transformations:** Ensure the `transformations` list in the result accurately reflects the operations (function calls, assignments, operators) encountered on the CPG nodes along the data flow path.
*   **`dependency_impact_analysis/3`:**
    *   **Transitive Closure:** Test that changes propagate correctly through multiple levels up to `:depth`.
    *   **`affected_communities`:** Create a CPG with distinct communities. Make a node in one community depend on/be depended on by nodes in other communities. Verify the analysis correctly lists these *distinct* affected communities.
*   **`detect_architectural_smells/2`:**
    *   **Thresholds:** Test how varying `centrality_thresholds` or `coupling_thresholds` (as percentile or absolute values) affects smell detection. A node might be a "God Object" at 95th percentile centrality but not at 99th.
    *   **Feature Envy/Shotgun Surgery:** These are subtle. Your test CPGs need to be carefully crafted.
        *   *Feature Envy:* Module A, Function F1. F1 uses 1 variable/calls 1 function from Module A, but uses 5 variables/calls 5 functions from Module B. This should be flagged.
        *   *Shotgun Surgery:* Function G in Module Core. Change in G necessitates changes in Module X, Module Y, Module Z (which are in different communities and not otherwise closely related). The `dependency_impact_analysis` should show high `affected_communities` count for a relatively small direct `downstream_nodes` count.
*   **`analyze_module_cohesion/3`:**
    *   If implementing LCOM (Lack of Cohesion in Methods) variants, test with known LCOM examples. For CPG, this involves looking at shared variable usage (via DFG paths within the module's CPG subgraph) among function CPG nodes.
    *   Internal vs. External Edge Ratio: Test a module CPG that's highly connected internally but has few CPG edges (call, data) to outside module CPGs.

#### C. Query Enhancement Tests (`QueryBuilder`, `QueryExecutor`)

*   **Key Focus:** Correctly translating declarative queries into CPG operations, including on-demand computation and caching.
*   **`QueryBuilder.evaluate_condition_internal/2` for CPG metrics:**
    *   Test percentile operators (`:gt_percentile`, etc.): The evaluation logic needs to fetch *all* relevant scores for that metric across the CPG to determine the percentile value for the comparison.
    *   `in_community_with`: This needs to check if the current item's `community_id` matches the `community_id` of the `other_node_id` (which might involve a separate CPG lookup for the other node or assuming community IDs are globally unique and pre-calculated).
*   **`QueryExecutor` On-Demand Computation and Persistence:**
    *   Set up a scenario where a CPG metric (e.g., PageRank for functions in `ModuleX`) is *not* pre-computed in the `EnhancedRepository`.
    *   Execute a query like `FROM :functions WHERE :module_name == ModuleX AND :centrality_pagerank > 0.1`.
    *   Verify:
        1.  `CPGMath.pagerank_centrality/2` (or equivalent) *is called* (mock or use telemetry).
        2.  The correct PageRank scores are returned for `ModuleX` functions.
        3.  The computed PageRank scores (for *all* functions in `ModuleX`'s CPG, not just the one passing the filter) are persisted back to `EnhancedRepository` (e.g., by checking the `EnhancedFunctionData.cpg.unified_analysis.complexity_analysis.centrality_scores` or similar in ETS after the query).
        4.  The `CPGData.version` for `ModuleX` (or its functions' CPGs) is updated if `centrality_scores_version` is used.
*   **`QueryExecutor` with `CPGOptimizer` (Conceptual):**
    *   While the `CPGOptimizer` itself is complex, you can test its *intended effects*. For example, if a query has two filters, `A` (very selective, uses an index on CPG node properties) and `B` (less selective, requires full CPG algorithm run), the execution time should reflect that `A` is applied first. This is hard to assert directly without deep instrumentation of the executor. Timing tests might give an indication.

#### D. Pattern Matcher Enhancement Tests

*   **Key Focus:** Correctly using CPG metrics within pattern rules.
*   **CPG Rule Types:**
    *   `:cpg_node_metric`: Ensure `applies_to:` correctly targets the CPG node (e.g., the CPG node for the overall module vs. a specific function's entry CPG node). Test percentile evaluation logic.
    *   `:cpg_graph_metric`: Test patterns that assert global CPG properties (e.g., "module CPG density < 0.2").
    *   `:cpg_path_check`: Create a pattern that says "function `F` is problematic if there's a data flow path from a CPG node marked `:user_input_source` to a CPG node marked `:sql_execution_sink` within `F`'s CPG, AND this path does not traverse a CPG node marked `:sanitizer`."
*   **Combining AST and CPG Rules:** Test a pattern where a function is flagged if (AST rule: LoC > 100) AND (CPG rule: `centrality_betweenness_score` > 0.8 for its CPG node).
*   **On-Demand Metric Computation in PatternMatcher:** Similar to `QueryExecutor`, if a pattern rule needs a CPG metric not yet computed for the current CPG, the `PatternMatcher` should trigger its computation (via `CPGMath/CPGSemantics`), ensure it's cached in the `CPGData` (and persisted via `EnhancedRepository`), and then use it.

#### E. Performance Optimization Tests

*   **Incremental CPG Updates (`CPGBuilder.update_cpg/2`):**
    *   **Scenario 1 (Small function body change, no signature change):**
        1.  Generate initial CPG for `ModuleA`. Store its version and a checksum/hash.
        2.  Simulate a change to `ModuleA.func1`'s body.
        3.  Call `CPGBuilder.update_cpg/2`.
        4.  Verify: New CPG version. Only CPG nodes/edges *within* `func1`'s CPG subgraph are significantly different. Inter-procedural CPG edges to/from `func1` remain structurally similar (unless call targets changed within `func1`). Algorithmic caches in `CPGData.metadata` related to `func1` are cleared/marked stale.
    *   **Scenario 2 (Function signature change / Added function / Deleted function):**
        1.  Verify CPG structure is correctly modified (nodes/edges added/removed).
        2.  Verify inter-procedural CPG edges (call graph to/from this function) are correctly updated/removed/added.
        3.  Verify CPG version increments and caches are broadly invalidated.
*   **`CPGOptimizer` (Indirectly via Query Performance):**
    *   Craft queries where an optimized plan (e.g., using a CPG node property index before a full graph traversal) would be significantly faster. Benchmark against a (hypothetical or actual) naive execution.
*   **Memory Management (`MemoryManager`):**
    *   **String Interning:** Hard to test directly without introspection tools. Could test by serializing CPGs with many common strings created with/without interning and comparing binary sizes.
    *   **Compression:** Test that `MemoryManager.compress_old_analysis/1` (when adapted for CPGs) does indeed reduce the reported memory for CPG data of inactive modules (mock `EnhancedRepository` to simulate it holding CPGs and being asked to compress/decompress).
    *   **Lazy Loading:** If `EnhancedRepository` loads CPG summaries, test that a query needing detailed CPG node info triggers a subsequent load of those details.

#### F. AI/ML Feature Extraction Tests (`AI.Bridge`)

*   **`get_cpg_node_features_for_ai/3`:**
    *   Request a mix of direct `CPGNode` properties (e.g., `:ast_type`) and algorithmic metrics (e.g., `:centrality_pagerank`).
    *   Verify all are returned correctly.
    *   If an algorithmic metric isn't pre-cached in the CPG, ensure it's computed on-demand, cached back into the CPG (and this updated CPG is persisted), and then returned.

### III. Final Thoughts for Claude

*   **Think about State:** Many of these tests involve state changes (CPG updates, cache updates). Ensure your test setups and teardowns handle this cleanly, especially for `async: false` tests interacting with shared `EnhancedRepository` state.
*   **Clarity of Intent:** When generating a `CPGData.t()` fixture for a test, ensure its structure clearly reflects the scenario you're trying to test (e.g., for a "God Object" test, one node should have vastly more edges than others).
*   **Performance Tests as a Separate Suite:** The "benchmark" tests should likely be tagged (e.g., `@tag :benchmark`) and run separately, as they can be slow and are more about characterization than strict pass/fail in a TDD loop.

This detailed guidance, combined with your ability to parse the API/design docs and the comprehensive test list, should enable you to construct an exceptionally thorough and effective test suite. Good luck!

---