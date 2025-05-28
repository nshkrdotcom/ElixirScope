# ElixirScope Design Overview

This document provides a high-level overview of the ElixirScope system architecture, its core components, and their interactions. ElixirScope is designed as a next-generation debugging and observability platform for Elixir applications, centered around the concept of an "Execution Cinema" powered by AI-driven analysis and deep compile-time AST instrumentation.

## Table of Contents

1.  [Introduction](#1-introduction)
2.  [Core Philosophy](#2-core-philosophy)
3.  [Architectural Layers and Key Components](#3-architectural-layers-and-key-components)
    *   [3.1. Compile-Time Layer](#31-compile-time-layer)
    *   [3.2. Capture Layer](#32-capture-layer)
    *   [3.3. Storage Layer](#33-storage-layer)
    *   [3.4. Analysis Layer (Static & Dynamic)](#34-analysis-layer-static--dynamic)
    *   [3.5. AI Layer](#35-ai-layer)
    *   [3.6. Query Layer](#36-query-layer)
    *   [3.7. Distributed Layer](#37-distributed-layer)
4.  [Data Flow](#4-data-flow)
    *   [4.1. Compile-Time Data Flow](#41-compile-time-data-flow)
    *   [4.2. Runtime Data Flow](#42-runtime-data-flow)
    *   [4.3. Query/Analysis Data Flow](#43-queryanalysis-data-flow)
5.  [Key Data Structures](#5-key-data-structures)
6.  [Extensibility](#6-extensibility)
7.  [Performance and Scalability Goals](#7-performance-and-scalability-goals)

---

## 1. Introduction

ElixirScope aims to revolutionize how developers debug and understand Elixir applications. It moves beyond traditional logging and tracing by:
*   Capturing a comprehensive history of execution ("Total Recall").
*   Correlating runtime behavior with static code structure at a granular level.
*   Providing an "Execution Cinema" experience for time-travel debugging.
*   Leveraging AI for intelligent instrumentation, analysis, and insights.

## 2. Core Philosophy

*   **Deep Observability**: Go beyond surface-level metrics to understand the intricate details of program execution.
*   **AST-Runtime Correlation**: Bridge the gap between static code and its dynamic behavior using AST Node IDs as the fundamental link.
*   **AI-Driven Intelligence**: Utilize AI/ML for smart instrumentation planning, pattern recognition, predictive analysis, and insightful recommendations.
*   **Performance-Awareness**: Achieve deep observability with minimal runtime overhead, making it suitable for production environments through intelligent sampling and optimized components.
*   **Developer Experience**: Provide intuitive tools and visualizations (like the Execution Cinema) to simplify debugging complex concurrent and distributed systems.

## 3. Architectural Layers and Key Components

ElixirScope is structured into several logical layers, each with distinct responsibilities:

### 3.1. Compile-Time Layer

Responsible for analyzing source code and instrumenting it before execution.
*   **`Mix.Tasks.Compile.ElixirScope`**: The Mix compiler task that orchestrates compile-time processing.
*   **`ElixirScope.CompileTime.Orchestrator`**: Generates instrumentation plans based on AI analysis and user configuration.
*   **`ElixirScope.ASTRepository.Parser` & `NodeIdentifier`**: Parses Elixir code into ASTs and assigns unique, stable AST Node IDs to instrumentable constructs.
*   **`ElixirScope.AST.Transformer` & `EnhancedTransformer`**: Modify the AST to inject calls to the `InstrumentationRuntime`, embedding AST Node IDs and other metadata.
*   **`ElixirScope.AST.InjectorHelpers`**: Provides utilities for generating the AST snippets for instrumentation calls.

### 3.2. Capture Layer

Responsible for capturing runtime events from instrumented code.
*   **`ElixirScope.Capture.InstrumentationRuntime`**: The low-level API called by instrumented code to report events. Designed for extreme performance.
*   **`ElixirScope.Capture.Ingestor`**: An ultra-fast component that receives raw trace data from `InstrumentationRuntime` and prepares `ElixirScope.Events` structs.
*   **`ElixirScope.Capture.RingBuffer`**: A high-performance, lock-free ring buffer for temporarily holding events before asynchronous processing.
*   **`ElixirScope.Capture.AsyncWriter` & `AsyncWriterPool`**: Workers that consume events from `RingBuffer`, enrich them, and forward them for storage and further processing.
*   **`ElixirScope.Capture.PipelineManager`**: Supervises the asynchronous event processing pipeline components.
*   **`ElixirScope.Capture.TemporalBridge` & `TemporalBridgeEnhancement`**: Correlate runtime events with timestamps and AST context, enabling time-travel debugging.
*   **`ElixirScope.Capture.EnhancedInstrumentation`**: Manages advanced debugging features like structural breakpoints, data flow breakpoints, and semantic watchpoints, by intercepting or processing events from `InstrumentationRuntime`.

### 3.3. Storage Layer

Responsible for persistently storing captured events and analyzed AST data.
*   **`ElixirScope.Storage.DataAccess`**: Provides a high-performance ETS-based storage solution with multiple indexes for events.
*   **`ElixirScope.Storage.EventStore`**: A GenServer wrapper for `DataAccess`, providing a supervised and potentially global event store.
*   **`ElixirScope.Capture.TemporalStorage`**: Specialized ETS-based storage optimized for temporal queries, AST node correlation, and supporting `TemporalBridge`.
*   **`ElixirScope.ASTRepository.Enhanced.Repository`**: The central GenServer for storing all static analysis artifacts, including `EnhancedModuleData`, `EnhancedFunctionData`, and generated CFGs, DFGs, and CPGs. It uses ETS for in-memory storage and provides a rich query API.
*   **`ElixirScope.ASTRepository.MemoryManager`**: Manages memory usage for the `EnhancedRepository`, including caching, cleanup, and compression strategies.

### 3.4. Analysis Layer (Static & Dynamic)

Responsible for analyzing code structure and runtime behavior.
*   **Static Analysis (AST Repository Sub-components)**:
    *   **`ElixirScope.ASTRepository.ASTAnalyzer`**: Performs deep analysis of ASTs to populate `EnhancedModuleData` and `EnhancedFunctionData`.
    *   **`ElixirScope.ASTRepository.Enhanced.CFGGenerator`**: Generates Control Flow Graphs.
    *   **`ElixirScope.ASTRepository.Enhanced.DFGGenerator`**: Generates Data Flow Graphs (SSA-based).
    *   **`ElixirScope.ASTRepository.Enhanced.CPGBuilder`**: Unifies AST, CFG, and DFG into Code Property Graphs.
    *   **`ElixirScope.ASTRepository.PatternMatcher`**: Identifies AST patterns, behavioral patterns (OTP, design), and anti-patterns.
*   **Dynamic Analysis (Correlation & Core Logic)**:
    *   **`ElixirScope.ASTRepository.RuntimeCorrelator`**: Core component for linking runtime events (via `ast_node_id` and `correlation_id`) to static AST/CPG structures stored in the `EnhancedRepository`.
    *   **`ElixirScope.Core.EventManager`**: Manages querying and filtering of runtime events.
    *   **`ElixirScope.Core.StateManager`**: Tracks GenServer state history and enables state reconstruction.
    *   **`ElixirScope.Core.MessageTracker`**: Analyzes inter-process message flows.

### 3.5. AI Layer

Leverages static and dynamic analysis results to provide intelligent insights and control.
*   **`ElixirScope.AI.Bridge`**: Facilitates interaction between AI components and the data layers (AST Repository, Query Engine).
*   **`ElixirScope.AI.Analysis.IntelligentCodeAnalyzer`**: Performs semantic analysis, quality assessment, and suggests refactorings.
*   **`ElixirScope.AI.ComplexityAnalyzer`**: Calculates various code complexity metrics.
*   **`ElixirScope.AI.PatternRecognizer`**: Identifies common Elixir/OTP/Phoenix patterns in code structure.
*   **`ElixirScope.AI.Predictive.ExecutionPredictor`**: Uses ML models to predict execution paths, resource usage, and concurrency impacts.
*   **`ElixirScope.AI.LLM.Client`, `Config`, `Providers`**: Manages interaction with Large Language Models (e.g., Gemini, Vertex AI, Mock) for tasks like code explanation and fix suggestions.

### 3.6. Query Layer

Enables querying of both static and dynamic data.
*   **`ElixirScope.QueryEngine.Engine`**: Optimized engine for retrieving runtime events from `EventStore`.
*   **`ElixirScope.ASTRepository.QueryBuilder`**: Fluent API for constructing complex queries against the `EnhancedRepository`.
*   **`ElixirScope.ASTRepository.QueryExecutor`**: Executes queries built by `QueryBuilder` against the `EnhancedRepository`. (May be integrated directly into `EnhancedRepository`'s API).
*   **`ElixirScope.QueryEngine.ASTExtensions`**: Extends the main query engine to support correlated queries that join static AST/CPG data with runtime event data.

### 3.7. Distributed Layer

Manages tracing and event synchronization in distributed Elixir environments.
*   **`ElixirScope.Distributed.GlobalClock`**: Provides hybrid logical clocks for ordering events across nodes.
*   **`ElixirScope.Distributed.EventSynchronizer`**: Handles efficient synchronization of events between nodes.
*   **`ElixirScope.Distributed.NodeCoordinator`**: Manages node discovery, registration, and coordinates distributed tracing activities.

## 4. Data Flow

### 4.1. Compile-Time Data Flow
1.  Source Code -> `ProjectPopulator` / `Mix.Tasks.Compile.ElixirScope`
2.  `Parser` & `NodeIdentifier` -> AST with Node IDs
3.  AST -> `ASTAnalyzer` -> `EnhancedModuleData` / `EnhancedFunctionData`
4.  Function AST -> `CFGGenerator` -> `CFGData`
5.  Function AST -> `DFGGenerator` -> `DFGData`
6.  AST/CFG/DFG -> `CPGBuilder` -> `CPGData`
7.  All static analysis data -> `EnhancedRepository` for storage.
8.  Instrumentation Plan (`Orchestrator` + AI) + AST with Node IDs -> `Transformer` -> Instrumented AST (written to build output).

### 4.2. Runtime Data Flow
1.  Instrumented Code Execution -> Calls to `InstrumentationRuntime` (with `ast_node_id`, `correlation_id`).
2.  `InstrumentationRuntime` -> `Ingestor` -> `ElixirScope.Events` struct.
3.  `Events` -> `RingBuffer`.
4.  `AsyncWriterPool` -> Reads from `RingBuffer` -> Enriches Events.
5.  Enriched Events -> `EventStore` (for persistent storage via `DataAccess`).
6.  Enriched Events (especially those with `ast_node_id`) -> `TemporalBridge` -> `TemporalStorage` (for time-travel).
7.  Events with `ast_node_id` -> `RuntimeCorrelator` for immediate/cached AST context linking.

### 4.3. Query/Analysis Data Flow
1.  User/AI Query -> `QueryEngine` / `EnhancedRepository` API / `AI.Bridge`.
2.  **Static Queries**: `QueryBuilder` -> `QueryExecutor` -> `EnhancedRepository` (accessing CPG, EnhancedModule/FunctionData).
3.  **Runtime Queries**: `QueryEngine.Engine` -> `EventStore` / `TemporalStorage`.
4.  **Correlated Queries**: `QueryEngine.ASTExtensions` orchestrates:
    *   Static query to `EnhancedRepository`.
    *   Runtime query to `EventStore`/`TemporalStorage`, parameterized by static results (e.g., using `ast_node_id`s).
    *   Joins results.
5.  **AI Analysis**: AI Components use `AI.Bridge` to fetch CPGs from `EnhancedRepository` and correlated runtime features from `QueryEngine`.
6.  **Time-Travel Debugging**: `TemporalBridgeEnhancement` queries `TemporalStorage` for events and `EnhancedRepository` (via `RuntimeCorrelator`) for AST/CPG context to reconstruct past states.

## 5. Key Data Structures

*   **`ElixirScope.Events.t()`**: The base structure for all runtime events, including common metadata like `event_id`, `timestamp`, `pid`, `correlation_id`, and `event_type`, with event-specific data in the `data` field.
*   **`ElixirScope.ASTRepository.Enhanced.EnhancedModuleData.t()`**: Comprehensive static representation of a module.
*   **`ElixirScope.ASTRepository.Enhanced.EnhancedFunctionData.t()`**: Comprehensive static representation of a function.
*   **`ElixirScope.ASTRepository.Enhanced.CFGData.t()`**: Control Flow Graph structure.
*   **`ElixirScope.ASTRepository.Enhanced.DFGData.t()`**: Data Flow Graph structure (SSA-based).
*   **`ElixirScope.ASTRepository.Enhanced.CPGData.t()`**: Code Property Graph structure.
*   **`ast_node_id :: String.t()`**: The crucial link between static code and runtime events.

## 6. Extensibility

ElixirScope is designed with extensibility in mind:
*   **New Analyzers**: AI components or static analyzers can be added by consuming data from the `EnhancedRepository` (CPGs are particularly rich) and `QueryEngine`.
*   **Custom Instrumentation**: While the system aims for intelligent automatic instrumentation, the `InstrumentationRuntime` API can be used for custom tracing needs.
*   **LLM Providers**: The `ElixirScope.AI.LLM.Provider` behaviour allows for adding new LLM backends.
*   **Storage Backends**: While ETS is the primary in-memory store, `DataAccess` and `EnhancedRepository` could be adapted to support other backends (e.g., Mnesia, dedicated graph databases for CPGs) for larger-scale persistence or different query characteristics.
*   **Event Types**: New event types can be added to `ElixirScope.Events` and processed through the capture pipeline.

## 7. Performance and Scalability Goals

*   **Low Runtime Overhead**: Target <1% overhead in production for balanced instrumentation strategies. This is achieved through high-performance capture components (`InstrumentationRuntime`, `Ingestor`, `RingBuffer`) and intelligent sampling.
*   **Scalable Storage**: ETS provides efficient in-memory storage. `DataAccess` and `EnhancedRepository` are designed for fast lookups and updates. `MemoryManager` helps control resource usage.
*   **Efficient Analysis**: Graph generation (CFG, DFG, CPG) is optimized. Complex queries are supported by indexing and caching.
*   **Parallel Processing**: `ProjectPopulator`, `AsyncWriterPool`, and some AI analysis tasks are designed for parallel execution to leverage multi-core architectures.
*   **Distributed Tracing**: The distributed layer aims to provide consistent tracing and event correlation across a cluster of Elixir nodes.

This design overview provides a snapshot of ElixirScope's architecture. Individual component documentation and the integration guide offer more detailed information.
