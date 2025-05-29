Okay, let's design a simple Phoenix-based UI sample application to demonstrate the playback of debugging information captured by ElixirScope's compile-time instrumentation.

**Sample App Name:** `PhoenixScopePlayer`
(Implies playing back ElixirScope captured data within a Phoenix UI)

**Core Concept:**
The `PhoenixScopePlayer` app will simulate loading a pre-captured debugging "session" from an ElixirScope-instrumented application. It will then allow users to "play back" this session, visualizing the sequence of events, code execution, and variable states over time. This is a *viewer/player*, not a live debugger itself.

---

## I. UI Design (Focus on Information Architecture & User Experience)

### 1. Main Views/Pages

*   **A. Session Selection View (`/`)**
    *   **Purpose:** Allow the user to choose a pre-recorded debugging session to play back.
    *   **Elements:**
        *   Header: "ElixirScope - Debug Session Playback"
        *   List of available sessions (e.g., "Simple Function Run", "GenServer Interaction", "Complex Algorithm Trace").
            *   Each session item shows:
                *   Session Name/ID
                *   Brief Description (e.g., "Execution of MyModule.calculate/2")
                *   Timestamp of capture
                *   Number of events
        *   A "Load & Play" button next to each session.
    *   **Interaction:** Clicking "Load & Play" navigates to the Playback View for that session.

*   **B. Playback View (`/session/:session_id/play`)**
    *   **Purpose:** The main interface for replaying and inspecting a selected debugging session.
    *   **Layout:** A multi-panel layout.
        *   **Panel 1: Timeline & Controls (Top or Bottom Bar)**
            *   **Controls:**
                *   Play/Pause Button
                *   Step Forward Button (event by event)
                *   Step Backward Button (event by event)
                *   Go to Start Button
                *   Go to End Button
                *   Playback Speed Control (e.g., 1x, 2x, 0.5x - optional for simplicity)
            *   **Timeline Display:**
                *   Simple textual display: "Event X / Y" (e.g., "Event 57 / 342")
                *   (Optional advanced: A simple visual slider or progress bar representing the event sequence).
        *   **Panel 2: Event Log (Left or Main Panel)**
            *   **Content:** A chronological, scrollable list of captured events.
            *   **Each Event Item:**
                *   Timestamp (relative or absolute)
                *   Event Type (e.g., `FUNCTION_ENTRY`, `LINE_EXECUTION`, `VAR_SNAPSHOT`, `EXPRESSION_VALUE`, `FUNCTION_EXIT`)
                *   Key Information (e.g., `MyModule.my_func/2`, `Line: 42`, `Var: x = 10`, `Expr: a + b => 15`)
                *   AST Node ID (for debugging the debugger, perhaps hidden by default)
            *   **Interaction:** Clicking an event in the log seeks the playback to that event, updating other panels. The currently active event is highlighted.
        *   **Panel 3: Code View (Right or Main Panel)**
            *   **Content:** Displays the source code of the module/function relevant to the current event in the timeline.
            *   **Highlighting:** The line of code corresponding to the current event (or the line where a variable snapshot was taken) is highlighted.
            *   **Navigation:** If a function call event occurs, the Code View could switch to display the called function's source (if available in the pre-captured data).
        *   **Panel 4: State Inspector (Right Panel, below Code View or Tabbed)**
            *   **Variables Tab:**
                *   Displays local variables and their values as captured by `local_variable_snapshot` events at the current timeline point.
                *   Format: `variable_name: value`.
            *   **Expression Values Tab (Optional):**
                *   Displays values of traced expressions if `expression_value` events are present for the current timeline point.
                *   Format: `expression_source: value`.
            *   **Call Stack Tab (Simplified):**
                *   Displays a simplified call stack based on `FUNCTION_ENTRY` and `FUNCTION_EXIT` events.
                *   Format: List of `Module.function/arity`.

### 2. User Flow

1.  User visits the root URL (`/`).
2.  User sees the **Session Selection View**.
3.  User clicks "Load & Play" for a session.
4.  User is navigated to the **Playback View** (`/session/:id/play`).
5.  The Playback View loads the first event of the session. Code View, Event Log, and State Inspector populate accordingly.
6.  User uses timeline controls (Play, Step, etc.).
7.  As the timeline progresses:
    *   Event Log scrolls and highlights the current event.
    *   Code View updates to show relevant code and highlights the current execution line.
    *   State Inspector updates to show variable values at that point in time.
    *   Call Stack updates.

### 3. Simplicity Considerations for Design

*   **No Live Connection:** Data is pre-recorded. This simplifies the demo significantly.
*   **Read-Only:** The UI is for playback and inspection, not for setting new breakpoints or modifying execution.
*   **Focus on Core Data:** Prioritize displaying function calls, line execution, and variable states.
*   **Minimalist Styling:** Functional and clear, rather than aesthetically complex.

---

## II. Codebase Design (`test_apps/phoenix_scope_player/`)

This design assumes Phoenix with LiveView for interactivity.

