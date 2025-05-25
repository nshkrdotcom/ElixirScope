Okay, we've thoroughly covered the AI analysis that *plans* the instrumentation, the AST transformation that *injects* it, the `InstrumentationRuntime` that *receives* calls from instrumented code, the `Ingestor` and `RingBuffer` that *capture* those events, the `AsyncWriterPool/AsyncWriter` that *processes* them, the `EventCorrelator` that *links* them, and `DataAccess` which *stores* them.

A crucial area that bridges ElixirScope with real-world applications and leverages a standard Elixir ecosystem feature is the **Phoenix Integration Layer (`ElixirScope.Phoenix.Integration`)**. This layer uses Telemetry events to capture rich contextual information from Phoenix applications without requiring as much direct AST transformation for these specific framework events.

---

**ElixirScope Technical Document: Phoenix Framework Integration Layer**

**Document Version:** 1.8
**Date:** 2024-05-24
**Authors:** ElixirScope Team (AI Assisted)

**Abstract:**

This document provides a detailed technical examination of the `ElixirScope.Phoenix.Integration` module. This layer is responsible for instrumenting Phoenix applications by leveraging Phoenix's built-in Telemetry event system. It allows ElixirScope to capture detailed information about the lifecycle of HTTP requests, controller actions, LiveView interactions, Channel communications, and Ecto database queries without extensive AST modification of Phoenix's internal code. This document details the Telemetry event handlers, correlation ID propagation techniques, the types of Phoenix-specific events captured, and how this integration enriches the overall trace data available for ElixirScope's "Execution Cinema."

**Table of Contents:**

1.  Introduction and Purpose
    1.1. Importance of Deep Phoenix Visibility
    1.2. Leveraging Telemetry for Non-Intrusive Instrumentation
    1.3. Design Goals: Comprehensive Coverage, Correlation, Minimal Overhead
2.  Architectural Placement and Workflow (Diagram Reference: `DIAGS.md#1, #8`)
    2.1. `ElixirScope.Phoenix.Integration` Module Role
    2.2. Attaching to Phoenix and Ecto Telemetry Events
    2.3. Interaction with `ElixirScope.Capture.InstrumentationRuntime`
3.  HTTP Request Lifecycle Tracing
    3.1. Telemetry Events Handled:
        *   `[:phoenix, :endpoint, :start]` and `[:phoenix, :endpoint, :stop]`
        *   `[:phoenix, :router_dispatch, :start]` and `[:phoenix, :router_dispatch, :stop]` (Currently not in code, but listed in `DIAGS.md`)
        *   `[:phoenix, :controller, :start]` and `[:phoenix, :controller, :stop]`
    3.2. Correlation ID Generation and Propagation
        3.2.1. Generating ID at `[:phoenix, :endpoint, :start]`
        3.2.2. Storing ID in `conn.private[:elixir_scope_correlation_id]`
        3.2.3. Retrieving ID in subsequent handlers
    3.3. Data Captured: Method, Path, Params, Remote IP, Status, Duration, Response Size
    3.4. Reporting via `InstrumentationRuntime.report_phoenix_request_start/complete` etc.
4.  Phoenix Controller Tracing
    4.1. Linking Controller Actions to Endpoint Request Correlation ID
    4.2. Capturing Controller Module, Action Name, and Parameters
    4.3. Reporting via `InstrumentationRuntime.report_phoenix_controller_entry/exit`
5.  Phoenix LiveView Tracing
    5.1. Telemetry Events Handled:
        *   `[:phoenix, :live_view, :mount, :start/:stop]`
        *   `[:phoenix, :live_view, :handle_event, :start/:stop]`
        *   `[:phoenix, :live_view, :handle_info, :start/:stop]`
    5.2. Correlation ID Propagation via `socket.assigns[:elixir_scope_correlation_id]`
    5.3. Capturing Module, Params, Event Names, `assigns` (Initial and Diffs)
    5.4. Reporting via `InstrumentationRuntime.report_liveview_...` functions
