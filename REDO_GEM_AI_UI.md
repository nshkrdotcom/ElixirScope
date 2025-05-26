Okay, let's dive into designing the AI Consumer Interface. First, we'll discuss and decide on the consumption model, then detail the interface itself.

**How Will Your AI Process Consume the Event Stream?**

The choice of how the AI process consumes events depends heavily on the specific needs of the "automated loops" versus the "HITL debugger" (Execution Cinema).

There are two primary models for event consumption:

1.  **Batch/Query-Based Consumption (Pull Model):**
    *   **Mechanism:** The AI process queries a data store (like `ElixirScope.Storage.DataAccess`) for events based on specific criteria (time range, process ID, correlation ID, event type, etc.).
    *   **Pros:**
        *   Allows AI to process data at its own pace.
        *   Good for historical analysis, training ML models, and offline tasks.
        *   Enables complex queries and aggregations directly on the stored data.
        *   Simplifies the "hot path" of event capture, as `AsyncWriter` only needs to write to storage.
    *   **Cons:**
        *   Not truly real-time; there's a delay between event occurrence and its availability for querying (ingestion + storage latency).
        *   For live debugging, requires continuous polling or a notification mechanism.
    *   **Primary Source:** `ElixirScope.Storage.DataAccess`.

2.  **Streaming Consumption (Push Model):**
    *   **Mechanism:** The AI process subscribes to an event stream and receives events as they are processed by the capture pipeline.
    *   **Pros:**
        *   Enables near real-time processing and visualization, crucial for the "Execution Cinema."
        *   Can react immediately to specific events for alerting or dynamic adjustments.
    *   **Cons:**
        *   The AI consumer must be able to keep up with the event stream to avoid backpressure on the capture pipeline.
        *   Requires a robust streaming infrastructure (e.g., pub/sub, dedicated streaming GenServer).
        *   Handling historical data alongside real-time data requires more complex consumer logic (e.g., backfilling).
    *   **Potential Sources:**
        *   **Option A: Directly from `AsyncWriter` (or a component it notifies):** `AsyncWriter` could, in parallel to writing to storage, publish events to a pub/sub system or a dedicated streaming GenServer. Lowest latency.
        *   **Option B: From `RingBuffer` (via a separate consumer task):** A dedicated task could read from the `RingBuffer` and stream to AI. Decouples from `AsyncWriter` but adds another `RingBuffer` reader.
        *   **Option C: From `Storage.DataAccess` (via a "tailing" or pub/sub mechanism on new writes):** Events are stored first, then streamed. Slightly higher latency but leverages existing storage.

**Decision & Rationale:**

For a robust and flexible system, a **hybrid approach leveraging both models** is best:

*   **For Automated AI Loops (Offline/Batch Analysis, Model Training):**
    *   **Primary Consumption Model:** Batch/Query-Based via `ElixirScope.Storage.DataAccess`.
    *   **Reasoning:** These processes often need large historical datasets, can run asynchronously, and benefit from the powerful querying capabilities of a dedicated storage layer.

*   **For HITL Debugger ("Execution Cinema" - Real-time & Historical):**
    *   **Primary Consumption Model for Live View:** Streaming Consumption.
    *   **Source for Streaming:** To keep the primary capture pipeline (`Ingestor` -> `RingBuffer` -> `AsyncWriter` -> `Storage`) lean and focused on durable capture, the **`Storage.DataAccess` layer (or a closely associated service) should provide the streaming API.** This could be implemented via:
        *   A GenServer that consumers subscribe to, which itself tails new writes to `Storage.DataAccess` (e.g., using ETS `select_replace` notifications if ETS is the backend, or a similar mechanism for other stores).
        *   Alternatively, `AsyncWriter` could publish to a lightweight, in-memory pub/sub system (like `Registry` or a dedicated GenServer-based one) *in addition* to writing to `Storage.DataAccess`. AI consumers would subscribe to this pub/sub. This offers lower latency for live streaming.
    *   **Primary Consumption Model for Context/History:** Batch/Query-Based via `ElixirScope.Storage.DataAccess`.
    *   **Reasoning for HITL:** The "Execution Cinema" needs to display live events as they happen but also allow the user to pause, rewind (query historical data), and inspect past states.

**Chosen Streaming Source for Initial Design:**

