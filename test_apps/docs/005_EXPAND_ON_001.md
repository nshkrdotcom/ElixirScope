Okay, here are more specific technical details for implementing the `PhoenixScopePlayer` application. This should provide enough guidance for an AI coding assistant like Claude to start generating the code.

## III. Detailed Technical Specifications

### 1. Pre-captured Data Format (`priv/captured_data/session_X/`)

Assume ElixirScope's instrumentation runtime (or a simulator) generates these JSON files.

*   **A. `events.json`**: An array of event objects. Each event should have a consistent structure.
    ```json
    // events.json
    [
      {
        "timestamp": 1678886400000000, // Nanoseconds monotonic
        "relative_ts_ms": 0,           // Milliseconds from session start
        "event_type": "FUNCTION_ENTRY", // e.g., FUNCTION_ENTRY, FUNCTION_EXIT, LINE_EXECUTION, VAR_SNAPSHOT, EXPR_VALUE
        "ast_node_id": "MyModule.my_func/2:def", // Stable ID from ElixirScope.ASTRepository.Parser
        "data": {
          "module": "Elixir.MyModule",
          "function": "my_func",
          "arity": 2,
          "args": [{"type": "integer", "value_str": "10"}, {"type": "string", "value_str": "\"hello\""}] // Args stringified
        }
      },
      {
        "timestamp": 1678886400001000,
        "relative_ts_ms": 1,
        "event_type": "LINE_EXECUTION",
        "ast_node_id": "MyModule.my_func/2:line_5",
        "data": { "line": 5 }
      },
      {
        "timestamp": 1678886400001500,
        "relative_ts_ms": 1, // Can be same if very fast
        "event_type": "VAR_SNAPSHOT",
        "ast_node_id": "MyModule.my_func/2:line_5:after_assign_x",
        "data": {
          "line": 5,
          "variables": {
            "x": {"type": "integer", "value_str": "10"},
            "y": {"type": "string", "value_str": "\"hello\""}
          }
        }
      },
      {
        "timestamp": 1678886400002000,
        "relative_ts_ms": 2,
        "event_type": "EXPR_VALUE",
        "ast_node_id": "MyModule.my_func/2:line_6:expr_add",
        "data": {
          "line": 6,
          "expression_str": "x + 5",
          "value": {"type": "integer", "value_str": "15"}
        }
      },
      {
        "timestamp": 1678886400003000,
        "relative_ts_ms": 3,
        "event_type": "FUNCTION_EXIT",
        "ast_node_id": "MyModule.my_func/2:def",
        "data": {
          "module": "Elixir.MyModule",
          "function": "my_func",
          "arity": 2,
          "return_value": {"type": "integer", "value_str": "15"},
          "duration_ns": 3000000 // Duration of the function call
        }
      }
      // ... more events
    ]
    ```
    *   `value_str` is used for display; actual type info is in `type`.
    *   `args`, `variables`, `value`, `return_value` all use the `{"type": "...", "value_str": "..."}` structure.

*   **B. `source_code.json`**: A map of module names to their source code as strings.
    ```json
    // source_code.json
    {
      "Elixir.MyModule": "defmodule MyModule do\n  def my_func(x, y) do\n    # ... code ...\n  end\nend",
      "Elixir.AnotherModule": "..."
    }
    ```

*   **C. `ast_map.json`**: A map linking `ast_node_id` to its source location.
    ```json
    // ast_map.json
    {
      "MyModule.my_func/2:def": {
        "module": "Elixir.MyModule",
        "start_line": 3,
        "end_line": 10
      },
      "MyModule.my_func/2:line_5": {
        "module": "Elixir.MyModule",
        "start_line": 5,
        "end_line": 5
      },
      "MyModule.my_func/2:line_5:after_assign_x": { // For var snapshots taken after an assignment
        "module": "Elixir.MyModule",
        "start_line": 5, // The line the assignment is on
        "end_line": 5
      }
      // ... more mappings
    }
    ```
    *   The `ast_node_id` for a line execution event directly maps to a line.
    *   The `ast_node_id` for function entry/exit maps to the function definition's span.
    *   The `ast_node_id` for variable snapshots or expression values might map to a specific sub-line construct or the line they occurred on.

