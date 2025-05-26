Okay, we've covered the AI planning, AST transformation, event capture (RingBuffer, Ingestor, Async processing), event correlation, and the hot storage (DataAccess).

A critical piece that ties many of these together, especially for user-facing value and enabling the "Execution Cinema" debugging paradigm, is the **`ElixirScope.Capture.InstrumentationRuntime`** module. While we've touched on its role as the API called by instrumented code, a deeper dive into its internal mechanics, performance characteristics, and interaction with per-process context is essential. This module is the absolute front line of event capture from the user's application.

---

**ElixirScope Technical Document: Instrumentation Runtime Engine**

**Document Version:** 1.6
**Date:** 2024-05-24
**Authors:** ElixirScope Team (AI Assisted)

**Abstract:**

This document provides an in-depth technical analysis of the `ElixirScope.Capture.InstrumentationRuntime` module. This module serves as the direct, high-performance interface between instrumented application code and the ElixirScope event capture pipeline. Its functions are injected into user code at compile-time via AST transformation and are responsible for initiating the capture of various trace events (function calls, state changes, messages, etc.). The design emphasizes extremely low overhead, especially when tracing is disabled or minimally configured, and efficient management of per-process tracing context, including correlation IDs and call stacks. This document details its API, internal context management, interaction with the `EventIngestor`, performance considerations, and its crucial role in enabling effective event correlation.

**Table of Contents:**

1.  Introduction and Purpose
    1.1. Bridge Between Instrumented Code and ElixirScope
    1.2. Design Goals: Ultra-Low Overhead, Context Management, Graceful Degradation
2.  Architectural Placement and Core API (Diagram Reference: `DIAGS.md#1, #2, #3`)
    2.1. Functions Called by Instrumented Code
    2.2. Key API Functions (`report_function_entry`, `report_function_exit`, etc.)
3.  Per-Process Context Management
    3.1. Rationale for Process-Local Context
    3.2. Use of Process Dictionary (`Process.put/get`)
        3.2.1. `@context_key`: Storing `InstrumentationContext` map
        3.2.2. `@call_stack_key`: Storing the list of active correlation IDs
    3.3. `InstrumentationContext` Struct/Map
        3.3.1. `:buffer` (Reference to `RingBuffer`)
        3.3.2. `:correlation_id` (Current active root/trace ID)
        3.3.3. `:call_stack` (List of `correlation_id`s for nested calls)
        3.3.4. `:enabled` (Boolean flag for quick bypass)
    3.4. `initialize_context/0` and `clear_context/0`
    3.5. Context Propagation (Challenges with Async Operations like `Task.async`)
4.  Core Event Reporting Logic
    4.1. `report_function_entry/3`
        4.1.1. Checking `:enabled` flag
        4.1.2. Generating/Retrieving `correlation_id` for the call chain
        4.1.3. Generating a unique `call_id` (often same as `correlation_id` for this entry)
        4.1.4. Pushing `call_id` to process-local call stack
        4.1.5. Invoking `Ingestor.ingest_function_call/6`
    4.2. `report_function_exit/3`
        4.2.1. Checking `:enabled` flag
        4.2.2. Retrieving `call_id` (from argument, originally from `report_function_entry`)
        4.2.3. Popping from process-local call stack
        4.2.4. Invoking `Ingestor.ingest_function_return/4`
    4.3. `report_state_change/2`, `report_message_send/2`, `report_error/3`, etc.
        4.3.1. Similar pattern: check enabled, get context, invoke `Ingestor`.
        4.3.2. Utilizing `current_correlation_id/0` for context.
5.  Interaction with `ElixirScope.Capture.Ingestor`
    5.1. Data Passed to `Ingestor`
    5.2. Synchronous Nature of the Call
6.  Performance Characteristics
    6.1. The "Hot Path": Overhead of an Instrumented Call
        6.1.1. When `enabled?` is false (target: tens of nanoseconds)
        6.1.2. When `enabled?` is true (target: hundreds of nanoseconds before `Ingestor` call)
    6.2. Cost of Process Dictionary Access
    6.3. Cost of Correlation ID Generation and Call Stack Manipulation
    6.4. `measure_overhead/1` Function for Benchmarking
7.  Enabling/Disabling Instrumentation
    7.1. `enabled?/0` Function for Fast Checks
    7.2. `with_instrumentation_disabled/1` for Self-Instrumentation Avoidance
    7.3. Granular Control via AI Plan (Future: context reflects plan)
