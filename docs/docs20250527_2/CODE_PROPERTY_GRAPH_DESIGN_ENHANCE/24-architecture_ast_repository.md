# ElixirScope AST Repository: System Architecture

## 1. Overview

The ElixirScope AST Repository is a sophisticated backend system designed to provide deep static analysis capabilities for Elixir code. It goes beyond simple AST storage by generating and interlinking Control Flow Graphs (CFGs), Data Flow Graphs (DFGs) using Static Single Assignment (SSA), and ultimately, Code Property Graphs (CPGs). This rich, multi-faceted representation of code enables advanced querying, pattern detection, and serves as a foundational layer for AI-powered code intelligence and revolutionary debugging experiences.

The architecture prioritizes:
-   **Semantic Richness:** Understanding Elixir-specific constructs.
-   **Performance:** Efficient storage and querying for large codebases.
-   **Extensibility:** Allowing for new analyses and integrations.
-   **Correlation:** Linking static analysis data with runtime events.

## 2. Core Components and Their Roles

The AST Repository comprises several key modules, each with a distinct responsibility:

```mermaid
graph TD
    subgraph "Input & Population"
        SRC[Source Code *.ex, *.exs] --> PP[ProjectPopulator]
        FW[FileWatcher] --> SYNC[Synchronizer]
        PP --> ANA[ASTAnalyzer]
        SYNC --> ANA
    end

    subgraph "AST Processing & Generation"
        ANA --> NI[NodeIdentifier]
        ANA --> CFG_GEN[CFGGenerator]
        ANA --> DFG_GEN[DFGGenerator]
        NI --> AST_WITH_IDS[AST with Node IDs]
        AST_WITH_IDS --> CFG_GEN
        AST_WITH_IDS --> DFG_GEN
        CFG_GEN --> CFG_DATA[CFGData]
        DFG_GEN --> DFG_DATA[DFGData]
        DFG_DATA --> CPG_BUILD[CPGBuilder]
        CFG_DATA --> CPG_BUILD
        AST_WITH_IDS --> CPG_BUILD # Or EnrichedFunctionData containing these
        CPG_BUILD --> CPG_DATA[CPGData]
    end

    subgraph "Storage & Management"
        REPO[ASTRepository.Repository (GenServer)]
        CONF[ASTRepository.Config] --> REPO
        CONF --> PP
        CONF --> FW
        ANA --> STORE_MOD[EnhancedModuleData]
        STORE_MOD --> REPO
        CPG_DATA -- Stores --> REPO
    end

    subgraph "Querying & Access"
        QB[QueryBuilder] --> QS[QuerySpec]
        QS --> QX[QueryExecutor]
        QX --> REPO
        REPO --> RESULTS[Query Results]
        RESULTS --> API_EXT[ASTExtensions for Main QueryEngine]
    end

    subgraph "Integration & Usage"
        API_EXT --> AI_B[AI.Bridge]
        API_EXT --> TEMP_B[TemporalBridge.ASTIntegration]
        API_EXT --> RUNTIME_B[RuntimeBridge]
        RUNTIME_B_CT[RuntimeBridge.CompileTimeHelpers] --> INSTR_MAP[InstrumentationMapper]
        TEST_GEN[TestDataGenerator] -- For Testing --> ANA
        TEST_GEN -- For Testing --> PP
    end

    style SRC fill:#ccc,stroke:#333
    style REPO fill:#87CEEB,stroke:#333,stroke-width:2px
    style CPG_DATA fill:#FFD700,stroke:#333,stroke-width:2px
```

*   **Configuration (`ASTRepository.Config`):**
    *   Provides centralized access to all configuration settings for the AST repository components, with sensible defaults. Governs behavior of populator, watcher, analyzers, and storage.

*   **Input & Population:**
    *   **`ProjectPopulator`:** Responsible for the initial, full scan of an Elixir project. It discovers source files, orchestrates parsing and analysis via `ASTAnalyzer`, and stores the resulting `EnhancedModuleData` (including function details, CFGs, DFGs) into the `Repository`.
    *   **`FileWatcher`:** Monitors the project's file system for changes (create, modify, delete) to Elixir source files. It debounces events and notifies the `Synchronizer`.
    *   **`Synchronizer`:** Receives file change events from the `FileWatcher`. It handles incremental updates to the `Repository` by re-analyzing changed files or removing data for deleted files, ensuring the repository stays consistent with the codebase.

