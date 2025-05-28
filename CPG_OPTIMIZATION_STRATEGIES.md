# CPG Performance and Memory Optimization Strategies

**`CPG_OPTIMIZATION_STRATEGIES.MD`**

## 1. Overview

As ElixirScope projects grow, managing the performance and memory footprint of Code Property Graphs (CPGs) becomes critical. This document outlines strategies for optimizing CPG generation, storage, querying, and incremental updates. These optimizations will be implemented across modules like `CPGBuilder`, `EnhancedRepository`, `MemoryManager`, and potentially a new `CPGOptimizer`.

## 2. Incremental CPG Updates

*   **PRD Link:** FR5.1
*   **Goal:** Avoid full CPG rebuilds for minor code changes; update only affected CPG portions.
*   **Responsibility:** `CPGBuilder`, `EnhancedRepository`, `Synchronizer`.
*   **Strategy:**
    1.  **Change Detection (`FileWatcher`, `Synchronizer`):**
        *   When a file changes, the `Synchronizer` receives the event.
        *   It determines the scope of the change (e.g., specific functions modified, module-level changes).
    2.  **Granular Re-analysis (`CPGBuilder`, `ASTAnalyzer`, Graph Generators):**
        *   Instead of re-analyzing the whole module, only re-analyze the AST of modified functions.
        *   Regenerate CFG, DFG for affected functions.
    3.  **Targeted CPG Updates (`CPGBuilder`):**
        *   Identify CPG nodes and edges corresponding to the changed code parts using AST Node IDs.
        *   **Node Updates**: Update properties of existing CPG nodes.
        *   **Edge Updates**: Add/remove/update CPG edges connected to modified nodes.
        *   **Structural Changes**: If function signatures change or functions are added/deleted, more significant CPG surgery is needed (add/remove subgraphs).
    4.  **Dependency Propagation (`CPGBuilder`, `CPGSemantics`):**
        *   After local CPG updates, identify if these changes affect inter-functional CPG edges (e.g., call graph edges, inter-procedural data flow edges).
        *   Update these connecting edges.
    5.  **Algorithmic Result Invalidation/Recomputation (`CPGMath`, `CPGSemantics`, `MemoryManager`):**
        *   Invalidate cached algorithmic results (centrality, communities, paths) that are affected by the CPG change.
        *   Trigger partial/focused recomputation of these algorithms. For instance, if a node's connectivity changes, its centrality and the centrality of its neighbors might need re-evaluation. Community structures might shift locally.
*   **Challenges:**
    *   Precisely mapping source code changes to CPG diffs.
    *   Efficiently updating inter-procedural dependencies.
    *   Minimizing recomputation of global graph algorithms.
*   **Detailed Strategy:**
    1.  **Change Identification (`Synchronizer`, `FileWatcher`):**
        *   `FileWatcher` detects a file change.
        *   `Synchronizer` receives the changed `file_path`. It invokes `ProjectPopulator.parse_and_analyze_file(file_path)` to get the new `EnhancedModuleData` (which includes new AST, function list, etc.).
        *   The `Synchronizer` then needs to signal to the `CPGBuilder` or `EnhancedRepository` that a specific module's CPG needs an update, providing the old and new `EnhancedModuleData` or just the new one and the module name.
    2.  **Delta Calculation (Conceptual - within `CPGBuilder` or a dedicated diffing utility):**
        *   Compare the old `EnhancedModuleData.ast` (or its function list) with the new one to identify added, deleted, or modified functions.
        *   For modified functions, a more granular AST diff might be performed to pinpoint exact changes.
    3.  **Targeted CPG Regeneration/Update (`CPGBuilder`):**
        *   **Deleted Functions:** Remove corresponding CPG nodes and edges related to these functions. This includes their internal CFG/DFG representations within the CPG and any inter-procedural CPG edges (calls, data flows) connected to them.
        *   **Added Functions:** Generate new CPG subgraphs for these functions and integrate them into the main CPG, adding necessary inter-procedural edges.
        *   **Modified Functions:**
            *   **Option A (Simpler):** Treat as delete + add. Remove old CPG subgraph, generate new one.
            *   **Option B (More Complex, Efficient):** Attempt to patch the existing CPG subgraph.
                *   Regenerate CFG/DFG for the modified function's AST.
                *   Diff the new CFG/DFG against the old one embedded in the CPG.
                *   Update CPG nodes/edges based on this diff. This is highly complex.
    4.  **Inter-Procedural Edge Updates (`CPGBuilder`):**
        *   After local CPG changes, re-evaluate call graph edges and inter-procedural data flow edges connected to the modified/added/deleted functions.
        *   If a function's signature changed, update all call sites.
    5.  **Algorithmic Result Invalidation (`CPGBuilder` notifying `MemoryManager` or directly updating `CPGData`):**
        *   Crucially, any change to the CPG structure necessitates invalidating cached results from `CPGMath` and `CPGSemantics` (centrality, communities, paths, etc.) that depend on the modified parts of the graph.
        *   A simple strategy is to invalidate all algorithmic results for the entire CPG containing the change.
        *   A more advanced strategy would be to identify the "blast radius" of the CPG change and only invalidate/recompute algorithmic results for the affected subgraph and its dependencies.