Let's assume for the initial detailed design that a dedicated module, say `ElixirScope.Streaming.EventStreamer`, will be responsible for providing the real-time event stream. This module would likely get events by being notified by `AsyncWriter` (or `Storage.DataAccess` upon successful write) or by tailing the `RingBuffer` itself. This decouples the `AsyncWriter` slightly.

---

**AI Consumer Interface Design**

This interface isn't a single module the AI calls, but rather the collection of APIs provided by ElixirScope components that AI processes will use to access event data.

**I. Batch/Query Interface (via `ElixirScope.Storage.DataAccess`)**

This interface is for historical analysis, model training, and providing context to the HITL debugger.

```elixir
defmodule ElixirScope.Storage.DataAccess do
  # ... (existing functions like store_event, get_event) ...

  @typedoc """
  Options for querying events.
  - `start_time_monotonic`/`end_time_monotonic`: Nanosecond monotonic timestamps.
  - `start_time_wall`/`end_time_wall`: Nanosecond wall-clock timestamps.
  - `pid`: Filter by specific process ID.
  - `correlation_id`: Filter by a root correlation ID (to get an entire trace).
  - `event_types`: List of event type atoms (e.g., `[:function_entry, :local_variable_snapshot]`).
  - `mfa`: Filter by `{module, function, arity}`.
  - `tags`: Filter by custom key-value tags (if events are tagged).
  - `text_search`: Full-text search on event data (e.g., variable names, log messages).
  - `limit`: Maximum number of events to return.
  - `offset`/`page_token`: For pagination.
  - `sort_by`: Field to sort by (e.g., `:timestamp`, `:wall_time`).
  - `sort_order`: `:asc` or `:desc`.
  - `projection`: List of event fields to return (e.g., `[:timestamp, :event_type, :pid, "data.variables.x"]`).
  """
  @type query_opts_v1 :: [
    start_time_monotonic: integer(),
    end_time_monotonic: integer(),
    start_time_wall: integer(),
    end_time_wall: integer(),
    pid: pid(),
    correlation_id: String.t(),
    event_types: [atom()],
    mfa: {module(), atom(), arity()},
    tags: %{String.t() => any()},
    text_search: String.t(),
    limit: non_neg_integer(),
    offset: non_neg_integer() | {:page_token, String.t()},
    sort_by: atom() | String.t(), # String for nested fields like "data.duration_ns"
    sort_order: :asc | :desc,
    projection: [atom() | String.t()] # String for nested fields
  ]

  @doc """
  Queries stored events based on flexible criteria.
  Returns a list of events and potentially a next_page_token.
  """
  @spec query_events(query_opts_v1()) ::
          {:ok, %{events: [Events.t()], next_page_token: String.t() | nil, total_matches: non_neg_integer()}} |
          {:error, term()}
  def query_events(opts) do
    # Implementation uses ETS match_specs, secondary indexes, etc.
    # - Combines multiple filters (AND logic by default, OR needs explicit handling).
    # - Handles pagination.
    # - Applies projections to reduce data transfer.
    # - `total_matches` gives an idea of the full result set size.
    :not_implemented
  end

  @doc """
  Retrieves an entire correlated trace given a root correlation ID or any event ID within the trace.
  Events are typically sorted by timestamp.
  """
  @spec get_trace_by_correlation_id(String.t(), query_opts_v1()) ::
          {:ok, [Events.t()]} | {:error, term()}
  def get_trace_by_correlation_id(correlation_id, opts \\ []) do
    # Implementation finds all events with the same root correlation ID.
    # May involve traversing parent_id links if not all events have root_id.
    # `opts` can be used for further filtering within the trace (e.g., time range).
    :not_implemented
  end

  @doc """
  Reconstructs the call stack for a given process at a specific (monotonic) timestamp.
  Returns a list of {module, function, arity} tuples representing the stack.
  """
  @spec get_call_stack_at(pid(), integer()) :: {:ok, [{module(), atom(), arity()}]} | {:error, term()}
  def get_call_stack_at(pid, timestamp_monotonic) do
    # Implementation queries function_entry/exit events for the PID up to the timestamp.
    :not_implemented
  end

  @doc """
  Retrieves all captured state snapshots for a given PID, optionally within a time range.
  """
  @spec get_state_snapshots(pid(), query_opts_v1()) :: {:ok, [Events.t()]} | {:error, term()}
  def get_state_snapshots(pid, opts \\ []) do
    # Filters for event_type: :local_variable_snapshot or other state event types.
    query_events(Keyword.merge(opts, pid: pid, event_types: [:local_variable_snapshot])) # Example event type
  end

  @doc """
  Aggregates event data.
  Example: count events per MFA, average execution time for a function.
  - `group_by`: Field(s) to group by (e.g., `[:event_type, :mfa]`).
  - `aggregations`: Map of aggregations to perform (e.g., `%{count: :*, avg_duration: {:avg, "data.duration_ns"}}`).
  - `filters`: `query_opts_v1` to filter data before aggregation.
  """
  @type aggregation_opts_v1 :: [
    group_by: [atom() | String.t()],
    aggregations: %{atom() => {:count | :sum | :avg | :min | :max, atom() | String.t() | :*}},
    filters: query_opts_v1()
  ]
  @spec aggregate_events(aggregation_opts_v1()) :: {:ok, [map()]} | {:error, term()}
  def aggregate_events(opts) do
    # Powerful function for statistical analysis by AI.
    :not_implemented
  end

  @doc """
  Retrieves the source code snippet related to an event, if available.
  Requires events to store file/line information and access to the project's source.
  """
  @spec get_source_context(event_id :: String.t(), lines_before :: non_neg_integer(), lines_after :: non_neg_integer()) ::
          {:ok, %{file_path: String.t(), line_number: non_neg_integer(), code_snippet: String.t()}} |
          {:error, :not_found | :source_unavailable}
  def get_source_context(event_id, lines_before \\ 5, lines_after \\ 5) do
    :not_implemented
  end
end
```

