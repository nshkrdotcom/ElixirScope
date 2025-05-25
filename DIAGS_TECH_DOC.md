Okay, I have reviewed the project documentation, code, and tests, including `DIAGS.md` and `DIAGS2.md`. Based on this review, here is a detailed technical document designed to complement those diagrams and provide deeper insight into the ElixirScope system.

---

**ElixirScope: Technical Architecture and Implementation Details**

**Version:** 0.1.0 (Foundation)

**Document Version:** 1.0

**Date:** 2024-05-24

**Table of Contents**

1.  Introduction
2.  System Architecture Overview
    2.1. Core Layers and Principles
    2.2. High-Level Data Flow
3.  AI-Driven Instrumentation Strategy
    3.1. Code Analysis (`ElixirScope.AI.CodeAnalyzer`)
    3.2. Pattern Recognition (`ElixirScope.AI.PatternRecognizer`)
    3.3. Complexity Analysis (`ElixirScope.AI.ComplexityAnalyzer`)
    3.4. Instrumentation Planning (`ElixirScope.AI.Orchestrator`)
4.  Compile-Time AST Transformation
    4.1. Mix Compiler Task (`ElixirScope.Compiler.MixTask`)
    4.2. AST Transformer (`ElixirScope.AST.Transformer`)
    4.3. Injector Helpers (`ElixirScope.AST.InjectorHelpers`)
5.  Event Capture Pipeline
    5.1. Instrumentation Runtime (`ElixirScope.Capture.InstrumentationRuntime`)
    5.2. Event Ingestor (`ElixirScope.Capture.Ingestor`)
    5.3. Ring Buffer (`ElixirScope.Capture.RingBuffer`)
    5.4. Pipeline Management (`ElixirScope.Capture.PipelineManager`, `AsyncWriterPool`, `AsyncWriter`)
6.  Event Processing and Storage
    6.1. Event Correlator (`ElixirScope.Capture.EventCorrelator`)
    6.2. Data Access Layer (`ElixirScope.Storage.DataAccess`)
    6.3. Query Coordination (Future - `ElixirScope.Storage.QueryCoordinator`)
7.  Framework Integration
    7.1. Phoenix Integration (`ElixirScope.Phoenix.Integration`)
8.  Distributed System Support
    8.1. Node Coordinator (`ElixirScope.Distributed.NodeCoordinator`)
    8.2. Event Synchronizer (`ElixirScope.Distributed.EventSynchronizer`)
    8.3. Global Clock (`ElixirScope.Distributed.GlobalClock`)
9.  Performance, Reliability, and Memory Management
10. Testing Strategy
11. Configuration Management (`ElixirScope.Config`)
12. Future Evolution
13. Conclusion

---

## 1. Introduction

ElixirScope is an AI-powered execution cinema debugger designed to provide deep observability into Elixir and Phoenix applications. Its core vision is to enable "total recall" of application behavior, facilitating time-travel debugging through an intuitive visual interface. This document complements the architectural diagrams found in `DIAGS.md` and `DIAGS2.md` by providing detailed technical explanations of ElixirScope's components, their interactions, and design rationale, focusing on the "Foundation Complete" state.

The system aims to achieve sub-microsecond event capture overhead and leverages a layered architecture to manage complexity from AI-driven instrumentation planning to high-performance event processing and storage.

## 2. System Architecture Overview

ElixirScope's architecture is designed in layers, allowing for separation of concerns and modular development. The primary layers, as depicted in `DIAGS.md#1. High-Level Architecture Overview` and `DIAGS2.md#2. Module Dependency Graph`, are:

*   **AI Intelligence Layer:** Analyzes code and plans instrumentation.
*   **Auto-Instrumentation Layer:** Modifies code at compile-time.
*   **Event Capture Pipeline:** Ingests events from running applications with high performance.
*   **Processing & Storage Layer:** Asynchronously processes, correlates, and stores events.
*   **Analysis & Visualization Layer (Future):** Provides the "Execution Cinema" UI and advanced AI insights.

### 2.1. Core Layers and Principles

