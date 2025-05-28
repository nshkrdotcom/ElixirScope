# ElixirScope API Documentation

This document provides comprehensive API documentation for ElixirScope, its components, and the Enhanced AST Repository.

## Table of Contents

1.  [Core ElixirScope API (`ElixirScope`)](#1-core-elixirscope-api-elixirscope)
2.  [Configuration Management (`ElixirScope.Config`)](#2-configuration-management-elixirscopeconfig)
3.  [Event System (`ElixirScope.Events`)](#3-event-system-elixirscopeevents)
4.  [Utilities (`ElixirScope.Utils`)](#4-utilities-elixirscopeutils)
5.  [Storage Layer](#5-storage-layer)
    *   [DataAccess (`ElixirScope.Storage.DataAccess`)](#51-dataaccess-elixirscopestoragedataaccess)
    *   [EventStore (`ElixirScope.Storage.EventStore`)](#52-eventstore-elixirscopestorageeventstore)
    *   [TemporalStorage (`ElixirScope.Capture.TemporalStorage`)](#53-temporalstorage-elixirscopecapturetemporalstorage)
6.  [Core Logic Layer](#6-core-logic-layer)
    *   [EventManager (`ElixirScope.Core.EventManager`)](#61-eventmanager-elixirscopecoreeventmanager)
    *   [StateManager (`ElixirScope.Core.StateManager`)](#62-statemanager-elixirscopecorestatemanager)
    *   [MessageTracker (`ElixirScope.Core.MessageTracker`)](#63-messagetracker-elixirscopecoremessagetracker)
    *   [AIManager (`ElixirScope.Core.AIManager`)](#64-aimanager-elixirscopecoreaimanager)
7.  [Capture Layer](#7-capture-layer)
    *   [RingBuffer (`ElixirScope.Capture.RingBuffer`)](#71-ringbuffer-elixirscopecaptureringbuffer)
    *   [Ingestor (`ElixirScope.Capture.Ingestor`)](#72-ingestor-elixirscopecaptureingestor)
    *   [InstrumentationRuntime (`ElixirScope.Capture.InstrumentationRuntime`)](#73-instrumentationruntime-elixirscopecaptureinstrumentationruntime)
    *   [AsyncWriter (`ElixirScope.Capture.AsyncWriter`)](#74-asyncwriter-elixirscopecaptureasyncwriter)
    *   [AsyncWriterPool (`ElixirScope.Capture.AsyncWriterPool`)](#75-asyncwriterpool-elixirscopecaptureasyncwriterpool)
    *   [PipelineManager (`ElixirScope.Capture.PipelineManager`)](#76-pipelinemanager-elixirscopecapturepipelinemanager)
    *   [TemporalBridge (`ElixirScope.Capture.TemporalBridge`)](#77-temporalbridge-elixirscopecapturetemporalbridge)
    *   [TemporalBridgeEnhancement (`ElixirScope.Capture.TemporalBridgeEnhancement`)](#78-temporalbridgeenhancement-elixirscopecapturetemporalbridgeenhancement)
    *   [EnhancedInstrumentation (`ElixirScope.Capture.EnhancedInstrumentation`)](#79-enhancedinstrumentation-elixirscopecaptureenhancedinstrumentation)
8.  [AST Transformation Layer](#8-ast-transformation-layer)
    *   [Transformer (`ElixirScope.AST.Transformer`)](#81-transformer-elixirscopeasttransformer)
    *   [EnhancedTransformer (`ElixirScope.AST.EnhancedTransformer`)](#82-enhancedtransformer-elixirscopeastenhancedtransformer)
    *   [InjectorHelpers (`ElixirScope.AST.InjectorHelpers`)](#83-injectorhelpers-elixirscopeastinjectorhelpers)
9.  [Enhanced AST Repository Layer](#9-enhanced-ast-repository-layer)
    *   [AST Repository Config (`ElixirScope.ASTRepository.Config`)](#91-ast-repository-config-elixirscopeastrepositoryconfig)
    *   [NodeIdentifier (`ElixirScope.ASTRepository.NodeIdentifier`)](#92-nodeidentifier-elixirscopeastrepositorynodeidentifier)
    *   [Parser (`ElixirScope.ASTRepository.Parser`)](#93-parser-elixirscopeastrepositoryparser)
    *   [ASTAnalyzer (`ElixirScope.ASTRepository.ASTAnalyzer`)](#94-astanalyzer-elixirscopeastrepositoryastanalyzer)
    *   [CFGGenerator (`ElixirScope.ASTRepository.Enhanced.CFGGenerator`)](#95-cfggenerator-elixirscopeastrepositoryenhancedcfggenerator)
    *   [DFGGenerator (`ElixirScope.ASTRepository.Enhanced.DFGGenerator`)](#96-dfggenerator-elixirscopeastrepositoryenhanceddfggenerator)
    *   [CPGBuilder (`ElixirScope.ASTRepository.Enhanced.CPGBuilder`)](#97-cpgbuilder-elixirscopeastrepositoryenhancedcpgbuilder)
    *   [EnhancedRepository (`ElixirScope.ASTRepository.Enhanced.Repository`)](#98-enhancedrepository-elixirscopeastrepositoryenhancedrepository)
    *   [ProjectPopulator (`ElixirScope.ASTRepository.Enhanced.ProjectPopulator`)](#99-projectpopulator-elixirscopeastrepositoryenhancedprojectpopulator)
    *   [FileWatcher (`ElixirScope.ASTRepository.Enhanced.FileWatcher`)](#910-filewatcher-elixirscopeastrepositoryenhancedfilewatcher)
    *   [Synchronizer (`ElixirScope.ASTRepository.Enhanced.Synchronizer`)](#911-synchronizer-elixirscopeastrepositoryenhancedsynchronizer)
    *   [QueryBuilder (`ElixirScope.ASTRepository.QueryBuilder`)](#912-querybuilder-elixirscopeastrepositoryquerybuilder)
    *   [QueryExecutor (`ElixirScope.ASTRepository.QueryExecutor`)](#913-queryexecutor-elixirscopeastrepositoryqueryexecutor)
    *   [RuntimeBridge (`ElixirScope.ASTRepository.RuntimeBridge`)](#914-runtimebridge-elixirscopeastrepositoryruntimebridge)
    *   [PatternMatcher (`ElixirScope.ASTRepository.PatternMatcher`)](#915-patternmatcher-elixirscopeastrepositorypatternmatcher)
    *   [MemoryManager (`ElixirScope.ASTRepository.MemoryManager`)](#916-memorymanager-elixirscopeastrepositorymemorymanager)
    *   [TestDataGenerator (`ElixirScope.ASTRepository.TestDataGenerator`)](#917-testdatagenerator-elixirscopeastrepositorytestdatagenerator)
10. [Query Engine Layer](#10-query-engine-layer)
    *   [Engine (`ElixirScope.QueryEngine.Engine`)](#101-engine-elixirscopequeryengineengine)
    *   [ASTExtensions (`ElixirScope.QueryEngine.ASTExtensions`)](#102-astextensions-elixirscopequeryengineastextensions)
11. [AI Layer](#11-ai-layer)
    *   [AI Bridge (`ElixirScope.AI.Bridge`)](#111-ai-bridge-elixirscopeaibridge)
    *   [IntelligentCodeAnalyzer (`ElixirScope.AI.Analysis.IntelligentCodeAnalyzer`)](#112-intelligentcodeanalyzer-elixirscopeaianalysisintelligentcodeanalyzer)
    *   [ComplexityAnalyzer (`ElixirScope.AI.ComplexityAnalyzer`)](#113-complexityanalyzer-elixirscopeaicomplexityanalyzer)
    *   [PatternRecognizer (`ElixirScope.AI.PatternRecognizer`)](#114-patternrecognizer-elixirscopeaipatternrecognizer)
    *   [CompileTime Orchestrator (`ElixirScope.CompileTime.Orchestrator`)](#115-compiletime-orchestrator-elixirscopecompiletimeorchestrator)
    *   [LLM Client (`ElixirScope.AI.LLM.Client`)](#116-llm-client-elixirscopeaillmclient)
    *   [LLM Config (`ElixirScope.AI.LLM.Config`)](#117-llm-config-elixirscopeaillmconfig)
    *   [LLM Response (`ElixirScope.AI.LLM.Response`)](#118-llm-response-elixirscopeaillmresponse)
    *   [LLM Providers](#119-llm-providers)
    *   [Predictive ExecutionPredictor (`ElixirScope.AI.Predictive.ExecutionPredictor`)](#1110-predictive-executionpredictor-elixirscopeaipredictiveexecutionpredictor)
12. [Distributed Layer](#12-distributed-layer)
    *   [GlobalClock (`ElixirScope.Distributed.GlobalClock`)](#121-globalclock-elixirscopedistributedglobalclock)
    *   [EventSynchronizer (`ElixirScope.Distributed.EventSynchronizer`)](#122-eventsynchronizer-elixirscopedistributedeventsynchronizer)
    *   [NodeCoordinator (`ElixirScope.Distributed.NodeCoordinator`)](#123-nodecoordinator-elixirscopedistributednodecoordinator)
13. [Mix Tasks](#13-mix-tasks)
    *   [Compile.ElixirScope (`Mix.Tasks.Compile.ElixirScope`)](#131-compileelixirscope-mixtaskscompileelixirscope)
14. [Integration Patterns and Best Practices](#14-integration-patterns-and-best-practices)
15. [Performance Characteristics and Limitations](#15-performance-characteristics-and-limitations)
16. [Migration Guide: Basic to Enhanced Repository](#16-migration-guide-basic-to-enhanced-repository)

---

## 1. Core ElixirScope API (`ElixirScope`)

The `ElixirScope` module is the main entry point for interacting with the ElixirScope system.

### `start(opts \\ [])`
Starts ElixirScope with the given options.
*   **Options:**
    *   `:strategy`: Instrumentation strategy (`:minimal`, `:balanced`, `:full_trace`).
    *   `:sampling_rate`: Event sampling rate (0.0 to 1.0).
    *   `:modules`: Specific modules to instrument.
    *   `:exclude_modules`: Modules to exclude.
*   **Returns:** `:ok` or `{:error, term()}`.
*   **Example:** `ElixirScope.start(strategy: :full_trace)`

### `stop()`
Stops ElixirScope and all tracing.
*   **Returns:** `:ok`.
*   **Example:** `ElixirScope.stop()`

### `status()`
Gets the current status of ElixirScope, including running state, configuration, stats, and storage usage.
*   **Returns:** `map()`.
*   **Example:** `status = ElixirScope.status()`

### `get_events(query \\ [])`
Queries captured events based on criteria.
*   **Query Options:** `:pid`, `:event_type`, `:since`, `:until`, `:limit`.
*   **Returns:** `[ElixirScope.Events.t()]` or `{:error, term()}`.
*   **Example:** `events = ElixirScope.get_events(pid: self(), limit: 100)`

### `get_state_history(pid)`
Gets the state history for a GenServer process.
*   **Returns:** `[ElixirScope.Events.StateChange.t()]` or `{:error, term()}`.
*   **Example:** `history = ElixirScope.get_state_history(pid)`

### `get_state_at(pid, timestamp)`
Reconstructs the state of a GenServer at a specific timestamp.
*   **Returns:** `term()` or `{:error, term()}`.
*   **Example:** `state = ElixirScope.get_state_at(pid, timestamp)`

### `get_message_flow(sender_pid, receiver_pid, opts \\ [])`
Gets message flow between two processes.
*   **Returns:** `[ElixirScope.Events.MessageSend.t()]` or `{:error, term()}`.
*   **Example:** `messages = ElixirScope.get_message_flow(sender_pid, receiver_pid)`

### `analyze_codebase(opts \\ [])`
Manually triggers AI analysis of the current codebase.
*   **Returns:** `:ok` or `{:error, term()}`.
*   **Example:** `ElixirScope.analyze_codebase()`

### `update_instrumentation(updates)`
Updates the instrumentation plan at runtime.
*   **Returns:** `:ok` or `{:error, term()}`.
*   **Example:** `ElixirScope.update_instrumentation(sampling_rate: 0.5)`

### `running?()`
Checks if ElixirScope is currently running.
*   **Returns:** `boolean()`.
*   **Example:** `if ElixirScope.running?(), do: ...`

### `get_config()`
Gets the current configuration.
*   **Returns:** `ElixirScope.Config.t()` or `{:error, term()}`.
*   **Example:** `config = ElixirScope.get_config()`

### `update_config(path, value)`
Updates configuration at runtime for allowed paths.
*   **Returns:** `:ok` or `{:error, term()}`.
*   **Example:** `ElixirScope.update_config([:ai, :planning, :sampling_rate], 0.8)`

---

## 2. Configuration Management (`ElixirScope.Config`)

Manages loading, validation, and runtime access to ElixirScope configuration.

### `start_link(opts \\ [])`
Starts the configuration server.
*   **Returns:** `GenServer.on_start()`.

### `get()`
Gets the current complete configuration.
*   **Returns:** `ElixirScope.Config.t()`.

### `get(path)`
Gets a specific configuration value by path (list of atoms).
*   **Returns:** `term()` or `nil`.
*   **Example:** `sampling_rate = ElixirScope.Config.get([:ai, :planning, :sampling_rate])`

### `update(path, value)`
Updates allowed configuration paths at runtime.
*   **Returns:** `:ok` or `{:error, term()}`.
*   **Example:** `ElixirScope.Config.update([:ai, :planning, :sampling_rate], 0.7)`

### `validate(config)`
Validates a configuration structure.
*   **Returns:** `{:ok, config}` or `{:error, reasons}`.

---

## 3. Event System (`ElixirScope.Events`)

Defines core event structures and utilities for serialization.

### `new_event(event_type, data, opts \\ [])`
Creates a new base event with automatic metadata.
*   **Returns:** `ElixirScope.Events.t()`.
*   **Example:** `event = ElixirScope.Events.new_event(:custom_event, %{detail: "info"})`

### `serialize(event)`
Serializes an event to binary format.
*   **Returns:** `binary()`.

### `deserialize(binary)`
Deserializes an event from binary format.
*   **Returns:** `ElixirScope.Events.t()`.

#### Event Structs
The module defines various event structs like `FunctionEntry`, `FunctionExit`, `ProcessSpawn`, `MessageSend`, etc. Each has specific fields relevant to the event type. Consult the source file for detailed struct definitions.

---

## 4. Utilities (`ElixirScope.Utils`)

Provides high-performance utilities for timestamps, ID generation, data inspection, and performance measurement.

### `monotonic_timestamp()`
Generates a high-resolution monotonic timestamp in nanoseconds.
*   **Returns:** `integer()`.

### `wall_timestamp()`
Generates a wall clock timestamp in nanoseconds.
*   **Returns:** `integer()`.

### `format_timestamp(timestamp_ns)`
Converts a nanosecond timestamp to a human-readable string.
*   **Returns:** `String.t()`.

### `measure(fun)`
Measures execution time of a 0-arity function in nanoseconds.
*   **Returns:** `{result, duration_ns :: integer()}`.

### `generate_id()`
Generates a unique, roughly sortable integer ID.
*   **Returns:** `integer()`.

### `generate_correlation_id()`
Generates a unique UUID v4 string for correlation.
*   **Returns:** `String.t()`.

### `id_to_timestamp(id)`
Extracts the timestamp component from a generated ID.
*   **Returns:** `integer()`.

### `safe_inspect(term, opts \\ [])`
Safely inspects a term with size limits.
*   **Returns:** `String.t()`.

### `truncate_if_large(term, max_size \\ 5000)`
Truncates a term if its binary representation exceeds `max_size`.
*   **Returns:** `term()` or `{:truncated, binary_size, type_hint}`.

### `term_size(term)`
Estimates the memory footprint of a term in bytes.
*   **Returns:** `non_neg_integer()`.

### `measure_memory(fun)`
Measures memory usage before and after executing a 0-arity function.
*   **Returns:** `{result, {memory_before, memory_after, memory_diff}}`.

### `process_stats(pid \\ self())`
Gets current statistics for a given process.
*   **Returns:** `map()`.

### `system_stats()`
Gets system-wide performance statistics.
*   **Returns:** `map()`.

### `format_bytes(bytes)`
Formats a byte size into a human-readable string (KB, MB, GB).
*   **Returns:** `String.t()`.

### `format_duration(nanoseconds)`
Formats a duration in nanoseconds into a human-readable string (μs, ms, s).
*   **Returns:** `String.t()`.

### `valid_positive_integer?(value)`
Validates if a value is a positive integer.
*   **Returns:** `boolean()`.

### `valid_percentage?(value)`
Validates if a value is a percentage (0.0 to 1.0).
*   **Returns:** `boolean()`.

### `valid_pid?(pid)`
Validates if a PID exists and is alive.
*   **Returns:** `boolean()`.

---

## 5. Storage Layer

### 5.1. DataAccess (`ElixirScope.Storage.DataAccess`)

High-performance ETS-based storage for ElixirScope events with multiple indexes.

### `new(opts \\ [])`
Creates a new DataAccess instance with ETS tables.
*   **Options:** `:name`, `:max_events`.
*   **Returns:** `{:ok, ElixirScope.Storage.DataAccess.t()}` or `{:error, term()}`.

### `store_event(storage, event)`
Stores a single event.
*   **Returns:** `:ok` or `{:error, term()}`.

### `store_events(storage, events)`
Stores multiple events in batch.
*   **Returns:** `{:ok, count_stored}` or `{:error, term()}`.

### `get_event(storage, event_id)`
Retrieves an event by its ID.
*   **Returns:** `{:ok, ElixirScope.Events.event()}` or `{:error, :not_found}`.

### `query_by_time_range(storage, start_time, end_time, opts \\ [])`
Queries events by time range.
*   **Options:** `:limit`, `:order` (`:asc` or `:desc`).
*   **Returns:** `{:ok, [ElixirScope.Events.event()]}` or `{:error, term()}`.

### `query_by_process(storage, pid, opts \\ [])`
Queries events by process ID.
*   **Returns:** `{:ok, [ElixirScope.Events.event()]}` or `{:error, term()}`.

### `query_by_function(storage, module, function, opts \\ [])`
Queries events by function (module and function name).
*   **Returns:** `{:ok, [ElixirScope.Events.event()]}` or `{:error, term()}`.

### `query_by_correlation(storage, correlation_id, opts \\ [])`
Queries events by correlation ID.
*   **Returns:** `{:ok, [ElixirScope.Events.event()]}` or `{:error, term()}`.

### `get_stats(storage)`
Gets storage statistics (event counts, memory usage, timestamps).
*   **Returns:** `map()`.

### `cleanup_old_events(storage, cutoff_timestamp)`
Removes events older than the specified timestamp.
*   **Returns:** `{:ok, count_removed}` or `{:error, term()}`.

### `destroy(storage)`
Destroys the storage and cleans up ETS tables.
*   **Returns:** `:ok`.

*(Note: `get_events_since/1`, `event_exists?/1`, `store_events/1` (simplified arity), `get_instrumentation_plan/0`, `store_instrumentation_plan/1` are utility functions using a default storage instance, typically for simpler internal use or testing.)*

### 5.2. EventStore (`ElixirScope.Storage.EventStore`)

A GenServer wrapper around `ElixirScope.Storage.DataAccess` providing a global, supervised event store. It also provides a compatible `store_event/3` API for components expecting it.

### `start_link(opts \\ [])`
Starts the EventStore GenServer.
*   **Returns:** `GenServer.on_start()`.

### `store_event(store, event)`
Stores a single event using the underlying DataAccess instance.
*   **Returns:** `GenServer.on_start()`. (via `GenServer.call`)

### `query_events(store, filters)`
Queries events using the underlying DataAccess instance.
*   **Returns:** `GenServer.on_start()`. (via `GenServer.call`)

### `get_index_stats(store)`
Gets indexing statistics from the underlying DataAccess instance.
*   **Returns:** `GenServer.on_start()`. (via `GenServer.call`)

### `get_events_via_data_access(store)`
For integration testing, retrieves events directly.
*   **Returns:** `GenServer.on_start()`. (via `GenServer.call`)

*(Note: The `ElixirScope.EventStore` module is a separate wrapper for `ElixirScope.Storage.EventStore` providing a simplified `store_event/3` API and managing a global default instance. Its API is simpler and primarily for internal use by older components.)*

### 5.3. TemporalStorage (`ElixirScope.Capture.TemporalStorage`)

Specialized storage for events with temporal indexing and AST correlation, designed for Cinema Debugger functionality.

### `start_link(opts \\ [])`
Starts a new TemporalStorage process.
*   **Options:** `:name`, `:max_events`, `:cleanup_interval`.
*   **Returns:** `{:ok, pid()}` or `{:error, term()}`.

### `store_event(storage_ref, event)`
Stores an event with temporal indexing. Events are expected to be maps with `:timestamp`, `:ast_node_id` (optional), `:correlation_id` (optional), and `:data`.
*   **Returns:** `:ok` or `{:error, term()}` (via GenServer call).

### `get_events_in_range(storage_ref, start_time, end_time)`
Retrieves events within a time range, ordered chronologically.
*   **Returns:** `{:ok, [event()]}` or `{:error, term()}`.

### `get_events_for_ast_node(storage_ref, ast_node_id)`
Gets events associated with a specific AST node ID.
*   **Returns:** `{:ok, [event()]}` or `{:error, term()}`.

### `get_events_for_correlation(storage_ref, correlation_id)`
Gets events associated with a specific correlation ID.
*   **Returns:** `{:ok, [event()]}` or `{:error, term()}`.

### `get_all_events(storage_ref)`
Gets all events in chronological order.
*   **Returns:** `{:ok, [event()]}` or `{:error, term()}`.

### `get_stats(storage_ref)`
Gets storage statistics.
*   **Returns:** `{:ok, map()}` or `{:error, term()}`.

---

## 6. Core Logic Layer

### 6.1. EventManager (`ElixirScope.Core.EventManager`)

Manages runtime event querying and filtering, bridging `RuntimeCorrelator` with the main API.

### `get_events(opts \\ [])`
Gets events based on query criteria. Delegates to `QueryEngine` or `RuntimeCorrelator`.
*   **Query Options:** `:pid`, `:event_type`, `:since`, `:until`, `:limit`.
*   **Returns:** `{:ok, [map()]}` or `{:error, term()}`.

### `get_events_with_query(query)`
Gets events with a map or function-based query.
*   **Returns:** `{:ok, [map()]}` or `{:error, term()}`.

### `get_events_for_ast_node(ast_node_id)`
Gets events for a specific AST node ID (delegates to `RuntimeCorrelator`).
*   **Returns:** `{:ok, [map()]}` or `{:error, term()}`.

### `get_correlation_statistics()`
Gets correlation statistics from `RuntimeCorrelator`.
*   **Returns:** `{:ok, map()}` or `{:error, term()}`.

### 6.2. StateManager (`ElixirScope.Core.StateManager`)

Manages process state history and temporal queries.

### `get_state_history(pid)`
Gets the state history for a GenServer process.
*   **Returns:** `{:ok, [map()]}` or `{:error, term()}`. (Currently returns `{:error, :not_implemented_yet}` or `{:ok, []}` if tracking disabled/no events).

### `get_state_at(pid, timestamp)`
Reconstructs the state of a GenServer at a specific timestamp.
*   **Returns:** `{:ok, term()}` or `{:error, term()}`. (Currently reconstructs from most recent `:state_change` event before timestamp).

### `has_state_history?(pid)`
Checks if state history data is available for a process.
*   **Returns:** `boolean()`. (Currently returns `false`).

### `get_statistics()`
Gets state tracking statistics.
*   **Returns:** `{:ok, map()}` or `{:error, term()}`.

### 6.3. MessageTracker (`ElixirScope.Core.MessageTracker`)

Tracks message flows between processes.

### `get_message_flow(from_pid, to_pid, opts \\ [])`
Gets message flow between two processes.
*   **Returns:** `{:ok, [map()]}` or `{:error, term()}`. (Correlates send/receive events).

### `get_process_messages(pid, opts \\ [])`
Gets all incoming and outgoing messages for a specific process.
*   **Returns:** `{:ok, map()}` or `{:error, term()}`. (Currently returns `{:error, :not_implemented_yet}` if tracking disabled).

### `get_statistics()`
Gets message flow statistics.
*   **Returns:** `{:ok, map()}` or `{:error, term()}`.

### `tracking_enabled?(pid)`
Checks if message tracking is enabled for a process.
*   **Returns:** `boolean()`. (Currently returns `false`).

### `enable_tracking(pid)` / `disable_tracking(pid)`
Enables/disables message tracking for a process.
*   **Returns:** `:ok` or `{:error, term()}`. (Currently returns `{:error, :not_implemented}`).

### 6.4. AIManager (`ElixirScope.Core.AIManager`)

Manages AI integration and analysis capabilities.

### `analyze_codebase(opts \\ [])`
Analyzes the codebase using AI capabilities.
*   **Returns:** `{:ok, map()}` or `{:error, term()}`. (Currently returns `{:error, :not_implemented_yet}` if AI disabled).

### `update_instrumentation(config)`
Updates instrumentation configuration based on AI recommendations.
*   **Returns:** `{:ok, map()}` or `{:error, term()}`. (Currently returns `{:error, :not_implemented_yet}` if AI disabled).

### `get_statistics()` / `available?()` / `get_model_info()` / `configure(opts)` / `recommend_instrumentation(modules)`
Various functions for AI management. (Currently mostly placeholders or return `{:error, :not_implemented}`).

---

## 7. Capture Layer

### 7.1. RingBuffer (`ElixirScope.Capture.RingBuffer`)

High-performance lock-free ring buffer for event ingestion.

### `new(opts \\ [])`
Creates a new ring buffer.
*   **Options:** `:size` (power of 2), `:overflow_strategy` (`:drop_oldest`, `:drop_newest`, `:block`), `:name`.
*   **Returns:** `{:ok, ElixirScope.Capture.RingBuffer.t()}` or `{:error, term()}`.

### `write(buffer, event)`
Writes an event to the ring buffer. Critical hot path.
*   **Returns:** `:ok` or `{:error, :buffer_full}`.

### `read(buffer, read_position \\ 0)`
Reads the next available event from the buffer.
*   **Returns:** `{:ok, event, new_position}` or `:empty`.

### `read_batch(buffer, start_position, count)`
Reads multiple events in batch.
*   **Returns:** `{[ElixirScope.Events.event()], new_position}`.

### `stats(buffer)` / `size(buffer)` / `clear(buffer)` / `destroy(buffer)`
Utility functions for buffer management.

### 7.2. Ingestor (`ElixirScope.Capture.Ingestor`)

Ultra-fast event ingestor, acts as the hot path for event capture.

### `get_buffer()` / `set_buffer(buffer)`
Manages the shared ring buffer for runtime components.

### `ingest_function_call(buffer, module, function, args, caller_pid, correlation_id)`
Ingests a function call event. Optimized for speed.
*   **Returns:** `ingest_result :: :ok | {:error, term()}`.

### `ingest_function_return(buffer, return_value, duration_ns, correlation_id)`
Ingests a function return event.
*   **Returns:** `ingest_result`.

### `ingest_process_spawn(buffer, parent_pid, child_pid)`
Ingests a process spawn event.
*   **Returns:** `ingest_result`.

### `ingest_message_send(buffer, from_pid, to_pid, message)`
Ingests a message send event.
*   **Returns:** `ingest_result`.

### `ingest_state_change(buffer, server_pid, old_state, new_state)`
Ingests a state change event.
*   **Returns:** `ingest_result`.

### `ingest_performance_metric(buffer, metric_name, value, metadata \\ %{})`
Ingests a performance metric event.
*   **Returns:** `ingest_result`.

### `ingest_error(buffer, error_type, error_message, stacktrace)`
Ingests an error event.
*   **Returns:** `ingest_result`.

### `ingest_batch(buffer, events)`
Ingests multiple events in batch.
*   **Returns:** `{:ok, count_ingested}` or `{:error, term()}`.

### `create_fast_ingestor(buffer)`
Creates a pre-configured ingestor function for a specific buffer.
*   **Returns:** `(ElixirScope.Events.event() -> ingest_result)`.

### `benchmark_ingestion(buffer, sample_event, iterations \\ 1000)`
Measures ingestion performance.
*   **Returns:** `map()` with timing statistics.

### `validate_performance(buffer)`
Validates if ingestion performance meets targets.
*   **Returns:** `:ok` or `{:error, term()}`.

*(Includes Phoenix, LiveView, Ecto, GenServer, and Distributed specific ingestors like `ingest_phoenix_request_start`, `ingest_liveview_mount_start`, etc.)*

### 7.3. InstrumentationRuntime (`ElixirScope.Capture.InstrumentationRuntime`)

Runtime API for instrumented code to report events. This module is called by transformed AST.

### `report_function_entry(module, function, args)`
Reports a function call entry.
*   **Returns:** `correlation_id :: term()` or `nil`.

### `report_function_exit(correlation_id, return_value, duration_ns)`
Reports a function call exit.
*   **Returns:** `:ok`.

*(Other `report_*` functions for process spawn, message send, state change, errors, etc. follow a similar pattern.)*

#### AST-Aware Reporting (Enhanced)
These functions are called by AST transformed with `EnhancedTransformer` and include `ast_node_id`.

### `report_ast_function_entry_with_node_id(module, function, args, correlation_id, ast_node_id)`
Reports function entry with AST node ID.
*   **Returns:** `:ok`.

### `report_ast_function_exit_with_node_id(correlation_id, return_value, duration_ns, ast_node_id)`
Reports function exit with AST node ID.
*   **Returns:** `:ok`.

### `report_ast_variable_snapshot(correlation_id, variables, line, ast_node_id)`
Reports a local variable snapshot with AST node correlation.
*   **Returns:** `:ok`.

### `report_ast_expression_value(correlation_id, expression, value, line, ast_node_id)`
Reports an expression value with AST node correlation.
*   **Returns:** `:ok`.

### `report_ast_line_execution(correlation_id, line, context, ast_node_id)`
Reports line execution with AST node correlation.
*   **Returns:** `:ok`.

*(Other AST-specific reporting functions like `report_ast_pattern_match`, `report_ast_branch_execution`, `report_ast_loop_iteration` exist.)*

### Context Management
### `initialize_context()` / `clear_context()` / `enabled?()` / `current_correlation_id()`
Manage the per-process instrumentation context.

### `with_instrumentation_disabled(fun)`
Temporarily disables instrumentation for the current process during `fun` execution.

### `get_ast_correlation_metadata()`
Returns metadata for correlating runtime events with AST nodes.

### `validate_ast_node_id(ast_node_id)`
Validates the format of an AST node ID.
*   **Returns:** `{:ok, ast_node_id}` or `{:error, reason}`.

*(Includes Phoenix, LiveView, Ecto, GenServer, and Distributed specific reporting functions like `report_phoenix_request_start`, `report_liveview_mount_start`, etc. These mirror the Ingestor API but are intended for direct calls from instrumented code.)*

### 7.4. AsyncWriter (`ElixirScope.Capture.AsyncWriter`)

Worker process that consumes events from ring buffers, enriches, and processes them. Managed by `AsyncWriterPool`.

### `start_link(config)`
Starts an AsyncWriter worker.
*   **Config:** `:ring_buffer`, `:batch_size`, `:poll_interval_ms`, `:max_backlog`.
*   **Returns:** `GenServer.on_start()`.

### `get_state(pid)` / `get_metrics(pid)` / `set_position(pid, position)` / `stop(pid)`
Management functions for the worker.

### `enrich_event(event)`
Enriches an event with correlation and processing metadata.
*   **Returns:** Enriched `event :: map()`.

### 7.5. AsyncWriterPool (`ElixirScope.Capture.AsyncWriterPool`)

Manages a pool of `AsyncWriter` processes.

### `start_link(opts \\ [])`
Starts the AsyncWriterPool.
*   **Config:** `:pool_size`, `:ring_buffer`, `:batch_size`, etc. (passed to workers).
*   **Returns:** `GenServer.on_start()`.

### `get_state(pid)` / `scale_pool(pid, new_size)` / `get_metrics(pid)` / `get_worker_assignments(pid)` / `health_check(pid)` / `stop(pid)`
Management functions for the pool.

### 7.6. PipelineManager (`ElixirScope.Capture.PipelineManager`)

Supervises Layer 2 asynchronous processing components like `AsyncWriterPool`.

### `start_link(opts \\ [])`
Starts the PipelineManager supervisor.
*   **Returns:** `Supervisor.on_start()`.

### `get_state(pid \\ __MODULE__)` / `update_config(pid \\ __MODULE__, new_config)` / `health_check(pid \\ __MODULE__)` / `get_metrics(pid \\ __MODULE__)` / `shutdown(pid \\ __MODULE__)`
Management functions for the pipeline.

### 7.7. TemporalBridge (`ElixirScope.Capture.TemporalBridge`)

Bridge between `InstrumentationRuntime` and `TemporalStorage` for real-time temporal correlation.

### `start_link(opts \\ [])`
Starts the TemporalBridge process.
*   **Options:** `:name`, `:temporal_storage`, `:buffer_size`, `:flush_interval`.
*   **Returns:** `GenServer.on_start()`.

### `correlate_event(bridge_ref, temporal_event)`
Correlates and stores a runtime event with temporal indexing. Called by `InstrumentationRuntime`.
*   **Returns:** `:ok` or `{:error, term()}` (via GenServer cast).

### `get_events_in_range(bridge_ref, start_time, end_time)`
Retrieves events within a time range.
*   **Returns:** `{:ok, [temporal_event()]}` or `{:error, term()}`.

### `get_events_for_ast_node(bridge_ref, ast_node_id)`
Gets events associated with a specific AST node ID.
*   **Returns:** `{:ok, [temporal_event()]}` or `{:error, term()}`.

### `get_events_for_correlation(bridge_ref, correlation_id)`
Gets events associated with a specific correlation ID.
*   **Returns:** `{:ok, [temporal_event()]}` or `{:error, term()}`.

### `get_stats(bridge_ref)` / `flush_buffer(bridge_ref)`
Management functions.

#### Cinema Debugger Interface
### `reconstruct_state_at(bridge_ref, timestamp)`
Reconstructs system state at a specific point in time.
*   **Returns:** `{:ok, map()}` or `{:error, term()}`.

### `trace_execution_path(bridge_ref, target_event)`
Reconstructs the execution sequence that led to a particular event.
*   **Returns:** `{:ok, [temporal_event()]}` or `{:error, term()}`.

### `get_active_ast_nodes(bridge_ref, start_time, end_time)`
Shows AST nodes active during a specific time window.
*   **Returns:** `{:ok, [ast_node_id()]}` or `{:error, term()}`.

### Integration with InstrumentationRuntime
### `register_as_handler(bridge_ref)` / `unregister_handler()` / `get_registered_bridge()`
Manages the global registration of the bridge for `InstrumentationRuntime`.

### 7.8. TemporalBridgeEnhancement (`ElixirScope.Capture.TemporalBridgeEnhancement`)

Extends `TemporalBridge` with AST integration for AST-aware time-travel debugging.

### `start_link(opts \\ [])`
Starts the TemporalBridgeEnhancement process.
*   **Options:** `:temporal_bridge`, `:ast_repo`, `:correlator`, `:event_store`, `:enabled`.
*   **Returns:** `GenServer.on_start()`.

### `reconstruct_state_with_ast(session_id, timestamp, ast_repo \\ nil)`
Reconstructs state with AST context.
*   **Returns:** `{:ok, ast_enhanced_state :: map()}` or `{:error, term()}`.

### `get_ast_execution_trace(session_id, start_time, end_time)`
Gets an AST-aware execution trace for a time range.
*   **Returns:** `{:ok, ast_execution_trace :: map()}` or `{:error, term()}`.

### `get_states_for_ast_node(session_id, ast_node_id)`
Gets all states associated with a specific AST node ID.
*   **Returns:** `{:ok, [ast_enhanced_state :: map()]}` or `{:error, term()}`.

### `get_execution_flow_between_nodes(session_id, from_ast_node_id, to_ast_node_id, time_range \\ nil)`
Shows execution path and state transitions between two AST nodes.
*   **Returns:** `{:ok, execution_flow :: map()}` or `{:error, term()}`.

### `set_enhancement_enabled(enabled)` / `get_enhancement_stats()` / `clear_caches()`
Management functions.

### 7.9. EnhancedInstrumentation (`ElixirScope.Capture.EnhancedInstrumentation`)

Integrates AST-correlation for advanced debugging features like structural breakpoints and semantic watchpoints.

### `start_link(opts \\ [])`
Starts the EnhancedInstrumentation process.
*   **Options:** `:ast_repo`, `:correlator`, `:enabled`, `:ast_correlation_enabled`.
*   **Returns:** `GenServer.on_start()`.

### `enable_ast_correlation()` / `disable_ast_correlation()`
Controls AST correlation for events.

### `set_structural_breakpoint(breakpoint_spec)`
Sets a breakpoint that triggers on AST patterns.
*   **Returns:** `{:ok, breakpoint_id :: String.t()}` or `{:error, term()}`.

### `set_data_flow_breakpoint(breakpoint_spec)`
Sets a breakpoint that triggers on variable flow through AST paths.
*   **Returns:** `{:ok, breakpoint_id :: String.t()}` or `{:error, term()}`.

### `set_semantic_watchpoint(watchpoint_spec)`
Sets a watchpoint to track variables through AST structure.
*   **Returns:** `{:ok, watchpoint_id :: String.t()}` or `{:error, term()}`.

### `remove_breakpoint(breakpoint_id)` / `list_breakpoints()` / `get_stats()`
Breakpoint management and statistics.

### Enhanced Reporting Functions
These are called by the enhanced AST transformer.
*   `report_enhanced_function_entry(module, function, args, correlation_id, ast_node_id)`
*   `report_enhanced_function_exit(correlation_id, return_value, duration_ns, ast_node_id)`
*   `report_enhanced_variable_snapshot(correlation_id, variables, line, ast_node_id)`
All return `:ok`.

---

## 8. AST Transformation Layer

### 8.1. Transformer (`ElixirScope.AST.Transformer`)

Core AST transformation engine for injecting basic instrumentation.

### `transform_module(ast, plan)`
Transforms a complete module AST based on the instrumentation plan.
*   **Returns:** Transformed `ast :: Macro.t()`.

### `transform_function(function_ast, plan)`
Transforms a single function definition.
*   **Returns:** Transformed `function_ast :: Macro.t()`.

*(Specific transformation functions for GenServer, Phoenix Controller, LiveView callbacks also exist.)*

### 8.2. EnhancedTransformer (`ElixirScope.AST.EnhancedTransformer`)

Enhanced AST transformer for granular compile-time instrumentation, providing "Cinema Data".

### `transform_with_enhanced_instrumentation(ast, plan)`
Transforms AST with enhanced capabilities like local variable capture and expression tracing.
*   **Returns:** Transformed `ast :: Macro.t()`.

### `transform_with_granular_instrumentation(ast, plan)`
Transforms AST with fine-grained instrumentation based on the plan.
*   **Returns:** Transformed `ast :: Macro.t()`.

### `inject_local_variable_capture(ast, plan)`
Injects local variable capture at specified lines or after expressions.
*   **Returns:** Transformed `ast :: Macro.t()`.

### `inject_expression_tracing(ast, plan)`
Injects expression tracing for specified expressions.
*   **Returns:** Transformed `ast :: Macro.t()`.

### `inject_custom_debugging_logic(ast, plan)`
Injects custom debugging logic AST snippets at specified points.
*   **Returns:** Transformed `ast :: Macro.t()`.

### 8.3. InjectorHelpers (`ElixirScope.AST.InjectorHelpers`)

Helper functions for generating AST snippets for instrumentation calls. These are primarily internal to the transformation process.

---

## 9. Enhanced AST Repository Layer

This layer provides storage and advanced analysis of code, including CFG, DFG, and CPG.

### 9.1. AST Repository Config (`ElixirScope.ASTRepository.Config`)

Centralized configuration for AST Repository components.

### `get(key_path, default_value \\ nil)` / `get(key, default_value \\ nil)`
Gets a configuration value.
*   **Returns:** `term()`.

### `repository_genserver_name()` / `populator_include_deps?()` / `analysis_timeout_ms()` etc.
Accessor functions for specific configuration values with defaults. Consult the source for a full list.

### `all_configs()`
Returns all AST repository configurations as a map.

### 9.2. NodeIdentifier (`ElixirScope.ASTRepository.NodeIdentifier`)

Manages generation, parsing, and validation of unique AST Node IDs.

### `assign_ids_to_ast(ast, initial_context)`
Assigns unique AST node IDs to traversable nodes in an AST, injecting them into node metadata.
*   **Returns:** Transformed `ast :: Macro.t()`.

### `generate_id_for_current_node(node, context)`
Generates a unique AST Node ID based on the node and its context.
*   **Returns:** `ast_node_id :: String.t()`.

### `get_id_from_ast_meta(meta)`
Extracts an AST Node ID from a node's metadata.
*   **Returns:** `ast_node_id :: String.t()` or `nil`.

### `parse_id(ast_node_id)`
Parses an AST Node ID string into its constituent parts.
*   **Returns:** `{:ok, map()}` or `{:error, :invalid_format}`.

### `assign_ids_custom_traverse(ast_node, context)`
Alternative traversal for assigning IDs with more path control (often used internally or by `TestDataGenerator`).
*   **Returns:** Transformed `ast :: Macro.t()`.

### 9.3. Parser (`ElixirScope.ASTRepository.Parser`)

Enhanced AST parser that assigns unique node IDs and extracts instrumentation points. (Note: This refers to the "new" parser logic, potentially integrated into `ASTAnalyzer` or used by `ProjectPopulator`).

### `assign_node_ids(ast)`
Assigns unique node IDs to instrumentable AST nodes.
*   **Returns:** `{:ok, enhanced_ast}` or `{:error, reason}`.
*   **Example:** `{:ok, enhanced_ast} = Parser.assign_node_ids(original_ast)`

### `extract_instrumentation_points(enhanced_ast)`
Extracts instrumentation points from an AST that has already had node IDs assigned.
*   **Returns:** `{:ok, instrumentation_points :: [map()]}` or `{:error, reason}`.

### `build_correlation_index(enhanced_ast, instrumentation_points)`
Builds a map of `correlation_id -> ast_node_id`.
*   **Returns:** `{:ok, correlation_index :: map()}` or `{:error, reason}`.

### 9.4. ASTAnalyzer (`ElixirScope.ASTRepository.ASTAnalyzer`)

Performs comprehensive AST analysis, populating `EnhancedModuleData` and `EnhancedFunctionData`.

### `analyze_module_ast(module_ast, module_name, file_path, opts \\ [])`
Analyzes a module's AST.
*   **Returns:** `{:ok, ElixirScope.ASTRepository.EnhancedModuleData.t()}` or `{:error, term()}`.

### `analyze_function_ast(fun_ast, module_name, fun_name, arity, file_path, ast_node_id_prefix, opts \\ [])`
Analyzes a single function's AST.
*   **Returns:** `{:ok, ElixirScope.ASTRepository.EnhancedFunctionData.t()}` or `{:error, term()}`.

*(Internal helper functions extract dependencies, attributes, complexities, etc.)*

### 9.5. CFGGenerator (`ElixirScope.ASTRepository.Enhanced.CFGGenerator`)

Enhanced Control Flow Graph generator.

### `generate_cfg(function_ast, opts \\ [])`
Generates a CFG for an Elixir function.
*   **Options:** `:function_key`, `:include_path_analysis`, `:max_paths`.
*   **Returns:** `{:ok, ElixirScope.ASTRepository.Enhanced.CFGData.t()}` or `{:error, term()}`.

### 9.6. DFGGenerator (`ElixirScope.ASTRepository.Enhanced.DFGGenerator`)

Enhanced Data Flow Graph generator using SSA form.

### `generate_dfg(function_ast, opts \\ [])`
Generates a DFG for an Elixir function. (Note: the code shows `generate_dfg/1` and `generate_dfg/2`, the `docs/docs20250527_2/CODE_PROPERTY_GRAPH_DESIGN_ENHANCE/4-dfg_generator.ex` shows `generate_dfg/3`. Assuming the 2-arity is the primary one for the enhanced version).
*   **Returns:** `{:ok, ElixirScope.ASTRepository.Enhanced.DFGData.t()}` or `{:error, term()}`.

### `trace_variable(dfg, variable_name)`
Traces a variable through its data flow. (Note: This function is defined in the older `WRITEUP_CURSOR/4-dfg_generator.ex` but conceptually belongs here).
*   **Returns:** `{:ok, map()}` or `{:error, term()}`.

### `get_dependencies(dfg, variable_name)`
Gets all dependencies for a variable.
*   **Returns:** `[String.t()]` (list of variable names it depends on).

### 9.7. CPGBuilder (`ElixirScope.ASTRepository.Enhanced.CPGBuilder`)

Builds a Code Property Graph by unifying AST, CFG, and DFG.

### `build_cpg(ast, opts \\ [])`
Builds a CPG for a given function's AST. (Note: the code shows `build_cpg/2` taking AST, the older `WRITEUP_CURSOR/5-cpg_builder.ex` takes `EnhancedFunctionData`).
*   **Returns:** `{:ok, ElixirScope.ASTRepository.Enhanced.CPGData.t()}` or `{:error, term()}`.

### `query_cpg(cpg, query)`
Queries the CPG for nodes matching specific criteria. (Defined in older `WRITEUP_CURSOR/5-cpg_builder.ex`).
*   **Returns:** `{:ok, [CPGNode.t()]}` or `{:error, term()}`.

### `find_pattern(cpg, pattern_spec)`
Finds patterns in the CPG based on graph structure. (Defined in older `WRITEUP_CURSOR/5-cpg_builder.ex`).
*   **Returns:** `{:ok, [map()]}` or `{:error, term()}`.

### 9.8. EnhancedRepository (`ElixirScope.ASTRepository.Enhanced.Repository`)

Central GenServer for storing and managing all enhanced AST-related data (EnhancedModuleData, EnhancedFunctionData, CFG, DFG, CPG).

### `start_link(opts \\ [])`
Starts the EnhancedRepository GenServer.
*   **Options:** `:name`, `:memory_limit`.
*   **Returns:** `GenServer.on_start()`.

### `store_enhanced_module(module_name, ast, opts \\ [])`
Stores enhanced module data with advanced analysis. (Note: This is different from `store_module/2` which takes `EnhancedModuleData.t()`).
*   **Returns:** `GenServer.on_start()`. (via `GenServer.call`)

### `get_enhanced_module(module_name)`
Retrieves enhanced module data.
*   **Returns:** `{:ok, ElixirScope.ASTRepository.Enhanced.EnhancedModuleData.t()}` or `{:error, :not_found}`.

### `store_enhanced_function(module_name, function_name, arity, ast, opts \\ [])`
Stores enhanced function data with CFG/DFG analysis.
*   **Returns:** `GenServer.on_start()`. (via `GenServer.call`)

### `get_enhanced_function(module_name, function_name, arity)`
Retrieves enhanced function data.
*   **Returns:** `{:ok, ElixirScope.ASTRepository.Enhanced.EnhancedFunctionData.t()}` or `{:error, :not_found}`.

### `get_cfg(module_name, function_name, arity)`
Generates or retrieves CFG for a function.
*   **Returns:** `{:ok, ElixirScope.ASTRepository.Enhanced.CFGData.t()}` or `{:error, term()}`.

### `get_dfg(module_name, function_name, arity)`
Generates or retrieves DFG for a function.
*   **Returns:** `{:ok, ElixirScope.ASTRepository.Enhanced.DFGData.t()}` or `{:error, term()}`.

### `get_cpg(module_name, function_name, arity)`
Generates or retrieves CPG for a function.
*   **Returns:** `{:ok, ElixirScope.ASTRepository.Enhanced.CPGData.t()}` or `{:error, term()}`.

### `query_analysis(query_type, params \\ %{})`
Performs advanced analysis queries (complexity, security, performance, etc.).
*   **Returns:** `GenServer.on_start()`. (via `GenServer.call`)

### `get_performance_metrics()`
Gets performance metrics for repository analysis operations.
*   **Returns:** `{:ok, map()}`.

### `populate_project(project_path, opts \\ [])`
Populates repository with project AST data using `ProjectPopulator`.
*   **Returns:** `GenServer.on_start()`. (via `GenServer.call`)

### `clear_repository()` / `get_statistics()` / `health_check(pid)` / `get_ast_node(pid, ast_node_id)` / `find_references(pid, m, f, a)` / `correlate_event_to_ast(pid, event)`
Standard repository management and query functions, adapted for enhanced data.

### 9.9. ProjectPopulator (`ElixirScope.ASTRepository.Enhanced.ProjectPopulator`)

Populates the Enhanced AST Repository by discovering, parsing, and analyzing project files.

### `populate_project(repo, project_path, opts \\ [])`
Populates the repository with data from an Elixir project.
*   **Options:** `:include_patterns`, `:exclude_patterns`, `:max_file_size`, `:parallel_processing`, `:generate_cfg`, `:generate_dfg`, `:generate_cpg`.
*   **Returns:** `{:ok, results_map}` or `{:error, reason}`. `results_map` contains stats about processed files, modules, functions, and duration.

### `parse_and_analyze_file(file_path)`
Parses and analyzes a single file. Used by `Synchronizer`.
*   **Returns:** `{:ok, ElixirScope.ASTRepository.Enhanced.EnhancedModuleData.t()}` or `{:error, reason}`.

### `discover_elixir_files(project_path, opts \\ [])`
Discovers Elixir source files in a project.
*   **Returns:** `{:ok, [String.t()]}` or `{:error, term()}`.

### `parse_files(files, opts \\ [])`
Parses AST from discovered files.
*   **Returns:** `{:ok, [parsed_file_map]}` or `{:error, term()}`.

### `analyze_modules(parsed_files, opts \\ [])`
Analyzes parsed modules with enhanced analysis (CFG, DFG, CPG).
*   **Returns:** `{:ok, %{module_name => EnhancedModuleData.t()}}` or `{:error, term()}`.

### `build_dependency_graph(analyzed_modules, opts \\ [])`
Builds dependency graph from analyzed modules.
*   **Returns:** `{:ok, dependency_graph_map}` or `{:error, term()}`.

### 9.10. FileWatcher (`ElixirScope.ASTRepository.Enhanced.FileWatcher`)

Real-time file system watcher for the Enhanced AST Repository.

### `start_link(opts \\ [])`
Starts the FileWatcher GenServer.
*   **Options:** `:watch_dirs`, `:synchronizer` (pid of Synchronizer), `:debounce_ms`.
*   **Returns:** `GenServer.on_start()`.

### `watch_project(project_path, opts \\ [])` / `stop_watching()` / `get_status(pid \\ __MODULE__)` / `flush_changes()` / `rescan_project()` / `update_config(new_opts)` / `stop(pid \\ __MODULE__)` / `subscribe(pid \\ __MODULE__, subscriber_pid)`
Management and control functions for the file watcher.

### 9.11. Synchronizer (`ElixirScope.ASTRepository.Enhanced.Synchronizer`)

Handles incremental synchronization of the Enhanced AST Repository based on file change events.

### `start_link(opts \\ [])`
Starts the Synchronizer GenServer.
*   **Options:** `:repository` (pid of Repository), `:batch_size`.
*   **Returns:** `GenServer.on_start()`.

### `get_status(pid)` / `sync_file(pid, file_path)` / `sync_file_deletion(pid, file_path)` / `sync_files(pid, file_paths)` / `stop(pid)`
Synchronization and management functions. `sync_file` and `sync_files` return `{:ok, results_list}` or `{:error, reason}`.

### 9.12. QueryBuilder (`ElixirScope.ASTRepository.QueryBuilder`)

Advanced query builder for the Enhanced AST Repository. (Note: The new version is in `lib/elixir_scope/ast_repository/query_builder.ex`).

### `build_query(query_spec)`
Builds a query structure from a map or keyword list.
*   **Returns:** `{:ok, query_t :: map()}` or `{:error, term()}`. Query includes fields like `select`, `from`, `where`, `order_by`, `limit`, `estimated_cost`, `optimization_hints`.

### `execute_query(repo, query_spec)`
Executes a query against the repository.
*   **Returns:** `{:ok, query_result :: map()}` or `{:error, term()}`. `query_result` includes `data` and `metadata`.

### `get_cache_stats()` / `clear_cache()`
Cache management functions.

*(Older `find_functions()`, `by_complexity()`, `calls_mfa()`, etc. are ways to construct the `query_spec` map).*

### 9.13. QueryExecutor (`ElixirScope.ASTRepository.QueryExecutor`)

Executes query specifications against the AST Repository. (This module is from `CODE_PROPERTY_GRAPH_DESIGN_ENHANCE` and might be an internal detail or superseded by direct Repository query functions).

### `execute_query(query_spec, repo_pid \\ Repository)`
Executes a prepared query specification.
*   **Returns:** `{:ok, results :: list()}` or `{:error, term()}`.

### 9.14. RuntimeBridge (`ElixirScope.ASTRepository.RuntimeBridge`)

Bridge for `InstrumentationRuntime` to interact with `ASTRepository` (primarily for compile-time helpers and potential post-runtime lookup).

### `ast_node_id_exists?(ast_node_id, repo_pid \\ Repository)`
Verifies if an `ast_node_id` is known to the repository.
*   **Returns:** `boolean()`. (Conceptual, likely too slow for direct runtime use).

### `get_minimal_ast_context(ast_node_id, repo_pid \\ Repository)`
Fetches minimal static context for an AST Node ID. (More for post-runtime processing).
*   **Returns:** `{:ok, map()}` or `{:error, term()}`.

### `notify_ast_node_executed(ast_node_id, function_key, correlation_id, repo_pid \\ Repository)`
(Conceptual) Notifies repository about an executed AST node.
*   **Returns:** `:ok`.

### `CompileTimeHelpers.ensure_and_get_ast_node_id(current_ast_node, id_generation_context)`
Used by instrumentation tooling at compile-time to get/ensure an AST node ID.
*   **Returns:** `{Macro.t(), String.t() | nil}`.

### `CompileTimeHelpers.prepare_runtime_call_args(original_ast_node_with_id, runtime_function, additional_static_args)`
Used by instrumentation tooling at compile-time to prepare arguments for `InstrumentationRuntime` calls.
*   **Returns:** `Macro.t()`.

### 9.15. PatternMatcher (`ElixirScope.ASTRepository.PatternMatcher`)

Advanced pattern matcher for AST, behavioral, and anti-patterns.

### `start_link(opts \\ [])`
Starts the PatternMatcher GenServer.
*   **Returns:** `GenServer.on_start()`.

### `match_ast_pattern(repo, pattern_spec)`
Matches structural AST patterns.
*   **Spec:** `%{pattern: Macro.t(), confidence_threshold: float(), ...}`.
*   **Returns:** `{:ok, pattern_result :: map()}` or `{:error, term()}`. `pattern_result` contains `matches`, `total_analyzed`, `analysis_time_ms`.

### `match_behavioral_pattern(repo, pattern_spec)`
Matches behavioral patterns (OTP, design patterns).
*   **Spec:** `%{pattern_type: atom(), confidence_threshold: float(), ...}`.
*   **Returns:** `{:ok, pattern_result :: map()}` or `{:error, term()}`.

### `match_anti_pattern(repo, pattern_spec)`
Matches anti-patterns and code smells.
*   **Spec:** `%{pattern_type: atom(), confidence_threshold: float(), ...}`.
*   **Returns:** `{:ok, pattern_result :: map()}` or `{:error, term()}`.

### `register_pattern(pattern_name, pattern_def)` / `get_pattern_stats()` / `clear_cache()`
Pattern library management and statistics.

### 9.16. MemoryManager (`ElixirScope.ASTRepository.MemoryManager`)

Manages memory for the Enhanced AST Repository.

### `start_link(opts \\ [])`
Starts the MemoryManager GenServer.
*   **Options:** `:monitoring_enabled`.
*   **Returns:** `GenServer.on_start()`.

### `monitor_memory_usage()`
Monitors current memory usage.
*   **Returns:** `{:ok, memory_stats :: map()}` or `{:error, term()}`.

### `cleanup_unused_data(opts \\ [])`
Cleans up unused AST data.
*   **Options:** `:max_age`, `:force`, `:dry_run`.
*   **Returns:** `:ok` or `{:error, term()}`.

### `compress_old_analysis(opts \\ [])`
Compresses infrequently accessed analysis data.
*   **Options:** `:access_threshold`, `:age_threshold`, `:compression_level`.
*   **Returns:** `{:ok, compression_stats :: map()}` or `{:error, term()}`.

### `implement_lru_cache(cache_type, opts \\ [])`
Configures LRU cache for queries, analysis, or CPGs.
*   **Options:** `:max_entries`, `:ttl`, `:eviction_policy`.
*   **Returns:** `:ok` or `{:error, term()}`.

### `memory_pressure_handler(pressure_level)`
Handles memory pressure situations (`:level_1` to `:level_4`).
*   **Returns:** `:ok` or `{:error, term()}`.

### `get_stats()` / `set_monitoring(enabled)` / `force_gc()`
Statistics, monitoring control, and manual GC.

### `cache_get(cache_type, key)` / `cache_put(cache_type, key, value)` / `cache_clear(cache_type)`
Direct cache manipulation functions.

### 9.17. TestDataGenerator (`ElixirScope.ASTRepository.TestDataGenerator`)

Utilities for generating test fixtures for AST Repository components. This module is for testing purposes.

### `simple_assignment_ast(var_name, value_ast, meta \\ [])` / `if_else_ast(...)` / `case_ast(...)` / `function_call_ast(...)` / `block_ast(...)`
Generate basic AST snippets.

### `function_def_ast(type, head_ast, body_ast, meta \\ [])` / `simple_function_head_ast(...)` / `module_def_ast(...)` / `simple_module_name_alias(...)`
Generate function and module definition ASTs.

### `generate_enhanced_function_data(module_name, function_ast, file_path \\ "test_gen.ex", opts \\ [])`
Generates an `EnhancedFunctionData` struct from AST, assigning Node IDs.
*   **Returns:** `{:ok, ElixirScope.ASTRepository.EnhancedFunctionData.t()}` or `{:error, term()}`.

### `generate_enhanced_module_data(module_ast_with_ids, module_name, file_path, opts \\ [])`
Generates an `EnhancedModuleData` struct from module AST.
*   **Returns:** `{:ok, ElixirScope.ASTRepository.EnhancedModuleData.t()}` or `{:error, term()}`.

### `generate_complex_test_module_ast(module_name_atom, num_functions \\ 3)`
Generates a complex module AST with multiple functions.

### `create_mock_project_on_disk(project_name_atom, num_modules \\ 2, num_functions_per_module \\ 2)`
Generates a mock project structure on disk for testing.
*   **Returns:** `root_path :: String.t()`.

---

## 10. Query Engine Layer

### 10.1. Engine (`ElixirScope.QueryEngine.Engine`)

Optimized query engine for event retrieval.

### `analyze_query(query)`
Analyzes a query to determine optimal execution strategy.
*   **Returns:** `ElixirScope.QueryEngine.Engine.t()` (struct with strategy info).

### `estimate_query_cost(store, query)`
Estimates the cost of executing a query.
*   **Returns:** `non_neg_integer()` (estimated cost).

### `execute_query(store, query)`
Executes a query against the EventStore.
*   **Returns:** `{:ok, [event()]}` or `{:error, term()}`.

### `execute_query_with_metrics(store, query)`
Executes a query and returns detailed performance metrics.
*   **Returns:** `{:ok, [event()], metrics :: map()}` or `{:error, term()}`.

### `get_optimization_suggestions(store, query)`
Provides optimization suggestions for a query.
*   **Returns:** `[String.t()]`.

### 10.2. ASTExtensions (`ElixirScope.QueryEngine.ASTExtensions`)

Extends Query Engine to query the Enhanced AST Repository.

### `execute_ast_query(query)`
Executes a static analysis query against the AST Repository.
*   **Query:** `%{type: ast_query_type(), params: map(), opts: keyword()}`.
*   **Returns:** `{:ok, results}` or `{:error, term()}`. `results` can be list, map, or `CPGData.t()`.

### `execute_correlated_query(static_query, runtime_query_template, join_key \\ :ast_node_id)`
Combines static AST information with runtime events.
*   **Returns:** `{:ok, correlated_results :: list(map())}` or `{:error, term()}`.

---

## 11. AI Layer

### 11.1. AI Bridge (`ElixirScope.AI.Bridge`)

Interface for AI components to access AST Repository and Query Engine.

### `get_function_cpg_for_ai(function_key, repo_pid \\ Repository)`
Fetches full CPG for a function.
*   **Returns:** `{:ok, CPGData.t()}` or `{:error, term()}`.

### `find_cpg_nodes_for_ai_pattern(cpg_pattern_dsl, function_key \\ nil, repo_pid \\ Repository)`
Finds CPG nodes based on a structural/semantic pattern.
*   **Returns:** `{:ok, [CPGNode.t()]}` or `{:error, term()}`.

### `get_correlated_features_for_ai(target_type, ids, runtime_event_filters, static_features, dynamic_features)`
Retrieves correlated static and dynamic features for AI models.
*   **Target Type:** `:function_keys` or `:cpg_node_ids`.
*   **Returns:** `{:ok, list(map())}` or `{:error, term()}`.

*(Also defines patterns for `AI.CodeAnalyzer`, `AI.ASTEmbeddings`, `AI.PredictiveAnalyzer`, and LLM interaction.)*

### 11.2. IntelligentCodeAnalyzer (`ElixirScope.AI.Analysis.IntelligentCodeAnalyzer`)

AI-powered code analyzer for semantic analysis, quality assessment, and refactoring suggestions.

### `start_link(opts \\ [])`
Starts the IntelligentCodeAnalyzer GenServer.

### `analyze_semantics(code_ast)`
Analyzes code semantics.
*   **Returns:** `{:ok, analysis_map}` (complexity, patterns, semantic_tags, maintainability).

### `assess_quality(module_code)`
Assesses code quality across multiple dimensions.
*   **Returns:** `{:ok, assessment_map}` (overall_score, dimensions, issues).

### `suggest_refactoring(code_section)`
Generates intelligent refactoring suggestions.
*   **Returns:** `{:ok, [suggestion_map]}`.

### `identify_patterns(module_ast)`
Identifies design patterns and anti-patterns.
*   **Returns:** `{:ok, %{patterns: list, anti_patterns: list}}`.

### `get_stats()`
Gets analyzer statistics.

### 11.3. ComplexityAnalyzer (`ElixirScope.AI.ComplexityAnalyzer`)

Analyzes code complexity for modules and functions.

### `calculate_complexity(ast)`
Calculates complexity for a single AST node.
*   **Returns:** `map()` (score, nesting_depth, cyclomatic, pattern_match, performance_indicators).

### `analyze_module(ast)`
Analyzes complexity for an entire module.
*   **Returns:** `ElixirScope.AI.ComplexityAnalyzer.t()` (struct with aggregated complexities).

### `is_performance_critical?(ast)`
Determines if code is performance-critical.
*   **Returns:** `boolean()`.

### `analyze_state_complexity(ast)`
Analyzes state complexity for stateful modules.
*   **Returns:** `:high | :medium | :low | :none`.

### 11.4. PatternRecognizer (`ElixirScope.AI.PatternRecognizer`)

Identifies common OTP, Phoenix, and architectural patterns.

### `identify_module_type(ast)`
Identifies the primary type of a module (e.g., `:genserver`, `:phoenix_controller`).
*   **Returns:** `atom()`.

### `extract_patterns(ast)`
Extracts patterns and characteristics from module AST.
*   **Returns:** `map()` containing callbacks, actions, events, children, strategy, etc.

### 11.5. CompileTime Orchestrator (`ElixirScope.CompileTime.Orchestrator`)

Orchestrates compile-time AST instrumentation plan generation.

### `generate_plan(target, opts \\ %{})`
Generates an AST instrumentation plan.
*   **Target:** `module :: atom()` or `{module, function, arity}`.
*   **Opts:** `:functions`, `:capture_locals`, `:trace_expressions`, `:granularity`.
*   **Returns:** `{:ok, plan :: map()}` or `{:error, term()}`.

### `generate_function_plan(module, function, arity, opts \\ %{})`
Generates a plan for on-demand instrumentation of a specific function.
*   **Returns:** `{:ok, plan :: map()}` or `{:error, term()}`.

### `get_instrumentation_plan()`
Gets the current instrumentation plan from `DataAccess`.
*   **Returns:** `{:ok, plan :: map()}` or `{:error, :no_plan}`.

### `analyze_and_plan(project_path)`
Analyzes a project and generates/stores a comprehensive instrumentation plan.
*   **Returns:** `{:ok, plan :: map()}` or `{:error, term()}`.

### `update_plan(updates)`
Updates an existing instrumentation plan.
*   **Returns:** `{:ok, plan :: map()}` or `{:error, term()}`.

### `analyze_runtime_feedback(performance_data)`
Analyzes runtime data and suggests plan adjustments.
*   **Returns:** `{:ok, adjusted_plan, suggestions}` or `{:error, term()}`.

### `plan_for_module(module_code)`
Generates a simple instrumentation plan for a given module's code string.
*   **Returns:** `{:ok, plan :: map()}` or `{:error, term()}`.

### `validate_plan(plan)`
Validates an instrumentation plan.
*   **Returns:** `{:ok, overall_valid :: boolean(), validation_results :: map()}`.

### 11.6. LLM Client (`ElixirScope.AI.LLM.Client`)

Main interface for interacting with LLM providers. Handles provider selection and fallback.

### `analyze_code(code, context \\ %{})`
Analyzes code using the configured LLM.
*   **Returns:** `ElixirScope.AI.LLM.Response.t()`.

### `explain_error(error_message, context \\ %{})`
Explains an error using the LLM.
*   **Returns:** `ElixirScope.AI.LLM.Response.t()`.

### `suggest_fix(problem_description, context \\ %{})`
Suggests a fix using the LLM.
*   **Returns:** `ElixirScope.AI.LLM.Response.t()`.

### `get_provider_status()`
Returns the status of configured LLM providers.
*   **Returns:** `map()`.

### `test_connection()`
Tests connectivity to the primary LLM provider.
*   **Returns:** `ElixirScope.AI.LLM.Response.t()`.

### 11.7. LLM Config (`ElixirScope.AI.LLM.Config`)

Configuration management for LLM providers.

### `get_gemini_api_key()` / `get_vertex_json_file()` / `get_vertex_credentials()`
Accessors for provider-specific credentials.

### `get_primary_provider()`
Determines the primary LLM provider based on configuration.
*   **Returns:** `:vertex | :gemini | :mock`.

### `get_fallback_provider()`
Returns the fallback provider (always `:mock`).

### `get_gemini_base_url()` / `get_vertex_base_url()` / `get_gemini_model()` / `get_vertex_model()` / `get_request_timeout()`
Accessors for provider URLs, models, and request timeout.

### `valid_config?(provider_atom)`
Checks if configuration is valid for a given provider.
*   **Returns:** `boolean()`.

### `debug_config()`
Returns a map of current LLM configuration (API keys masked).

### 11.8. LLM Response (`ElixirScope.AI.LLM.Response`)

Standardized response struct for all LLM provider interactions.

### `success(text, confidence \\ 1.0, provider, metadata \\ %{})`
Creates a successful response.
*   **Returns:** `ElixirScope.AI.LLM.Response.t()`.

### `error(error_message, provider, metadata \\ %{})`
Creates an error response.
*   **Returns:** `ElixirScope.AI.LLM.Response.t()`.

### `success?(response)` / `get_text(response)` / `get_error(response)`
Utility functions for inspecting responses.

### 11.9. LLM Providers
(`ElixirScope.AI.LLM.Providers.Gemini`, `Vertex`, `Mock`)
These modules implement the `ElixirScope.AI.LLM.Provider` behaviour. Their public API matches the callbacks defined in the behaviour: `analyze_code/2`, `explain_error/2`, `suggest_fix/2`, `provider_name/0`, `configured?/0`, `test_connection/0`.

### 11.10. Predictive ExecutionPredictor (`ElixirScope.AI.Predictive.ExecutionPredictor`)

Predicts execution paths, resource usage, and concurrency impacts.

### `start_link(opts \\ [])`
Starts the ExecutionPredictor GenServer.

### `predict_path(module, function, args)`
Predicts execution path for a function call.
*   **Returns:** `{:ok, prediction_map}` or `{:error, term()}`. Prediction map includes `:predicted_path`, `:confidence`, `:alternatives`, `:edge_cases`.

### `predict_resources(context)`
Predicts resource usage for an execution context.
*   **Context:** `%{function: atom(), input_size: integer(), ...}`.
*   **Returns:** `{:ok, resources_map}` (memory, cpu, io, execution_time, confidence).

### `analyze_concurrency_impact(function_signature)`
Analyzes concurrency bottlenecks and scaling factors.
*   **Signature:** `{module, function, arity}` or `function_name_atom`.
*   **Returns:** `{:ok, impact_map}` (bottleneck_risk, recommended_pool_size, scaling_factor).

### `train(training_data)` / `predict_batch(contexts)` / `get_stats()`
Model training, batch prediction, and statistics.

---

## 12. Distributed Layer

### 12.1. GlobalClock (`ElixirScope.Distributed.GlobalClock`)

Distributed global clock for event synchronization using hybrid logical clocks.

### `start_link(opts \\ [])`
Starts the GlobalClock GenServer.

### `now()`
Gets the current logical timestamp `{logical_time, wall_time, node_id}`.
*   **Returns:** `timestamp :: tuple()` or `fallback_timestamp :: integer()`.

### `update_from_remote(remote_timestamp, remote_node)`
Updates the clock with a timestamp from another node (GenServer cast).

### `sync_with_cluster()`
Synchronizes the clock with all known cluster nodes (GenServer cast).

### `initialize_cluster(nodes)`
Initializes the cluster with a list of nodes (GenServer cast).

### `get_state()`
Gets the current state of the global clock (GenServer call).

### 12.2. EventSynchronizer (`ElixirScope.Distributed.EventSynchronizer`)

Synchronizes events across distributed ElixirScope nodes.

### `sync_with_cluster(cluster_nodes)`
Synchronizes events with all nodes in the cluster.
*   **Returns:** `{:ok, sync_results :: list()}`.

### `sync_with_node(target_node, last_sync_time \\ nil)`
Synchronizes events with a specific node.
*   **Returns:** `{:ok, count_received}` or `{:error, {target_node, reason}}`.

### `handle_sync_request(sync_request_map)`
Handles incoming synchronization requests from other nodes (typically called via RPC).
*   **Returns:** `{:ok, local_events_for_sync}` or `{:error, term()}`.

### `full_sync_with_cluster(cluster_nodes)`
Forces a full synchronization with all cluster nodes.

### 12.3. NodeCoordinator (`ElixirScope.Distributed.NodeCoordinator`)

Coordinates ElixirScope tracing across multiple BEAM nodes.

### `start_link(opts \\ [])`
Starts the NodeCoordinator GenServer.

### `setup_cluster(nodes)`
Sets up the ElixirScope cluster with the given list of node names.

### `register_node(node)` / `get_cluster_nodes()` / `sync_events()` / `distributed_query(query_params)`
Cluster management, event synchronization, and distributed query execution functions (GenServer calls).

---

## 13. Mix Tasks

### 13.1. Compile.ElixirScope (`Mix.Tasks.Compile.ElixirScope`)

Mix compiler that transforms Elixir ASTs to inject ElixirScope instrumentation.

### `run(argv)`
The main entry point for the Mix compiler task.
*   **Returns:** `{:ok, []}` on success, or `{:error, [reason]}` on failure.

### `transform_ast(ast, plan)`
Publicly accessible function (primarily for tests) to transform an AST directly with a given plan.
*   **Returns:** Transformed `ast :: Macro.t()`.

---

## 14. Integration Patterns and Best Practices

*   **Initialization**: Start `ElixirScope` early in your application's lifecycle, typically in `application.ex`.
    ```elixir
    def start(_type, _args) do
      children = [
        ElixirScope, # Start ElixirScope and its supervision tree
        # ... your other application children
      ]
      Supervisor.start_link(children, strategy: :one_for_one)
    end
    ```
*   **Configuration**: Configure ElixirScope via `config/config.exs` (and environment-specific files). Pay attention to `:default_strategy` and `:sampling_rate` for performance tuning.
*   **AST Repository**: For applications requiring deep static analysis, ensure the `ProjectPopulator` is run (e.g., via a Mix task or on application start in dev/test) to populate the `EnhancedRepository`. The `FileWatcher` can keep it synchronized.
*   **Event Ingestion**: The `InstrumentationRuntime` is the primary interface for instrumented code. It's designed for high performance. Events flow through `Ingestor` to `RingBuffer`, then processed by `AsyncWriterPool` and stored by `Storage.DataAccess` (via `Storage.EventStore`).
*   **Temporal Debugging**: `TemporalBridge` and `TemporalStorage` enable time-travel features. `TemporalBridgeEnhancement` links this with AST data from `EnhancedRepository` via `RuntimeCorrelator`.
*   **Querying**: Use `ElixirScope.get_events/1` for basic runtime event queries. For advanced static/dynamic correlated queries, use `ElixirScope.QueryEngine.ASTExtensions` which interacts with `EnhancedRepository` and `QueryEngine.Engine`. The `QueryBuilder` can help construct complex query specifications.
*   **AI Analysis**: Interact with AI components like `IntelligentCodeAnalyzer` for insights. `CompileTime.Orchestrator` uses these to generate instrumentation plans.
*   **Custom Instrumentation**: While ElixirScope aims for automatic instrumentation, specific needs can be met by manually calling `InstrumentationRuntime.report_*` functions, especially the AST-aware variants if `ast_node_id`s are available.
*   **Performance**: Monitor ElixirScope's overhead using `ElixirScope.status()` and `ElixirScope.ASTRepository.MemoryManager.get_stats()`. Adjust sampling rates and instrumentation strategies as needed.

---

## 15. Performance Characteristics and Limitations

### Performance
*   **Event Ingestion**: Designed for >100k events/sec. `InstrumentationRuntime` calls aim for sub-microsecond overhead when disabled, and low single-digit microsecond overhead when enabled.
*   **AST Repository**:
    *   Module storage: Target <10ms (Enhanced: <50ms for complex).
    *   CFG/DFG/CPG Generation: Can be resource-intensive. Targets are <100ms (CFG), <200ms (DFG), <500ms (CPG) per typical function/module. Very large or complex code units will take longer.
    *   Query Response: Target <100ms (Enhanced: <50ms) for 95th percentile of common queries. Complex CPG graph pattern queries can be slower.
*   **Memory Usage**:
    *   Base ElixirScope: Aims for minimal constant overhead.
    *   RingBuffers: Configurable, bounded memory.
    *   EventStore/DataAccess: Memory usage proportional to the number of events stored in ETS.
    *   AST Repository: Target <500MB for 1000 modules. `MemoryManager` helps control this.
*   **AI Components**: Performance varies. LLM interactions involve network latency. Local analysis (Complexity, PatternRecognizer) is faster.

### Limitations
*   **Metaprogramming**: Deep analysis of heavily metaprogrammed code (macros generating significant code structures at compile time) can be challenging. CPGs may represent the expanded code.
*   **Inter-Process Communication (IPC) across non-ElixirScope nodes**: Full tracing of IPC may be limited if remote nodes are not also running ElixirScope or a compatible tracing agent. Distributed features (`ElixirScope.Distributed.*`) address this within an ElixirScope cluster.
*   **Large Codebases**: While designed for scalability, extremely large codebases (e.g., 5000+ modules) might strain default memory limits or increase analysis times. Configuration tuning and potentially sampling of analysis might be needed.
*   **Runtime Overhead**: While minimized, full tracing (`:full_trace` strategy with 1.0 sampling) will have noticeable overhead, especially in performance-sensitive applications. Use `:balanced` or `:minimal` strategies with appropriate sampling in production.
*   **AI Model Dependency**: LLM-based features depend on external API availability and performance, and may incur costs.
*   **AST Node ID Stability**: While efforts are made for stability, significant code refactorings (e.g., moving large blocks of code, major function signature changes) can alter AST Node IDs, potentially orphaning old runtime data from new static analysis.
*   **Current Implementation Status**: Some advanced features (e.g., full inter-procedural DFG/CPG, some AI predictions) are still under development or in early stages. The documentation reflects the intended API surface and capabilities.

---

## 16. Migration Guide: Basic to Enhanced Repository

Migrating from a conceptual "basic" AST repository to the "Enhanced AST Repository" involves several considerations:

1.  **Data Structures**:
    *   `ElixirScope.ASTRepository.ModuleData` -> `ElixirScope.ASTRepository.Enhanced.EnhancedModuleData`: The enhanced version stores the full AST, detailed function analyses (including CFG, DFG, CPG links), comprehensive dependencies, OTP pattern info, and richer metrics.
    *   `ElixirScope.ASTRepository.FunctionData` -> `ElixirScope.ASTRepository.Enhanced.EnhancedFunctionData`: The enhanced version includes fields for CFG, DFG, CPG data, detailed variable tracking, call graphs, and more granular complexity/quality metrics.
    *   **New Structures**: The enhanced system introduces many new data structures for CFG, DFG, CPG nodes/edges, complexity metrics, scope info, variable versions, etc., primarily within the `ElixirScope.ASTRepository.Enhanced.*` and `ElixirScope.ASTRepository.Enhanced.SupportingStructures.*` namespaces.

2.  **Core Repository API**:
    *   The primary GenServer is now `ElixirScope.ASTRepository.Enhanced.Repository`.
    *   `store_module/2` and `store_function/2` now expect the enhanced data structures.
    *   New functions exist for storing/retrieving CFG, DFG, CPG data specifically (e.g., `EnhancedRepository.get_cfg/3`).
    *   The `EnhancedRepository` has more specialized query functions beyond basic `get_module/2` or `get_function/3`.

3.  **Analysis Workflow**:
    *   **Old**: Basic parsing, limited metadata extraction.
    *   **New**:
        1.  `Parser.assign_node_ids` (or `NodeIdentifier`) assigns stable IDs to AST nodes.
        2.  `ASTAnalyzer` populates `EnhancedModuleData` and `EnhancedFunctionData` with detailed static analysis.
        3.  `CFGGenerator`, `DFGGenerator`, `CPGBuilder` (all from the `Enhanced` namespace) generate their respective graphs, which are then linked or stored within `EnhancedFunctionData` or queried separately.
        4.  `ProjectPopulator` (enhanced version) orchestrates this for an entire project.
        5.  `FileWatcher` and `Synchronizer` (enhanced versions) keep the repository up-to-date incrementally.

4.  **Querying**:
    *   **Old**: Basic lookups by module/function name.
    *   **New**:
        *   `QueryBuilder` helps construct complex queries for static data.
        *   `QueryExecutor` processes these queries against the `EnhancedRepository`.
        *   `QueryEngine.ASTExtensions` allows correlated queries combining static data from `EnhancedRepository` with runtime event data.

5.  **Runtime Correlation**:
    *   **Old**: May have relied on simpler correlation mechanisms.
    *   **New**: `RuntimeCorrelator` uses `ast_node_id`s (embedded in instrumented code by `EnhancedTransformer` using `NodeIdentifier`) to link runtime events directly to specific AST/CPG nodes stored in `EnhancedRepository`. `TemporalBridgeEnhancement` leverages this for AST-aware time-travel.

6.  **Key Benefits of Migration**:
    *   **Deep Code Understanding**: CFG, DFG, and CPG enable much deeper analysis than AST alone.
    *   **Precise Runtime Correlation**: Linking runtime events to exact AST nodes.
    *   **Advanced Debugging**: Features like structural/data-flow breakpoints and semantic watchpoints become possible.
    *   **Enhanced AI Capabilities**: Richer static context for AI-driven analysis, predictions, and recommendations.
    *   **Improved Querying**: More powerful and specific queries on code structure and properties.

**Migration Steps (Conceptual)**:

1.  **Update Dependencies**: Ensure all ElixirScope components are using the "Enhanced" versions of AST repository modules.
2.  **Adapt Data Storage**: If custom storage solutions were used, they need to accommodate the new `EnhancedModuleData` and `EnhancedFunctionData` structures, or rely on `EnhancedRepository`'s ETS tables.
3.  **Modify Analysis Pipeline**: Update any custom code analysis or project processing logic to use `ProjectPopulator`, `ASTAnalyzer`, and the new graph generators.
4.  **Update Instrumentation**: If custom AST transformation was done, it needs to be updated to use `NodeIdentifier` for ID generation and ensure `EnhancedTransformer` is used for injecting calls with `ast_node_id`s.
5.  **Revise Query Logic**: Update any code that queries AST information to use `QueryBuilder` and `QueryEngine.ASTExtensions` or the direct API of `EnhancedRepository`.
6.  **Test Thoroughly**: Ensure all integrations function correctly with the new data structures and APIs.

---
