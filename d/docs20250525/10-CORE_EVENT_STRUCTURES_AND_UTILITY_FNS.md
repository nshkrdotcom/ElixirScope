Okay, we've thoroughly covered:
1.  AI Planning & Code Analysis
2.  AST Transformation
3.  Instrumentation Runtime
4.  Event Ingestion (Ingestor & RingBuffer)
5.  Asynchronous Processing Pipeline (AsyncWriters)
6.  Event Correlation
7.  Hot Storage (DataAccess)
8.  Phoenix Integration
9.  Configuration & Application Lifecycle

A crucial aspect that underpins much of this, especially the event capture and storage, is the **Core Event Structures (`ElixirScope.Events`) and Utility Functions (`ElixirScope.Utils`)**. While parts of these have been touched upon in other documents (e.g., `InstrumentationRuntime` creating events, `Ingestor` processing them), a dedicated document focusing on their design, the variety of event types, serialization, and the general-purpose utilities is essential.

---

**ElixirScope Technical Document: Core Event Structures and Utility Functions**

**Document Version:** 1.10
**Date:** 2024-05-24
**Authors:** ElixirScope Team (AI Assisted)

**Abstract:**

This document provides a detailed technical examination of ElixirScope's core event structures, defined primarily within the `ElixirScope.Events` module, and the general-purpose utility functions provided by `ElixirScope.Utils`. These modules form the bedrock for data representation and common operations throughout the ElixirScope system. The design of event structures emphasizes lightweightness, self-containment, and extensibility, while the utilities offer high-performance, reliable functions for timestamping, ID generation, data inspection, and formatting. Understanding these foundational elements is key to appreciating how ElixirScope captures, processes, and represents telemetry data.

**Table of Contents:**

1.  Introduction and Purpose
    1.1. Role as Foundational Data and Tooling Layers
    1.2. Design Goals: Efficiency, Clarity, Reusability, Accuracy
2.  `ElixirScope.Events` Module
    2.1. Base Event Structure (`ElixirScope.Events` defstruct)
        2.1.1. Common Fields: `event_id`, `timestamp`, `wall_time`, `node`, `pid`, `correlation_id`, `parent_id`, `event_type`, `data`
    2.2. Detailed Event Type Definitions
        2.2.1. Function Execution Events (`FunctionExecution`, `FunctionEntry`, `FunctionExit`)
        2.2.2. Process Events (`ProcessEvent`, `ProcessSpawn`, `ProcessExit`)
        2.2.3. Message Events (`MessageEvent`, `MessageSend`, `MessageReceive`)
        2.2.4. State Change Events (`StateChange`, `VariableAssignment`)
        2.2.5. Performance Events (`PerformanceMetric`, `GarbageCollection`)
        2.2.6. Error Events (`ErrorEvent`, `CrashDump`)
        2.2.7. VM Events (`VMEvent`, `SchedulerEvent`, `NodeEvent`)
        2.2.8. ETS/DETS Events (`TableEvent`)
        2.2.9. Trace Control Events (`TraceControl`)
    2.3. Event Creation (`new_event/3`, Specific Constructors)
    2.4. Event Serialization and Deserialization (`serialize/1`, `deserialize/1`)
        2.4.1. Use of `:erlang.term_to_binary/2` with `:compressed`
        2.4.2. Safety with `:erlang.binary_to_term/2` and `:safe`
    2.5. Event Size Considerations and Truncation (Interaction with `Utils.truncate_data`)