*   **AI-First Strategy:** The AI layer (comprising `CodeAnalyzer`, `PatternRecognizer`, `ComplexityAnalyzer`, and `Orchestrator`) drives instrumentation decisions. This allows for intelligent and context-aware tracing.
*   **Compile-Time Instrumentation:** The `Compiler.MixTask` integrates with the Elixir build process, using `AST.Transformer` to inject tracing calls, minimizing runtime decision-making for capture.
*   **Decoupled High-Performance Capture:** The hot path for event capture (`InstrumentationRuntime` -> `Ingestor` -> `RingBuffer`) is optimized for speed and minimal overhead. Asynchronous processing (`AsyncWriterPool`, `EventCorrelator`) handles heavier tasks off the hot path.
*   **Structured Event Model:** `ElixirScope.Events` defines a comprehensive set of event types, ensuring consistent data capture.
*   **Resilient Storage:** `Storage.DataAccess` uses ETS for fast "hot" storage, with plans for tiered "warm" and "cold" storage.
*   **Test-Driven Development:** Ensures robustness and correctness, with over 325 tests validating the foundation.

### 2.2. High-Level Data Flow

As illustrated in `DIAGS.md#10. Complete Event Lifecycle`:

1.  **Analysis & Planning:** Source code is analyzed by the AI Layer, resulting in an instrumentation plan.
2.  **Compile-Time:** The `MixTask` uses this plan to transform ASTs, injecting calls to `InstrumentationRuntime`.
3.  **Runtime Capture:** Instrumented code executes, `InstrumentationRuntime` calls report events to `Ingestor`, which writes them to `RingBuffer`.
4.  **Async Processing:** `AsyncWriterPool` workers read from `RingBuffer`. `EventCorrelator` enriches events with causal links.
5.  **Storage:** Enriched events are stored in `DataAccess` (ETS).
6.  **Query & Analysis (Future):** A Query API will allow the UI and AI to access and analyze stored data.

## 3. AI-Driven Instrumentation Strategy

The AI layer is responsible for understanding the codebase and generating an optimal instrumentation plan. This process is depicted in `DIAGS.md#3. AI Analysis and Instrumentation Flow`.

### 3.1. Code Analysis (`ElixirScope.AI.CodeAnalyzer`)

*   **Input:** Elixir source code files.
*   **Process:**
    *   Parses code into ASTs.
    *   Utilizes `PatternRecognizer` to identify OTP behaviors (GenServers, Supervisors), Phoenix components (Controllers, LiveViews), and other common Elixir patterns.
    *   Leverages `ComplexityAnalyzer` to score modules and functions based on structural complexity (nesting depth, cyclomatic complexity), state management, and potential performance characteristics.
    *   (Future) May integrate with LLMs for deeper semantic understanding.
*   **Output:** A structured analysis of the codebase, including module types, identified patterns, complexity scores, and potential areas of interest for instrumentation.
*   **Current Implementation:** Relies on rule-based heuristics and AST traversal as seen in `ElixirScope.AI.CodeAnalyzerTest` and the module code.

### 3.2. Pattern Recognition (`ElixirScope.AI.PatternRecognizer`)

*   **Functionality:** Scans ASTs to detect specific code structures:
    *   `use GenServer`, `use Supervisor`, `use Phoenix.Controller`, `use Phoenix.LiveView`, etc.
    *   Common callback definitions (`handle_call`, `init`, `mount`, Phoenix actions).
    *   Database interaction patterns (e.g., calls to `Repo`).
    *   Message passing patterns (`GenServer.call/cast`, `send`).
*   **Mechanism:** Primarily uses `Macro.prewalk/3` to traverse the AST and match known patterns. The `elixir_scope/ai/pattern_recognizer.ex` file contains various helper functions (e.g., `has_genserver_use?/1`, `extract_phoenix_actions/1`).

### 3.3. Complexity Analysis (`ElixirScope.AI.ComplexityAnalyzer`)

*   **Metrics Calculated:**
    *   **Complexity Score:** A weighted score based on nesting depth, cyclomatic complexity, pattern matching complexity, pipe operations, and Enum operations.
    *   **Nesting Depth:** Maximum depth of nested control structures (case, if, cond, fn).
    *   **Cyclomatic Complexity:** Number of linearly independent paths through the code.
    *   **State Complexity:** For stateful modules, analyzes state operations and mutations.
    *   **Performance Criticality:** Heuristics to identify loops, recursion, heavy computation, or large data structures.