*   **AST Processing & Generation:**
    *   **`NodeIdentifier`:** Generates unique, stable, and parseable string IDs for every significant node in an AST. These IDs are crucial for linking static constructs to runtime events and for creating consistent references within CFGs, DFGs, and CPGs. It injects an `:ast_node_id` into the metadata of AST nodes.
    *   **`ASTAnalyzer`:** Takes raw Elixir AST (typically for a module or function, now augmented with node IDs) and performs a detailed static analysis. It extracts metadata such as function signatures, variable scopes (initial pass), calls, dependencies, module attributes, and basic complexity metrics. It populates `EnhancedModuleData` and `EnhancedFunctionData` structures.
    *   **`CFGGenerator`:** Takes a function's AST (with node IDs) and generates its Control Flow Graph (`CFGData`), representing all possible execution paths, decision points, and basic blocks. It calculates CFG-specific complexity metrics.
    *   **`DFGGenerator`:** Takes a function's AST (with node IDs) and generates its Data Flow Graph (`DFGData`) using Static Single Assignment (SSA) form. It tracks variable definitions, uses, rebindings, and identifies data dependencies and phi nodes for merging variable versions at control flow joins.
    *   **`CPGBuilder`:** The capstone generator. It takes `EnhancedFunctionData` (which now includes its associated `CFGData` and `DFGData`) and unifies them into a `CPGData` structure. CPG nodes primarily correspond to AST nodes but are enriched with CFG and DFG semantics. Edges in the CPG represent AST parent-child relationships, control flow, data flow, and call dependencies.

*   **Storage & Management (`ASTRepository.Repository`):**
    *   A GenServer acting as the central in-memory database for all static analysis artifacts.
    *   Utilizes ETS tables for efficient storage and indexed retrieval of `EnhancedModuleData`, `EnhancedFunctionData`, individual AST nodes (if stored separately), `CPGData`, and various indexes (e.g., module by file path, function by complexity).
    *   Provides a public API for storing, retrieving, deleting, and querying these artifacts.
    *   Manages memory and concurrency.

*   **Querying & Access:**
    *   **`QueryBuilder`:** Provides a fluent API or helper functions to construct declarative query specifications (`ast_repo_query_spec`) for interrogating the data stored in the `Repository`.
    *   **`QueryExecutor`:** Takes a query specification from the `QueryBuilder` and executes it against the `Repository`. It handles data fetching, filtering, sorting, and limiting, primarily by translating query parts into efficient ETS lookups or selections.
    *   **`QueryEngine.ASTExtensions`:** Integrates the AST repository's querying capabilities into ElixirScope's main query engine, allowing for correlated queries that combine static analysis results with runtime event data.

*   **Integration & Usage:**
    *   **`RuntimeBridge`:** Provides utilities for compile-time instrumentation (`CompileTimeHelpers` used by `InstrumentationMapper` to get/use AST Node IDs) and minimal, fast lookups or asynchronous notifications from the runtime environment to the AST repository.
    *   **`TemporalBridge.ASTIntegration`:** Enhances the existing `TemporalBridge` to use AST/CPG context (fetched from the `Repository` via `ast_node_id`s in runtime events) to provide richer information during time-travel debugging and state reconstruction.
    *   **`AI.Bridge`:** Defines how various AI components (Pattern Recognizers, Predictive Analyzers, Embedding Generators, LLM Interfaces) access and utilize the CPGs and other static analysis data from the `Repository` for their tasks.
    *   **`TestDataGenerator`:** Utilities to create mock ASTs and project structures for robust testing of all repository components.

## 3. Data Flow

### 3.1. Initial Population Flow

1.  `ProjectPopulator` is invoked with a project path.
2.  It discovers all relevant Elixir source files using configured patterns and ignores.
3.  For each file:
    a.  Reads and parses the content into a raw Elixir AST.
    b.  Determines the module name.
    c.  Invokes `ASTAnalyzer.analyze_module_ast` with the raw AST.
        i.  `ASTAnalyzer` calls `NodeIdentifier.assign_ids_to_ast` (or a custom traversal) to inject `:ast_node_id` into the module's AST.
        ii. `ASTAnalyzer` traverses the ID-enriched module AST to extract `EnhancedModuleData`, including stubs or full ASTs for each function.
        iii.For each function AST within the module:
            1.  `ASTAnalyzer` performs initial function-level analysis.
            2.  `CFGGenerator.generate_cfg` is called with the function's AST (with IDs) to produce `CFGData`.
            3.  `DFGGenerator.generate_dfg` is called with the function's AST (with IDs) and its function key to produce `DFGData` (SSA-based).
            4.  The resulting `EnhancedFunctionData` is populated with this CFG and DFG data.
            5.  `CPGBuilder.build_cpg` is called with the complete `EnhancedFunctionData` to produce `CPGData`.
    d.  The fully populated `EnhancedModuleData` (containing analyzed functions with their CPGs, or references to them) is passed to `ASTRepository.Repository.store_module`.
4.  `Repository` stores the `EnhancedModuleData`, individual `EnhancedFunctionData`, and `CPGData` in their respective ETS tables, updating all relevant indexes.

### 3.2. Incremental Update Flow (File Change)

