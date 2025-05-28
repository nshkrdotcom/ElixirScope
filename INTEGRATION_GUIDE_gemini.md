# ElixirScope Enhanced AST Repository Integration Guide

This guide explains how to integrate the Enhanced AST Repository (including CFG, DFG, and CPG capabilities) with other ElixirScope components and leverage its advanced features for debugging and analysis.

## Table of Contents

1.  [Overview of Integration Architecture](#1-overview-of-integration-architecture)
2.  [Compile-Time Integration](#2-compile-time-integration)
    *   [AST Parsing and Node ID Assignment](#21-ast-parsing-and-node-id-assignment)
    *   [CFG, DFG, CPG Generation](#22-cfg-dfg-cpg-generation)
    *   [Instrumentation Mapping and Transformation](#23-instrumentation-mapping-and-transformation)
    *   [Project Population and Synchronization](#24-project-population-and-synchronization)
3.  [Runtime Integration](#3-runtime-integration)
    *   [Event Capture with AST Node IDs](#31-event-capture-with-ast-node-ids)
    *   [Runtime Correlation with `RuntimeCorrelator`](#32-runtime-correlation-with-runtimecorrelator)
    *   [Storing AST-Enhanced Events](#33-storing-ast-enhanced-events)
4.  [Query-Time and Analysis Integration](#4-query-time-and-analysis-integration)
    *   [Querying Static Data (`EnhancedRepository`, `QueryBuilder`, `QueryExecutor`)](#41-querying-static-data-enhancedrepository-querybuilder-queryexecutor)
    *   [Correlated Queries (`QueryEngine.ASTExtensions`)](#42-correlated-queries-queryengineastextensions)
    *   [Temporal Bridge Enhancement for Time-Travel Debugging](#43-temporal-bridge-enhancement-for-time-travel-debugging)
5.  [AI Components Integration](#5-ai-components-integration)
    *   [Using `AI.Bridge` for Context](#51-using-aibridge-for-context)
    *   [Code Analysis and Pattern Recognition](#52-code-analysis-and-pattern-recognition)
    *   [Predictive Analysis](#53-predictive-analysis)
    *   [LLM Interaction](#54-llm-interaction)
6.  [Advanced Debugging Features](#6-advanced-debugging-features)
    *   [Structural Breakpoints](#61-structural-breakpoints)
    *   [Data Flow Breakpoints](#62-data-flow-breakpoints)
    *   [Semantic Watchpoints](#63-semantic-watchpoints)
7.  [Best Practices for Integration](#7-best-practices-for-integration)
8.  [Troubleshooting Common Issues](#8-troubleshooting-common-issues)

---

## 1. Overview of Integration Architecture

The Enhanced AST Repository is central to ElixirScope's advanced analysis and debugging capabilities. It provides a rich, static representation of code (AST, CFG, DFG, CPG) that is correlated with dynamic runtime information.

**Key Integration Principles:**

*   **AST Node ID**: A unique, stable identifier (`module:function:path_hash`) assigned to AST nodes. This ID is the primary key for linking static analysis data with runtime events.
*   **Compile-Time Analysis**: During compilation (or a pre-processing step), code is parsed, AST Node IDs are assigned, CFG/DFG/CPGs are generated, and this information is stored in the `EnhancedRepository`.
*   **Instrumentation**: The `EnhancedTransformer` injects calls to `InstrumentationRuntime`, embedding `ast_node_id`s into these calls.
*   **Runtime Correlation**: `InstrumentationRuntime` captures events tagged with `ast_node_id`s. The `RuntimeCorrelator` (and `TemporalBridgeEnhancement`) uses these IDs to link runtime behavior back to the static code structures in the `EnhancedRepository`.
*   **Querying**: The `QueryEngine` (via `ASTExtensions`) can perform correlated queries, joining static properties from the `EnhancedRepository` with runtime event data from `EventStore` or `TemporalStorage`.
*   **AI Leverage**: AI components use the CPG and correlated data from the repository to provide deeper insights, plan instrumentation, and make predictions.

## 2. Compile-Time Integration

### 2.1. AST Parsing and Node ID Assignment

1.  **Source Parsing**: Elixir source files (`.ex`, `.exs`) are read.
2.  **AST Generation**: `Code.string_to_quoted/2` generates the initial Elixir AST.
3.  **Node ID Assignment**:
    *   The `ElixirScope.ASTRepository.Parser` (specifically its `assign_node_ids/1` function or logic integrated within `ASTAnalyzer`/`ProjectPopulator`) traverses the AST.
    *   It uses `ElixirScope.ASTRepository.NodeIdentifier.generate_id_for_current_node/2` to create and assign unique `ast_node_id`s to relevant AST nodes. These IDs are stored in the node's metadata (e.g., `Keyword.put(meta, :ast_node_id, new_id)`).
    *   The `NodeIdentifier` aims for stability of these IDs across non-structural code changes.

### 2.2. CFG, DFG, CPG Generation

Once an AST (potentially with Node IDs) is available for a function:

1.  **CFG Generation**:
    *   `ElixirScope.ASTRepository.Enhanced.CFGGenerator.generate_cfg(function_ast, opts)` is called.
    *   It produces `CFGData.t()` containing nodes, edges, complexity metrics, and path analysis. CFG nodes are linked to original `ast_node_id`s.
2.  **DFG Generation**:
    *   `ElixirScope.ASTRepository.Enhanced.DFGGenerator.generate_dfg(function_ast, opts)` is called.
    *   It produces `DFGData.t()` using SSA form, detailing variable definitions, uses, data flows, and phi nodes. DFG elements are also linked to `ast_node_id`s.
3.  **CPG Generation**:
    *   `ElixirScope.ASTRepository.Enhanced.CPGBuilder.build_cpg(function_ast_or_enhanced_function_data, opts)` is called.
    *   It takes the AST (or `EnhancedFunctionData` containing AST, CFG, and DFG) and unifies them into a `CPGData.t()`.
    *   CPG nodes primarily derive from AST nodes, augmented with CFG/DFG info. Edges represent AST structure, control flow, and data flow.

### 2.3. Instrumentation Mapping and Transformation

1.  **Instrumentation Plan**: The `ElixirScope.CompileTime.Orchestrator` (using `AI.CodeAnalyzer` and `AI.PatternRecognizer`) generates an instrumentation plan. This plan specifies which code constructs (functions, expressions, etc.) should be instrumented.
2.  **Mapper**: `ElixirScope.ASTRepository.InstrumentationMapper.map_instrumentation_points/2` takes an AST and determines specific AST nodes that correspond to the plan's targets. It uses `ast_node_id`s for precision.
3.  **Transformer**:
    *   `ElixirScope.AST.Transformer` (for basic instrumentation) or `ElixirScope.AST.EnhancedTransformer` (for granular "Cinema Data" instrumentation) modifies the AST.
    *   It uses `ElixirScope.AST.InjectorHelpers` to generate AST snippets for calls to `ElixirScope.Capture.InstrumentationRuntime`.
    *   Crucially, the `ast_node_id` of the instrumented source construct is embedded as an argument in the injected runtime call (e.g., `InstrumentationRuntime.report_ast_function_entry_with_node_id(..., ast_node_id)`).

### 2.4. Project Population and Synchronization

1.  **Initial Population**:
    *   `ElixirScope.ASTRepository.Enhanced.ProjectPopulator.populate_project(repo_pid, project_path, opts)` discovers all relevant Elixir files.
    *   For each file, it parses the AST, invokes `ASTAnalyzer` (which implicitly handles Node ID assignment via `Parser` or `NodeIdentifier`), and then triggers CFG, DFG, (optionally) CPG generation.
    *   The resulting `EnhancedModuleData` (containing `EnhancedFunctionData` with their respective graphs) is stored in the `EnhancedRepository`.
2.  **Continuous Synchronization**:
    *   `ElixirScope.ASTRepository.Enhanced.FileWatcher` monitors project files for changes.
    *   Upon detecting a change (create, modify, delete), it notifies `ElixirScope.ASTRepository.Enhanced.Synchronizer`.
    *   The `Synchronizer` re-parses and re-analyzes the changed file(s) and updates the `EnhancedRepository` incrementally.

## 3. Runtime Integration

### 3.1. Event Capture with AST Node IDs

*   Instrumented code, when executed, calls functions in `ElixirScope.Capture.InstrumentationRuntime` (e.g., `report_ast_function_entry_with_node_id`, `report_ast_variable_snapshot`).
*   These calls include the `ast_node_id` (embedded at compile-time) and the current `correlation_id` (managed by `InstrumentationRuntime`'s call stack).
*   `InstrumentationRuntime` forwards these events, now tagged with `ast_node_id` and `correlation_id`, to the event ingestion pipeline (e.g., `Ingestor` -> `RingBuffer`).

### 3.2. Runtime Correlation with `RuntimeCorrelator`

*   `ElixirScope.ASTRepository.RuntimeCorrelator` is responsible for the primary link between runtime events and static AST data.
*   **`correlate_event_to_ast(repo, event)`**: Given a runtime event containing `module`, `function`, `arity`, and potentially `line_number` or an explicit `ast_node_id`, this function queries the `EnhancedRepository` to find the corresponding static `ast_context` (including the canonical `ast_node_id`, CPG info, etc.).
*   **`get_runtime_context(repo, event)`**: Provides a more comprehensive context, including variable scope and call hierarchy, by leveraging CFG/DFG data associated with the correlated AST node.
*   **`enhance_event_with_ast(repo, event)`**: Augments a raw runtime event with rich `ast_context`, structural info, and data flow info.
*   **`build_execution_trace(repo, events)`**: Constructs an AST-aware trace, showing the sequence of AST nodes executed and related variable states.

### 3.3. Storing AST-Enhanced Events

*   Events captured by `InstrumentationRuntime` (now potentially including `ast_node_id`) are passed to `ElixirScope.Capture.Ingestor`.
*   The `Ingestor` writes these events to `RingBuffer`.
*   `AsyncWriterPool` processes events from `RingBuffer` and sends them to `ElixirScope.Storage.EventStore` (via `ElixirScope.Storage.DataAccess`). The `EventStore` should be capable of indexing events by `ast_node_id` and `correlation_id`.
*   `ElixirScope.Capture.TemporalBridge` consumes events (potentially from `InstrumentationRuntime` directly or from `EventStore`) and stores them in `ElixirScope.Capture.TemporalStorage`, which also indexes by `timestamp`, `ast_node_id`, and `correlation_id`.

## 4. Query-Time and Analysis Integration

### 4.1. Querying Static Data (`EnhancedRepository`, `QueryBuilder`, `QueryExecutor`)

*   The `ElixirScope.ASTRepository.Enhanced.Repository` provides direct APIs to fetch `EnhancedModuleData`, `EnhancedFunctionData`, and specific graphs (CFG, DFG, CPG).
*   For more complex static queries (e.g., "find all functions with cyclomatic complexity > 10 and calling `Ecto.Repo.all/2`"), use `ElixirScope.ASTRepository.QueryBuilder` to construct a query specification.
*   This specification is then passed to `ElixirScope.ASTRepository.QueryExecutor.execute_query/2` (or directly to `EnhancedRepository.query_analysis/2`) which processes it against the repository's data.

### 4.2. Correlated Queries (`QueryEngine.ASTExtensions`)

*   `ElixirScope.QueryEngine.ASTExtensions.execute_ast_query(query)` allows querying static data from the `EnhancedRepository`.
*   `ElixirScope.QueryEngine.ASTExtensions.execute_correlated_query(static_query, runtime_query_template, join_key)` is the core function for combining static and dynamic data:
    1.  It first executes the `static_query` against the `EnhancedRepository` to get a set of static elements (e.g., functions matching certain criteria).
    2.  It extracts `join_key` values (e.g., `ast_node_id`s or `function_key`s) from the static results.
    3.  It uses these values to parameterize and execute `runtime_query_template` against the `EventStore` (via `QueryEngine.Engine`).
    4.  Finally, it joins the static results with the runtime events.

### 4.3. Temporal Bridge Enhancement for Time-Travel Debugging

*   `ElixirScope.Capture.TemporalBridgeEnhancement` uses `RuntimeCorrelator` and `EnhancedRepository` to provide AST-aware time-travel features.
*   **`reconstruct_state_with_ast(...)`**: Reconstructs process state at a timestamp and enriches it with the AST/CPG context of the code executing at that time.
*   **`get_ast_execution_trace(...)`**: Shows the sequence of AST nodes traversed during an execution segment, correlating them with runtime events and state changes.
*   **`get_states_for_ast_node(...)`**: Allows "semantic stepping" by finding all runtime states associated with a particular `ast_node_id`.
*   **`get_execution_flow_between_nodes(...)`**: Visualizes the runtime path taken between two points in the static code structure.

## 5. AI Components Integration

The `ElixirScope.AI.Bridge` module serves as the primary interface for AI components.

### 5.1. Using `AI.Bridge` for Context

*   `ElixirScope.AI.Bridge.get_function_cpg_for_ai(function_key, ...)`: Fetches the CPG for a function, which is a rich input for many AI models.
*   `ElixirScope.AI.Bridge.find_cpg_nodes_for_ai_pattern(pattern_dsl, ...)`: Allows AI to query for specific code structures using a CPG pattern.
*   `ElixirScope.AI.Bridge.get_correlated_features_for_ai(...)`: Provides a way to extract a combined feature set (static CPG properties + dynamic runtime summaries) for AI models, especially for `PredictiveAnalyzer`.

### 5.2. Code Analysis and Pattern Recognition

*   `ElixirScope.AI.Analysis.IntelligentCodeAnalyzer` uses ASTs (and potentially CPGs via `AI.Bridge`) to perform semantic analysis, quality assessment, and suggest refactorings.
*   `ElixirScope.AI.ComplexityAnalyzer` analyzes ASTs/CPGs for various complexity metrics.
*   `ElixirScope.AI.PatternRecognizer` uses ASTs/CPGs to identify OTP patterns, Phoenix structures, and other architectural elements.
*   `ElixirScope.ASTRepository.PatternMatcher` provides a dedicated service for matching AST, behavioral, and anti-patterns against the `EnhancedRepository`.

### 5.3. Predictive Analysis

*   `ElixirScope.AI.Predictive.ExecutionPredictor` uses historical data (runtime events correlated with static features via `AI.Bridge`) to train models that predict execution paths, resource usage, and concurrency impacts.

### 5.4. LLM Interaction

*   `ElixirScope.AI.LLM.Client` uses the configured LLM provider.
*   `ElixirScope.AI.Bridge.query_llm_with_cpg_context(...)` shows a pattern where CPG data (e.g., code snippets, complexity) enriches prompts sent to an LLM for code understanding or suggestions.

## 6. Advanced Debugging Features

These features are primarily managed by `ElixirScope.Capture.EnhancedInstrumentation` and leverage the `RuntimeCorrelator` and `EnhancedRepository`.

### 6.1. Structural Breakpoints

*   **Setup**: `EnhancedInstrumentation.set_structural_breakpoint(spec)` defines a breakpoint based on an AST pattern (e.g., a specific function call signature, a type of loop). `spec` includes the AST `pattern`, `condition` (e.g., `:pattern_match_failure`), and `ast_path`.
*   **Runtime**:
    *   When `InstrumentationRuntime` reports an event (e.g., `report_enhanced_function_entry`), it includes the `ast_node_id`.
    *   `EnhancedInstrumentation` (or `RuntimeCorrelator` on its behalf) checks if the AST node associated with `ast_node_id` (fetched from `EnhancedRepository`) matches any active structural breakpoint patterns.
    *   If a match and condition are met, the breakpoint "triggers" (e.g., logs, pauses execution via a debugger interface).

### 6.2. Data Flow Breakpoints

*   **Setup**: `EnhancedInstrumentation.set_data_flow_breakpoint(spec)` defines a breakpoint on a `variable` name, an `ast_path` (scope), and `flow_conditions` (e.g., `:assignment`, `:function_call`).
*   **Runtime**:
    *   Requires DFG information from `EnhancedRepository` for the relevant function.
    *   When `InstrumentationRuntime.report_enhanced_variable_snapshot` is called, `EnhancedInstrumentation` checks if the snapshot involves the watched `variable`.
    *   It then uses the DFG to see if the current `ast_node_id` and the state of the variable satisfy the `flow_conditions` within the specified `ast_path`.

### 6.3. Semantic Watchpoints

*   **Setup**: `EnhancedInstrumentation.set_semantic_watchpoint(spec)` defines a watchpoint on a `variable` within an `ast_scope`, tracking its value changes as it flows `track_through` certain AST constructs (e.g., `:pattern_match`, `:function_call`).
*   **Runtime**:
    *   Leverages CPG data from `EnhancedRepository`.
    *   When `InstrumentationRuntime.report_enhanced_variable_snapshot` occurs, `EnhancedInstrumentation` checks if the snapshot is within the `ast_scope` and involves the watched `variable`.
    *   It uses the CPG's data flow edges and AST structure to determine if the variable's current state change is part of a tracked semantic flow.
    *   Value history is maintained for the watchpoint.

## 7. Best Practices for Integration

*   **AST Node ID Consistency**: Ensure `NodeIdentifier` logic is robust and consistently applied by `Parser`/`ASTAnalyzer` and used by `EnhancedTransformer`. This is the bedrock of correlation.
*   **Repository Availability**: Ensure `EnhancedRepository` (and its GenServer process) is started and available before compile-time tasks (`Mix.Tasks.Compile.ElixirScope`) or runtime components (`RuntimeCorrelator`, `TemporalBridgeEnhancement`) that depend on it.
*   **Configuration**: Use `ElixirScope.Config` and `ElixirScope.ASTRepository.Config` for centralized configuration.
*   **Asynchronous Operations**: For performance, interactions that might be slow (e.g., full CPG generation, complex AI analysis) should be done asynchronously or in background tasks, especially if triggered by runtime events.
*   **Caching**: Leverage caching mechanisms provided by `QueryBuilder` and `MemoryManager` for frequently accessed static data or query results.
*   **Error Handling**: Implement robust error handling for API calls between components (e.g., when `RuntimeCorrelator` queries `EnhancedRepository`).
*   **Incremental Updates**: Utilize `FileWatcher` and `Synchronizer` for efficient incremental updates to the `EnhancedRepository` to keep static analysis fresh without full project re-scans.

## 8. Troubleshooting Common Issues

*   **No Correlation Data**:
    *   Verify `ast_node_id`s are being correctly assigned during parsing and injected during transformation.
    *   Ensure `RuntimeCorrelator` is running and correctly configured with the `EnhancedRepository`.
    *   Check if `InstrumentationRuntime` is reporting events with `ast_node_id`s.
*   **Slow Performance**:
    *   **Analysis Time**: Profile `ASTAnalyzer` and graph generators (CFG, DFG, CPG). Consider optimizing their algorithms or enabling lazy generation for parts of the CPG.
    *   **Query Time**: Use `QueryBuilder.get_optimization_hints()` and `QueryEngine.Engine.get_optimization_suggestions()`. Ensure `EnhancedRepository` indexes are effective. Check `MemoryManager` cache hit rates.
    *   **Runtime Overhead**: Reduce instrumentation granularity or sampling rate via `ElixirScope.Config`.
*   **AST Node ID Mismatches**:
    *   Ensure the same `NodeIdentifier` logic is used consistently.
    *   If code is refactored, `ast_node_id`s may change. The repository might need mechanisms to map old IDs to new ones or version AST data.
*   **`EnhancedRepository` Not Populated**:
    *   Ensure `ProjectPopulator.populate_project/3` has been run successfully.
    *   Check logs from `FileWatcher` and `Synchronizer` for any errors during file processing.
*   **AI Components Not Working**:
    *   Verify `AI.Bridge` can access `EnhancedRepository` and `QueryEngine`.
    *   Check logs from the specific AI component for errors (e.g., LLM API errors, model loading issues).
    *   Ensure CPGs (if required by the AI component) are being generated and are accessible.
*   **Out-of-Memory Errors**:
    *   Monitor `MemoryManager` statistics. Adjust its thresholds or the `EnhancedRepository`'s memory limits.
    *   Profile CPG generation and storage, as CPGs can be large. Consider lazy loading or partial CPGs for very large functions/modules.


