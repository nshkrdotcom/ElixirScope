# ElixirScope AST Repository: Performance & Scalability Guide

This document outlines the performance considerations, optimization strategies, and scalability plans for the ElixirScope AST Repository. The goal is to ensure the repository can handle large Elixir projects efficiently, providing fast analysis and query responses.

## 1. Performance Goals

The AST Repository aims to achieve the following performance targets:

*   **Initial Project Population:**
    *   Small projects (<50 modules): < 10 seconds
    *   Medium projects (50-200 modules): < 60 seconds
    *   Large projects (200-1000 modules): < 5 minutes
*   **Incremental Synchronization (single file change):** < 2 seconds (including re-analysis and CPG update for the changed module).
*   **Query Performance (Static Data):**
    *   Simple metadata queries (e.g., get function by MFA): < 1ms
    *   Complex pattern queries on CPG (single function): < 50ms
    *   Project-wide queries (e.g., find all callers of an MFA): < 500ms for medium projects.
*   **Memory Usage:**
    *   Overhead per module (excluding full AST/CPG storage if optimized): < 500KB
    *   Total repository memory for medium projects: < 500MB (configurable limit).
*   **Runtime Bridge Interaction:** Minimal impact, ideally < 100µs for any synchronous operations (though most should be async).

## 2. Core Architecture and Performance Implications

The AST Repository relies heavily on ETS for in-memory storage and indexing. This provides excellent read performance but has implications for write contention (mitigated by `:write_concurrency`) and overall memory usage.

*   **ETS Tables:**
    *   `Repository` uses multiple ETS tables for modules, functions, CPGs, and various indexes.
    *   `:read_concurrency` and `:write_concurrency` are enabled to improve parallel access.
    *   `ordered_set` is used for tables requiring range queries or sorted iteration (e.g., temporal indexes if events were stored here, though primary event storage is separate). `set` or `bag` are used otherwise.
*   **Data Structures:**
    *   `EnhancedModuleData`, `EnhancedFunctionData`, and `CPGData` can become large. Strategies for selective loading or summarization are important.
*   **Analysis Pipeline:**
    *   `ASTAnalyzer` -> `CFGGenerator` -> `DFGGenerator` -> `CPGBuilder`. Each step adds processing time. Parallelization per module/function during `ProjectPopulator` is key.

## 3. Optimization Strategies

### 3.1. ETS Optimizations

*   **Selective Indexing:** Only create indexes that are actively used by common query patterns. Over-indexing can slow down writes.
    *   Current indexes: module by file, function by AST node ID (def), calls by target, functions by complexity bucket.
*   **Match Specifications (`:ets.select`, `:ets.match_object`):** Utilize these for efficient data retrieval instead of full table scans (`:ets.tab2list` or `:ets.foldl/3` on large tables without good filtering).
*   **Table Types:** Choose appropriate table types (`:set`, `:ordered_set`, `:bag`, `:duplicate_bag`) based on key uniqueness and access patterns.
*   **Concurrency:** Leverage `:write_concurrency` and `:read_concurrency`. For write-heavy operations, consider sharding or distributing writes across multiple tables/processes if contention becomes an issue.
*   **Data Size Management:**
    *   Store large ASTs or CPG components (e.g., detailed graph structures) in separate tables or even offload to disk/binary terms if memory pressure is high, keeping essential metadata and summaries in primary tables. The `ASTCompressor` concept from the original design ideas (2.md) could be relevant here.
    *   Consider `:compressed` option for ETS tables storing large terms, at the cost of some CPU for compression/decompression.

### 3.2. Analysis Pipeline Optimization

*   **Parallel Processing (`ProjectPopulator`):**
    *   Use `Task.async_stream` to parse and analyze files/modules in parallel, up to `System.schedulers_online()` or a configurable limit.
*   **Incremental Analysis (`Synchronizer`):**
    *   Only re-analyze changed files.
    *   For structural changes within a file (e.g., function signature change), identify and re-analyze only dependent modules/functions if inter-procedural analysis is deep. (This is an advanced optimization).
*   **Lazy Computation:**
    *   Generate CFGs, DFGs, and CPGs on demand when a function/module is first queried for such data, rather than all upfront during initial population. Cache the results. This is especially useful for large projects where not all CPGs might be needed immediately. The `CPGBuilder` would be invoked by the `Repository` on a cache miss.
    *   The `LazyComputation` module design from `2.md` could be adapted.
*   **AST Traversal Efficiency:**
    *   Use efficient AST traversal techniques (e.g., `Macro.prewalk/3` or optimized custom walkers) in `ASTAnalyzer`, `NodeIdentifier`, and generators. Avoid redundant traversals.

### 3.3. Query Optimizations (`QueryExecutor` & `Repository`)

*   **Query Planning:** The `QueryExecutor` should analyze query specifications from `QueryBuilder` to choose the most efficient execution plan (e.g., which index to use first, order of filter application).
*   **Index-First Queries:** Prioritize queries that can leverage ETS indexes over full scans.
*   **Result Caching:** Cache results of common or expensive queries. `ASTRepository.Config` defines TTLs. Cache invalidation must be handled correctly by the `Synchronizer` upon code changes.
*   **Limiting and Pagination:** Always encourage or enforce limits on queries that can return large result sets. Implement pagination for APIs that might return many items.
*   **Projection:** Only fetch the data fields required by the query (`select` clause in `QueryBuilder`) rather than entire large structs, if underlying ETS storage allows (e.g., if data is denormalized or specific fields are indexed).