6.  Phoenix Channel Tracing
    6.1. Telemetry Events Handled:
        *   `[:phoenix, :channel, :join, :start/:stop]`
        *   `[:phoenix, :channel, :handle_in, :start/:stop]`
    6.2. Correlation ID Generation for Channel Interactions
    6.3. Capturing Channel Module, Topic, Event, Payload
    6.4. Reporting via `InstrumentationRuntime.report_phoenix_channel_...` functions
7.  Ecto Query Tracing (within Phoenix Context)
    7.1. Telemetry Events Handled: `[:ecto, :repo, :query, :start/:stop]`
    7.2. Correlating Ecto Queries to the Originating HTTP Request or LiveView/Channel Event
        7.2.1. Retrieving Correlation ID from Process Dictionary (`Process.get(:elixir_scope_correlation_id)`)
    7.3. Capturing Repo, Source, Query (Sanitized), Params, Query/Decode Times, Result
    7.4. Reporting via `InstrumentationRuntime.report_ecto_query_start/complete`
8.  Enabling and Disabling Phoenix Integration (`enable/0`, `disable/0`)
    8.1. Dynamically Attaching/Detaching Telemetry Handlers
9.  Interaction with AST-Based Instrumentation
    9.1. Complementary Roles: Telemetry for framework events, AST for application logic.
    9.2. Ensuring Consistent Correlation ID Usage Between Both Systems
10. Performance Considerations for Telemetry Handlers
    10.1. Overhead of Telemetry Event Handling
    10.2. Efficiency of Data Extraction and Reporting
11. Testing Strategies for Phoenix Integration
12. Conclusion

---

## 1. Introduction and Purpose

### 1.1. Importance of Deep Phoenix Visibility

The Phoenix framework is a cornerstone of many Elixir applications. Understanding the flow of requests, the behavior of controllers, the intricacies of LiveView updates, real-time channel interactions, and associated database queries is crucial for effective debugging and performance analysis. The `ElixirScope.Phoenix.Integration` layer provides this specialized visibility.

### 1.2. Leveraging Telemetry for Non-Intrusive Instrumentation

Phoenix (and Ecto) emit a rich set of `Telephmetry` events at various points in their lifecycle. Telemetry is a dynamic dispatching library for metrics and instrumentation. By attaching handlers to these well-defined events, ElixirScope can capture detailed framework-level information without needing to perform complex AST transformations on Phoenix's or Ecto's internal code. This approach is generally more stable across framework versions and less intrusive.

### 1.3. Design Goals

*   **Comprehensive Coverage:** Capture key events across the Phoenix stack (HTTP, Controllers, LiveView, Channels) and related Ecto queries.
*   **Seamless Correlation:** Ensure that events captured via Telemetry are correctly correlated with each other (e.g., an Ecto query linked to the controller action that triggered it) and with events captured via AST instrumentation from application code.
*   **Minimal Overhead:** Telemetry handlers must be highly performant to avoid adding significant latency to Phoenix operations.
*   **Ease of Use:** Enable/disable Phoenix tracing with simple function calls.

## 2. Architectural Placement and Workflow

As depicted in `DIAGS.md#1. Overall System Architecture` and detailed in `DIAGS.md#8. Phoenix Integration Flow`, the `Phoenix.Integration` module acts as a bridge between the Phoenix framework's Telemetry events and ElixirScope's core capture pipeline.

### 2.1. `ElixirScope.Phoenix.Integration` Module Role

This module contains the logic to:
1.  Attach custom handler functions to specific Telemetry event names.
2.  Extract relevant data from the `measurements` and `metadata` provided by these Telemetry events.
3.  Manage and propagate correlation IDs across related Telemetry events.
4.  Format this data into ElixirScope-specific event structures.
5.  Report these formatted events to `ElixirScope.Capture.InstrumentationRuntime`.

### 2.2. Attaching to Phoenix and Ecto Telemetry Events