**II. Real-Time Streaming Interface (e.g., via `ElixirScope.Streaming.EventStreamer`)**

This interface is for the "Execution Cinema" live view and real-time automated alerts/analysis.

```elixir
defmodule ElixirScope.Streaming.EventStreamer do
  @typedoc """
  Options for subscribing to an event stream.
  Similar to `DataAccess.query_opts_v1` but for filtering the live stream.
  - `subscriber_pid`: The PID of the AI process that will receive events.
  - `batch_size`: How many events to batch before sending (0 or 1 for immediate).
  - `batch_timeout_ms`: Max time to wait before sending a partial batch.
  - `start_from`: :now | {:timestamp_monotonic, integer()} | {:event_id, String.t()}
  """
  @type stream_subscribe_opts_v1 :: [
    subscriber_pid: pid(),
    batch_size: non_neg_integer(),
    batch_timeout_ms: non_neg_integer(),
    start_from: :now | {:timestamp_monotonic, integer()} | {:event_id, String.t()}
  ] ++ DataAccess.query_opts_v1() # Reuse query_opts for filtering

  @doc """
  Subscribes an AI process to receive a real-time stream of ElixirScope events.
  The subscriber_pid will receive messages of the form `{:elixir_scope_events, [Events.t()]}`.
  Returns a unique subscription ID.
  """
  @spec subscribe(stream_subscribe_opts_v1()) :: {:ok, subscription_id :: String.t()} | {:error, term()}
  def subscribe(opts) do
    # Implementation:
    # - Starts/manages a GenServer or uses a Registry for subscriptions.
    # - This EventStreamer would itself be a consumer of events from AsyncWriter (via pub/sub)
    #   or by tailing Storage.DataAccess.
    # - Applies filters from `opts`.
    # - Handles batching and delivery to `subscriber_pid`.
    # - Manages backpressure if subscriber is slow.
    # - If `start_from` is historical, it first queries DataAccess and sends historical events,
    #   then switches to live streaming.
    :not_implemented
  end

  @doc """
  Modifies an existing stream subscription (e.g., change filters).
  """
  @spec update_subscription(subscription_id :: String.t(), new_filter_opts :: DataAccess.query_opts_v1()) ::
          :ok | {:error, :not_found | term()}
  def update_subscription(subscription_id, new_opts) do
    :not_implemented
  end

  @doc """
  Unsubscribes an AI process from the event stream.
  """
  @spec unsubscribe(subscription_id :: String.t()) :: :ok | {:error, :not_found}
  def unsubscribe(subscription_id) do
    :not_implemented
  end

  @doc """
  Pauses event delivery for a subscription. Events are buffered or dropped based on policy.
  """
  @spec pause_stream(subscription_id :: String.t()) :: :ok | {:error, :not_found}
  def pause_stream(subscription_id) do
    :not_implemented
  end

  @doc """
  Resumes event delivery for a paused subscription.
  Optionally allows specifying how to handle buffered events (e.g., send_all, send_latest, discard).
  """
  @spec resume_stream(subscription_id :: String.t(),
                       buffered_event_policy :: :send_all | :send_latest_n | :discard_all) ::
          :ok | {:error, :not_found}
  def resume_stream(subscription_id, buffered_event_policy \\ :send_all) do
    :not_implemented
  end
end
```