### 2. `PhoenixScopePlayer.DataProvider` Module

*   **Public API:**
    *   `list_sessions() :: [%{id: String.t(), name: String.t(), description: String.t(), timestamp: DateTime.t(), event_count: integer()}]`
        *   Reads `priv/captured_data/` to find session directories.
        *   For each session, it might read a small `session_meta.json` (not detailed above, but good for descriptions) or derive info from `events.json`.
    *   `get_session_events(session_id :: String.t()) :: {:ok, [map()]} | {:error, :not_found}`
        *   Reads and parses `priv/captured_data/#{session_id}/events.json`.
    *   `get_session_source_code(session_id :: String.t()) :: {:ok, %{String.t() => String.t()}} | {:error, :not_found}`
        *   Reads and parses `priv/captured_data/#{session_id}/source_code.json`.
    *   `get_session_ast_map(session_id :: String.t()) :: {:ok, map()} | {:error, :not_found}`
        *   Reads and parses `priv/captured_data/#{session_id}/ast_map.json`.
*   **Implementation Notes:**
    *   Use `Jason` for JSON parsing.
    *   Cache loaded session data in memory (e.g., in an Agent or ETS table) to avoid re-reading files if performance becomes an issue for the demo. For simplicity, direct reads are fine initially.
    *   Error handling for missing files or invalid JSON.

### 3. `PhoenixScopePlayer.PlaybackEngine` (GenServer)

*   **State:**
    ```elixir
    defstruct [
      session_id: nil,
      all_events: [],         // Loaded from DataProvider
      current_event_index: 0, // 0-based index
      playback_status: :paused, // :paused, :playing
      variables_at_current_step: %{},
      call_stack_at_current_step: [],
      playback_speed: 1.0,    // Multiplier for playback timer
      timer_ref: nil,         // Reference to the :play timer
      subscriber: nil         // PID of the PlaybackLive LiveView
    ]
    ```
*   **Client API (Functions calling GenServer):**
    *   `start_link(session_id, subscriber_pid)`
    *   `get_current_playback_state(pid)`: Returns current event, variables, call stack, index, total events.
    *   `play(pid)`
    *   `pause(pid)`
    *   `step_forward(pid)`
    *   `step_backward(pid)`
    *   `seek_to_event(pid, event_index)`
    *   `set_speed(pid, speed_multiplier)`
*   **`init({session_id, subscriber_pid})`:**
    *   Loads all events for `session_id` using `DataProvider.get_session_events/1`.
    *   Initializes `current_event_index` to 0.
    *   Calculates initial `variables_at_current_step` and `call_stack_at_current_step`.
    *   Sets `subscriber` to `subscriber_pid`.
*   **`handle_cast(:play, state)`:**
    *   Sets `playback_status` to `:playing`.
    *   Starts a timer using `Process.send_after/3` to send `:tick` messages. Interval based on `playback_speed`.
    *   Notifies subscriber.
*   **`handle_cast(:pause, state)`:**
    *   Sets `playback_status` to `:paused`.
    *   Cancels the `:tick` timer if active.
    *   Notifies subscriber.
*   **`handle_cast(:step_forward, state)` & `handle_info(:tick, state)`:**
    *   If `current_event_index < length(all_events) - 1`:
        *   Increment `current_event_index`.
        *   Recalculate `variables_at_current_step` and `call_stack_at_current_step` by processing events *up to the new index*.
        *   Notify subscriber with the new state.
        *   If `playback_status == :playing`, schedule next `:tick`.
    *   Else (end of session):
        *   Set `playback_status` to `:paused`.
        *   Notify subscriber.
*   **`handle_cast(:step_backward, state)`:**
    *   If `current_event_index > 0`:
        *   Decrement `current_event_index`.
        *   Recalculate state.
        *   Notify subscriber.
*   **`handle_cast({:seek_to_event, event_index}, state)`:**
    *   Set `current_event_index` to `event_index` (validate bounds).
    *   Recalculate state.
    *   Notify subscriber.