The `enable/0` function uses `:telemetry.attach_many/4` to subscribe to a list of predefined Telemetry events. For example:
```elixir
# From ElixirScope.Phoenix.Integration
:telemetry.attach_many(
  :elixir_scope_phoenix_http, # Unique ID for the attachment
  [ # List of event names to handle
    [:phoenix, :endpoint, :start],
    [:phoenix, :endpoint, :stop],
    # ... other events ...
  ],
  &handle_http_event/4,        # Handler function
  %{}                          # Initial handler config (state)
)
```
Separate attachments are made for HTTP, LiveView, Channel, and Ecto events, each potentially using a different main handler function (`handle_http_event`, `handle_liveview_event`, etc.).

### 2.3. Interaction with `ElixirScope.Capture.InstrumentationRuntime`

The Telemetry handler functions, after extracting and formatting data, use the API provided by `ElixirScope.Capture.InstrumentationRuntime` to report the semantic event. For instance:
*   `handle_http_event` for `[:phoenix, :endpoint, :start]` calls `InstrumentationRuntime.report_phoenix_request_start(...)`.
*   `handle_liveview_event` for `[:phoenix, :live_view, :mount, :start]` calls `InstrumentationRuntime.report_liveview_mount_start(...)`.
The `InstrumentationRuntime` then forwards these to the `EventIngestor` as usual.

## 3. HTTP Request Lifecycle Tracing

### 3.1. Telemetry Events Handled

*   **`[:phoenix, :endpoint, :start]`**:
    *   **Triggered:** When an HTTP request first hits the Phoenix endpoint.
    *   **Action:** Generates a new root `correlation_id` for this request. Stores this ID in `conn.private`. Reports a `:phoenix_request_start` event.
*   **`[:phoenix, :endpoint, :stop]`**:
    *   **Triggered:** After the entire request has been processed and a response is sent.
    *   **Action:** Retrieves the `correlation_id` from `conn.private`. Reports a `:phoenix_request_complete` event including status code, duration, and response size.
*   **`[:phoenix, :router_dispatch, :start/:stop]`**: (Conceptual, as per `DIAGS.md#8`, though not in current code `Phoenix.Integration`) Would trace the routing phase.
*   **`[:phoenix, :controller, :start/:stop]`**: Traces the execution of a specific controller action.

### 3.2. Correlation ID Generation and Propagation

#### 3.2.1. Generating ID at `[:phoenix, :endpoint, :start]`
A unique `correlation_id` (e.g., via `Utils.generate_correlation_id/0`) is created when a request begins.

#### 3.2.2. Storing ID in `conn.private[:elixir_scope_correlation_id]`
The `Plug.Conn.put_private(conn, :elixir_scope_correlation_id, correlation_id)` function is used to associate the generated ID with the current connection. This makes it available to other Telemetry handlers or instrumented application code that has access to the `conn`.

#### 3.2.3. Retrieving ID in subsequent handlers
Handlers for `[:phoenix, :endpoint, :stop]`, `[:phoenix, :controller, :start/:stop]`, and even instrumented Plug functions can retrieve this `correlation_id` from `conn.private[:elixir_scope_correlation_id]`.

### 3.3. Data Captured

*   Method (GET, POST, etc.), request path, query parameters, headers.
*   Remote IP address.
*   Response status code, content type, duration.
*   Response body size.

### 3.4. Reporting

Via `InstrumentationRuntime.report_phoenix_request_start/5` and `InstrumentationRuntime.report_phoenix_request_complete/4`.

## 4. Phoenix Controller Tracing

### 4.1. Linking Controller Actions to Endpoint Request Correlation ID

The handlers for `[:phoenix, :controller, :start]` and `[:phoenix, :controller, :stop]` retrieve the `correlation_id` established by the `[:phoenix, :endpoint, :start]` handler from `metadata.conn.private`. This links controller activity directly to the overall HTTP request.

### 4.2. Capturing Controller Module, Action Name, and Parameters

The `metadata` map provided by these Telemetry events contains `metadata.controller` (the module name), `metadata.action` (the atom action name), and `metadata.params`.

### 4.3. Reporting

Via `InstrumentationRuntime.report_phoenix_controller_entry/4` and `InstrumentationRuntime.report_phoenix_controller_exit/4`.