1.  `FileWatcher` detects a change (create, modify, delete) to an Elixir file.
2.  After debouncing, it sends a `FileChangeEvent` to `Synchronizer.sync_changes_batch`.
3.  `Synchronizer` processes each event:
    *   **Create/Modify:**
        a.  Reads and parses the file.
        b.  Determines module name. If the module name changed in a modified file, the old module entry is marked for deletion/update.
        c.  Invokes `ASTAnalyzer.analyze_module_ast` (which follows the same internal flow as in initial population: ID assignment, function analysis, CFG/DFG/CPG generation).
        d.  The new/updated `EnhancedModuleData` (with CPGs) is stored in the `Repository`. The `store_module` operation in the `Repository` should handle overwriting existing data and updating indexes.
        e.  (Future) `Synchronizer` may trigger analysis of dependent modules if inter-module dependencies changed significantly.
    *   **Delete:**
        a.  `Synchronizer` determines the module name associated with the deleted file path (via `Repository.get_module_by_filepath`).
        b.  Calls `Repository.delete_module` to remove the module, its functions, CPGs, and associated index entries.
        c.  (Future) Triggers updates for modules that depended on the deleted module.

### 3.3. Query Flow (Example: Find complex functions and their runtime error rate)

1.  User or AI component uses `QueryBuilder` to construct a correlated query:
    *   Static part: `find_functions() |> by_complexity(:cyclomatic, :gt, 10)`
    *   Runtime part: `template for errors in last 24h`
    *   Join on: `function_key`
2.  The main `ElixirScope.Query.Engine` receives this correlated query spec.
3.  It first dispatches the static part to `ASTRepository.QueryExecutor` (or via `ASTExtensions`).
    a.  `QueryExecutor` parses the static query spec.
    b.  Calls `ASTRepository.Repository.query_functions` with filters for complexity.
    c.  `Repository` uses its ETS tables and indexes (e.g., `@complexity_index`) to efficiently find matching `EnhancedFunctionData`.
    d.  `QueryExecutor` returns the list of complex functions (specifically their `function_key`s if projected).
4.  Main `Query.Engine` takes the resulting `function_key`s.
5.  For each `function_key` (or in a batch), it queries `TemporalStorage` (via `TemporalBridge`) for runtime error events associated with that `function_key` within the specified time range.
6.  The main `Query.Engine` joins the static function data with the runtime error counts/summaries.
7.  The final correlated result is returned.

## 4. Key Design Principles & Decisions

*   **Centralized Repository (`ASTRepository.Repository`):** A single GenServer manages all static analysis data, ensuring controlled access and consistency. ETS is used for high-speed in-memory access.
*   **Layered Analysis:** Raw AST -> ID-Enriched AST -> `EnhancedModule/FunctionData` (basic analysis) -> CFG/DFG -> CPG. Each layer builds upon the previous.
*   **Stable AST Node IDs (`NodeIdentifier`):** Crucial for linking static analysis to dynamic runtime events and for maintaining consistency during incremental updates. The chosen strategy (e.g., path-based with contextual hashing) aims for a balance of stability and uniqueness.
*   **SSA for DFG (`DFGGenerator`):** Chosen to correctly model Elixir's immutability and variable rebinding semantics, enabling precise data flow tracking.
*   **Unified CPG (`CPGBuilder`):** The ultimate goal is to represent code in a CPG, allowing powerful graph-based queries that span syntax, control flow, and data flow. CPG nodes are primarily AST-derived but augmented.
*   **Incremental Synchronization (`FileWatcher`, `Synchronizer`):** Designed to keep the repository up-to-date with code changes without requiring a full re-analysis of the entire project for every small change.
*   **Decoupled Querying (`QueryBuilder`, `QueryExecutor`):** Separates query construction from execution, allowing for different execution backends in the future (e.g., direct ETS, or a graph database query language for CPGs).
*   **Configuration Driven (`ASTRepository.Config`):** Behavior of components is managed via a centralized configuration system, allowing users to tune performance and features.
*   **Integration via Bridges:** Dedicated bridge modules (`RuntimeBridge`, `TemporalBridge.ASTIntegration`, `AI.Bridge`) define clear interfaces for how other parts of ElixirScope interact with the AST Repository.

## 5. Future Considerations & Scalability

*   **Graph Database Integration:** While ETS is used initially, the CPG data is well-suited for a dedicated graph database (Neo4j, ArangoDB). The `Repository` API can be adapted to use such a backend for CPG storage and querying, potentially keeping hot/summary data in ETS.
*   **Inter-Procedural Analysis:** True inter-procedural DFG and CFG (across function calls, especially dynamic ones) is complex. The current design focuses on intra-procedural analysis, with call graphs providing the links. Full inter-procedural CPGs are a future extension.
*   **Metaprogramming and Macros:** Handling code generated by macros requires either analyzing pre-expansion AST and post-expansion AST and linking them, or analyzing the fully expanded AST. The current design primarily focuses on the AST available after standard macro expansion.
*   **Performance at Scale:** For extremely large projects (millions of LOC), strategies like on-demand CPG generation, partial loading, or even distributed analysis might be necessary. The current design assumes a single-node repository.
*   **Error Resilience:** Robust error handling in `ProjectPopulator` and `Synchronizer` to ensure that errors in one file/module do not halt the analysis of others. Storing partial analysis results.

This architecture provides a solid and extensible foundation for ElixirScope's advanced static analysis capabilities, enabling the envisioned "revolutionary debugging experience."