8.  Framework-Specific Reporting Functions (Phoenix, LiveView, Ecto, GenServer)
    8.1. Purpose: Provide semantic-rich reporting for common framework events.
    8.2. Mechanism: These functions format specific event data and call appropriate `Ingestor` functions.
    8.3. Examples from `InstrumentationRuntime`: `report_phoenix_request_start`, `report_liveview_handle_event_start`, `report_ecto_query_start`, `report_genserver_callback_start`.
9.  Challenges and Considerations
    9.1. Tail Call Optimization (TCO) and Instrumentation
    9.2. Ensuring Correctness in Highly Concurrent Scenarios
    9.3. Impact on Garbage Collection
10. Testing Strategies
11. Conclusion

---

## 1. Introduction and Purpose

### 1.1. Bridge Between Instrumented Code and ElixirScope

The `ElixirScope.Capture.InstrumentationRuntime` module serves as the crucial, first point of contact between an application instrumented by ElixirScope and the ElixirScope data capture system. Functions within this module are directly injected into the user's code at compile-time by the AST Transformation Engine. When the instrumented application runs, these injected calls are executed, signaling ElixirScope about various runtime events such as function entries, exits, state changes, and message passing.

### 1.2. Design Goals

*   **Ultra-Low Overhead:** This is the most critical design goal. Calls to `InstrumentationRuntime` functions must be exceptionally fast, especially when instrumentation is minimally configured or globally disabled. The target overhead for a disabled call is tens of nanoseconds, and for an enabled call (excluding the subsequent `Ingestor` call), hundreds of nanoseconds.
*   **Efficient Context Management:** It must efficiently manage per-process tracing context, including correlation identifiers and call stacks, to enable accurate causal analysis downstream.
*   **Graceful Degradation:** If ElixirScope is not fully initialized, disabled, or encounters an internal issue, calls to the runtime should degrade gracefully (ideally becoming near no-ops) without crashing the instrumented application.
*   **Clear API:** Provide a well-defined set of functions for various event types that the AST Transformer can reliably inject.

## 2. Architectural Placement and Core API

As seen in `DIAGS.md#1, #2, #3`, `InstrumentationRuntime` is called directly by the `Instrumented Application` and, in turn, calls the `EventIngestor`.

### 2.1. Functions Called by Instrumented Code

The AST Transformation Engine injects calls like:
```elixir
# In an instrumented function
def my_instrumented_function(arg1, arg2) do
  correlation_id_for_this_call = ElixirScope.Capture.InstrumentationRuntime.report_function_entry(MyModule, :my_instrumented_function, [arg1, arg2])
  try do
    # ... original function body ...
    result = # ... original result ...
    ElixirScope.Capture.InstrumentationRuntime.report_function_exit(correlation_id_for_this_call, :normal, result)
    result
  catch
    kind, reason ->
      ElixirScope.Capture.InstrumentationRuntime.report_function_exit(correlation_id_for_this_call, kind, reason)
      :erlang.raise(kind, reason, __STACKTRACE__)
  end
end
```

### 2.2. Key API Functions

The `elixir_scope/capture/instrumentation_runtime.ex` file defines a comprehensive API:

*   **Core Tracing:**
    *   `report_function_entry(module, function, args)`: Reports function entry. Returns a `correlation_id` (or `call_id`) for this specific call instance.
    *   `report_function_exit(correlation_id, return_value_or_kind, duration_ns_or_reason)`: Reports function exit (normal or exceptional).
    *   `report_state_change(old_state, new_state)`
    *   `report_message_send(to_pid, message)`
    *   `report_process_spawn(child_pid)`
    *   `report_error(error, reason, stacktrace)`
*   **Context Management:**
    *   `initialize_context/0`: Sets up tracing context for the current process.
    *   `clear_context/0`: Removes tracing context.
    *   `enabled?/0`: Fast check if tracing is active for the current process.
    *   `current_correlation_id/0`: Gets the ID of the encompassing trace.
    *   `with_instrumentation_disabled/1`: Executes a function with tracing temporarily off.
*   **Framework-Specific (Semantic Richness):**
    *   `report_phoenix_request_start/5`, `report_phoenix_request_complete/4`, etc.
    *   `report_liveview_mount_start/4`, `report_liveview_handle_event_complete/5`, etc.
    *   `report_ecto_query_start/5`, `report_ecto_query_complete/5`, etc.
    *   `report_genserver_callback_start/3`, etc.
    *   `report_node_event/3`, `report_partition_detected/2`

## 3. Per-Process Context Management

To correctly correlate events originating from or related to a specific BEAM process, and to track nested operations within that process, `InstrumentationRuntime` maintains a process-local context.