**III. Data Formats and General Considerations:**

*   **Event Structure:** All events consumed, whether batch or stream, will conform to `ElixirScope.Events.t()` or projections thereof.
*   **Timestamps:** Clarity on `timestamp` (monotonic, for ordering and duration) vs. `wall_time` (for display and correlation with external systems). Both should be in nanoseconds.
*   **Correlation IDs:** The `correlation_id` (root trace ID) and `parent_id` (for call chains) are crucial for AI to reconstruct execution flows.
*   **Error Handling:** API functions should return `{:ok, ...}` or `{:error, reason}` tuples. Reasons should be descriptive atoms or tuples.
*   **Performance:**
    *   `DataAccess.query_events` needs to be highly optimized with appropriate ETS table types (e.g., `ordered_set` for time ranges) and secondary indexes.
    *   `EventStreamer` must handle potentially high event rates without becoming a bottleneck. Efficient filtering and batching are key.
*   **Configuration:** The AI consumer might need access to `ElixirScope.Config` to understand current sampling rates, capture depths, etc., which might influence its analysis or requests.

**How Different AI Consumers Would Use These Interfaces:**

1.  **Automated AI Loops (Offline Analysis & Model Training):**
    *   Uses `DataAccess.query_events/1` extensively to fetch large datasets based on various criteria (e.g., all events for a specific module over the past week, all error events).
    *   Uses `DataAccess.aggregate_events/1` to get statistical summaries (e.g., "What's the P95 latency for `MyApp.MyService.process_request/2`?").
    *   Uses `DataAccess.get_trace_by_correlation_id/2` to retrieve full execution traces for detailed analysis or as input for sequence-based ML models.
    *   Periodically fetches data to retrain its internal models.

2.  **HITL Debugger ("Execution Cinema"):**
    *   **Live View:**
        *   Calls `EventStreamer.subscribe/1` with filters based on the user's current focus (e.g., specific PID, MFA).
        *   Receives `{:elixir_scope_events, [Events.t()]}` messages and updates the UI in real-time.
    *   **Historical Exploration (when paused or "rewinding"):**
        *   Calls `EventStreamer.pause_stream/1`.
        *   Uses `DataAccess.query_events/1` to fetch historical events around a specific point of interest.
        *   Uses `DataAccess.get_trace_by_correlation_id/2` to show the full context of a selected event.
        *   Uses `DataAccess.get_call_stack_at/2` to display the call stack.
        *   Uses `DataAccess.get_state_snapshots/2` and `DataAccess.get_source_context/3` to show variable states and code.
    *   **Resuming Live View:**
        *   Calls `EventStreamer.resume_stream/2`, possibly with `start_from: :now` or `start_from: {:event_id, last_displayed_event_id}` to catch up.

3.  **AI for Real-time Anomaly Detection/Alerting:**
    *   Subscribes to `EventStreamer.subscribe/1` with filters for specific critical events or patterns.
    *   Processes incoming events in real-time.
    *   If an anomaly is detected (e.g., unusually high latency for an event, sequence of error events), it might:
        *   Trigger an alert.
        *   Dynamically request `ElixirScope.AI.Orchestrator` to increase instrumentation detail for the affected components.
        *   Log a more detailed diagnostic trace using `DataAccess.get_trace_by_correlation_id/2`.

This dual-interface approach (Batch/Query + Streaming) provides the necessary flexibility for various AI consumption patterns, from deep offline analysis to interactive real-time debugging. The key is to ensure both `DataAccess` and `EventStreamer` are robust and performant.