## 5. Phoenix LiveView Tracing

### 5.1. Telemetry Events Handled

*   **`[:phoenix, :live_view, :mount, :start/:stop]`**: Captures initial LiveView setup, parameters, session data, and final assigns.
*   **`[:phoenix, :live_view, :handle_event, :start/:stop]`**: Captures user-triggered events, their parameters, and changes to `socket.assigns`.
*   **`[:phoenix, :live_view, :handle_info, :start/:stop]`**: Captures server-pushed message handling and resulting `assigns` changes.

### 5.2. Correlation ID Propagation via `socket.assigns[:elixir_scope_correlation_id]`

Similar to `conn.private` for HTTP requests, a `correlation_id` is generated/retrieved and stored in `socket.assigns` (e.g., `socket = put_socket_correlation_id(metadata.socket, correlation_id)`). This allows events within a single LiveView's lifecycle to be grouped.
*   The `put_socket_correlation_id` helper in `Phoenix.Integration` uses `Map.update!(:assigns, ...)` ensuring it works even if `Phoenix.LiveView.assign/3` is not directly available (e.g., in older Phoenix versions or minimal setups).

### 5.3. Capturing

Module name, `params`, event names, initial `socket.assigns`, and diffs of `assigns` across `handle_event`/`handle_info` calls (by comparing current assigns with `get_previous_assigns(metadata.socket)`).

### 5.4. Reporting

Via specific `InstrumentationRuntime.report_liveview_...` functions (e.g., `report_liveview_mount_start`, `report_liveview_handle_event_complete`).

## 6. Phoenix Channel Tracing

### 6.1. Telemetry Events Handled

*   **`[:phoenix, :channel, :join, :start/:stop]`**: Tracks clients joining a channel topic.
*   **`[:phoenix, :channel, :handle_in, :start/:stop]`**: Tracks incoming messages from clients on a channel.

### 6.2. Correlation ID Generation for Channel Interactions

A new `correlation_id` is typically generated for each significant channel interaction (join attempt, incoming message) to trace its specific lifecycle.

### 6.3. Capturing

Channel module, topic, event name, message payload, socket state (if relevant and serializable).

### 6.4. Reporting

Via `InstrumentationRuntime.report_phoenix_channel_...` functions.

## 7. Ecto Query Tracing (within Phoenix Context)

### 7.1. Telemetry Events Handled

*   **`[:ecto, :repo, :query, :start/:stop]`**: Emitted by Ecto repositories around query execution.

### 7.2. Correlating Ecto Queries to the Originating HTTP Request or LiveView/Channel Event

This is a crucial correlation. The Telemetry handler for Ecto events attempts to retrieve an existing `correlation_id` from the **process dictionary** of the process executing the Ecto query.
```elixir
# In handle_ecto_event for :start
correlation_id = get_process_correlation_id() || generate_correlation_id()
# In handle_ecto_event for :stop
correlation_id = get_process_correlation_id()
```
*   **How the ID gets into the Process Dictionary:** When `InstrumentationRuntime` functions are called (either by AST-instrumented application code that *then* calls Ecto, or by Phoenix Telemetry handlers like controller actions), `InstrumentationRuntime` manages a per-process context which includes the active `correlation_id`. If the Telemetry handler for controller actions correctly sets this process-local `correlation_id` (e.g., via a wrapper or by `InstrumentationRuntime` functions doing it implicitly), then Ecto calls made from that controller action will execute in a process that has this ID in its dictionary.
*   `get_process_correlation_id/0` in `Phoenix.Integration` uses `Process.get(:elixir_scope_correlation_id)`. This implies that either the `InstrumentationRuntime` or the Phoenix Telemetry handlers for higher-level events (like controller actions) must use `Process.put(:elixir_scope_correlation_id, id)` to make it available.

### 7.3. Capturing

Repository module, query source (schema), sanitized SQL query (to remove sensitive data, e.g., `String.replace(query, ~r/\$\d+/, "?")`), number of parameters, query time, decode time, and query result (often summarized or truncated).