### 3.1. Rationale for Process-Local Context

Elixir processes are isolated. A function call in one process is distinct from a call (even to the same function) in another. Message sends originate from one process and target another. Therefore, context like the current call stack or the active trace ID must be scoped to the process where the event occurs.

### 3.2. Use of Process Dictionary (`Process.put/get`)

The process dictionary is used for storing this context due to its extremely fast access (it's part of the process control block).
*   `@context_key (:elixir_scope_context)`: Stores the main context map.
*   `@call_stack_key (:elixir_scope_call_stack)`: Stores the list of active correlation IDs representing the current function call stack within this process. Using a separate key might offer a slight optimization if only the call stack is frequently accessed.

### 3.3. `InstrumentationContext` Struct/Map

The value stored under `@context_key` is a map (conceptually a struct):
```elixir
%{
  buffer: RingBuffer.t() | nil,         # Reference to the RingBuffer for this process/node
  correlation_id: term() | nil,        # The ID of the outermost/root trace this process is part of
  call_stack: [term()],                # Stack of correlation_ids for nested calls: [current_call, parent_call, ...]
  enabled: boolean()                   # Is tracing active in this context?
}
```
The `call_stack` field within this main context map seems redundant if `@call_stack_key` is also used directly. The code uses `@call_stack_key` for `push_call_stack/1`, `pop_call_stack/0`, and `current_correlation_id/0`. The main context map seems to be primarily for the `buffer` reference and the global `enabled` flag.

### 3.4. `initialize_context/0` and `clear_context/0`

*   `initialize_context/0`:
    1.  Attempts to get a reference to the main/active `RingBuffer` (via `get_buffer/0` which looks up an application environment variable or a persistent term).
    2.  If a buffer is found, it sets `@context_key` to `%{buffer: buffer, enabled: true, ...}` and `@call_stack_key` to `[]`.
    3.  If no buffer is found, it sets `@context_key` to `%{enabled: false, ...}`.
    This function should be called by processes that are intended to be entry points for tracing (e.g., a Phoenix request handler process, the start of a GenServer call).
*   `clear_context/0`: Deletes `@context_key` and `@call_stack_key` from the process dictionary, effectively disabling tracing for subsequent calls in that process unless re-initialized.

### 3.5. Context Propagation (Challenges with Async Operations like `Task.async`)

A significant challenge is propagating the tracing context (especially `correlation_id` and `call_stack`) across process boundaries created by mechanisms like `Task.async/1`, `spawn/1`, etc.
*   The current `InstrumentationRuntime` primarily manages context *within* a single process.
*   If `Task.async(fn -> instrumented_code() end)` is called, the new task's process will not automatically inherit the caller's ElixirScope context.
*   **Solution Strategies (not fully explicit in current `InstrumentationRuntime`):**
    1.  **Manual Propagation:** The AI/AST Transformer could inject code to explicitly pass the current `correlation_id` and relevant parent `call_id` to the new process (e.g., as an argument to the spawned function), which then calls `initialize_context` with these inherited IDs.
    2.  **`VMTracer` for Spawns:** `report_process_spawn/1` captures parent/child PIDs. The `EventCorrelator` can use this to link the child's subsequent traces back to the parent's context.
    3.  **Process Dictionary Inheritance (Limited):** Some spawn operations can inherit parts of the process dictionary, but this is not a general solution.

## 4. Core Event Reporting Logic

### 4.1. `report_function_entry/3` (Module, Function, Args)

1.  **Checks `enabled?` flag:**
    ```elixir
    case get_context() do
      %{enabled: false} -> nil // Fast exit
      %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
        // Proceed with tracing
    ```
2.  **Correlation ID & Call ID:**
    *   `correlation_id = generate_correlation_id()`: A new unique ID (`call_id`) is generated for *this specific function call instance*. The term "correlation_id" here in `InstrumentationRuntime` is more akin to a `call_id`. The broader trace correlation ID (linking an entire request, for example) would ideally be part of the context or explicitly passed.
    *   The `current_correlation_id/0` function retrieves the ID from the top of the `@call_stack_key`, which would be the `call_id` of the *calling* function (parent call). This parent `call_id` is what `EventCorrelator` would use as `parent_id`.
3.  **Push to Call Stack:** `push_call_stack(correlation_id)` (the `call_id` for the current function) is added to the head of the list stored at `@call_stack_key`.
4.  **Invoke Ingestor:** `Ingestor.ingest_function_call(buffer, module, function, args, self(), correlation_id)` is called. Note: `self()` is passed as `caller_pid`, and the `correlation_id` argument to `ingest_function_call` is the `call_id` of the current function.

### 4.2. `report_function_exit/3` (Correlation ID, Return/Kind, Duration/Reason)

1.  **Checks `enabled?` flag.**
2.  **Retrieves `call_id`:** The `correlation_id` argument passed to this function is the `call_id` that was returned by the corresponding `report_function_entry`.
3.  **Pop from Call Stack:** `pop_call_stack/0` removes the current function's `call_id` from `@call_stack_key`.
4.  **Invoke Ingestor:** `Ingestor.ingest_function_return(buffer, return_value, duration_ns, correlation_id)` is called, passing the original `call_id`.

### 4.3. `report_state_change/2`, `report_message_send/2`, `report_error/3`, etc.

These functions follow a similar pattern:
1.  Check `enabled?` from `get_context()`.
2.  Retrieve the `buffer` from the context.
3.  Collect necessary event-specific data.
4.  Call the appropriate `Ingestor.ingest_...` function.
5.  For context, they would implicitly use `current_correlation_id/0` (the `call_id` of the function they are called from) to allow `EventCorrelator` to link these events (e.g., a state change) to the function call that caused it.

## 5. Interaction with `ElixirScope.Capture.Ingestor`

*   `InstrumentationRuntime` functions directly call functions in the `ElixirScope.Capture.Ingestor` module.
*   **Data Passed:** All necessary data to construct an `ElixirScope.Events` struct is passed (module, function, args, PID, correlation/call IDs, return values, etc.).
*   **Synchronous Call:** The call from `InstrumentationRuntime` to `Ingestor` is a synchronous Elixir function call. The `Ingestor` then performs its (very fast) operations, including the write to the `RingBuffer`. The `InstrumentationRuntime` function only returns after the `Ingestor` function (and thus the `RingBuffer.write`) completes. This entire path must be extremely quick.

## 6. Performance Characteristics

### 6.1. The "Hot Path": Overhead of an Instrumented Call

This is the sum of `report_function_entry` and `report_function_exit` overhead.
#### 6.1.1. When `enabled?` is false
*   `get_context()`: One `Process.get/2` call.
*   Pattern match on `%{enabled: false}`.
*   Return `nil` or `:ok`.
*   **Target:** Tens of nanoseconds. This is critical for production scenarios where ElixirScope might be included but tracing is globally off or highly sampled.
#### 6.1.2. When `enabled?` is true
*   `get_context()`: One `Process.get/2`.
*   `generate_correlation_id()`: Calls `System.monotonic_time/1`, `self/0`, `make_ref/0`.
*   `push_call_stack/1`: One `Process.get/2` and one `Process.put/2`.
*   Call to `Ingestor` function (which includes event struct creation, timestamping, ID generation, data truncation, and `RingBuffer.write`).
*   `pop_call_stack/0`: One `Process.get/2` and one `Process.put/2` (for exit).
*   **Target:** Hundreds of nanoseconds *before* the `Ingestor` call. The `Ingestor` + `RingBuffer.write` adds its own sub-microsecond latency. The total overhead for a fully traced call (entry + exit + ingest) aims to be in the low single-digit microseconds.

### 6.2. Cost of Process Dictionary Access

`Process.get/2` and `Process.put/2` are generally very fast as they access memory local to the process. However, frequent modifications (puts) can have a minor impact on GC for that process. This is deemed acceptable given the need for per-process context.

### 6.3. Cost of Correlation ID Generation and Call Stack Manipulation

*   `generate_correlation_id()` (as `{System.monotonic_time(:nanosecond), self(), make_ref()}`) is efficient.
*   List manipulation for `call_stack` (prepend on push, tail on pop) is efficient for relatively shallow call stacks typically encountered. Very deep recursion could make stack operations slightly more costly, but this is a general Elixir consideration too.

### 6.4. `measure_overhead/1` Function for Benchmarking

This utility function provides a way to empirically measure the overhead of `report_function_entry` and `report_function_exit` calls under both enabled and disabled states, which is vital for performance validation.

## 7. Enabling/Disabling Instrumentation

### 7.1. `enabled?/0` Function for Fast Checks

This is the primary guard at the beginning of most reporting functions. Its speed is critical.
`def enabled?, do: case Process.get(@context_key) do %{enabled: e} -> e; _ -> false end`

### 7.2. `with_instrumentation_disabled/1` for Self-Instrumentation Avoidance

This higher-order function allows ElixirScope's internal components (e.g., `Ingestor`, `AsyncWriter`) to execute code without triggering further ElixirScope tracing, preventing infinite recursion. It temporarily sets the `:enabled` flag in the process context to `false` for the duration of the given function's execution.

### 7.3. Granular Control via AI Plan (Future: context reflects plan)

Currently, the `:enabled` flag in the context is quite global for the process. A more advanced implementation tied to the AI instrumentation plan could involve:
*   The AST Transformer injecting not just calls but also checks against the *specific plan directives* for that function/callback.
*   Or, the `InstrumentationContext` could hold more detailed information about what aspects are enabled for the current `call_id` (e.g., `capture_args: true/false`). `report_function_entry` would then pass only relevant data to the `Ingestor`. This moves more decision-making into the hot path but allows finer-grained control. ElixirScope seems to currently favor passing more data to `Ingestor` and letting `Ingestor` (e.g., via `Utils.truncate_data`) or later stages handle it.

## 8. Framework-Specific Reporting Functions

The numerous `report_phoenix_...`, `report_liveview_...`, etc., functions in `InstrumentationRuntime` serve to:
*   Provide a semantically richer API for framework-specific instrumentation (called by Telemetry handlers in `Phoenix.Integration` or specialized AST transformations).
*   Encapsulate the logic for extracting relevant data from framework-specific structures (e.g., `conn`, `socket`, telemetry metadata).
*   Format this data and call the appropriate generic or specialized `Ingestor.ingest_...` function.
For example, `report_phoenix_request_start/5` takes `method, path, params, remote_ip` and internally calls `Ingestor.ingest_phoenix_request_start`, which creates an event of type `:phoenix_request_start`.

## 9. Challenges and Considerations

### 9.1. Tail Call Optimization (TCO) and Instrumentation

If a function is tail-recursive, the Elixir compiler might optimize away stack frames. If `report_function_exit` is injected *after* a tail call, it might never be executed for intermediate recursive calls.
*   **Mitigation:** Instrumenting tail calls correctly is tricky. One approach is to transform tail calls into non-tail calls by capturing the result before the tail call, reporting exit, and then making the call. This, however, breaks TCO and can lead to stack overflows for deep recursion.
*   Alternatively, rely on the `EventCorrelator` to infer exits for TCO'd calls if a new `report_function_entry` for the *same function* occurs in the same process before an explicit exit for the previous call. This is complex.
*   The current implementation likely relies on the `try/catch` wrapping, which itself can interfere with TCO depending on how the compiler handles it. This needs careful testing.

### 9.2. Ensuring Correctness in Highly Concurrent Scenarios

While the process dictionary is process-local, the overall system state (RingBuffers, ETS tables in Correlator/DataAccess) is shared. The design relies on `:atomics` for lock-free RingBuffer metadata and ETS's concurrency features. Rigorous concurrency testing is essential.

### 9.3. Impact on Garbage Collection

Frequent `Process.put/2` calls (for call stack) can increase the frequency of minor GCs for highly active processes with deep call stacks that change often. The data stored is small (list of PIDs/terms), so the impact is generally expected to be minimal but measurable.

## 10. Testing Strategies

(If `elixir_scope/capture/instrumentation_runtime_test.exs` existed)
*   **Unit Tests:**
    *   Verify `initialize_context` sets up context correctly based on `get_buffer` result.
    *   Test `enabled?` under different context states.
    *   Test `push_call_stack`, `pop_call_stack`, `current_correlation_id` for correct stack manipulation.
    *   Test `with_instrumentation_disabled/1` correctly toggles and restores the enabled flag.
    *   For each `report_...` function:
        *   Verify it calls the correct `Ingestor` function with correctly formatted arguments when enabled.
        *   Verify it's a near no-op and doesn't call `Ingestor` when disabled.
*   **Performance Tests:**
    *   Use `measure_overhead/1` to verify performance targets for enabled/disabled call paths.
    *   Benchmark repeated context initializations and call stack manipulations.
*   **Integration with AST Transformer:** Ensure the `correlation_id` returned by `report_function_entry` is correctly captured by the transformed AST and passed to `report_function_exit`.

## 11. Conclusion

The `ElixirScope.Capture.InstrumentationRuntime` is a linchpin of the ElixirScope system. It forms the highly optimized, performance-critical boundary between the user's application and the ElixirScope backend. Its reliance on the process dictionary for context management allows for efficient per-process call stack tracking and correlation ID propagation. The extensive API caters to both generic function tracing and semantically rich framework-specific events. Successful implementation and rigorous performance tuning of this module are fundamental to ElixirScope's ability to capture comprehensive trace data with minimal application impact.