*   **Implementation:** Found in `elixir_scope/ai/complexity_analyzer.ex`, it uses AST traversal to count relevant constructs.

### 3.4. Instrumentation Planning (`ElixirScope.AI.Orchestrator`)

*   **Input:** Analysis results from `CodeAnalyzer` and global configuration from `ElixirScope.Config` (e.g., `default_strategy`, `sampling_rate`).
*   **Process:**
    1.  Prioritizes modules and functions based on complexity, criticality (derived from analysis), and user configuration.
    2.  Determines the appropriate instrumentation level for each target (e.g., `:minimal`, `:function_boundaries`, `:full_trace`).
    3.  Decides what specific data to capture (arguments, return values, state changes, exceptions, performance metrics).
    4.  Calculates estimated performance impact and adjusts the plan to meet targets (e.g., `ai.planning.performance_target`).
*   **Output:** A declarative instrumentation plan, typically a map where keys are `{module, function, arity}` tuples and values are instrumentation directives. This plan is stored via `DataAccess.store_instrumentation_plan/1` and retrieved by `MixTask`.
*   **Current Implementation:** The `Orchestrator` manages this flow, with `CodeAnalyzer.generate_instrumentation_plan/1` containing logic for plan generation.

## 4. Compile-Time AST Transformation

This layer modifies the application's code at compile time to inject ElixirScope tracing calls. The process is illustrated in `DIAGS.md#6. AST Transformation Process`.

### 4.1. Mix Compiler Task (`ElixirScope.Compiler.MixTask`)

*   **Role:** Integrates ElixirScope into the standard Elixir build process. It is registered as a custom compiler that runs *before* the main `:elixir` compiler.
*   **Workflow:**
    1.  Invoked by `mix compile`.
    2.  Fetches the current instrumentation plan from `AI.Orchestrator`.
    3.  Identifies Elixir source files to be instrumented.
    4.  For each targeted file:
        *   Reads the source code and parses it into an AST.
        *   Passes the AST and the relevant part of the instrumentation plan to `AST.Transformer`.
        *   Writes the transformed AST (as source code) to a temporary location in the `_build` directory. The standard Elixir compiler then compiles this instrumented version.
*   **Status:** Foundation exists. `PROGRESS.md` notes AST Transformation Engine is "In Progress".

### 4.2. AST Transformer (`ElixirScope.AST.Transformer`)

*   **Functionality:** The core engine for modifying ASTs.
*   **Mechanism:**
    *   Receives an AST and instrumentation directives from `MixTask`.
    *   Uses `Macro.prewalk/2` and `Macro.postwalk/2` to traverse the AST.
    *   Identifies target nodes (e.g., `def`, `defp`, specific callbacks based on plan).
    *   Uses `AST.InjectorHelpers` to generate `quote` blocks for instrumentation calls.
    *   Replaces or wraps original AST nodes with instrumented versions.
*   **Key Transformations:**
    *   **Function Wrapping:** Injects calls to `InstrumentationRuntime.report_function_entry` at the start and `report_function_exit` at the end (within a `try/catch` block to capture exceptions).
    *   **Callback Instrumentation:** For GenServer, Phoenix, LiveView callbacks, injects calls to capture state, parameters, or other relevant context.
*   **Current Code:** `elixir_scope/ast/transformer.ex` and `elixir_scope/ast/transformer_test.exs` show logic for transforming various function definitions, GenServer callbacks, Phoenix actions, and LiveView callbacks.

### 4.3. Injector Helpers (`ElixirScope.AST.InjectorHelpers`)

*   **Purpose:** A library of functions that abstract the generation of common instrumentation code snippets (quoted ASTs).
*   **Examples:**
    *   `report_function_entry_call/2`: Generates the AST for calling `InstrumentationRuntime.report_function_entry`.
    *   `wrap_with_try_catch/3`: Generates a `try/catch` block around the original function body, including calls to `report_function_exit` in `rescue` and `after` clauses.
    *   Specific helpers for GenServer state capture, Phoenix param capture, etc.
*   **Benefit:** Keeps the `Transformer` logic cleaner and centralizes the structure of injected calls.

## 5. Event Capture Pipeline