```
phoenix_scope_player/
├── assets/
│   ├── css/
│   │   └── app.scss
│   └── js/
│       └── app.js
├── lib/
│   ├── phoenix_scope_player/
│   │   ├── application.ex
│   │   ├── playback_engine.ex       # GenServer to manage playback state of a session
│   │   └── data_provider.ex         # Module to load/serve pre-captured session data
│   └── phoenix_scope_player_web/
│       ├── components/
│       │   ├── code_view_live.ex      # LiveView component for displaying code
│       │   ├── event_log_live.ex      # LiveView component for the event log
│       │   └── state_inspector_live.ex # LiveView component for variables/expressions
│       ├── controllers/
│       │   ├── page_controller.ex     # For initial session selection page (if not LiveView)
│       │   └── playback_controller.ex # For setting up a playback session
│       ├── endpoint.ex
│       ├── gettext.ex
│       ├── live/
│       │   ├── session_list_live.ex   # LiveView for the session selection page
│       │   └── playback_live.ex       # Main LiveView for the playback UI
│       ├── router.ex
│       ├── telemetry.ex
│       └── templates/
│           ├── layout/
│           │   └── app.html.heex
│           ├── page/
│           │   └── index.html.heex      # For SessionListLive
│           └── playback/
│               └── show.html.heex       # For PlaybackLive (main layout)
│                   # Partials for different panels might go here or be components
├── priv/
│   ├── captured_data/              # Directory for pre-recorded session data
│   │   ├── session_1/
│   │   │   ├── events.json         # List of ElixirScope events
│   │   │   ├── source_code.json    # Map of {module_name, source_string}
│   │   │   └── ast_map.json        # Map of {ast_node_id, {file, line_start, line_end}} (simplified)
│   │   └── session_2/
│   │       └── ...
│   └── static/
│       └── ...
├── test/
│   └── ...
└── mix.exs
```

### Key Module Responsibilities:

*   **`PhoenixScopePlayer.DataProvider`:**
    *   `list_sessions()`: Returns metadata for all available pre-recorded sessions.
    *   `get_session_data(session_id)`: Loads events, source code, and AST mapping for a given session ID from `priv/captured_data/`.
    *   `get_event_at_index(session_id, index)`: Retrieves a specific event.
    *   `get_source_code(session_id, module_name)`: Retrieves source for a module.
    *   `get_line_for_ast_node(session_id, ast_node_id)`: Maps AST Node ID to a line number.

*   **`PhoenixScopePlayer.PlaybackEngine` (GenServer):**
    *   Manages the state for a single playback session.
    *   `start_link(session_id)`: Starts the engine for a session.
    *   `handle_call(:get_current_state, _from, state)`: Returns current event, variables, call stack.
    *   `handle_cast(:play, state)`, `handle_cast(:pause, state)`, `handle_cast(:step_forward, state)`, etc.
    *   `handle_cast({:seek_to_event, event_index}, state)`.
    *   Holds the full list of events for the session, current event index, playback status (playing/paused).
    *   Calculates variable states and call stack based on events up to the current index.

*   **`PhoenixScopePlayerWeb.SessionListLive` (LiveView):**
    *   `mount`: Calls `DataProvider.list_sessions()` and assigns to socket.
    *   `render`: Displays the list of sessions with "Load & Play" links/buttons.
    *   `handle_event("load_session", %{"id" => session_id}, socket)`: Redirects to the PlaybackView for the selected session.

*   **`PhoenixScopePlayerWeb.PlaybackLive` (LiveView - The Main UI):**
    *   `mount(params, _session, socket)`:
        *   Extracts `session_id` from `params`.
        *   Starts a `PlaybackEngine` GenServer for this session.
        *   Loads initial session data (first event, relevant code) via `DataProvider` and `PlaybackEngine`.
        *   Assigns initial data to socket.
    *   `render(assigns)`: Renders the multi-panel layout using child LiveView components or direct HEEx.
    *   `handle_event` for timeline controls (e.g., "play", "step_forward", "seek"):
        *   Sends corresponding casts/calls to its `PlaybackEngine`.
    *   `handle_info({:playback_update, playback_engine_state}, socket)`:
        *   Receives updates from its `PlaybackEngine` (e.g., new current event, variables).
        *   Updates its assigns, triggering re-renders of relevant panels.
        *   Fetches necessary source code via `DataProvider` if the module context changes.

*   **Component LiveViews (e.g., `CodeViewLive`, `EventLogLive`, `StateInspectorLive`):**
    *   These would be child LiveViews or function components rendered by `PlaybackLive`.
    *   They receive data (current event, current code, current variables) as assigns from `PlaybackLive` and render their specific panel.
    *   `EventLogLive` might handle clicks on events to send a "seek" event to `PlaybackLive`.

### Data Flow (Example: User clicks "Step Forward")

1.  `PlaybackLive` `handle_event("step_forward", ...)` is triggered.
2.  `PlaybackLive` sends `GenServer.cast(playback_engine_pid, :step_forward)`.
3.  `PlaybackEngine` `handle_cast(:step_forward, state)`:
    *   Increments its internal event index.
    *   Determines the new current event.
    *   Re-calculates variable states and call stack based on events up to the new index.
    *   Sends an update message to `PlaybackLive` (its parent/subscriber): `send(self_playback_live_pid, {:playback_update, new_engine_state})`.
4.  `PlaybackLive` `handle_info({:playback_update, new_engine_state}, socket)`:
    *   Updates socket assigns: `@current_event`, `@variables`, `@call_stack`, `@current_module`, `@current_line`.
    *   If `@current_module` changed, it might fetch new source code using `DataProvider`.
5.  Phoenix re-renders `PlaybackLive` and its components, updating the UI.

This design provides a simple yet effective way to demonstrate the core value of ElixirScope's compile-time instrumentation by allowing users to "see" an execution unfold. The use of pre-recorded data keeps the demo app itself simple and focused on UI/UX for playback.

---

This covers the UI and codebase design. The next step would be to ask for specific implementations of these modules, starting with the `DataProvider` to load the pre-recorded data, then the `PlaybackEngine`, and finally the LiveView components.
