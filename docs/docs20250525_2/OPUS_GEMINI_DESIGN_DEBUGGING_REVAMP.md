Okay, this is a very pointed and important critique. The document `OPUS_DONT_REINVENT_AND_USE_BUILTIN_DEBUG.md` (and to some extent `OPUS_CRITIQUE.md`) makes a strong case that ElixirScope, in its current foundational design, might be over-investing in custom AST-based instrumentation and underutilizing powerful, built-in BEAM/OTP tracing and debugging primitives.

Let's do a deep dive into this.

**Is ElixirScope Reinventing Wheels?**

The core of the argument is that functionalities like process tracing, state inspection, and message tracing have existing, robust counterparts in the BEAM ecosystem.

1.  **Process Tracing (Function Calls/Returns):**
    *   **ElixirScope's AST Approach:** Injects calls to `InstrumentationRuntime.report_function_entry/exit` into user code at compile time.
        *   **Pros:** Highly selective (driven by AI plan), can capture custom data (local variables, specific context) directly from the function's scope, potentially lower overhead per *traced* call if tracing is sparse (direct function call vs. trace message processing).
        *   **Cons:** Requires recompilation to change what's traced, cannot easily instrument third-party libraries without source or running systems.
    *   **BEAM's `:erlang.trace/3` and `:dbg`:**
        *   **Pros:** Runtime enabling/disabling, can trace any code (including third-party and OTP itself) without recompilation, well-understood, robust. `:dbg` offers a higher-level interface.
        *   **Cons:** Can be a firehose of data if not carefully filtered with match specs, trace messages need to be received and processed by a tracer process (introducing some overhead and complexity), harder to capture arbitrary internal function state.

    **Analysis:** ElixirScope's AST approach offers more *control over what data is captured from within the function's scope* and potentially finer-grained selectivity based on an AI plan. However, for general function call/return tracing, `:erlang.trace` (especially with match specs) is indeed powerful and dynamic. ElixirScope *is* reinventing a part of the call tracing mechanism but aiming for a different set of trade-offs (compile-time optimization, custom data).

2.  **Process State Inspection:**
    *   **ElixirScope's "Time-Travel" Goal:** Aims for `ElixirScope.get_state_at(pid, timestamp)`, which implies reconstructing historical state. This is achieved by instrumenting callbacks (e.g., GenServer `handle_call`) to report state changes.
    *   **BEAM's `:sys.get_state/1`, `Process.info/2`:** Get the *current* state or information of a process.
    *   **BEAM's `:sys.trace/2`:** Can be used to receive trace messages when OTP processes (like GenServers) change state or handle messages. These trace messages often include the state.

    **Analysis:**
    *   For *current state*, using `:sys.get_state/1` is the standard.
    *   For *historical state changes of OTP processes*, `:sys.trace/2` is a built-in way to capture them at runtime. ElixirScope's AST transformation of callbacks achieves a similar outcome but by modifying the callback code itself.
    *   The "time-travel" aspect (reconstructing state at an arbitrary past point) requires storing snapshots/deltas and replaying events. This is a layer *above* just capturing state changes, and neither AST nor `:sys.trace` alone provide the full replay engine. The critique is valid that `:sys.trace` could be the *source* of state change events for OTP processes, rather than AST-injecting into every callback.

3.  **Message Tracing:**
    *   **ElixirScope's AST Approach:** Can instrument message sends (`send/2`, `GenServer.call/cast`) and receives (`receive` blocks, `handle_info`, etc.) to call `InstrumentationRuntime.report_message_send/receive`.
    *   **BEAM's `:erlang.trace(pid, true, [:send, :receive])`:** Traces all messages for a PID.

    **Analysis:** Similar to function tracing. AST provides selectivity and custom context capture around message operations. `:erlang.trace` is a blanket runtime approach. ElixirScope's `EventCorrelator` then tries to link these, which is a necessary step regardless of capture method.

**The Verdict from the Critique:**

The critique in `OPUS_DONT_REINVENT_AND_USE_BUILTIN_DEBUG.md` (and implied by `OPUS_CRITIQUE.MD`) is that for a "state-of-the-art debugger" focused on **dynamic, runtime analysis, especially in production**, relying primarily on compile-time AST transformation is a misstep. The BEAM offers rich runtime tracing that is more flexible and less intrusive for many debugging scenarios.

**How to Revamp ElixirScope to Use Built-in Tools More Effectively (as per the Proposal):**

The proposal in `OPUS_DONT_REINVENT_AND_USE_BUILTIN_DEBUG.md` is compelling. It suggests shifting ElixirScope's primary data capture mechanism from AST transformation to leveraging runtime BEAM tracing capabilities.

Here's a detailed outline of such a revamp:

**Phase 1: Runtime Capture Engine based on BEAM Primitives**

*   **Goal:** Replace primary AST-based event generation with handlers for BEAM trace messages and `:sys` events. The backend (`Ingestor`, `RingBuffer`, `AsyncWriter`, `EventCorrelator`, `DataAccess`) largely remains the same, but it now consumes events originating from BEAM traces.

*   **1.1. `ElixirScope.Runtime.Tracer` (New or Enhanced `VMTracer`)**
    *   **Responsibilities:**
        *   Acts as the BEAM trace message handler process(es).
        *   Dynamically enables/disables tracing on target PIDs, modules, or MFAs using `:erlang.trace/3`, `:erlang.trace_pattern/3`, and potentially `:dbg` module (OTP 25+ offers more capabilities).
        *   Receives raw trace messages (e.g., `{:trace, pid, :call, {M,F,A}}`, `{:trace, pid, :send, msg, to_pid}`).
        *   Transforms these raw trace messages into `ElixirScope.Events` structs (e.g., `FunctionEntry`, `MessageSend`). This involves parsing the trace message format.
        *   Forwards these ElixirScope events to `ElixirScope.Capture.Ingestor`.
    *   **Example `tracer_loop` snippet (from `OPUS_DONT_REINVENT_AND_USE_BUILTIN_DEBUG.md`):**
        ```elixir
        defp tracer_loop(opts) do
          correlation_id_map = Process.get(:elixir_scope_correlation_map, %{}) # Manage correlation IDs per PID

          receive do
            {:trace_ts, pid, :call, {mod, fun, args}, timestamp} ->
              call_id = ElixirScope.Utils.generate_id() # For this call
              Process.put({:elixir_scope_call_id, pid, {mod, fun, length(args)}}, call_id)
              current_corr_id = Map.get(correlation_id_map, pid, ElixirScope.Utils.generate_correlation_id()) # Get or start trace
              # ... create ElixirScope.Events.FunctionEntry ...
              # ... forward to Ingestor ...

            {:trace_ts, pid, :return_from, {mod, fun, arity}, return_value, timestamp} ->
              call_id = Process.get({:elixir_scope_call_id, pid, {mod, fun, arity}})
              # ... create ElixirScope.Events.FunctionExit, using call_id ...
              # ... forward to Ingestor ...

            # ... other trace message types (:send, :receive, :spawn, etc.) ...
          end
          tracer_loop(opts) # Loop to process more messages
        end
        ```
    *   **Key Change:** `InstrumentationRuntime`'s role significantly diminishes for direct calls. It might still be used for very custom, user-defined events or if some AST injection is retained for specific purposes.