This pipeline is designed for extremely high performance and low overhead, enabling "total recall." Diagrams `DIAGS.md#2. Event Capture Pipeline Detail` and `DIAGS.md#5. Ring Buffer Implementation Detail` are key references.

### 5.1. Instrumentation Runtime (`ElixirScope.Capture.InstrumentationRuntime`)

*   **API for Instrumented Code:** Provides the functions that are directly called by the code injected during AST transformation (e.g., `report_function_entry/3`, `report_state_change/2`).
*   **Process-Local Context:** Manages context within the instrumented process, often using the process dictionary (`Process.put/get(@context_key, @call_stack_key)`). This context includes:
    *   A reference to the target `RingBuffer`.
    *   The current `correlation_id`.
    *   A call stack for tracking nested function calls within the same process.
    *   An `enabled` flag for quick bypassing of instrumentation.
*   **Operation:**
    1.  Receives data from the instrumented application.
    2.  If enabled, generates a new correlation ID for new call chains or uses the current one.
    3.  Manages the per-process call stack.
    4.  Formats a lightweight event.
    5.  Immediately passes the event to `ElixirScope.Capture.Ingestor`.
*   **Performance:** Critical hot path. Designed for sub-microsecond overhead. `with_instrumentation_disabled/1` allows ElixirScope's own code to avoid self-instrumentation.

### 5.2. Event Ingestor (`ElixirScope.Capture.Ingestor`)

*   **Role:** A set of highly optimized public functions (not a GenServer) responsible for the first stage of event processing.
*   **Functionality:**
    1.  Receives raw event data from `InstrumentationRuntime` or `VMTracer`.
    2.  Constructs full `ElixirScope.Events` structs.
    3.  Assigns high-resolution timestamps (`Utils.monotonic_timestamp`, `Utils.wall_timestamp`) and unique event IDs (`Utils.generate_id`).
    4.  Performs data truncation (`Utils.truncate_data/2`) for large arguments, return values, or state to manage event size.
    5.  Writes the event struct to the appropriate `ElixirScope.Capture.RingBuffer`.
*   **Optimization:** Achieves high throughput (>1M events/sec claimed in docs) via direct function calls and efficient event struct creation. Batch ingestion (`ingest_batch/2`) is provided for even higher throughput (claimed 24x improvement).

### 5.3. Ring Buffer (`ElixirScope.Capture.RingBuffer`)

*   **Design:** A lock-free, concurrent-safe, fixed-size circular buffer. `DIAGS.md#5` illustrates its structure.
*   **Implementation:**
    *   Uses `:atomics` for managing read/write pointers (`@write_pos`, `@read_pos`) and statistics (`@total_writes`, `@total_reads`, `@dropped_events`), enabling lock-free operations.
    *   The actual buffer storage uses an ETS table (`:buffer_table`) where the key is the buffer index (`position &&& buffer.mask`).
*   **Key Features:**
    *   **Size:** Configurable, must be a power of 2 for efficient bitwise modulo (`mask`).
    *   **Overflow Strategy:** Configurable behavior when full (`:drop_oldest`, `:drop_newest`, `:block`). `:drop_oldest` involves advancing the read pointer.
    *   **Multiple Readers:** Supported by consumers tracking their own read positions.
    *   **Performance:** Designed for sub-microsecond writes.
*   **Statistics:** Provides detailed stats on utilization, writes, reads, and dropped events.

### 5.4. Pipeline Management (`ElixirScope.Capture.PipelineManager`, `AsyncWriterPool`, `AsyncWriter`)

*   **`ElixirScope.Capture.PipelineManager`:**
    *   A `Supervisor` responsible for managing the asynchronous parts of the capture pipeline.
    *   Supervises one or more `AsyncWriterPool` instances and potentially `EventCorrelator` instances.
    *   Its state (config, start time, basic stats) is maintained in an ETS table (`:pipeline_manager_state`).
*   **`ElixirScope.Capture.AsyncWriterPool`:**
    *   Manages a pool of `AsyncWriter` worker processes.
    *   Responsible for distributing the workload of reading from `RingBuffer`(s).
    *   Handles worker failures and can dynamically scale the pool size.
    *   Aggregates metrics from its workers.