### 7.4. Reporting

Via `InstrumentationRuntime.report_ecto_query_start/5` and `InstrumentationRuntime.report_ecto_query_complete/5`.

## 8. Enabling and Disabling Phoenix Integration (`enable/0`, `disable/0`)

*   `enable/0`: Calls `:telemetry.attach_many/4` for each group of Phoenix/Ecto events.
*   `disable/0`: Calls `:telemetry.detach/1` using the unique attachment IDs (e.g., `:elixir_scope_phoenix_http`) to stop handling these events. This allows dynamic control over Phoenix-specific tracing.

## 9. Interaction with AST-Based Instrumentation

*   **Complementary Roles:** Telemetry handles framework-level events. AST-based instrumentation handles application-specific business logic within controllers, models, services, GenServers called by Phoenix components, etc.
*   **Consistent Correlation:** For a cohesive trace, it's vital that the `correlation_id` established by a Phoenix Telemetry handler (e.g., for an HTTP request) is propagated and used by any AST-instrumented application code called during that request. This is typically achieved by:
    1.  The Phoenix Telemetry handler (e.g., for controller start) retrieving the `correlation_id` from `conn.private`.
    2.  This handler, or the `InstrumentationRuntime` function it calls, setting this `correlation_id` as the active one in the current process's context (e.g., `Process.put(:elixir_scope_correlation_id, id)` or via `InstrumentationRuntime`'s internal context stack).
    3.  AST-instrumented functions subsequently called within this process will then pick up and use this active `correlation_id`.

## 10. Performance Considerations for Telemetry Handlers

*   Telemetry handlers are executed synchronously in the process that emits the Telemetry event. Therefore, they must be extremely fast.
*   Work done in handlers:
    *   Data extraction from `measurements` and `metadata` (generally cheap).
    *   Correlation ID retrieval/generation (fast).
    *   A call to an `InstrumentationRuntime.report_...` function.
*   The critical path is again the `InstrumentationRuntime` -> `Ingestor` -> `RingBuffer.write`. As long as this remains sub-microsecond, the overhead of Telemetry-based tracing should be minimal.
*   Excessive data processing, complex logic, or I/O within a Telemetry handler would directly impact the performance of the instrumented Phoenix/Ecto operation. ElixirScope avoids this by deferring heavy work.

## 11. Testing Strategies for Phoenix Integration

As outlined in `test/elixir_scope/phoenix/integration_test.exs` (and its more complete version in `FOUNDATION_IMPLEMENTATION_GUIDE.md`):
*   Use `Phoenix.ConnTest` and `Phoenix.LiveViewTest` to simulate real Phoenix interactions.
*   A full test Phoenix application (`test/support/test_phoenix_app.ex`) is essential.
*   **Tests should:**
    *   Make HTTP requests to various controller actions (GET, POST, errors).
    *   Interact with LiveViews (mount, handle_event).
    *   Connect to and send messages over Channels.
    *   Trigger Ecto queries.
    *   After interactions, query `ElixirScope.Storage.DataAccess` to:
        *   Verify that the expected sequence of Phoenix/Ecto semantic events was captured.
        *   Confirm that all related events share the correct `correlation_id`.
        *   Check that captured data (params, assigns, query details) is accurate.
*   Integration with a mock `InstrumentationRuntime` initially can help test the Telemetry handling logic in isolation.

## 12. Conclusion

The `ElixirScope.Phoenix.Integration` module provides powerful and relatively non-intrusive observability into Phoenix applications by tapping into the rich Telemetry ecosystem. Its ability to capture detailed lifecycle events from HTTP requests, controllers, LiveViews, Channels, and Ecto, and crucially, to correlate these events using a propagated ID, is fundamental for building a comprehensive "Execution Cinema" for Phoenix-based systems. Ensuring efficient correlation ID management between Telemetry-captured events and AST-instrumented application code is key for a unified trace view. The performance of the Telemetry handlers themselves is critical and relies on the speed of the underlying `InstrumentationRuntime` and `Ingestor` path.