*   **1.2. `ElixirScope.Runtime.StateMonitor` (New - based on `:sys.install`)**
    *   **Responsibilities:**
        *   Uses `:sys.install/2` to attach to target OTP processes (GenServers, etc.).
        *   Implements the `sys_debug` callback functions (`system_continue/3`, `system_terminate/4`, `handle_event/2` - though `handle_event` is often for custom debug messages, state changes are usually seen in trace messages from `handle_call/cast/info` if tracing is enabled on the GenServer process itself, or directly in `handle_event`'s `new_state` if `:sys.install` is used to intercept state).
        *   The `OPUS_DONT_REINVENT_AND_USE_BUILTIN_DEBUG.md`'s `ElixirScope.TimeTravel.StateCapture` with `handle_event/2` is a good example for GenServer state capture *if `:sys.install` is used to make the GenServer call this debug handler as part of its loop*.
        *   Alternatively, if tracing `:call` and `:return_to` on the GenServer PID, the state might be part of the return value of callbacks, accessible via trace messages.
    *   **Event Generation:** Transforms OTP state changes or callback invocations into `ElixirScope.Events.StateChange` events and sends them to `Ingestor`.

*   **1.3. `ElixirScope.Runtime` (Public API Module - Revamped)**
    *   This module, as sketched in `OPUS_PROD_RUNTIME_INSTRUMENTATION_API_SKETCH.md`, becomes the primary user interface for *controlling runtime tracing*.
    *   `trace(module_or_pid, opts)`: Sets up `:erlang.trace` or `:dbg` traces.
    *   `instrument(module, opts)`: Could (optionally) still use hot code loading with AST-transformed versions for very deep, custom instrumentation if `:erlang.trace` is insufficient, but this becomes secondary.
    *   `enable_time_travel(target, opts)`: Would use `StateMonitor` to start capturing state snapshots/changes.
    *   **Key Change:** The AI layer now influences *which runtime traces are enabled and with what match specs*, rather than what AST transformations to perform.

**Phase 2: Time-Travel Engine on Runtime-Captured Data**

*   **Goal:** Build the state reconstruction and event replay logic using the data captured by the new runtime mechanisms.
*   **2.1. Snapshot Management:**
    *   `StateMonitor` or `Tracer` would be responsible for periodically capturing full state snapshots (e.g., `Process.info(pid)` for basic state, `:sys.get_state(pid)` for OTP state) in addition to deltas/changes. These snapshots become anchors for time-travel.
*   **2.2. `ElixirScope.TimeTravel.ReplayEngine` (New)**
    *   `replay_to(session_id, timestamp)`:
        1.  Finds the nearest state snapshot *before* `timestamp` from `DataAccess`.
        2.  Restores this state in a temporary/simulated environment.
        3.  Fetches all ElixirScope events (function calls, messages, state changes derived from traces) between the snapshot time and the target `timestamp`.
        4.  Symbolically "replays" these events against the restored state to reconstruct the state at `timestamp`. This requires defining how each event type affects state.
*   **2.3. `ElixirScope.Runtime.Interactive` (New - for REPL interaction):**
    *   `break(mfa, opts)`: Sets a runtime tracepoint that, when hit, might pause (if possible) or simply trigger detailed capture and allow inspection of the historically reconstructed state up to that point.
    *   `step_back(session_id)`: Uses the `ReplayEngine` to calculate the previous state.

**Phase 3: Integration with Existing Tools (Observer, Recon)**

*   As proposed in `OPUS_DONT_REINVENT_AND_USE_BUILTIN_DEBUG.md`:
    *   Enhance `:observer` by providing a custom backend module that feeds ElixirScope's historical data into Observer's views.
    *   Use `:recon_trace` for production-safe tracing, piping its output into ElixirScope's `Ingestor`.

**Impact on Existing ElixirScope Components:**

*   **`AI.*` Layer:**
    *   `CodeAnalyzer`, `PatternRecognizer`, `ComplexityAnalyzer` are still valuable for understanding code to *guide runtime tracing decisions*.
    *   `Orchestrator`: Now generates plans for *what to trace at runtime* (e.g., which PIDs, MFAs, match_specs for `:erlang.trace` or `:dbg`) instead of AST transformations.
*   **AST Transformation (`Compiler.MixTask`, `AST.Transformer`, `AST.InjectorHelpers`):**
    *   Largely deprecated for primary tracing.
    *   **Could be retained for:**
        *   Development-time "deep dive" instrumentation where maximum detail (e.g., local variable capture) is needed and recompilation is acceptable.
        *   Instrumenting specific patterns not easily catchable by runtime tracing (though this is rare).
        *   Injecting unique message IDs for robust message correlation if not handled by a library.
*   **`Capture.InstrumentationRuntime`:** Its direct-call API becomes less central. It might evolve into a set of functions used by the `Tracer` and `StateMonitor` to format events before sending to `Ingestor`, or for custom user-reported events.
*   **`Capture.Ingestor`, `RingBuffer`, `AsyncWriterPool`, `EventCorrelator`, `Storage.DataAccess`:** These backend components remain largely the same, as they process and store `ElixirScope.Events` structs, regardless of how those structs were initially generated (AST injection vs. BEAM trace message handling). The `EventCorrelator`'s job might become more complex if trace messages provide less precise context than AST-injected calls.

**Why this Revamp Addresses the Critique:**

1.  **Leverages Built-in Tools:** Directly uses `:erlang.trace`, `:sys.get_state`, `:sys.install`, `:dbg`, potentially `:recon`.
2.  **Dynamic Control:** Instrumentation can be enabled/disabled/modified at runtime without recompilation. Essential for production debugging.
3.  **Reduced Custom Code:** Less need to maintain complex AST transformation logic for basic tracing.
4.  **Wider Reach:** Can trace any BEAM code, including OTP and third-party libraries, without needing their source or modifying them.
5.  **Focus on Core Value:** ElixirScope's unique value shifts more towards:
    *   The "Execution Cinema" UI and time-travel replay.
    *   Intelligent AI analysis of traces to guide debugging.
    *   High-performance storage and querying of trace data.
    *   Sophisticated event correlation (which is still needed).

**Challenges of the Revamp:**

*   **Performance of Trace Handling:** Processing a high volume of BEAM trace messages in an Elixir tracer process can have its own overhead. Careful design of the tracer process (or pool of processes) is needed.
*   **Data Granularity:** Standard BEAM trace messages might not provide as much fine-grained internal state (e.g., local variables within a function) as AST injection could. Match specs can help extract arguments/return values.
*   **Correlation Complexity:** Correlating events based on less structured trace messages might be harder than correlating events generated by custom-injected calls that already carry context (like call IDs). The AI and `EventCorrelator` will need to be robust.

**Conclusion of the Deep Dive:**

The critique is largely **valid and insightful**. While ElixirScope's current foundation has impressive performance characteristics for its custom capture pipeline, it *is* substantially reinventing tracing mechanisms that have robust, dynamic, runtime counterparts in the BEAM.

**A revamp to prioritize runtime tracing using BEAM primitives for data acquisition, while retaining ElixirScope's backend for processing, storage, correlation, AI analysis, and the "Execution Cinema" UI, is a strategically sound direction.**

This shift would make ElixirScope:
*   More flexible for production and dynamic debugging.
*   Less reliant on compile-time modifications.
*   Better aligned with the Erlang/Elixir ecosystem's strengths.
*   Able to focus its "custom build" efforts on the truly differentiating features: AI-guided analysis, time-travel, and the Execution Cinema interface.

The AST transformation components wouldn't necessarily be discarded entirely but could become an optional, "deep-dive" instrumentation method for development or specific scenarios, rather than the primary means of data capture. The backend infrastructure (`RingBuffer`, `Ingestor`, `DataAccess`, `EventCorrelator`) is still highly valuable for processing the events, regardless of their origin.





Okay, this is a significant and valuable critique. The core argument is that ElixirScope's current AST-based instrumentation approach is reinventing capabilities already present (and often more flexible for runtime debugging) in the BEAM's built-in tracing mechanisms (`:erlang.trace`, `:sys.trace`, `:dbg`, etc.).

Let's accept this premise and outline a detailed plan to revamp ElixirScope to leverage these built-in tools more effectively, reducing custom code and increasing runtime flexibility, while still aiming for the "Execution Cinema" vision.

**Guiding Principles for the Revamp:**

1.  **Leverage BEAM Primitives:** Use `:erlang.trace`, `:sys.trace`, `:sys.install`, and potentially `:dbg` as the *primary* sources for capturing function calls, messages, and OTP state changes.
2.  **Runtime Control:** Shift focus from compile-time AST transformation to runtime configuration of tracing.
3.  **AI Guides Runtime Tracing:** The AI layer (`CodeAnalyzer`, `Orchestrator`) will now generate plans for *what to trace at runtime* (e.g., which PIDs, MFAs, match_specs) rather than what AST transformations to perform.
4.  **Retain Backend:** The high-performance event capture pipeline (`Ingestor`, `RingBuffer`, `AsyncWriterPool`), `EventCorrelator`, and `DataAccess` are still valuable for processing, correlating, and storing the events, regardless of their origin.
5.  **Simplify/Repurpose:** Components directly tied to AST transformation will be removed or significantly simplified.

---

## Step 1: Determine Which Files to Remove Entirely

Based on the shift away from primary AST-based instrumentation:

*   **`lib/elixir_scope/ast/transformer.ex`**: The core AST transformation logic is no longer the primary instrumentation method. While some very niche AST transformations *could* be kept for specific data captures (e.g., local variable values if deemed essential and not obtainable otherwise), for this revamp, we'll assume it's largely removed to embrace runtime tracing fully.
    *   **Decision:** **REMOVE.**
*   **`lib/elixir_scope/ast/injector_helpers.ex`**: These are helpers for `Transformer.ex`. If `Transformer.ex` is removed, these are also unnecessary.
    *   **Decision:** **REMOVE.**
*   **Test Files for Removed Components:**
    *   `test/elixir_scope/ast/transformer_test.exs`
    *   Any tests heavily reliant on testing the output of `InjectorHelpers` directly (if they exist separately).
    *   **Decision:** **REMOVE.**

---

## Step 2: Determine Which Files to Modify (and how)

Many existing files will be modified to reflect the new approach.

### 1. `lib/elixir_scope/capture/instrumentation_runtime.ex`

*   **Current Role:** API called by AST-injected code. Manages per-process context (call stacks, correlation IDs) using process dictionary.
*   **New Role:** Will be significantly slimmed down.
    *   It might still be used by the new `Runtime.Tracer` or `Runtime.StateMonitor` to report events *to the Ingestor* in a structured way.
    *   The complex per-process call stack management within `InstrumentationRuntime` (using `@call_stack_key`) becomes less critical if BEAM traces provide call/return context. The `EventCorrelator` will take on more responsibility for stack reconstruction from trace messages if needed.
    *   It could become a simpler set of functions for formatting events before they hit the `Ingestor`.
    *   The framework-specific `report_phoenix_*`, `report_liveview_*` etc. functions might still be called by the `Phoenix.Integration` Telemetry handlers, but they'd forward to the `Ingestor` with less internal context management.
*   **Decision:** **MODIFY.**

```elixir
# lib/elixir_scope/capture/instrumentation_runtime.ex (Modified - Heavily Simplified)
defmodule ElixirScope.Capture.InstrumentationRuntime do
  @moduledoc """
  Simplified Runtime API for reporting events to ElixirScope's Ingestor.
  Primarily used by internal tracing components (like Runtime.Tracer, Phoenix.Integration)
  and potentially for custom user-reported events.
  Focuses on formatting and forwarding events, with minimal internal state.
  """

  alias ElixirScope.Capture.{RingBuffer, Ingestor}
  alias ElixirScope.Utils

  @type correlation_id :: term()

  # Process dictionary key for a global context (buffer ref, enabled flag)
  @context_key :elixir_scope_global_context

  # --- Core Context Management (Simplified) ---
  defp get_global_context do
    Process.get(@context_key, %{enabled: false, buffer: nil})
  end

  @doc "Fast check if tracing is generally enabled for this process's context."
  @spec enabled?() :: boolean()
  def enabled? do
    case get_global_context() do
      %{enabled: true, buffer: _} -> true
      _ -> false
    end
  end

  @doc "Initializes a basic context, primarily for buffer reference."
  @spec initialize_context() :: :ok
  def initialize_context do
    case get_buffer_from_app_config() do
      {:ok, buffer} -> Process.put(@context_key, %{buffer: buffer, enabled: true})
      _ -> Process.put(@context_key, %{buffer: nil, enabled: false})
    end
    :ok
  end

  defp get_buffer_from_app_config do
    # Simplified: Assumes a single, globally accessible buffer reference
    # In a real system, this might involve looking up a :persistent_term or app env
    case Application.get_env(:elixir_scope, :main_buffer) do
      nil -> {:error, :no_buffer_configured}
      buffer_ref -> {:ok, buffer_ref} # Assuming buffer_ref is the actual RingBuffer struct/pid
    end
  end

  @doc "Temporarily disables instrumentation for the current process."
  @spec with_instrumentation_disabled((() -> term())) :: term()
  def with_instrumentation_disabled(fun) do
    old_context = Process.get(@context_key)
    case old_context do
      %{} = context -> Process.put(@context_key, %{context | enabled: false})
      _ -> Process.put(@context_key, %{enabled: false, buffer: nil})
    end
    try do
      fun.()
    after
      if old_context, do: Process.put(@context_key, old_context), else: Process.delete(@context_key)
    end
  end

  # --- Event Reporting Functions (Simplified - mainly forwarding) ---

  @doc "Reports a generic event. Used by internal tracers."
  @spec report_event(
          type :: atom(),
          data :: map(),
          pid :: pid(),
          correlation_id :: term() | nil,
          timestamp :: integer() | nil,
          wall_time :: integer() | nil
        ) :: :ok
  def report_event(type, data, event_pid, correlation_id, timestamp, wall_time) do
    with %{enabled: true, buffer: buffer} <- get_global_context(),
         not is_nil(buffer) do
      # The Ingestor now takes more responsibility for event creation
      Ingestor.ingest_generic_event(buffer, type, data, event_pid, correlation_id, timestamp, wall_time)
    else
      _ -> :ok # Silently drop if not enabled or no buffer
    end
  end

  # --- Framework-Specific Reporting (Called by Telemetry handlers or specialized tracers) ---
  # These now mostly format data and call the generic report_event or specialized Ingestor functions.

  def report_phoenix_request_start(correlation_id, method, path, params, remote_ip) do
    data = %{method: method, path: path, params: params, remote_ip: remote_ip}
    report_event(:phoenix_request_start, data, self(), correlation_id, nil, nil)
  end

  def report_phoenix_request_complete(correlation_id, status, _content_type, duration) do
    data = %{status: status, duration_ns: duration} # duration is expected in ns by correlator/storage
    report_event(:phoenix_request_complete, data, self(), correlation_id, nil, nil)
  end

  def report_phoenix_controller_entry(correlation_id, controller, action, params) do
    data = %{controller: controller, action: action, params: params}
    report_event(:phoenix_controller_entry, data, self(), correlation_id, nil, nil)
  end

  def report_phoenix_controller_exit(correlation_id, controller, action, duration) do
    data = %{controller: controller, action: action, duration_ns: duration}
    report_event(:phoenix_controller_exit, data, self(), correlation_id, nil, nil)
  end

  # ... Other report_phoenix_*, report_liveview_*, report_ecto_*, report_genserver_* functions ...
  # ... would be similarly simplified to format data and call report_event/6 or a specific Ingestor func ...

  def report_ecto_query_start(correlation_id, repo, source, query_text, params_count) do
    data = %{repo: repo, source: source, query: query_text, params_count: params_count}
    report_event(:ecto_query_start, data, self(), correlation_id, nil, nil)
  end

  def report_ecto_query_complete(correlation_id, repo, query_time, decode_time, result_summary) do
    data = %{repo: repo, query_time_ns: query_time, decode_time_ns: decode_time, result: result_summary}
    report_event(:ecto_query_complete, data, self(), correlation_id, nil, nil)
  end

  # ... etc. for other specific event types ...

  def report_node_event(event_type, node_name, metadata) do
    data = %{target_node: node_name, metadata: metadata}
    report_event(event_type, data, self(), nil, nil, nil) # Node events might not have a primary correlation_id
  end

  def report_partition_detected(partitioned_nodes, metadata) do
    data = %{partitioned_nodes: partitioned_nodes, metadata: metadata}
    report_event(:partition_detected, data, self(), nil, nil, nil)
  end
end
```

### 2. `lib/elixir_scope/capture/ingestor.ex`

*   **Current Role:** Receives data from `InstrumentationRuntime`, creates `ElixirScope.Events` structs, timestamps, truncates, and writes to `RingBuffer`.
*   **New Role:** Largely the same, but now needs to be robust to receiving event data that might originate from BEAM traces (via the new `Runtime.Tracer`). It might need a more generic `ingest_generic_event` function. The specific `ingest_function_call`, `ingest_function_return` will still be useful if the `Runtime.Tracer` pre-formats trace messages into this structure.
*   **Decision:** **MODIFY.**

```elixir
# lib/elixir_scope/capture/ingestor.ex (Modified)
defmodule ElixirScope.Capture.Ingestor do
  @moduledoc """
  Ultra-fast event ingestor for ElixirScope.
  Receives event data (from runtime tracers or direct calls), creates structured
  ElixirScope.Events, and writes them to the RingBuffer.
  """

  alias ElixirScope.Capture.RingBuffer
  alias ElixirScope.Events
  alias ElixirScope.Utils

  @type ingest_result :: :ok | {:error, term()}

  # ... (existing specific ingest functions like ingest_function_call can remain for structured input) ...
  def ingest_function_call(buffer, module, function, args, caller_pid, correlation_id) do
    event_data = %Events.FunctionEntry{ # Assuming FunctionEntry is the specific data struct
      module: module,
      function: function,
      arity: length(args),
      args: Utils.truncate_data(args),
      call_id: correlation_id, # call_id is the correlation_id for this entry
      caller_module: nil, # Might be harder to get from raw BEAM traces
      caller_function: nil,
      caller_line: nil
    }
    event = Events.new_event(:function_entry, event_data,
      pid: caller_pid,
      correlation_id: correlation_id # This might be the root_id or a specific call_id
                                     # EventCorrelator will refine this.
    )
    RingBuffer.write(buffer, event)
  end

  def ingest_function_return(buffer, return_value, duration_ns, correlation_id) do
    event_data = %Events.FunctionExit{ # Assuming FunctionExit for specific data
      # module, function, arity might be added by EventCorrelator by looking up entry
      call_id: correlation_id,
      result: Utils.truncate_data(return_value),
      duration_ns: duration_ns,
      exit_reason: :normal # Default, could be passed if it's an exception
    }
    event = Events.new_event(:function_exit, event_data,
      correlation_id: correlation_id
    )
    RingBuffer.write(buffer, event)
  end

  # --- New Generic Ingestion Function ---
  @doc "Ingests a generic event, typically from a runtime tracer."
  @spec ingest_generic_event(
          RingBuffer.t(),
          type :: atom(),
          data :: map(),
          event_pid :: pid(),
          correlation_id :: term() | nil,
          timestamp :: integer() | nil, # Monotonic timestamp if available from tracer
          wall_time :: integer() | nil  # Wall time if available from tracer
        ) :: ingest_result()
  def ingest_generic_event(buffer, type, data, event_pid, correlation_id, timestamp, wall_time) do
    # Prepare event options, using provided times if available
    opts = []
    opts = if correlation_id, do: Keyword.put(opts, :correlation_id, correlation_id), else: opts
    opts = if timestamp, do: Keyword.put(opts, :timestamp, timestamp), else: opts
    opts = if wall_time, do: Keyword.put(opts, :wall_time, wall_time), else: opts
    opts = Keyword.put(opts, :pid, event_pid)

    # Ensure data is truncated if it's a map/list that could be large
    # Specific event types might need more nuanced data construction here or in the tracer.
    processed_data = case data do
      map_data when is_map(map_data) -> Utils.truncate_data(map_data)
      list_data when is_list(list_data) -> Utils.truncate_data(list_data)
      _ -> data # Assume already handled or small
    end

    event = Events.new_event(type, processed_data, opts)
    RingBuffer.write(buffer, event)
  end

  # ... (other specific ingest_phoenix_*, ingest_ecto_* functions remain,
  #      they will be called by the modified InstrumentationRuntime,
  #      which in turn is called by Telemetry handlers) ...

  # Ensure all existing specific ingest functions are updated to use Events.new_event/3
  # and properly set event_type and data fields.

  # Example:
  def ingest_process_spawn(buffer, parent_pid, child_pid) do
    data = %Events.ProcessSpawn{
      spawned_pid: child_pid,
      parent_pid: parent_pid,
      # spawn_module/function/args might be harder to get from raw :erlang.trace(:spawn)
      # but can be enriched by EventCorrelator if parent context is known
      spawn_module: nil, spawn_function: nil, spawn_args: nil
    }
    event = Events.new_event(:process_spawn, data, pid: child_pid)
    RingBuffer.write(buffer, event)
  end

  def ingest_message_send(buffer, from_pid, to_pid, message) do
    data = %Events.MessageSend{
      sender_pid: from_pid,
      receiver_pid: to_pid,
      message: Utils.truncate_data(message),
      message_id: ElixirScope.Utils.generate_id() # A unique ID for this message instance
    }
    event = Events.new_event(:message_send, data, pid: from_pid)
    RingBuffer.write(buffer, event)
  end

  # ... (rest of the ingest functions, ensuring they create proper Events.new_event payloads) ...
  # ... (ingest_batch, create_fast_ingestor, benchmark_ingestion, validate_performance can remain) ...

  defp compute_state_diff(old_state, new_state) do
    if old_state == new_state, do: :no_change, else: :changed
  end

  defp inspect_diff(old, new) do
    %{old: inspect(old, limit: 20), new: inspect(new, limit: 20)}
  end
end
```

### 3. `lib/elixir_scope/compiler/mix_task.ex`

*   **Current Role:** Fetches plan from `AI.Orchestrator`, invokes `AST.Transformer`.
*   **New Role:**
    *   It might no longer be a *compiler* task in the sense of transforming ASTs for instrumentation.
    *   Its primary role could shift to being a Mix task that:
        1.  Triggers the `AI.Orchestrator` to analyze the project and generate/update a *runtime tracing plan*.
        2.  Perhaps stores this plan where the runtime components (`ElixirScope.Runtime` API) can access it.
    *   Alternatively, if some minimal AST transformation is kept (e.g., for injecting unique message IDs if that's the chosen correlation method), it would handle only those specific, limited transformations.
*   **Decision:** **MODIFY** (significant simplification or repurposing).

```elixir
# lib/elixir_scope/compiler/mix_task.ex (Modified - Repurposed for AI Analysis Triggering)
defmodule Mix.Tasks.Compile.ElixirScope do
  @moduledoc """
  Mix task to trigger ElixirScope's AI analysis and runtime plan generation.
  This task no longer performs AST transformation directly. It ensures that
  the AI analysis is up-to-date for runtime tracing decisions.
  """

  use Mix.Task

  alias ElixirScope.AI.Orchestrator

  @shortdoc "Analyzes project and prepares ElixirScope runtime tracing plan."
  def run(argv) do
    config_opts = parse_argv(argv)

    # Ensure ElixirScope application (including AI.Orchestrator) is started
    # This might be tricky if ElixirScope itself is a dependency being compiled.
    # Consider making this an explicit `mix elixir_scope.analyze` task instead of a compiler.
    case Application.ensure_all_started(:elixir_scope) do
      {:ok, _} ->
        project_path = File.cwd!() # Assuming Mix tasks run in project root
        IO.puts("ElixirScope: Analyzing project at #{project_path} to generate runtime tracing plan...")

        case Orchestrator.analyze_and_plan(project_path, config_opts) do
          {:ok, plan} ->
            IO.puts("ElixirScope: Runtime tracing plan generated and stored successfully.")
            # The plan is stored by Orchestrator (e.g., via DataAccess)
            # The runtime components will fetch this plan when ElixirScope starts.
            :ok
          {:error, reason} ->
            Mix.shell().error("ElixirScope: Failed to generate runtime tracing plan: #{inspect(reason)}")
            Mix.raise("ElixirScope analysis failed.")
        end
      {:error, {:elixir_scope, reason}} ->
        Mix.shell().error("ElixirScope application could not be started: #{inspect(reason)}")
        Mix.raise("ElixirScope prerequisites failed.")
      {:error, {app, reason}} ->
        Mix.shell().error("Failed to start dependency #{app} for ElixirScope: #{inspect(reason)}")
        Mix.raise("ElixirScope dependency failed.")
    end
  end

  defp parse_argv(argv) do
    # Parse options like --strategy, --sampling-rate if they should influence
    # the AI plan generated at this stage.
    {opts, _args, _invalid} = OptionParser.parse(argv,
      switches: [strategy: :atom, sampling_rate: :float]
    )
    opts # Return parsed options to be passed to Orchestrator.analyze_and_plan/2
  end
end

# Keep the alias for any remaining test or internal usage, but its role is different.
defmodule ElixirScope.Compiler.MixTask do
  defdelegate run(argv), to: Mix.Tasks.Compile.ElixirScope
  # transform_ast/2 would be removed if AST transformation is fully deprecated.
end
```
**Note on `Mix.Tasks.Compile.ElixirScope`:** A significant change here is considering whether this should remain a `Mix.Task.Compiler` or become a standard `Mix.Task` (e.g., `mix elixir_scope.analyze`). If it's no longer transforming code to be fed *into* the Elixir compiler, its place in the `compilers:` list is less justified. For now, the modified version assumes it runs to prep the AI plan.

### 4. `lib/elixir_scope/ai/orchestrator.ex`

*   **Current Role:** Manages AI analysis and generates an *AST instrumentation plan*.
*   **New Role:** Still manages AI analysis, but now generates a *runtime tracing plan*. This plan would specify which modules/functions/PIDs to trace dynamically, what match_specs to use for `:erlang.trace_pattern`, and what OTP processes to monitor with `:sys.install`.
*   **Decision:** **MODIFY.**

```elixir
# lib/elixir_scope/ai/orchestrator.ex (Modified)
defmodule ElixirScope.AI.Orchestrator do
  @moduledoc """
  AI orchestrator for ElixirScope, now focusing on generating RUNTIME tracing plans.
  Coordinates between different AI components to analyze code and generate
  dynamic tracing strategies.
  """
  use GenServer # Or Agent, depending on complexity needs

  alias ElixirScope.AI.CodeAnalyzer # PatternRecognizer, ComplexityAnalyzer are used by CodeAnalyzer
  alias ElixirScope.Storage.DataAccess # For storing/retrieving the runtime plan

  # Example of a runtime tracing plan structure
  # This would be much more detailed in reality
  @type runtime_tracing_plan :: %{
    global_trace_flags: list(atom), # e.g., [:call, :return_to, :send, :receive, :procs, :timestamp]
    module_traces: %{
      module_atom :: %{
        functions: %{
          {atom(), non_neg_integer()} :: %{ # {function_name, arity}
            trace_level: :basic | :detailed | :full, # Controls match_spec detail
            match_spec_conditions: list(tuple) # For :erlang.trace_pattern
          }
        },
        otp_monitoring: :none | :state_changes | :full_callbacks # For StateMonitor
      }
    },
    pid_specific_traces: %{
      # pid_string :: trace_options (for dynamic PID tracing)
    },
    sampling_rate: float()
    # ... other runtime controls ...
  }

  # --- Public API ---
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Gets the current runtime tracing plan."
  def get_runtime_tracing_plan do
    # Fetch from DataAccess (which uses ETS stats_table)
    case DataAccess.get_instrumentation_plan() do # Re-use existing DataAccess functions for plan storage
      {:ok, plan} -> {:ok, plan}
      _ -> {:error, :no_plan_found} # Or generate default if none found
    end
  end

  @doc "Analyzes the project and generates/updates the runtime tracing plan."
  def analyze_and_plan(project_path, opts \\ []) do
    # This might be called by a Mix task or an API
    GenServer.call(__MODULE__, {:analyze_and_plan, project_path, opts})
  end

  @doc "Updates the runtime tracing plan dynamically."
  def update_runtime_tracing_plan(new_plan_directives) do
    GenServer.call(__MODULE__, {:update_runtime_plan, new_plan_directives})
  end

  # --- GenServer Callbacks ---
  @impl true
  def init(_opts) do
    # Load initial plan or prepare for generation
    # May load a default "safe" runtime plan
    plan = case DataAccess.get_instrumentation_plan() do
      {:ok, p} -> p
      _ -> generate_default_runtime_plan() # A minimal, safe default
    end
    {:ok, %{current_plan: plan, project_analysis_cache: %{}}}
  end

  @impl true
  def handle_call({:analyze_and_plan, project_path, _opts}, _from, state) do
    # 1. Perform code analysis (CodeAnalyzer, etc. are still useful)
    analysis_result = CodeAnalyzer.analyze_project(project_path) # This is still valuable static analysis

    # 2. Generate RUNTIME tracing plan based on analysis and config
    runtime_plan = generate_runtime_plan_from_analysis(analysis_result, ElixirScope.Config.get())

    # 3. Store the new plan
    :ok = DataAccess.store_instrumentation_plan(runtime_plan)

    {:reply, {:ok, runtime_plan}, %{state | current_plan: runtime_plan, project_analysis_cache: analysis_result}}
  end

  @impl true
  def handle_call({:update_runtime_plan, directives}, _from, state) do
    # Apply directives to current_plan to create a new_plan
    # Validate new_plan
    # Store new_plan
    # Potentially notify active tracers to apply changes (complex)
    new_plan = apply_directives_to_plan(state.current_plan, directives)
    :ok = DataAccess.store_instrumentation_plan(new_plan)
    # Notify active tracing components about the plan update
    # This is a key part: how do Runtime.Tracer instances get the new plan?
    # PubSub, or Runtime.Tracer periodically polls Orchestrator/DataAccess.
    broadcast_plan_update(new_plan)
    {:reply, {:ok, new_plan}, %{state | current_plan: new_plan}}
  end

  # --- Private Helper Functions ---
  defp generate_default_runtime_plan do
    # A very minimal plan, e.g., trace nothing by default or only errors on key processes
    %{
      global_trace_flags: [:timestamp], # Minimal
      module_traces: %{},
      pid_specific_traces: %{},
      sampling_rate: Application.get_env(:elixir_scope, [:ai, :planning, :sampling_rate], 0.1) # Default low
    }
  end

  defp generate_runtime_plan_from_analysis(analysis_result, config) do
    # Logic to convert static analysis into runtime trace commands
    # Example: If CodeAnalyzer flags MyModule.my_func/2 as complex and critical:
    # module_traces: %{ MyModule => %{ functions: %{ {:my_func,2} => %{trace_level: :detailed, ...} }}}
    # This will use analysis_result (module types, complexity, etc.) and config (strategy, sampling)
    # to build the @type runtime_tracing_plan structure.

    # Placeholder for complex logic:
    # For now, just use a global strategy.
    default_strategy = config.ai.planning.default_strategy
    sampling_rate = config.ai.planning.sampling_rate

    module_traces =
      for {module_name, module_analysis} <- analysis_result.project_structure.regular_modules ++
                                           analysis_result.project_structure.genservers ++
                                           analysis_result.project_structure.phoenix_controllers, # etc.
          into: %{} do
        # Determine trace_level based on default_strategy and module_analysis.complexity_score, etc.
        trace_level = determine_trace_level_for_module(module_analysis, default_strategy)
        functions_to_trace = determine_functions_to_trace(module_analysis, trace_level)

        # Only add module if there are functions to trace
        if map_size(functions_to_trace) > 0 do
          {module_name, %{functions: functions_to_trace, otp_monitoring: determine_otp_monitoring(module_analysis, trace_level)}}
        else
          nil # Will be filtered out
        end
      end
      |> Enum.filter(fn {_, v} -> not is_nil(v) end) # Remove nil entries
      |> Enum.into(%{})


    %{
      global_trace_flags: determine_global_flags(default_strategy),
      module_traces: module_traces,
      pid_specific_traces: %{}, # Can be populated by runtime API calls
      sampling_rate: sampling_rate
    }
  end

  defp determine_trace_level_for_module(module_analysis, default_strategy) do
    # Simplified logic based on strategy and complexity
    case default_strategy do
      :minimal -> if module_analysis.complexity_score > 10, do: :basic, else: :none
      :balanced -> if module_analysis.complexity_score > 5, do: :detailed, else: :basic
      :full_trace -> :full
      _ -> :none
    end
  end

  defp determine_functions_to_trace(module_analysis, trace_level) do
    if trace_level == :none do
      %{}
    else
      # Extract function names from module_analysis (this needs CodeAnalyzer to provide MFAs)
      # For simplicity, let's assume CodeAnalyzer output has `module_analysis.functions = [{name,arity}, ...]`
      for {func_name, arity} <- module_analysis.functions || [], into: %{} do
        {{func_name, arity}, %{trace_level: trace_level, match_spec_conditions: []}}
      end
    end
  end

  defp determine_otp_monitoring(module_analysis, trace_level) do
    if module_analysis.module_type == :genserver && trace_level != :none do
      :state_changes # or :full_callbacks depending on trace_level
    else
      :none
    end
  end

  defp determine_global_flags(strategy) do
    case strategy do
      :minimal -> [:timestamp, :process_info] # Example
      :balanced -> [:call, :return_to, :send, :receive, :timestamp, :process_info]
      :full_trace -> [:all_trace_flags] # Example, expand this
      _ -> [:timestamp]
    end
  end


  defp apply_directives_to_plan(current_plan, directives) do
    # Logic to merge new directives into the existing plan
    # Example: directives could be {:add_module_trace, MyModule, trace_options}
    # This would deeply merge.
    Map.deep_merge(current_plan, directives) # Simplified
  end

  defp broadcast_plan_update(_new_plan) do
    # Use Phoenix.PubSub or similar to notify active Runtime.Tracer instances
    # ElixirScope.PubSub.broadcast("runtime_plan_updates", {:new_plan, new_plan})
    :ok
  end
end
```

### 5. `lib/elixir_scope/phoenix/integration.ex`

*   **Current Role:** Telemetry handlers call `InstrumentationRuntime` functions.
*   **New Role:** Telemetry handlers will now interact with the new `ElixirScope.Runtime` API to start/stop/tag traces or report specific semantic events that might be harder to infer from raw BEAM traces alone (e.g., "Phoenix request with this specific Plug session data started"). Or, they could directly call `Ingestor.ingest_generic_event` with Phoenix-specific event types.
*   **Decision:** **MODIFY.**

```elixir
# lib/elixir_scope/phoenix/integration.ex (Modified)
defmodule ElixirScope.Phoenix.Integration do
  @moduledoc "Phoenix-specific integration for ElixirScope using runtime tracing."

  alias ElixirScope.Capture.Ingestor # Or the new ElixirScope.Runtime API
  alias ElixirScope.Utils

  # Process dictionary key for Phoenix correlation ID
  @phoenix_correlation_key :elixir_scope_phoenix_correlation_id

  def enable do
    # Attach to fewer, more strategic Telemetry events if BEAM traces cover much.
    # Or, use Telemetry events to *tag* traces started by BEAM tracing.
    :telemetry.attach_many(
      :elixir_scope_phoenix_handlers,
      [
        [:phoenix, :endpoint, :start],
        [:phoenix, :endpoint, :stop],
        [:phoenix, :error_rendered] # New: for richer error context
        # Potentially reduce other handlers if BEAM traces for controller/LV processes are sufficient
      ],
      &handle_phoenix_event/4,
      %{}
    )
    # Ecto Telemetry can still be valuable
    attach_ecto_handlers()
  end

  def disable do
    :telemetry.detach(:elixir_scope_phoenix_handlers)
    :telemetry.detach(:elixir_scope_phoenix_ecto) # Ensure this ID matches ecto attach
  end

  def handle_phoenix_event([:phoenix, :endpoint, :start], _measurements, metadata, _config) do
    if ElixirScope.Runtime.Tracing.enabled_for_process?(self()) do # Assuming a new API from Runtime.Tracer
      conn = metadata.conn
      correlation_id = Utils.generate_correlation_id() # Root ID for this request
      Process.put(@phoenix_correlation_key, correlation_id)

      # Tag the current BEAM trace, or report a specific high-level event
      # Option 1: Tag existing BEAM trace (if Runtime.Tracer manages it)
      # ElixirScope.Runtime.Tracer.tag_trace(self(), %{phoenix_request_id: correlation_id, path: conn.request_path})

      # Option 2: Report specific Phoenix event
      Ingestor.ingest_generic_event(
        get_buffer_ref(), # Helper to get buffer
        :phoenix_request_start,
        %{method: conn.method, path: conn.request_path, params: conn.params, remote_ip: conn.remote_ip},
        self(),
        correlation_id,
        nil, nil
      )
    end
  end

  def handle_phoenix_event([:phoenix, :endpoint, :stop], measurements, metadata, _config) do
    if ElixirScope.Runtime.Tracing.enabled_for_process?(self()) do
      correlation_id = Process.get(@phoenix_correlation_key)
      # ElixirScope.Runtime.Tracer.end_segment(self(), :phoenix_request) or
      Ingestor.ingest_generic_event(
        get_buffer_ref(),
        :phoenix_request_stop,
        %{status: metadata.conn.status, duration_ns: measurements.duration},
        self(),
        correlation_id,
        nil, nil
      )
      Process.delete(@phoenix_correlation_key)
    end
  end

  def handle_phoenix_event([:phoenix, :error_rendered], measurements, metadata, _config) do
     if ElixirScope.Runtime.Tracing.enabled_for_process?(self()) do
      correlation_id = Process.get(@phoenix_correlation_key) # Or find from metadata if possible
      Ingestor.ingest_generic_event(
        get_buffer_ref(),
        :phoenix_error_rendered,
        %{status: metadata.status, kind: metadata.reason.__struct__, reason: metadata.reason, stacktrace: metadata.stacktrace, duration_ns: measurements.duration},
        self(),
        correlation_id,
        nil, nil
      )
    end
  end

  defp attach_ecto_handlers do
    :telemetry.attach_many(
      :elixir_scope_phoenix_ecto, # Unique ID for Ecto handlers
      [[:ecto, :repo, :query, :start], [:ecto, :repo, :query, :stop]],
      &handle_ecto_event/4,
      %{}
    )
  end

  def handle_ecto_event([:ecto, :repo, :query, :start], measurements, metadata, _config) do
    # Ecto queries often run in separate, short-lived processes spawned by DBConnection.
    # Propagating correlation ID here is key.
    # The AI plan might enable tracing for these Ecto query processes,
    # and we'd need a way to link their trace to the parent (e.g., Phoenix controller process).
    # This might involve DBConnection itself propagating some context, or ElixirScope
    # making educated guesses based on parent PIDs if :spawn is traced.

    # For Telemetry, try to get correlation_id from process dictionary if it was propagated
    # by the calling process (e.g. a Phoenix controller).
    correlation_id = Process.get(@phoenix_correlation_key) || Process.get(:elixir_scope_current_correlation_id)

    if ElixirScope.Runtime.Tracing.enabled_for_process?(self()) || correlation_id do
      Ingestor.ingest_generic_event(
        get_buffer_ref(),
        :ecto_query_start,
        %{repo: metadata.repo, source: metadata.source, query: Utils.truncate_data(metadata.query), params_count: length(metadata.params || []), query_time_ms: measurements.queue_time},
        self(),
        correlation_id, # Link to parent trace if available
        nil, nil
      )
    end
  end

  def handle_ecto_event([:ecto, :repo, :query, :stop], measurements, metadata, _config) do
    correlation_id = Process.get(@phoenix_correlation_key) || Process.get(:elixir_scope_current_correlation_id)
    if ElixirScope.Runtime.Tracing.enabled_for_process?(self()) || correlation_id do
      Ingestor.ingest_generic_event(
        get_buffer_ref(),
        :ecto_query_stop,
        %{repo: metadata.repo, result_size: result_size(metadata.result), query_time_ns: measurements.total_time, decode_time_ns: measurements.decode_time},
        self(),
        correlation_id,
        nil, nil
      )
    end
  end

  defp result_size({:ok, %{num_rows: nr, rows: _}}), do: nr
  defp result_size({:ok, %{rows: rows}}) when is_list(rows), do: length(rows)
  defp result_size(_), do: 0


  defp get_buffer_ref, do: Application.get_env(:elixir_scope, :main_buffer) # Example
end
```

### 6. `lib/elixir_scope/config.ex`

*   **Current Role:** Defines schema for many AST-transformation related settings (`instrumentation.*`).
*   **New Role:** Schema needs to change to reflect runtime tracing controls (e.g., default trace flags for `:erlang.trace`, settings for `StateMonitor`, rules for AI-driven runtime plan).
*   **Decision:** **MODIFY.**

```elixir
# lib/elixir_scope/config.ex (Modified - Schema Changes)
defmodule ElixirScope.Config do
  use GenServer
  require Logger

  defstruct [
    ai: %{
      # provider, api_key, model remain
      provider: :mock, api_key: nil, model: "gpt-4",
      analysis: %{ # CodeAnalyzer settings remain largely relevant
        max_file_size: 1_000_000, timeout: 30_000, cache_ttl: 3600
      },
      planning: %{ # This section changes significantly
        # default_strategy now influences RUNTIME tracing plans
        default_strategy: :balanced, # :minimal, :balanced, :full_runtime_trace
        performance_target: 0.01,    # Still relevant for AI to consider estimated impact
        sampling_rate: 1.0           # Global sampling for runtime traces
      }
    },
    capture: %{ # RingBuffer and AsyncProcessing settings largely remain
      ring_buffer: %{ size: 1_048_576, max_events: 100_000, overflow_strategy: :drop_oldest, num_buffers: :schedulers },
      processing: %{ batch_size: 1000, flush_interval: 100, max_queue_size: 10_000 }
      # vm_tracing is now the *primary* tracing config, not supplemental
      # This moves to a new :runtime_tracing section
    },
    runtime_tracing: %{ # NEW SECTION
      enabled_by_default: true, # Global switch for runtime tracing
      default_trace_flags: [:call, :return_to, :send, :receive, :timestamp, :procs], # For :erlang.trace
      default_otp_monitoring_level: :state_changes, # For StateMonitor (:none, :state_changes, :full_callbacks)
      max_traced_processes: 1000, # Safety limit
      trace_buffer_size_per_pid: 256, # For BEAM's internal trace message buffer
      module_trace_overrides: %{
        # MyModule => %{trace_flags: [:call], functions: %{ {:my_fun,1} => %{match_spec: ...}}}
      },
      exclude_modules_from_runtime_trace: [SomeNoisyLib]
    },
    storage: %{ # Remains largely the same
      hot: %{ max_events: 1_000_000, max_age_seconds: 3600, prune_interval: 60_000 },
      # ... warm, cold ...
    },
    interface: %{ # Remains largely the same
      iex_helpers: true, query_timeout: 5000,
      web: %{ enable: false, port: 4000 }
    }
    # The :instrumentation section (AST specific) is removed or heavily deprecated
    # instrumentation: %{ ... }
  ]

  # ... (start_link, get, update, init, handle_call, etc. remain mostly the same,
  #      but validation logic needs to be updated for the new schema) ...

  # --- Modified/New Validation Logic ---
  defp validate_runtime_tracing_config(rt_config) do
    # Validate rt_config.default_trace_flags, rt_config.max_traced_processes etc.
    with :ok <- validate_boolean(rt_config.enabled_by_default, "runtime_tracing.enabled_by_default"),
         :ok <- validate_list_of_atoms(rt_config.default_trace_flags, "runtime_tracing.default_trace_flags"),
         :ok <- validate_atom_in(rt_config.default_otp_monitoring_level, [:none, :state_changes, :full_callbacks], "runtime_tracing.default_otp_monitoring_level"),
         :ok <- validate_positive_integer(rt_config.max_traced_processes, "runtime_tracing.max_traced_processes")
    do
      :ok
    else
       err -> err
    end
  end

  # Update the main validate/1 function
  def validate(config) do
    with :ok <- validate_ai_config(config.ai),
         :ok <- validate_capture_config(config.capture),
         :ok <- validate_runtime_tracing_config(config.runtime_tracing), # ADDED
         :ok <- validate_storage_config(config.storage),
         :ok <- validate_interface_config(config.interface)
         # :ok <- validate_instrumentation_config(config.instrumentation) # REMOVED or Deprecated
    do
      {:ok, config}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Helper for new validation types
  defp validate_boolean(val, field) when is_boolean(val), do: :ok
  defp validate_boolean(_val, field), do: {:error, "#{field} must be a boolean"}

  defp validate_list_of_atoms(val, field) when is_list(val) and Enum.all?(val, &is_atom/1), do: :ok
  defp validate_list_of_atoms(_val, field), do: {:error, "#{field} must be a list of atoms"}

  defp validate_atom_in(val, allowed_atoms, field) when is_atom(val) and val in allowed_atoms, do: :ok
  defp validate_atom_in(_val, allowed_atoms, field), do: {:error, "#{field} must be one of #{inspect(allowed_atoms)}"}

  # ... (other existing private functions for loading, merging, validation helpers remain,
  #      but need to be adapted for the new schema paths if they were path-specific) ...
  # updatable_path?/1 will need to be revised for new runtime config keys.
  defp updatable_path?(path) do
    case path do
      [:ai, :planning, :sampling_rate] -> true
      [:ai, :planning, :default_strategy] -> true # This now influences runtime plan
      [:runtime_tracing, :enabled_by_default] -> true
      [:runtime_tracing, :default_trace_flags] -> true
      [:runtime_tracing, :sampling_rate] -> true # If runtime has its own sampling distinct from AI plan
      # ... other relevant runtime-updatable paths ...
      _ -> false
    end
  end
end
```

### 7. `lib/elixir_scope.ex` (Main API)

*   **Current Role:** `start/1` initializes ElixirScope, including triggering AST instrumentation implicitly via `Application.ensure_all_started`.
*   **New Role:** `start/1` will now focus on starting the runtime tracing infrastructure. It will still consult `AI.Orchestrator` for a *runtime tracing plan*.
*   **Decision:** **MODIFY.**

```elixir
# lib/elixir_scope.ex (Modified)
defmodule ElixirScope do
  @moduledoc """
  ElixirScope - AI-Powered Execution Cinema Debugger using Runtime Tracing.
  """

  require Logger

  # ... (typespecs for start_option might change to reflect runtime trace controls) ...
  @type start_option ::
    {:strategy, :minimal | :balanced | :full_runtime_trace} |
    {:sampling_rate, float()} |
    {:trace_modules, [module()]} | # For runtime tracing
    {:exclude_modules_from_trace, [module()]} # For runtime tracing

  @spec start([start_option()]) :: :ok | {:error, term()}
  def start(opts \\ []) do
    case Application.ensure_all_started(:elixir_scope) do
      {:ok, _} ->
        # Configuration is loaded by ElixirScope.Config GenServer
        # Now, apply runtime options and potentially activate tracing based on AI plan
        current_config = ElixirScope.Config.get()
        runtime_plan = case ElixirScope.AI.Orchestrator.get_runtime_tracing_plan() do
          {:ok, plan} -> plan
          _ -> # No plan, generate a default or use config's default
               # This assumes Orchestrator might have been run by a Mix task already
               # If not, analyze_and_plan might need to be callable here.
               # For simplicity, assume a plan is available or a default is used by Runtime.Tracer
               Logger.info("ElixirScope: No pre-generated runtime plan found, using defaults.")
               ElixirScope.AI.Orchestrator.generate_default_runtime_plan() # Ensure this func exists
        end

        # Pass runtime_plan and opts to the main runtime tracing controller
        case ElixirScope.Runtime.Controller.activate_tracing(runtime_plan, opts) do # Assuming a new Controller module
          :ok ->
            Logger.info("ElixirScope runtime tracing started successfully.")
            :ok
          {:error, reason} ->
            Logger.error("Failed to activate ElixirScope runtime tracing: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to start ElixirScope application: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @spec stop() :: :ok
  def stop do
    # Deactivate runtime tracing
    ElixirScope.Runtime.Controller.deactivate_tracing() # Assuming a new Controller module
    # Then stop the application
    case Application.stop(:elixir_scope) do
      :ok -> Logger.info("ElixirScope stopped")
      {:error, reason} -> Logger.warning("Error stopping ElixirScope: #{inspect(reason)}")
    end
    :ok # stop should be idempotent and not fail if already stopped
  end

  # status/0, running?/0, get_config/0, update_config/2 can remain largely the same
  # but get_performance_stats/0 and get_storage_stats/0 will need to be implemented
  # to fetch data from the actual runtime components.

  # Query functions (get_events, get_state_history etc.) remain :not_implemented_yet
  # AI functions (analyze_codebase, update_instrumentation) will now relate to runtime plans.
  def analyze_codebase(opts \\ []) do # Renamed from update_instrumentation
    if running?() do
      project_path = Keyword.get(opts, :project_path, File.cwd!())
      ElixirScope.AI.Orchestrator.analyze_and_plan(project_path, opts) # Triggers regeneration of runtime plan
    else
      {:error, :not_running}
    end
  end

  def update_instrumentation(directives) do # This now updates the *runtime* plan
    if running?() do
      ElixirScope.AI.Orchestrator.update_runtime_tracing_plan(directives)
    else
      {:error, :not_running}
    end
  end

  # ... (private helpers like configure_runtime_options would be removed or adapted
  #      for ElixirScope.Runtime.Controller.activate_tracing) ...
end
```

---

## Step 3: Add New Files for Runtime Tracing

### 1. `lib/elixir_scope/runtime.ex` (New API Module)

This module will house the user-facing API for controlling runtime tracing, similar to the sketch in `OPUS_PROD_RUNTIME_INSTRUMENTATION_API_SKETCH.md`.

```elixir
# lib/elixir_scope/runtime.ex (New File - Sketch)
defmodule ElixirScope.Runtime do
  @moduledoc """
  Public API for controlling ElixirScope's runtime tracing capabilities.
  Allows dynamic enabling/disabling of traces, setting trace levels,
  and targeting specific modules, functions, or processes.
  """

  alias ElixirScope.Runtime.Controller # Assuming a Controller GenServer manages tracers

  @type trace_target :: module() | {module(), atom()} | {module(), atom(), non_neg_integer()} | pid()
  @type trace_options :: [
    level: :basic | :detailed | :full, # Controls trace flags and match_spec detail
    trace_flags: list(atom),          # Specific :erlang.trace flags
    match_spec: list(tuple),          # Erlang match specification
    duration: {non_neg_integer(), :seconds | :minutes},
    sampling_rate: float()
  ]

  @doc "Globally enables or disables ElixirScope runtime tracing."
  def set_tracing_enabled(enabled_boolean) do
    Controller.set_global_tracing_status(enabled_boolean)
  end

  @doc "Starts tracing on a specific target with options."
  def trace(target, opts \\ []) do
    Controller.start_trace(target, opts)
  end

  @doc "Stops tracing on a specific target or by trace reference."
  def stop_trace(trace_ref_or_target) do
    Controller.stop_trace(trace_ref_or_target)
  end

  @doc "Lists all active runtime traces."
  def list_traces do
    Controller.list_active_traces()
  end

  @doc "Adjusts parameters of an active trace."
  def adjust_trace(trace_ref, adjustments) do
    Controller.adjust_trace_parameters(trace_ref, adjustments)
  end

  @doc "Enables state capture for OTP processes for time-travel."
  def enable_state_capture(target, opts \\ []) do
    # Target could be a GenServer name, PID, or module (for all instances)
    # Opts: snapshot_interval, max_snapshots, etc.
    ElixirScope.Runtime.StateMonitor.start_monitoring(target, opts)
  end

  @doc "Disables state capture for a target."
  def disable_state_capture(target) do
    ElixirScope.Runtime.StateMonitor.stop_monitoring(target)
  end

  # ... other APIs as sketched in OPUS_PROD_RUNTIME_INSTRUMENTATION_API_SKETCH.md
end
```

### 2. `lib/elixir_scope/runtime/controller.ex` (New File - Manages Tracers)

This `GenServer` would be the central point for managing runtime tracing. It receives API calls from `ElixirScope.Runtime` and orchestrates the `Runtime.Tracer` and `Runtime.StateMonitor`. It holds the current runtime tracing plan (obtained from `AI.Orchestrator` or `Config`).

```elixir
# lib/elixir_scope/runtime/controller.ex (New File - Sketch)
defmodule ElixirScope.Runtime.Controller do
  use GenServer
  require Logger

  alias ElixirScope.Runtime.Tracer
  alias ElixirScope.Runtime.StateMonitor
  alias ElixirScope.AI.Orchestrator

  defstruct [:global_tracing_enabled, :active_traces, :runtime_plan, :tracer_manager_pid, :state_monitor_manager_pid]

  # --- Public API (called by ElixirScope.Runtime) ---
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def activate_tracing(initial_plan, startup_opts) do
    GenServer.call(__MODULE__, {:activate_tracing, initial_plan, startup_opts})
  end

  def deactivate_tracing do
    GenServer.call(__MODULE__, :deactivate_tracing)
  end

  def set_global_tracing_status(enabled_boolean) do
    GenServer.cast(__MODULE__, {:set_global_status, enabled_boolean})
  end

  def start_trace(target, opts) do
    GenServer.call(__MODULE__, {:start_trace, target, opts})
  end
  # ... other API forwarding functions ...

  # --- GenServer Callbacks ---
  @impl true
  def init(_opts) do
    # Start child managers for tracers and state monitors
    {:ok, tracer_manager_pid} = ElixirScope.Runtime.TracerManager.start_link() # New module
    {:ok, state_monitor_manager_pid} = ElixirScope.Runtime.StateMonitorManager.start_link() # New module

    # Load initial runtime plan from Orchestrator/Config
    initial_plan = case Orchestrator.get_runtime_tracing_plan() do
      {:ok, plan} -> plan
      _ -> Orchestrator.generate_default_runtime_plan()
    end

    state = %__MODULE__{
      global_tracing_enabled: initial_plan.enabled_by_default || true, # from config
      active_traces: %{}, # trace_ref => %{target: ..., options: ...}
      runtime_plan: initial_plan,
      tracer_manager_pid: tracer_manager_pid,
      state_monitor_manager_pid: state_monitor_manager_pid
    }
    # If global tracing is enabled by default, apply the plan
    if state.global_tracing_enabled, do: apply_runtime_plan(state.runtime_plan, state.tracer_manager_pid)

    {:ok, state}
  end

  @impl true
  def handle_call({:activate_tracing, initial_plan, startup_opts}, _from, state) do
    # Apply startup_opts to initial_plan if necessary
    # For now, assume initial_plan is authoritative or use Config for opts
    new_plan = merge_opts_into_plan(initial_plan, startup_opts)
    apply_runtime_plan(new_plan, state.tracer_manager_pid)
    # Potentially start default state monitors based on plan
    apply_state_monitoring_plan(new_plan, state.state_monitor_manager_pid)

    {:reply, :ok, %{state | runtime_plan: new_plan, global_tracing_enabled: true}}
  end

  @impl true
  def handle_call(:deactivate_tracing, _from, state) do
    TracerManager.stop_all_traces(state.tracer_manager_pid)
    StateMonitorManager.stop_all_monitors(state.state_monitor_manager_pid)
    {:reply, :ok, %{state | global_tracing_enabled: false, active_traces: %{}}}
  end

  @impl true
  def handle_call({:start_trace, target, opts}, _from, state) do
    if state.global_tracing_enabled do
      trace_ref = ElixirScope.Utils.generate_id() # Unique ref for this trace
      case TracerManager.add_trace(state.tracer_manager_pid, trace_ref, target, opts) do
        :ok ->
          new_active_traces = Map.put(state.active_traces, trace_ref, %{target: target, options: opts, status: :active})
          {:reply, {:ok, trace_ref}, %{state | active_traces: new_active_traces}}
        error -> {:reply, error, state}
      end
    else
      {:reply, {:error, :tracing_globally_disabled}, state}
    end
  end
  # ... other handle_call for stop_trace, list_traces, adjust_trace ...

  @impl true
  def handle_cast({:set_global_status, enabled}, state) do
    if enabled && !state.global_tracing_enabled do
      apply_runtime_plan(state.runtime_plan, state.tracer_manager_pid) # Re-apply plan when enabling
      apply_state_monitoring_plan(state.runtime_plan, state.state_monitor_manager_pid)
    elsif !enabled && state.global_tracing_enabled do
      TracerManager.stop_all_traces(state.tracer_manager_pid)
      StateMonitorManager.stop_all_monitors(state.state_monitor_manager_pid)
    end
    {:noreply, %{state | global_tracing_enabled: enabled}}
  end

  # ... handle_info for plan updates from PubSub if Orchestrator broadcasts them ...

  defp apply_runtime_plan(plan, tracer_manager_pid) do
    # Stop existing traces that are not in the new plan or have changed options
    # For each entry in plan.module_traces, call TracerManager.add_trace
    TracerManager.apply_plan(tracer_manager_pid, plan)
  end

  defp apply_state_monitoring_plan(plan, state_monitor_manager_pid) do
    StateMonitorManager.apply_plan(state_monitor_manager_pid, plan)
  end

  defp merge_opts_into_plan(plan, opts) do
    # Logic to merge startup options (like :strategy, :sampling_rate from ElixirScope.start/1)
    # into the plan fetched from AI.Orchestrator, creating a final runtime plan.
    # This is where ElixirScope.start(strategy: :full_runtime_trace) would take effect.
    strategy_opt = Keyword.get(opts, :strategy)
    sampling_opt = Keyword.get(opts, :sampling_rate)

    new_plan = plan
    new_plan = if strategy_opt, do: Map.put(new_plan, :strategy, strategy_opt), else: new_plan
    new_plan = if sampling_opt, do: Map.put(new_plan, :sampling_rate, sampling_opt), else: new_plan
    # ... further logic to translate strategy into specific trace flags etc. ...
    new_plan
  end
end
```

### 3. `lib/elixir_scope/runtime/tracer_manager.ex` (New File) & `lib/elixir_scope/runtime/tracer.ex` (New File)

*   `TracerManager`: A `GenServer` or `Supervisor` that manages multiple `Tracer` instances. Each `Tracer` could be responsible for a specific set of trace patterns (e.g., one for all calls to `MyModule`, another for all messages to `pid_X`).
*   `Tracer`: A process (likely `GenServer`) that:
    *   Is started by `TracerManager` based on the runtime plan.
    *   Uses `:erlang.trace/3`, `:erlang.trace_pattern/3` to enable tracing.
    *   Defines a trace port or acts as the tracer process itself to receive BEAM trace messages.
    *   Converts raw BEAM trace messages (e.g., `{:trace, pid, :call, {M,F,A}}`) into `ElixirScope.Events` structs.
    *   Sends these events to `ElixirScope.Capture.Ingestor`.
    *   Manages correlation IDs for traced PIDs locally or via a shared context.

```elixir
# lib/elixir_scope/runtime/tracer.ex (New File - Sketch of an individual tracer process)
defmodule ElixirScope.Runtime.Tracer do
  use GenServer
  require Logger

  alias ElixirScope.Capture.Ingestor

  defstruct [:trace_ref, :target, :options, :buffer_ref, :traced_pids_correlation_ids, :local_call_stacks]

  def start_link(trace_ref, target, options, buffer_ref) do
    GenServer.start_link(__MODULE__, {trace_ref, target, options, buffer_ref}, name: via_name(trace_ref))
  end

  def via_name(trace_ref), do: {:via, Registry, {ElixirScope.TracersRegistry, trace_ref}}

  @impl true
  def init({trace_ref, target, options, buffer_ref}) do
    Process.flag(:trap_exit, true)
    # Set self as tracer for specific patterns
    # This is complex: :erlang.trace_pattern sets a global tracer for those MFA/PID calls.
    # Or, use :dbg.tracer/2 and :dbg.tp/2, :dbg.p/2.
    # Let's assume :dbg for more modern approach.
    :dbg.tracer(:process, {&handle_trace_event/2, self()}) # Self becomes the tracer
    # :dbg.p(:new_processes, [:call]) # Trace calls in new processes

    apply_trace_rules(target, options)

    state = %__MODULE__{
      trace_ref: trace_ref,
      target: target,
      options: options,
      buffer_ref: buffer_ref,
      traced_pids_correlation_ids: %{}, # PID => current_root_correlation_id
      local_call_stacks: %{}            # PID => list_of_call_ids
    }
    {:ok, state}
  end

  # This function is called by :dbg.tracer
  def handle_trace_event(trace_msg, tracer_pid_or_state) do
    # In a real :dbg tracer, the second arg is user-provided state.
    # Here, we'd send a message to the GenServer managing this trace.
    GenServer.cast(tracer_pid_or_state, {:trace_message, trace_msg})
  end

  @impl true
  def handle_cast({:trace_message, trace_msg}, state) do
    # Convert trace_msg to ElixirScope.Event and send to Ingestor
    # Example for a :call trace:
    case trace_msg do
      {:trace_ts, pid, :call, {m,f,a}, timestamp_monotonic} when is_pid(pid) ->
        args = if Keyword.get(state.options, :capture_args, true), do: a, else: :hidden
        # Correlation ID management:
        # - If pid is new to this tracer, start a new root correlation_id
        # - Push a new call_id onto this pid's local_call_stack
        root_corr_id = Map.get(state.traced_pids_correlation_ids, pid, ElixirScope.Utils.generate_correlation_id())
        call_id = ElixirScope.Utils.generate_id() # Unique ID for this call
        new_call_stack = [call_id | Map.get(state.local_call_stacks, pid, [])]

        Ingestor.ingest_generic_event(state.buffer_ref, :function_entry,
          %{module: m, function: f, arity: length(a), args: args, call_id: call_id, parent_call_id: List.first(Map.get(state.local_call_stacks, pid, []))},
          pid, root_corr_id, timestamp_monotonic, System.system_time(:nanosecond)) # Wall time

        new_corr_ids = Map.put(state.traced_pids_correlation_ids, pid, root_corr_id)
        new_stacks = Map.put(state.local_call_stacks, pid, new_call_stack)
        {:noreply, %{state | traced_pids_correlation_ids: new_corr_ids, local_call_stacks: new_stacks}}

      {:trace_ts, pid, :return_to, {m,f,arity}, return_value, timestamp_monotonic}  when is_pid(pid) ->
        # Pop call_id from stack, get duration, send :function_exit
        current_call_stack = Map.get(state.local_call_stacks, pid, [])
        {call_id_for_exit, rest_stack} = List.pop_at(current_call_stack, 0, nil) # Pop head
        root_corr_id = Map.get(state.traced_pids_correlation_ids, pid)

        # Duration needs entry timestamp, which should have been stored with call_id if needed by EventCorrelator
        # Or, EventCorrelator calculates duration by matching entry/exit events by call_id.

        Ingestor.ingest_generic_event(state.buffer_ref, :function_exit,
          %{module: m, function: f, arity: arity, result: return_value, call_id: call_id_for_exit, duration_ns: 0}, # Duration to be filled by Correlator
          pid, root_corr_id, timestamp_monotonic, System.system_time(:nanosecond))

        new_stacks = Map.put(state.local_call_stacks, pid, rest_stack)
        {:noreply, %{state | local_call_stacks: new_stacks}}

      # ... handle :send, :receive, :spawn, :exit, :link, :unlink, etc. ...
      _other_trace_msg ->
        # Logger.debug("Unhandled trace: #{inspect(other_trace_msg)}")
        {:noreply, state}
    end
  end

  @impl true
  def terminate(_reason, state) do
    # Clean up trace rules
    remove_trace_rules(state.target, state.options)
    :ok
  end

  defp apply_trace_rules(target, options) do
    match_spec = Keyword.get(options, :match_spec, [{:_, [], [{:return_trace}]}]) # Default match spec
    trace_flags = Keyword.get(options, :trace_flags, [:call, :return_to, :timestamp]) # Sensible defaults

    case target do
      pid when is_pid(pid) -> :dbg.p(pid, trace_flags) # Basic flags for PID
      {m,f,a} -> :dbg.tpl(m,f,a, match_spec)
      {m,f}   -> :dbg.tp(m,f, match_spec)
      m when is_atom(m) -> :dbg.tp(m, :_, match_spec) # Trace all functions in module
    end
    Logger.info("Applied trace rules for #{inspect target} with options #{inspect options}")
  end

  defp remove_trace_rules(target, _options) do
    # Use :dbg.ctpl, :dbg.ctp, :dbg.ctpg to clear traces
    case target do
      pid when is_pid(pid) -> :dbg.ctp(pid)
      {m,f,a} -> :dbg.ctpl(m,f,a)
      {m,f}   -> :dbg.ctp(m,f)
      m when is_atom(m) -> :dbg.ctp(m)
    end
    Logger.info("Removed trace rules for #{inspect target}")
  end
end
```
**Note on `TracerManager` and `Tracer`:** The details of how `TracerManager` chunks the runtime plan and assigns parts to individual `Tracer` processes are complex. A simpler initial model might have fewer, more general `Tracer` processes, or even a single one if `:dbg` tracer scales well. The `TracerManager` would handle starting/stopping these based on the overall plan.

### 4. `lib/elixir_scope/runtime/state_monitor_manager.ex` (New File) & `lib/elixir_scope/runtime/state_monitor.ex` (New File)

*   `StateMonitorManager`: Manages multiple `StateMonitor` instances.
*   `StateMonitor`: A process that uses `:sys.install/3` to attach to a specific OTP process (e.g., a GenServer by name or PID). It implements the debug handler functions (`system_continue`, `system_terminate`, etc.) and converts OTP debug messages (which often include state) into `ElixirScope.Events.StateChange` events, sending them to the `Ingestor`.

```elixir
# lib/elixir_scope/runtime/state_monitor.ex (New File - Sketch)
defmodule ElixirScope.Runtime.StateMonitor do
  @moduledoc "Monitors OTP process state using :sys.install for ElixirScope."
  use GenServer # Each monitor instance is a GenServer to hold its target and config
  require Logger

  alias ElixirScope.Capture.Ingestor

  defstruct [:target_pid, :target_name, :buffer_ref, :options, :last_known_state_hash, :sys_handle]

  def start_link(target, options, buffer_ref) do
    GenServer.start_link(__MODULE__, {target, options, buffer_ref}, [])
  end

  @impl true
  def init({target, options, buffer_ref}) do
    Process.flag(:trap_exit, true)
    # Resolve target to PID if it's a name
    target_pid = case target do
      pid when is_pid(pid) -> pid
      name when is_atom(name) -> Process.whereis(name)
    end

    if !target_pid || !Process.alive?(target_pid) do
      {:stop, :target_not_found_or_not_alive}
    else
      # Install self as a debug handler for the target process
      # The 'debug' data passed to :sys.install will be {self(), make_ref()}
      # to identify messages coming back from the :sys trace.
      # The target process's :sys debug messages will be sent to this StateMonitor.
      sys_handle = :sys.install(target_pid, {self(), make_ref()})
      # We might also need to explicitly trace the target_pid for :receive to get callback returns
      # if :sys.install doesn't give us state *after* the callback.
      # Or, more simply, rely on :sys.get_state after a callback trace message.

      Logger.info("StateMonitor started for #{inspect target_pid}")
      # Capture initial state
      initial_state = try_get_state(target_pid)
      report_state_snapshot(target_pid, initial_state, :initial, buffer_ref)


      state = %__MODULE__{
        target_pid: target_pid,
        target_name: if(is_atom(target), do: target, else: nil),
        buffer_ref: buffer_ref,
        options: options,
        last_known_state_hash: if(initial_state, do: :erlang.phash2(initial_state), else: nil),
        sys_handle: sys_handle
      }
      {:ok, state}
    end
  end

  # This module now needs to implement the debug handler behavior for :sys
  # These functions are NOT GenServer callbacks, they are called directly by :sys
  # in the context of THIS StateMonitor process when it receives a system message
  # from the traced process.

  @doc """
  :sys debug handler: called when the traced process receives a system message.
  `debug_data` is `{this_state_monitor_pid, ref}` set during :sys.install.
  `State` is the StateMonitor's own GenServer state.
  """
  def system_event(event_type, event_data, _from_pid, _debug_data, state_monitor_genserver_state) do
    # This is where we get system events like {:in, msg}, {:out, reply, new_state}, etc.
    # We need to extract state changes and report them.
    target_pid = state_monitor_genserver_state.target_pid
    current_state_hash = state_monitor_genserver_state.last_known_state_hash
    new_state = case event_type do
      # For GenServer, :out often contains the new state
      :out -> elem(event_data, 1) # Assuming event_data is {Reply, NewState} or {NewState}
      # Other event_types might require calling :sys.get_state(target_pid)
      _ -> try_get_state(target_pid)
    end

    if new_state do
      new_state_hash = :erlang.phash2(new_state)
      if new_state_hash != current_state_hash do
        # State has changed
        callback_name = extract_callback_from_event(event_type, event_data) # Heuristic
        Ingestor.ingest_generic_event(state_monitor_genserver_state.buffer_ref,
          :state_change,
          %{
            server_pid: target_pid,
            callback: callback_name,
            old_state_ref: :previous_hash, # Could store old_state if small, or just hash
            new_state_ref: Utils.truncate_data(new_state), # Store truncated new state
            state_diff: :computed_if_needed # Placeholder
          },
          target_pid,
          Process.get(:elixir_scope_current_correlation_id), # If propagated
          nil, nil
        )
        GenServer.cast(self(), {:update_last_hash, new_state_hash}) # Update internal state
      end
    end
    # The return value of system_event depends on what :sys expects.
    # Typically, it just needs to acknowledge.
    :ok
  end

  defp try_get_state(pid) do
    try do
      :sys.get_state(pid)
    rescue
      _ -> nil # Process might have died or not an OTP process
    end
  end

  defp report_state_snapshot(pid, current_state, reason, buffer_ref) do
    # Simplified, for full snapshots
    unless is_nil(current_state) do
      Ingestor.ingest_generic_event(buffer_ref,
        :state_snapshot, # A new event type for full snapshots
        %{server_pid: pid, reason: reason, state: Utils.truncate_data(current_state)},
        pid, Process.get(:elixir_scope_current_correlation_id), nil, nil
      )
    end
  end


  # GenServer callback to update internal hash
  @impl true
  def handle_cast({:update_last_hash, hash}, state) do
    {:noreply, %{state | last_known_state_hash: hash}}
  end


  @impl true
  def terminate(_reason, state) do
    # Clean up :sys.install handle
    if state.sys_handle, do: :sys.remove_handle(state.sys_handle)
    Logger.info("StateMonitor stopped for #{inspect state.target_pid || state.target_name}")
    :ok
  end

  defp extract_callback_from_event(:in, msg_tuple) when is_tuple(msg_tuple) and tuple_size(msg_tuple) >= 1 do
    # Attempt to guess callback from message, e.g. first element of tuple for GenServer calls
    elem(msg_tuple,0)
  end
  defp extract_callback_from_event(_, _), do: :unknown

end
```
**Note on `StateMonitor` and `:sys.install`**: `:sys.install` is powerful but complex. The debug handler functions it calls are *not* GenServer callbacks directly but are executed by the `StateMonitor` process when it receives system messages. The `StateMonitor` itself is a GenServer to manage its lifecycle and hold configuration. A simpler alternative for OTP state is to enable BEAM tracing on the OTP process and parse the state from trace messages of callback returns, which is often included. The `OPUS_DONT_REINVENT_AND_USE_BUILTIN_DEBUG.md` snippet for `StateCapture` suggests using `:sys.install` and then its `handle_event/2` to intercept state, which is a valid approach.

---

## Step 4: Update Test Suites

*   **Remove/Archive AST Tests:** Tests in `test/elixir_scope/ast/` and `test/elixir_scope/compiler/` are no longer relevant for the primary tracing mechanism.
*   **Modify `InstrumentationRuntimeTest`:** Heavily simplify to test the reduced API surface.
*   **Add New Tests:**
    *   `test/elixir_scope/runtime_test.exs`: For the new public API.
    *   `test/elixir_scope/runtime/controller_test.exs`.
    *   `test/elixir_scope/runtime/tracer_manager_test.exs` and `test/elixir_scope/runtime/tracer_test.exs`.
    *   `test/elixir_scope/runtime/state_monitor_manager_test.exs` and `test/elixir_scope/runtime/state_monitor_test.exs`.
*   **Update Integration Tests:** Existing integration tests (like Phoenix tests) must be updated to reflect that tracing is now enabled/controlled via the runtime API, not compile-time hooks.

---

## Step 5: Phased Rollout and Validation Plan

1.  **Implement `Runtime.Tracer` and `Runtime.StateMonitor` backbones:** Get them capturing basic BEAM trace messages and `:sys` events and successfully sending them to the `Ingestor`.
2.  **Implement `Runtime.Controller`:** Basic functionality to start/stop a few specific tracers/monitors.
3.  **Integrate `AI.Orchestrator` output:** Adapt `Orchestrator` to produce runtime plans. `Controller` consumes this plan to activate default tracing.
4.  **Build out `ElixirScope.Runtime` API:** Expose more granular control.
5.  **Refactor `Phoenix.Integration`:** Update Telemetry handlers.
6.  **Extensive Testing:** Focus on diverse applications, OTP patterns, and concurrency scenarios.
7.  **Performance Profiling:** Continuously measure overhead of runtime tracing and the processing pipeline.

---

This revamp is a significant undertaking but aligns ElixirScope more closely with BEAM's strengths and typical production debugging needs. It makes the "AI-Powered Execution Cinema" vision build upon a more flexible and ecosystem-friendly foundation. The backend components (`Ingestor`, `RingBuffer`, `AsyncWriterPool`, `EventCorrelator`, `DataAccess`) remain core to ElixirScope's value.