*   **`ElixirScope.Capture.AsyncWriter`:**
    *   A `GenServer` worker that:
        1.  Periodically polls a `RingBuffer` for new events using `RingBuffer.read_batch/3`.
        2.  Processes events in batches.
        3.  Enriches events (e.g., with processing metadata, placeholder for future correlation ID assignment by `EventCorrelator`).
        4.  (Future/Implied) Sends enriched/correlated events to `Storage.DataAccess` for persistence.
        5.  Maintains its own read position in the `RingBuffer`.

## 6. Event Processing and Storage

This layer handles the asynchronous processing, correlation, and persistent storage of captured events.

### 6.1. Event Correlator (`ElixirScope.Capture.EventCorrelator`)

*   **Purpose:** Establishes causal relationships between events. Key for building the "Execution Cinema" DAGs. `DIAGS.md#7. Event Correlation State Machine` shows its logic.
*   **Mechanism:**
    *   A `GenServer` that processes events received (typically from `AsyncWriter`s).
    *   Uses several ETS tables to maintain correlation state:
        *   `call_stacks_table`: Stores `{pid, [correlation_ids]}` to track nested function calls per process.
        *   `message_registry_table`: Stores `{message_signature, message_record}` to link sent messages to received messages.
        *   `correlation_metadata_table`: Stores `{correlation_id, metadata}` (type, creation time, PID).
        *   `correlation_links_table`: Stores `{correlation_id, {link_type, target_id}}` to build the linkage graph.
*   **Correlation Logic:**
    *   **Function Calls:** `report_function_entry` generates a new correlation ID, pushes it to the process's call stack. `report_function_exit` pops from the stack. Nested calls establish parent-child relationships.
    *   **Messages:** `report_message_send` registers a message signature. `report_message_send` (from `handle_info` etc.) looks up this signature to find the original sender's correlation ID.
*   **Output:** Produces `CorrelatedEvent` structs containing the original event plus correlation metadata and links.
*   **Cleanup:** Periodically cleans up expired correlation data from ETS tables based on TTL.

### 6.2. Data Access Layer (`ElixirScope.Storage.DataAccess`)

*   **Storage Engine:** Primarily uses ETS tables for "hot" storage, ensuring fast writes and reads for recent data. `DIAGS.md#4. Event Storage and Indexing Structure` details this.
*   **Tables:**
    *   **Primary Table (`<name>_events`):** Stores `{event_id, event_struct}`. Type: `:set`.
    *   **Temporal Index (`<name>_temporal`):** Stores `{timestamp, event_id}`. Type: `:bag`.
    *   **Process Index (`<name>_process`):** Stores `{pid, event_id}`. Type: `:bag`.
    *   **Function Index (`<name>_function`):** Stores `{{module, function}, event_id}`. Type: `:bag`.
    *   **Correlation Index (`<name>_correlation`):** Stores `{correlation_id, event_id}`. Type: `:bag`.
    *   **Stats Table (`<name>_stats`):** Stores metadata like total events, max events, oldest/newest timestamps, and the AI instrumentation plan.
*   **Operations:**
    *   `store_event/2` and `store_events/2` (batch): Writes events and updates all relevant indexes.
    *   `get_event/2`: Retrieves an event by its ID.
    *   `query_by_time_range/4`, `query_by_process/3`, `query_by_function/4`, `query_by_correlation/3`: Use indexes to fetch event IDs and then retrieve full events from the primary table.
*   **Data Pruning:** `cleanup_old_events/2` removes events older than a specified timestamp from all tables to manage storage size.

### 6.3. Query Coordination (Future - `ElixirScope.Storage.QueryCoordinator`)

*   **Role:** Will provide a higher-level API for complex queries, potentially spanning multiple `DataAccess` instances (e.g., hot and warm storage) or nodes. It will be responsible for constructing the 7 DAGs on demand or from pre-materialized views.
*   **Status:** Currently, querying is done directly via `DataAccess`. `ElixirScope.get_events/1` and related API functions are placeholders.

## 7. Framework Integration

### 7.1. Phoenix Integration (`ElixirScope.Phoenix.Integration`)