3.  `ElixirScope.Utils` Module
    3.1. Timestamp Generation
        3.1.1. `monotonic_timestamp/0`: High-resolution, for ordering and duration.
        3.1.2. `wall_timestamp/0`: System time, for correlation with external systems.
        3.1.3. `format_timestamp/1`: Human-readable conversion.
        3.1.4. `measure/1`: Function execution time measurement.
    3.2. ID Generation
        3.2.1. `generate_id/0`: Unique, roughly sortable event IDs (timestamp + node hash + random).
        3.2.2. `generate_correlation_id/0`: UUID v4 based for trace grouping.
        3.2.3. `id_to_timestamp/1`: Extracting timestamp from event ID.
    3.3. Data Inspection and Truncation
        3.3.1. `safe_inspect/2`: Inspecting terms with size limits.
        3.3.2. `truncate_if_large/2` & `truncate_data/2`: Returning placeholders for oversized terms.
        3.3.3. `term_size/1`: Estimating memory footprint.
    3.4. Performance Helpers
        3.4.1. `measure_memory/1`: Memory usage before/after function execution.
        3.4.2. `process_stats/1`: Current process statistics.
        3.4.3. `system_stats/0`: System-wide performance statistics.
    3.5. String and Data Formatting Utilities
        3.5.1. `format_bytes/1`: Human-readable byte sizes.
        3.5.2. `format_duration/1`: Human-readable nanosecond durations.
    3.6. Validation Helpers
        3.6.1. `valid_positive_integer?/1`, `valid_percentage?/1`, `valid_pid?/1`.
4.  Interaction and Usage by Other ElixirScope Components
    4.1. `Ingestor` and `InstrumentationRuntime`: Event creation and initial population.
    4.2. `DataAccess` and `EventCorrelator`: Storage and processing of event structs.
    4.3. `AI.CodeAnalyzer` and `AST.Transformer`: Understanding event data for planning and injection.
5.  Testing Strategies for Events and Utilities
6.  Conclusion

---

## 1. Introduction and Purpose

### 1.1. Role as Foundational Data and Tooling Layers

The `ElixirScope.Events` and `ElixirScope.Utils` modules provide the fundamental building blocks for representing trace information and performing common, low-level operations within the ElixirScope system.
*   `ElixirScope.Events` defines the schema and structure for all types of telemetry data captured during an application's execution. A consistent and well-defined event model is crucial for all subsequent processing, storage, querying, and analysis stages.
*   `ElixirScope.Utils` offers a suite of essential helper functions, focusing on high-performance and reliability for tasks frequently required by other ElixirScope components, such as precise timestamping, unique ID generation, and safe data handling.

### 1.2. Design Goals

*   **Efficiency (Events & Utils):** Event structs should be relatively lightweight. Utility functions, especially those on hot paths (timestamping, ID generation), must be highly performant.
*   **Clarity (Events):** Event types and their fields should be self-descriptive and capture relevant contextual information clearly.
*   **Reusability (Utils):** Provide a common set of robust tools to avoid code duplication and ensure consistency across the system.
*   **Accuracy (Utils):** Timestamps and ID generation must be reliable. Data inspection tools should prevent crashes due to overly large or complex terms.
*   **Extensibility (Events):** The event system should allow for new event types to be added as ElixirScope's capabilities expand.

## 2. `ElixirScope.Events` Module

This module defines the canonical structures for all events captured by ElixirScope.

### 2.1. Base Event Structure (`ElixirScope.Events` defstruct)

All specific event types are conceptually wrapped or built upon a base structure (though the code uses `ElixirScope.Events.new_event/3` to create a map-like struct with these common fields and a specific data payload). The common fields are:
*   `event_id`: A unique integer ID generated by `Utils.generate_id/0`.
*   `timestamp`: A high-resolution monotonic timestamp (nanoseconds) from `Utils.monotonic_timestamp/0`, used for ordering and duration calculations.
*   `wall_time`: A system wall clock timestamp (nanoseconds) from `Utils.wall_timestamp/0`, for correlation with external logs or human-readable display.
*   `node`: The BEAM node where the event originated (`Node.self()`).
*   `pid`: The process ID where the event primarily occurred (`self()`).
*   `correlation_id`: An optional ID (often a UUID string from `Utils.generate_correlation_id/0` or a structured term) used by `EventCorrelator` to link a series of related events (e.g., all events within a single HTTP request).
*   `parent_id`: An optional ID pointing to a parent event in a hierarchical relationship (e.g., a nested function call's entry event pointing to the outer call's entry event ID).
*   `event_type`: An atom identifying the kind of event (e.g., `:function_entry`, `:message_send`).
*   `data`: A map or struct containing the event-type-specific payload.