*   **State Calculation Logic (private functions in PlaybackEngine):**
    *   `calculate_variables_for_index(all_events, target_index) :: map()`
        *   Iterate `all_events` from `0` to `target_index`.
        *   If event is `VAR_SNAPSHOT`, update a temporary variable map.
        *   Return the final variable map.
    *   `calculate_call_stack_for_index(all_events, target_index) :: [map()]`
        *   Iterate `all_events` from `0` to `target_index`.
        *   If `FUNCTION_ENTRY`, push onto a temporary stack.
        *   If `FUNCTION_EXIT`, pop from the stack.
        *   Return the final stack.
*   **Notification to Subscriber:**
    *   After any state change, send `send(state.subscriber, {:playback_update, current_playback_engine_state_map})`.
    *   `current_playback_engine_state_map` should include: `current_event`, `variables`, `call_stack`, `current_index`, `total_events`, `status`.

### 4. `PhoenixScopePlayerWeb.SessionListLive`

*   **Assigns:** `socket |> assign(sessions: [])`
*   **`mount(_params, _session, socket)`:**
    *   `sessions = DataProvider.list_sessions()`
    *   `assign(socket, sessions: sessions)`
*   **`handle_event("load_session", %{"id" => session_id}, socket)`:**
    *   `{:noreply, push_redirect(socket, to: Routes.playback_path(socket, :show, session_id))}`

### 5. `PhoenixScopePlayerWeb.PlaybackLive`

*   **Assigns (Example):**
    ```elixir
    assigns = %{
      session_id: nil,
      playback_engine_pid: nil,
      current_event: nil,        // The full event map for the current step
      current_event_index: 0,
      total_events: 0,
      current_source_code: "",
      current_module: nil,
      highlight_line_start: nil,
      highlight_line_end: nil,
      variables: %{},            // Current variable snapshot
      call_stack: [],            // Current call stack
      playback_status: :paused,
      source_code_map: %{},      // All source code for the session
      ast_map: %{}               // All AST mappings for the session
    }
    ```
*   **`mount(%{"id" => session_id}, _session, socket)`:**
    *   `{:ok, source_code_map} = DataProvider.get_session_source_code(session_id)`
    *   `{:ok, ast_map} = DataProvider.get_session_ast_map(session_id)`
    *   `{:ok, engine_pid} = PlaybackEngine.start_link(session_id, self())`
    *   `playback_state = PlaybackEngine.get_current_playback_state(engine_pid)`
    *   Call `update_code_view_assigns(socket, playback_state, source_code_map, ast_map)` (helper function).
    *   `assign(socket, session_id: session_id, playback_engine_pid: engine_pid, source_code_map: source_code_map, ast_map: ast_map, ...other_assigns_from_playback_state)`
*   **`handle_event("play", _, socket)`:** `PlaybackEngine.play(socket.assigns.playback_engine_pid)`
*   **`handle_event("pause", _, socket)`:** `PlaybackEngine.pause(socket.assigns.playback_engine_pid)`
*   **`handle_event("step_forward", _, socket)`:** `PlaybackEngine.step_forward(socket.assigns.playback_engine_pid)`
*   ... (similarly for other controls)
*   **`handle_event("seek_from_log", %{"index" => index_str}, socket)`:**
    *   `index = String.to_integer(index_str)`
    *   `PlaybackEngine.seek_to_event(socket.assigns.playback_engine_pid, index)`
*   **`handle_info({:playback_update, engine_state}, socket)`:**
    *   `engine_state` is map like: `%{current_event: event_map, variables: vars, call_stack: stack, current_index: idx, total_events: total, status: status}`.
    *   Call `update_code_view_assigns(socket, engine_state, socket.assigns.source_code_map, socket.assigns.ast_map)`.
    *   `assign(socket, current_event: engine_state.current_event, variables: engine_state.variables, ...)`