*   **Mechanism:** Leverages Phoenix's built-in `:telemetry` events for instrumentation, minimizing direct code modification. `DIAGS.md#8. Phoenix Integration Flow` illustrates this.
*   **Events Handled:**
    *   `[:phoenix, :endpoint, :start/:stop]` for request lifecycle.
    *   `[:phoenix, :controller, :start/:stop]` for controller action timing.
    *   `[:phoenix, :live_view, :mount/:handle_event/:handle_info, :start/:stop]` for LiveView events.
    *   `[:phoenix, :channel, :join/:handle_in, :start/:stop]` for Channel events.
    *   `[:ecto, :repo, :query, :start/:stop]` for Ecto database queries.
*   **Correlation ID Propagation:**
    *   A new correlation ID is generated at `:endpoint, :start`.
    *   This ID is injected into `conn.private[:elixir_scope_correlation_id]` for HTTP requests and `socket.assigns[:elixir_scope_correlation_id]` for LiveViews.
    *   Downstream telemetry handlers retrieve this ID to link related events (e.g., controller actions, Ecto queries) to the originating request or LiveView interaction.
*   **Event Reporting:** Calls functions in `InstrumentationRuntime` (which then use `Ingestor`) to report Phoenix-specific events (e.g., `report_phoenix_request_start`, `report_ecto_query_start`).

## 8. Distributed System Support

ElixirScope aims to support tracing across distributed Elixir nodes. `DIAGS.md#9. Distributed Event Synchronization` shows the conceptual model.

### 8.1. Node Coordinator (`ElixirScope.Distributed.NodeCoordinator`)

*   **Role:** A `GenServer` on each node responsible for managing cluster membership and coordinating distributed operations.
*   **Functionality:**
    *   Node discovery (via `:net_kernel.monitor_nodes/1`) and registration within the ElixirScope cluster.
    *   Maintains a list of `cluster_nodes`.
    *   Initiates periodic event synchronization via `EventSynchronizer`.
    *   (Future) Coordinates distributed queries by fanning out queries to other nodes and aggregating results.
    *   Handles `:nodeup` and `:nodedown` events to update cluster state.

### 8.2. Event Synchronizer (`ElixirScope.Distributed.EventSynchronizer`)

*   **Purpose:** To ensure events captured on one node are eventually propagated to other nodes in the ElixirScope cluster.
*   **Mechanism:**
    1.  `sync_with_cluster/1` is called (e.g., periodically by `NodeCoordinator`).
    2.  For each other node, it determines events captured locally since the last sync with that node (`DataAccess.get_events_since/1`).
    3.  Sends these local events (potentially compressed or summarized via `prepare_events_for_sync/1`) to the target node using `:rpc.call(target_node, __MODULE__, :handle_sync_request, [sync_request])`.
    4.  `handle_sync_request/1` on the target node receives these events, stores them locally (using `store_remote_events/2`, which checks for duplicates via `DataAccess.event_exists?/1`), and sends back its own new events.
    5.  Maintains last sync times per node in an ETS table (`:elixir_scope_sync_state`).
*   **Current Status:** The code structure is present, including RPC calls. Full conflict resolution or advanced delta sync mechanisms might be areas for future enhancement.

### 8.3. Global Clock (`ElixirScope.Distributed.GlobalClock`)

*   **Goal:** To provide a mechanism for ordering events across a distributed system, crucial for reconstructing a globally consistent view of execution.
*   **Implementation Idea (Hybrid Logical Clocks):**
    *   Each event timestamp combines a logical clock component and a physical wall_time component.
    *   `now/0`: Increments local logical time and combines it with current wall time (plus a calculated offset) and the node ID.
    *   `update_from_remote/2`: When a timestamp is received from another node, the local logical clock is advanced to `max(local_logical, remote_logical) + 1`. The wall time offset might be adjusted gradually to keep clocks loosely synchronized.
*   **Current Status:** A `GenServer` implementation exists. Clock synchronization (`perform_cluster_sync/1`) involves broadcasting its current timestamp to other nodes. The "TODO for NTP" suggests physical clock sync is not yet deeply implemented.

## 9. Performance, Reliability, and Memory Management

As detailed in `DIAGS2.md` (Diagrams 1, 3, 4).