### 2.2. Detailed Event Type Definitions

The `elixir_scope/events.ex` file defines numerous `defmodule`s for specific event data payloads. Each typically includes fields relevant to that event type. Key examples:

*   **2.2.1. Function Execution Events:**
    *   `FunctionEntry`: `module`, `function`, `arity`, `args` (truncated), `call_id` (unique ID for this call instance), `caller_module/function/line`.
    *   `FunctionExit`: `module`, `function`, `arity`, `call_id` (to match entry), `result` (return value or exception, truncated), `duration_ns`, `exit_reason` (`:normal`, `:exception`, etc.).
    *   `FunctionExecution` (as seen in `Ingestor` and `DataAccess` tests): Appears to be a consolidated struct sometimes used, containing fields from both entry and exit, potentially populated at different stages or for simplified representation.
*   **2.2.2. Process Events:**
    *   `ProcessSpawn`: `spawned_pid`, `parent_pid`, `spawn_module/function/args/opts`, `registered_name`.
    *   `ProcessExit`: `exited_pid`, `exit_reason`, `lifetime_ns`, `message_count`, `final_state`.
    *   `ProcessEvent` (base for process-related events): `id`, `timestamp`, `pid`, `parent_pid`, `event_type`.
*   **2.2.3. Message Events:**
    *   `MessageSend`: `sender_pid`, `receiver_pid` (or name), `message` (truncated), `message_id` (unique message instance ID), `send_type` (`:send`, `:cast`, `:call`), `call_ref`.
    *   `MessageReceive`: `receiver_pid`, `sender_pid`, `message` (truncated), `message_id` (to match send), `receive_type` (`:receive`, `:handle_call`, etc.), `queue_time_ns`, `pattern_matched`.
    *   `MessageEvent` (base for message-related events): `id`, `timestamp`, `from_pid`, `to_pid`, `message`, `event_type`.
*   **2.2.4. State Change Events:**
    *   `StateChange`: `server_pid`, `callback` (e.g., `:handle_call`), `old_state` (truncated), `new_state` (truncated), `state_diff`, `trigger_message`, `trigger_call_id`.
    *   `VariableAssignment`: (For fine-grained tracing) `variable_name`, `old_value`, `new_value`, `assignment_type`, `scope_context`, `line_number`.
*   **2.2.5. Performance Events:**
    *   `PerformanceMetric`: `metric_name`, `value`, `metadata`, `metric_type`, `unit`, `source_context`.
    *   `GarbageCollection`: `heap_size_before/after`, `gc_type`, `duration_ns`.
*   **2.2.6. Error Events:**
    *   `ErrorEvent`: `error_type`, `error_class`, `error_message`, `stacktrace` (truncated), `context`, `recovery_action`.
    *   `CrashDump`: `crashed_pid`, `supervisor_pid`, `crash_reason`, `process_state`.
*   **2.2.7. VM Events:** `SchedulerEvent`, `NodeEvent`.
*   **2.2.8. ETS/DETS Events:** `TableEvent`.
*   **2.2.9. Trace Control Events:** `TraceControl`.

The presence of a generic `FunctionExecution` struct in some tests/modules alongside more specific `FunctionEntry`/`FunctionExit` implies an evolution or different use cases for event representation. The primary path via `InstrumentationRuntime` -> `Ingestor` uses `FunctionEntry` and `FunctionExit` style specific data in the `data` field of the base event.

### 2.3. Event Creation (`new_event/3`, Specific Constructors)

*   **`ElixirScope.Events.new_event(event_type, data, opts \\ [])`**: This is the primary factory function. It populates the common base event fields (generating `event_id`, `timestamp`, `wall_time` if not provided in `opts`) and sets the `event_type` and specific `data` payload.
*   **Specific Constructors (e.g., `Events.function_entry/X`, `Events.message_send/X`):** These are helper functions (currently found at the bottom of `events.ex` and marked for backward compatibility in tests) that simplify the creation of specific event types by constructing the `data` map/struct internally and then calling `new_event/3`. This promotes consistency.