*   **`update_code_view_assigns(socket, engine_state, source_code_map, ast_map)` (Helper):**
    *   `current_event = engine_state.current_event`
    *   If `current_event` is `nil` (e.g., empty session), set default code view assigns.
    *   Otherwise:
        *   `ast_node_id = current_event.ast_node_id`
        *   `ast_info = ast_map[ast_node_id]` (e.g., `%{module: "Elixir.MyModule", start_line: 5, end_line: 5}`)
        *   `module_name = ast_info.module`
        *   `source = source_code_map[module_name]`
        *   `assign(socket, current_source_code: source, current_module: module_name, highlight_line_start: ast_info.start_line, highlight_line_end: ast_info.end_line)`

### 6. Child Components (e.g., `CodeViewLive`)

*   **`CodeViewLive` (LiveComponent or Function Component):**
    *   Receives assigns: `@source_code`, `@highlight_line_start`, `@highlight_line_end`.
    *   Renders the source code, splitting it into lines.
    *   Adds a CSS class to the lines between `highlight_line_start` and `highlight_line_end` to highlight them.
    *   Could use a library like `Makeup` or `MakeupAlchemist` for syntax highlighting if desired, or just plain text.
*   **`EventLogLive`:**
    *   Receives assigns: `@all_events` (from `PlaybackEngine`'s state, passed down by `PlaybackLive`), `@current_event_index`.
    *   Renders a list of events.
    *   Highlights the event at `@current_event_index`.
    *   Each event item has `phx-click="seek_from_log" phx-value-index={index_of_event}`.
*   **`StateInspectorLive`:**
    *   Receives assigns: `@variables`, `@call_stack`, `@current_expression_values` (optional).
    *   Renders these in their respective tabs.

### 7. Router (`phoenix_scope_player_web/router.ex`)

```elixir
scope "/", PhoenixScopePlayerWeb do
  pipe_through :browser

  live "/", SessionListLive, :index
  live "/session/:id/play", PlaybackLive, :show
end
```

### 8. Key Data Flow and Interactions (Step Forward Example Refined)

1.  **User Click:** `PlaybackLive.html.heex` -> `phx-click="step_forward"`
2.  **LiveView Event:** `PlaybackLive.handle_event("step_forward", _, socket)`
3.  **GenServer Cast:** `PlaybackEngine.step_forward(socket.assigns.playback_engine_pid)`
4.  **Engine Logic:** `PlaybackEngine.handle_cast(:step_forward, state)`
    *   Increments `current_event_index`.
    *   Calls `calculate_variables_for_index(state.all_events, new_index)` -> `new_vars`.
    *   Calls `calculate_call_stack_for_index(state.all_events, new_index)` -> `new_stack`.
    *   Forms `engine_update_payload = %{current_event: state.all_events[new_index], variables: new_vars, ...}`.
    *   `send(state.subscriber, {:playback_update, engine_update_payload})`.
    *   Updates its own state.
5.  **LiveView Info:** `PlaybackLive.handle_info({:playback_update, engine_update_payload}, socket)`
    *   Extracts `current_event`, `variables`, `call_stack`, etc. from `engine_update_payload`.
    *   `new_assigns = update_code_view_assigns(socket, engine_update_payload, socket.assigns.source_code_map, socket.assigns.ast_map)`
    *   `socket = assign(socket, new_assigns)`
    *   `socket = assign(socket, current_event: ..., variables: ..., call_stack: ...)`
6.  **Phoenix Re-render:** UI updates based on new assigns.

### 9. Simplifications & Assumptions for this Demo App

*   **Pre-captured Data**: All debug session data is static and loaded from JSON files. No live ElixirScope integration.
*   **No Real ElixirScope Dependency**: The demo *simulates* ElixirScope data. `ElixirScope.ASTRepository.Parser`'s `ast_node_id` format is assumed.
*   **Stringified Values**: Variable and expression values in `events.json` are primarily strings for easy display, with a `type` hint. No complex term rendering.
*   **Limited Error Handling**: Focus on the happy path of playback.
*   **Basic UI/UX**: Emphasis on functionality over polished design.
*   **Source Code Availability**: Assumes all relevant source code for a session is available in `source_code.json`.
*   **Simplified Call Stack**: Call stack is derived simply from `FUNCTION_ENTRY`/`FUNCTION_EXIT` events.

This level of detail should enable the implementation of the `PhoenixScopePlayer` demo application. Each module can be developed iteratively.