*   **Implementation in `EnhancedRepository` / `CPGBuilder`:**
    *   `EnhancedRepository` might expose an `update_cpg_for_module(module_name, new_module_ast_or_data)` function.
    *   `CPGBuilder` would contain the logic to perform the delta analysis and targeted updates on a `CPGData.t()` struct.
    *   The `CPGData.t()` struct should perhaps include a version or checksum to help with cache invalidation.

## 3. CPG Query Optimizer (`CPGOptimizer` - Conceptual Module)

*   **PRD Link:** FR5.2
*   **Goal:** Analyze CPG query specifications and choose an optimal execution strategy.
*   **Responsibility:** A new `CPGOptimizer` module, used by `QueryBuilder` or `QueryExecutor`.
*   **Strategy:**
    1.  **Query Analysis:**
        *   Input: `QueryBuilder.query_t()` struct.
        *   Identify target entities (nodes, edges, types of nodes/edges).
        *   Identify filter conditions and their selectivity.
        *   Identify requested graph traversals or algorithmic computations (e.g., "find path", "get centrality > X").
    1a.  **Query Parsing & Analysis (`QueryBuilder`):**
        *   `QueryBuilder` parses the query spec.
    2.  **Plan Generation (`CPGOptimizer`):**
        *   Identify CPG entities involved (nodes, edges, specific types).
        *   Determine if the query can leverage existing indexes (e.g., index on node types, AST Node IDs, pre-computed centrality scores).
        *   For queries involving graph traversals (e.g., pathfinding, impact analysis):
            *   Estimate the scope of traversal.
            *   Choose appropriate graph traversal algorithms (BFS, DFS, Dijkstra's, A*).
            *   Consider if parts of the query can be satisfied by cached algorithmic results.
        *   For queries involving multiple conditions: Reorder filter application for early pruning of the search space.
    2a.  **Plan Generation:**
        *   **Index First:** Prioritize using available ETS indexes in `EnhancedRepository` or `QueryIndexes` within `CPGData` (e.g., index on CPG node types, AST Node IDs, pre-computed high-centrality nodes).
        *   **Filter Ordering:** Apply most selective filters first to reduce the working set of nodes/edges.
        *   **Traversal Strategy:** For pathfinding or neighborhood queries, choose appropriate graph traversal algorithms (BFS for shortest path, DFS for reachability/all paths) considering graph characteristics.
        *   **Algorithm Offloading:** If a query asks for a metric like "nodes with PageRank > 0.1", check if PageRank is pre-computed and cached. If not, decide whether to compute it for the whole graph or use an approximation if the query scope is limited.
        *   **Join Optimization (if querying across CPGs or with runtime data):** Standard database join optimization techniques (e.g., hash join, sort-merge join based on estimated cardinalities).
    3.  **Cost Estimation:** Refine the cost estimation provided by `QueryBuilder` by considering the CPG's specific structure (e.g., number of nodes of a certain type, average degree) and the chosen execution plan.
*   **Example:**
    *   Query: "Find all functions (:cpg_nodes of type :function_def) with betweenness_centrality > 0.5 and that call `Ecto.Repo.all/2`."
    *   **Strategy 1 (No CPG Algo Index):** Iterate all function CPG nodes, check for `Ecto.Repo.all/2` call (fast index), then compute/lookup betweenness for matching nodes.
    *   **Strategy 2 (With CPG Algo Index):** Lookup nodes with betweenness_centrality > 0.5 (fast index if available), then filter those for type :function_def and check for `Ecto.Repo.all/2` call.
    *   `CPGOptimizer` would choose the strategy with the lower estimated cost.
    *   Query: "Find functions (CPG node type `:function_def`) in module `MyMod` that call `External.API.call/0` and have betweenness centrality > 0.5."
*   **Example 2:**
    *   `CPGOptimizer` Plan:
        1.  Fetch CPG for `MyMod`.
        2.  Filter CPG nodes for `ast_type == :function_def` (uses index on CPG node properties if available).
        3.  For remaining nodes, check outgoing `:call_graph` CPG edges for `External.API.call/0` (uses CPG edge index if available).
        4.  For nodes passing step 3, retrieve/compute betweenness centrality (check `CPGData.metadata.cached_centrality_betweenness` or call `CPGMath`).
        5.  Filter by centrality > 0.5.

## 4. Memory-Efficient CPG Representations

*   **PRD Link:** FR5.3
*   **Goal:** Reduce the in-memory and on-disk footprint of CPGs.
*   **Strategies:**
    1.  **String Interning (`EnhancedRepository`, CPG Data Structures):**
        *   Store common strings found in CPG node/edge properties (e.g., variable names, function names, literal strings from AST) in a shared string pool (e.g., an ETS table mapping strings to integer IDs).
        *   Nodes/edges store integer IDs instead of full strings.
    2.  **Selective Property Storage (`CPGData`):**
        *   Not all properties might be needed for all nodes/edges. Use sparse maps or different node/edge structs for different types to avoid storing many `nil` fields.
    3.  **Data Compression (`MemoryManager`, `EnhancedRepository`):**
        *   For CPGs of modules/functions not recently accessed, compress their serialized `CPGData` (or parts of it, like detailed AST snippets within nodes) when persisted or held in a lower-priority memory cache.
        *   `:erlang.term_to_binary(data, [:compressed])`
    4.  **Lazy Loading of CPG Components (Conceptual - `EnhancedRepository`):**
        *   When loading a `CPGData` for a module, initially load only a summary or essential graph structure.
        *   Load detailed node properties (e.g., full AST snippets, detailed DFG information within a CPG node) on demand when a query specifically requires them.
    5.  **(Future) Off-Heap/Disk Storage for Large CPGs:**
        *   For extremely large projects, investigate storing parts of the CPG (e.g., less frequently accessed nodes/edges, or large property values) off the BEAM heap or on disk, managed by a system like RocksDB or a custom ETS-backed paging mechanism.
*   **Strategies & Responsibility:**
    1.  **String Interning (`CPGBuilder`, `EnhancedRepository`):**
        *   When `CPGBuilder` creates `CPGNode.t()` and `CPGEdge.t()`, common strings (function names, variable names, literal values from AST, node/edge types/subtypes) should be interned.
        *   `EnhancedRepository` can maintain a global (per-repository instance) or per-CPG intern pool (e.g., an ETS table mapping strings to integer IDs, or using Elixir atoms if the set is bounded and known).
        *   CPG nodes/edges store these integer IDs.
        *   Functions retrieving CPG data for display/analysis would de-intern these IDs.
    2.  **Selective Property Storage (`CPGNode.t()`, `CPGEdge.t()` design):**
        *   The `CPGNode.t()` and `CPGEdge.t()` structs might have many optional fields (`control_flow_info`, `data_flow_info`, `unified_properties`). Use maps for these fields so only present data consumes memory, rather than fixed struct fields that might often be `nil`.
        *   Alternatively, use different specialized structs for different conceptual CPG node/edge types if properties vary significantly (though this increases type complexity).
    3.  **Data Compression (`MemoryManager`, `EnhancedRepository`):**
        *   `MemoryManager`, during its `compress_old_analysis` cycle or when handling memory pressure, can identify CPGs (or parts of CPGs like large AST snippets within nodes) for modules that are infrequently accessed.
        *   It can then request `EnhancedRepository` to serialize these `CPGData.t()` objects (or their large sub-components) using `:erlang.term_to_binary(data, [:compressed])`.
        *   `EnhancedRepository` would store the compressed binary and mark the in-memory version as eligible for GC or replace it with a "lazy-load" stub.
        *   When accessed again, `EnhancedRepository` decompresses the data.
    4.  **Lazy Loading of CPG Components (`EnhancedRepository`, `CPGBuilder`):**
        *   When `EnhancedRepository.get_enhanced_module/1` loads a module, its `CPGData.t()` might initially be a "summary" CPG.
        *   Detailed information within CPG nodes (e.g., full DFG structure for a function node, detailed AST snippets) or expensive-to-load parts of the CPG (e.g., full inter-procedural data flow edges) are loaded on demand by `CPGBuilder` or specialized functions when a query explicitly needs them.
        *   This requires `CPGData.t()` to support partial loading and `CPGBuilder` to have functions like `CPGBuilder.load_detailed_node_info(cpg_summary, node_id)`.

*   `EnhancedRepository.get_performance_metrics/0` can expose aggregated CPG operation timings.

## 5. Algorithmic Result Caching

*   **PRD Link:** FR5.4
*   **Goal:** Cache results of computationally expensive graph algorithms to speed up subsequent queries.
*   **Strategy:**
    1.  **Cache Location:**
        *   **Within `CPGData.t()`**: Add fields like `metadata: %{cached_centrality_pagerank: %{...}, cached_communities_louvain: %{...}}`. This ties cached results directly to a specific CPG version.
        *   **`MemoryManager` Caches**: Use dedicated ETS tables managed by `MemoryManager` (e.g., `@cpg_analysis_cache_table`) to store results keyed by `{cpg_checksum, algorithm_name, params}`.
    2.  **Cache Key Generation:**
        *   Include CPG identifier (e.g., module name + file hash to represent CPG version).
        *   Include algorithm name and its specific parameters (e.g., `{:pagerank, alpha: 0.85}`).
    3.  **Invalidation:**
        *   **CPG Structural Change**: If the CPG structure for a module/function is updated (due to code changes), all cached algorithmic results for that CPG must be invalidated. The `Synchronizer` or `CPGBuilder` would signal this.
        *   **TTL**: Standard Time-To-Live policies managed by `MemoryManager`.
        *   **LRU/LFU Eviction**: When cache limits are reached, evict less relevant results.
    4.  **Granularity of Caching**:
        *   Cache entire result sets (e.g., all centrality scores for a CPG).
        *   Cache results for specific queries (e.g., "top 10 nodes by betweenness centrality").
*   **Example Workflow (Centrality):**
    1.  Query requests "nodes with PageRank > 0.01".
    2.  `QueryExecutor` checks `MemoryManager` cache for `{:pagerank, cpg_id, %{threshold: 0.01}}`. Miss.
    3.  `QueryExecutor` checks if `cpg.metadata.cached_centrality_pagerank` exists. Miss.
    4.  `CPGSemantics` (via `CPGMath`) computes all PageRank scores for `cpg`.
    5.  Result stored in `cpg.metadata.cached_centrality_pagerank` and potentially in `MemoryManager`'s cache.
    6.  Query is satisfied from the freshly computed (and now cached) scores.
*   **Strategy & Responsibility:**
    1.  **Cache Storage (`CPGData.metadata`, `MemoryManager`):**
        *   **Lightweight results/Per-CPG results:** Store directly in `CPGData.t().metadata` (e.g., `%{cached_centrality_pagerank: %{"nodeA" => 0.1, ...}}`). When `CPGData` is serialized/compressed, these caches go with it.
        *   **Heavier results/Cross-CPG results/Query-specific results:** Use `MemoryManager`'s ETS-based caches (e.g., `@cpg_cache_table`, `@analysis_cache_table`). The key could be `{cpg_version_checksum, :algorithm_name, algorithm_params_hash}`.
    2.  **Cache Population (`CPGMath`, `CPGSemantics`, `QueryExecutor`):**
        *   After a `CPGMath` or `CPGSemantics` function computes an expensive result (e.g., `community_louvain`), it (or the calling `QueryExecutor`) should offer it to the appropriate cache.
    3.  **Cache Lookup (`CPGMath`, `CPGSemantics`, `QueryExecutor`):**
        *   Before computation, these functions first check the relevant cache.
    4.  **Invalidation (`CPGBuilder`, `Synchronizer`, `MemoryManager`):**
        *   **Structural CPG Changes:** When `CPGBuilder` (triggered by `Synchronizer`) performs an incremental update on a `CPGData.t()`, it must invalidate relevant cached algorithmic results. This could be by:
            *   Deleting specific keys from `CPGData.t().metadata`.
            *   Updating a version/checksum on `CPGData.t()`, which automatically invalidates `MemoryManager` cache entries keyed with the old version/checksum.
            *   Notifying `MemoryManager` to evict entries related to the modified CPG.
        *   **TTL/LRU**: `MemoryManager` handles standard TTL and LRU eviction for its caches.

## 6. Performance Monitoring for CPG Operations

*   **Responsibility:** `EnhancedRepository`, `CPGBuilder`, `CPGMath`, `CPGSemantics`.
*   **Strategy:**
    *   Use `ElixirScope.Utils.measure/1` to wrap key operations:
        *   `CPGBuilder.build_cpg/2` (overall time).
        *   `CPGBuilder` incremental update steps.
        *   Individual algorithm executions in `CPGMath` and `CPGSemantics` (e.g., `strongly_connected_components`, `dependency_impact_analysis`).
        *   CPG query execution phases in `QueryExecutor`.
    *   Report these metrics to a central collector, possibly `EnhancedRepository`'s stats or `MemoryManager`.
*   The `EnhancedRepository` and `CPGBuilder` should use `ElixirScope.Utils.measure/1` to track durations of key CPG operations:
    *   CPG generation time (full and incremental).
    *   Specific graph algorithm execution times (e.g., centrality calculation).
    *   CPG query execution time.
*   These metrics can be reported to `MemoryManager` or a dedicated performance tracking system to identify bottlenecks in the CPG layer itself.

---