### 2.4. Event Serialization and Deserialization (`serialize/1`, `deserialize/1`)

*   **`serialize(event)`:** Uses `:erlang.term_to_binary(event, [:compressed])`. The `:compressed` option typically uses zlib compression (level 6 by default) which can significantly reduce the size of serialized terms, especially those with repetitive structures or large binaries. This is important for reducing `RingBuffer` memory and network bandwidth if events are sent across nodes.
*   **`deserialize(binary)`:** Uses `:erlang.binary_to_term(binary, [:safe])`. The `:safe` option restricts the atoms that can be created during deserialization to only those already existing in the system, providing some protection against atom exhaustion attacks if processing untrusted binary data (less of a concern for internally generated events but good practice).
*   `serialized_size(event)` provides the byte size of the serialized event.

### 2.5. Event Size Considerations and Truncation

Even with compression, event payloads (args, return values, state) can be very large. `ElixirScope.Utils.truncate_data/2` (aliased from `truncate_if_large/2`) is used by `Ingestor` and specific event constructors to limit the size of captured data before it's even put into an event struct. This is a critical mechanism for controlling memory usage and performance. Truncated data is typically replaced with a placeholder like `{:truncated, original_size, type_hint}`.

## 3. `ElixirScope.Utils` Module

This module provides a collection of crucial, often performance-sensitive helper functions.

### 3.1. Timestamp Generation

*   **3.1.1. `monotonic_timestamp/0` -> `System.monotonic_time(:nanosecond)`:** Returns an integer representing time in nanoseconds from an arbitrary starting point. Guaranteed to be monotonically increasing. Essential for correct event ordering and duration calculation within a single node.
*   **3.1.2. `wall_timestamp/0` -> `System.system_time(:nanosecond)`:** Returns an integer representing OS system time (Unix epoch time) in nanoseconds. Useful for displaying human-readable timestamps and correlating ElixirScope events with external logs or systems. Susceptible to system clock adjustments.
*   **3.1.3. `format_timestamp/1`:** Converts a nanosecond timestamp (presumably wall time, or monotonic converted to an epoch offset) to a human-readable string, attempting to include nanosecond precision.
*   **3.1.4. `measure/1`:** A utility to time the execution of a zero-arity function using `monotonic_timestamp/0`.

### 3.2. ID Generation

*   **3.2.1. `generate_id/0`:** Creates a unique integer ID. The implementation combines:
    *   `System.monotonic_time(:nanosecond)` (lower 48 bits).
    *   `:erlang.phash2(Node.self(), 65536)` (lower 8 bits, for node uniqueness in a cluster).
    *   `:rand.uniform(65536)` (lower 8 bits, for randomness to reduce collisions within the same nanosecond on the same node).
    The structure `(timestamp <<< 16) ||| (node_hash <<< 8) ||| random` makes IDs roughly sortable by time.
*   **3.2.2. `generate_correlation_id/0`:** Generates a standard UUID v4 string (e.g., "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"). Used for grouping logically related sequences of events.
*   **3.2.3. `id_to_timestamp/1`:** Extracts the 48-bit timestamp component from an ID generated by `generate_id/0` by right-shifting.

### 3.3. Data Inspection and Truncation

*   **3.3.1. `safe_inspect/2`:** Wraps `inspect/2` with default `limit` and `printable_limit` options to prevent trying to inspect overly large or deep terms, which can cause performance issues or crashes.
*   **3.3.2. `truncate_if_large/2` & `truncate_data/2`:** If the binary representation of a term exceeds `max_size` (default 5000 bytes for `truncate_if_large`, 1000 for `truncate_data`), it returns `{:truncated, original_binary_size, type_hint}`. Otherwise, returns the original term. This is used extensively by the `Ingestor` to cap the size of captured event payloads.
*   **3.3.3. `term_size/1`:** Uses `:erts_debug.flat_size/1 * :erlang.system_info(:wordsize)` to estimate the memory footprint of a term. Useful for heuristics about data size.

### 3.4. Performance Helpers