*   **Performance:**
    *   **Capture Path:** Optimized InstrumentationRuntime, Ingestor, and RingBuffer aim for sub-microsecond event handling. Batching in Ingestor/AsyncWriter improves throughput.
    *   **Storage:** ETS provides fast in-memory access. Indexing in `DataAccess` speeds up queries.
    *   **AI & AST Transformation:** These are compile-time or offline costs, designed not to impact runtime performance directly, though the *instrumented code itself* has runtime overhead.
*   **Reliability:**
    *   **Supervision:** `ElixirScope.Application` and `Capture.PipelineManager` supervise key components, enabling restarts.
    *   **Error Handling:** `try/catch` blocks are used in AST transformations and critical paths. `AsyncWriter` handles errors from RingBuffer or processing.
    *   **Circuit Breakers (Conceptual):** `InstrumentationRuntime` mentions a circuit breaker.
*   **Memory Management:**
    *   **RingBuffer:** Fixed size with overflow strategies prevents unbounded growth in the primary capture path.
    *   **DataAccess (ETS):** Pruning logic (`cleanup_old_events`) is implemented to keep hot storage bounded.
    *   **Event Truncation:** `Ingestor` and `Utils.truncate_data` limit the size of stored event payloads.

## 10. Testing Strategy

`DIAGS2.md#10. Testing Strategy Visualization` outlines the multi-level approach.

*   **Unit Tests:** Most modules have corresponding `_test.exs` files (e.g., `ring_buffer_test.exs`, `ingestor_test.exs`, `events_test.exs`). These cover individual component logic.
*   **Integration Tests:**
    *   `production_phoenix_test.exs` (though currently skipped) is designed for end-to-end testing with a real Phoenix app.
    *   Other tests implicitly cover integration (e.g., `AsyncWriterTest` tests interaction with `RingBuffer`).
*   **Performance Tests:** Tags like `@tag :performance` are used (e.g., in `RingBufferTest`) to benchmark critical operations. `Ingestor.benchmark_ingestion/3` provides a specific tool.
*   **Concurrency Tests:** `RingBufferTest` includes tests for concurrent writes and reads.
*   **Distributed Tests (Future/Basic):** Distributed tests for `NodeCoordinator` and `EventSynchronizer` would be crucial as these features mature.

The existing test suite is substantial (325 passing tests claimed), providing a good quality baseline for the foundation.

## 11. Configuration Management (`ElixirScope.Config`)

*   **Mechanism:** A `GenServer` (`ElixirScope.Config`) loads and manages the application's configuration.
*   **Sources:**
    1.  Default struct values.
    2.  Application environment (`config/*.exs`).
    3.  Environment variables (limited support, e.g., `ELIXIR_SCOPE_AI_PROVIDER`).
*   **Validation:** `Config.validate/1` checks the structure and values of the configuration against predefined rules (e.g., positive integers, valid atom values for enums).
*   **Runtime Updates:** Supports dynamic updates for specific, whitelisted configuration paths (`updatable_path?/1`) via `Config.update/2`. This allows tuning parameters like sampling rates without restarting.
*   **Access:** `Config.get/0` (full config) and `Config.get/1` (specific path) provide access to configuration values.

## 12. Future Evolution

`DIAGS2.md#12. Future Architecture Evolution` shows the progression:

*   **Phase 2: Execution Cinema:** Focus on UI, DAGs, visualization, time-travel. This requires the `QueryCoordinator` to be fully implemented and the 7 DAGs to be constructible from the correlated data.
*   **Phase 3: AI Enhancement:** Deeper LLM integration, advanced analysis, prediction, explanations.
*   **Phase 4: Production:** Full distribution, cloud-scale, security, SaaS.

The current "Foundation Complete" state provides the data capture, correlation primitives, and initial AI planning infrastructure necessary for these future phases.

## 13. Conclusion

The ElixirScope foundation represents a significant engineering effort, laying down the core components for a sophisticated AI-powered debugging and observability tool. The high-performance event capture pipeline, rule-based AI for instrumentation planning, and initial framework integrations (especially for Phoenix) are key strengths. While AST transformation is still in progress, the foundational modules are in place. The system is well-tested and designed with performance and scalability in mind, ready for the development of the "Execution Cinema" UI and more advanced AI capabilities. This technical document, in conjunction with `DIAGS.md` and `DIAGS2.md`, provides a comprehensive understanding of its architecture and implementation.