### 3.4. Memory Management

*   **Configurable Limits (`ASTRepository.Config`):**
    *   `repository_max_memory_mb`: Overall ETS memory limit. The `Repository` could monitor its table sizes periodically and trigger cleanup or stop accepting new data.
    *   `max_ast_nodes_for_full_cpg`: For very large functions, CPG generation might be skipped or a summary CPG created to save memory.
*   **Data Truncation:** For display or storage of very large AST snippets or variable values (as seen in `ElixirScope.Utils.truncate_data/2`), apply truncation.
*   **Garbage Collection Awareness:** While ETS is off-heap for data, Elixir processes managing it still use heap memory. Ensure GenServer states are lean and long-running computations yield or are broken into smaller pieces to allow BEAM GC to run effectively.
*   **Selective Persistence:** (Future) For very large datasets, implement strategies to offload less frequently accessed data (e.g., old CPGs, detailed ASTs for unchanged files) to disk (e.g., DETS, custom file storage) while keeping hot data and indexes in ETS.

## 4. Scalability Considerations

### 4.1. Handling Large Codebases

*   **Initial Population Time:** For projects with thousands of modules, initial population can be lengthy. `ProjectPopulator` uses parallel workers. Further improvements:
    *   A persistent "last analyzed" state for files, so re-population only processes new/changed files since the last run.
    *   Distributing the population task across multiple BEAM nodes if the project is accessible to them (advanced).
*   **Memory Footprint:**
    *   The primary concern. The strategies in "Memory Management" (selective CPGs, data truncation, offloading) are key.
    *   Consider storing only "fingerprints" or structural summaries of ASTs/CPGs for most modules, and fully analyzing/storing details only for "interesting" modules (e.g., complex ones, frequently changed ones, or those specified by the user).
*   **Index Size:** Indexes on text fields or complex keys can grow large. Use integer-based bucketed indexes where possible (e.g., complexity scores).

### 4.2. Concurrent Access

*   **`ASTRepository.Repository` GenServer:** As a single GenServer, it can become a bottleneck for writes if many `Synchronizer` tasks or `ProjectPopulator` workers try to store data simultaneously.
    *   **Mitigation 1:** Batch writes. `store_module` already implies storing multiple functions. `ProjectPopulator` can batch `EnhancedModuleData` structs to the `Repository`.
    *   **Mitigation 2:** Asynchronous writes. `store_module` could become a `cast` if immediate confirmation isn't strictly needed, with a separate queue/pool for ETS writes. This adds complexity.
    *   **Mitigation 3 (Advanced):** Shard the repository. For example, modules starting with A-M go to `Repository.A_M`, N-Z to `Repository.N_Z`. The main `Repository` API would act as a router. This is a significant architectural change.
*   **ETS Concurrency:** `:read_concurrency` and `:write_concurrency` help, but heavy writes to the same table can still lead to contention.

### 4.3. Distributed ElixirScope (Future)

If ElixirScope itself is to run in a distributed environment with multiple instances analyzing parts of a system or different systems:

*   **Federated AST Repository:** Each ElixirScope node would have its local AST Repository. A coordination layer (like `NodeCoordinator`) would be needed to route cross-node queries or synchronize essential CPG data (e.g., public APIs of modules for inter-service call graph analysis).
*   **Distributed CPGs:** Analyzing interactions between services would require a way to link CPGs from different nodes.
*   **Global Node IDs:** The `NodeIdentifier` scheme would need to be globally unique across the cluster.

## 5. Benchmarking and Profiling Plan

Continuous performance monitoring is essential.

1.  **Micro-benchmarks (`Benchee`):**
    *   ETS operations (insert, lookup, select, match) with realistic data sizes.
    *   Key functions in `ASTAnalyzer`, `CFG/DFG/CPG Generators` for typical AST inputs.
    *   `NodeIdentifier` ID generation speed.
    *   `QueryExecutor` filter application, sorting.
2.  **Macro-benchmarks (Simulated Project Population):**
    *   Use `TestDataGenerator` to create projects of varying sizes (Small, Medium, Large).
    *   Measure total time and memory usage for `ProjectPopulator.populate_project`.
    *   Measure time and memory for `Synchronizer.sync_changes_batch` with a percentage of files changed.
3.  **Query Benchmarks:**
    *   Execute a suite of predefined queries (from `USAGE_COOKBOOK_AST.md`) against populated repositories of different sizes.
    *   Measure query latency (p50, p95, p99).
4.  **Profiling Tools:**
    *   Use `:eprof`, `eflamé`, or BEAM observer for identifying CPU bottlenecks.
    *   Monitor ETS table memory usage (`:ets.info(table, :memory)`).
    *   Track GenServer message queue lengths for `Repository` and `FileWatcher`.
5.  **CI Integration:** Run a subset of performance tests in CI to catch regressions early.

By implementing these optimization strategies and continuously monitoring performance, the ElixirScope AST Repository can provide powerful static analysis capabilities efficiently and scale to meet the demands of complex Elixir projects.