*   **3.4.1. `measure_memory/1`:** Measures total BEAM memory (`:erlang.memory(:total)`) before and after executing a function, forcing garbage collection before each measurement for more stable readings. Returns `{result, {before, after, diff}}`.
*   **3.4.2. `process_stats/1`:** Returns a map of key statistics for a given PID (or `self()`) from `Process.info/2`, including `:memory`, `:reductions`, `:message_queue_len`, `:heap_size`, etc., plus a timestamp.
*   **3.4.3. `system_stats/0`:** Returns a map of system-wide Erlang VM statistics, including process counts, memory usage by category (total, processes, system, ets, atom), and scheduler info.

### 3.5. String and Data Formatting Utilities

*   **3.5.1. `format_bytes/1`:** Converts an integer byte count into a human-readable string (e.g., "1.5 MB", "200 B").
*   **3.5.2. `format_duration/1`:** Converts an integer nanosecond duration into a human-readable string (e.g., "1.5 ms", "2.0 s", "500 μs").

### 3.6. Validation Helpers

Simple predicates for common validation needs:
*   `valid_positive_integer?/1`
*   `valid_percentage?/1` (0.0 to 1.0)
*   `valid_pid?/1` (checks `Process.alive?/1`)

## 4. Interaction and Usage by Other ElixirScope Components

*   **`InstrumentationRuntime` and `Ingestor`:** Heavily rely on `Utils` for timestamping (`monotonic_timestamp`, `wall_timestamp`), ID generation (`generate_id`, `generate_correlation_id`), and data truncation (`truncate_data`). They are the primary producers of `ElixirScope.Events` structs, using `Events.new_event/3` or specific constructors.
*   **`DataAccess` and `EventCorrelator`:** Store, retrieve, and process `ElixirScope.Events` structs (or `CorrelatedEvent`s which wrap them). They use event fields like `event_id`, `timestamp`, `pid`, `correlation_id`, and `event_type` for indexing and logic.
*   **`AI.CodeAnalyzer` and `AST.Transformer`:** While they primarily deal with ASTs, their understanding of what data can be captured (defined by `Events` structs) informs the instrumentation plans they generate and the calls they inject.
*   **Configuration (`ElixirScope.Config`):** Validation helpers from `Utils` are used to validate configuration values.
*   **Testing modules:** Frequently use `Utils` for test setup (e.g., generating test IDs) and `Events` to create sample events.

## 5. Testing Strategies for Events and Utilities

*   **`ElixirScope.EventsTest`:**
    *   Verify correct creation of base events and specific event types with all fields populated.
    *   Test uniqueness of `event_id` and monotonicity of `timestamp` for sequentially created events.
    *   Thoroughly test `serialize/1` and `deserialize/1` round-tripping for all event types, including those with complex or large data (to ensure truncation and compression work as expected).
    *   Benchmark serialization/deserialization speed and serialized size.
*   **`ElixirScope.UtilsTest`:**
    *   Test `monotonic_timestamp` for monotonicity and `wall_timestamp` for reasonable values.
    *   Test `generate_id` for uniqueness over many iterations and `id_to_timestamp` for correctness.
    *   Test `generate_correlation_id` for correct UUID format and uniqueness.
    *   Test `safe_inspect`, `truncate_if_large`, `truncate_data` with various small, large, and complex terms, verifying truncation behavior and placeholder format.
    *   Test `term_size` for plausible estimates.
    *   Test `format_bytes` and `format_duration` with a range of input values.
    *   Test validation helpers with valid and invalid inputs.
    *   Performance tests for `generate_id` and timestamp functions.

## 6. Conclusion

The `ElixirScope.Events` and `ElixirScope.Utils` modules provide the critical low-level data structures and operational primitives for the entire ElixirScope system. The rich and extensible event schema allows for detailed data capture, while utilities for timestamping, ID generation, and safe data handling ensure efficiency and robustness. Their design and performant implementation are fundamental to ElixirScope's ability to capture, process, and analyze large volumes of trace data effectively. The existing test suites for these modules appear comprehensive, covering functionality, correctness, and some performance aspects.