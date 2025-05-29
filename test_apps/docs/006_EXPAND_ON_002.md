Okay, here are additional technical details to aid in the implementation of `PhoenixScopePlayer`, suitable for an AI like Claude or a human developer.

## I. Enhanced Module Details & Logic

### 1. `PhoenixScopePlayer.Application`

*   **Registry for PlaybackEngines:**
    *   The `PlaybackEngine` GenServers should be managed by a `Registry` to allow `PlaybackLive` to find/start them using the `session_id`.
    *   Add `PhoenixScopePlayer.PlaybackEngine.Registry` to the application's supervisor children.

    ```elixir
    # lib/phoenix_scope_player/application.ex
    def start(_type, _args) do
      children = [
        PhoenixScopePlayerWeb.Telemetry, # If you have one
        {Phoenix.PubSub, name: PhoenixScopePlayer.PubSub},
        PhoenixScopePlayerWeb.Endpoint,
        PhoenixScopePlayer.PlaybackEngine.Registry # Add this
      ]
      opts = [strategy: :one_for_one, name: PhoenixScopePlayer.Supervisor]
      Supervisor.start_link(children, opts)
    end
    ```
    *   `PhoenixScopePlayer.PlaybackEngine.Registry` itself would be a simple module:
        ```elixir
        # lib/phoenix_scope_player/playback_engine/registry.ex
        defmodule PhoenixScopePlayer.PlaybackEngine.Registry do
          use Registry, keys: :unique, name: __MODULE__
        end
        ```
        And the `PlaybackEngine` would use `name: via_session_id(session_id)` in `start_link` and `via_session_id/1` helper as shown in the previous detailed `playback_engine.ex`.

### 2. `PhoenixScopePlayer.DataProvider`

*   **Error Handling:** The `load_json/3` function should gracefully handle file read errors or JSON parsing errors beyond just returning `default_value`. It could log them or return `{:error, reason}`.
    ```elixir
    # lib/phoenix_scope_player/data_provider.ex (updated load_json)
    defp load_json(dir, file_name, default_value) do
      file_path = Path.join(dir, file_name)

      if File.exists?(file_path) do
        case File.read(file_path) do
          {:ok, content} ->
            case Jason.decode(content) do
              {:ok, decoded_json} -> decoded_json
              {:error, reason} ->
                IO.warn("Failed to parse JSON from #{file_path}: #{inspect(reason)}")
                default_value
            end
          {:error, reason} ->
            IO.warn("Failed to read file #{file_path}: #{inspect(reason)}")
            default_value
        end
      else
        # IO.warn("File not found: #{file_path}") # Optional: too noisy if files are optional
        default_value
      end
    end
    ```
*   **AST Node ID to Line Mapping:** The `get_ast_node_location/2` function expects `ast_node_id` as a string key in `ast_map.json`. Ensure consistency if AST Node IDs are numbers in `events.json`.

### 3. `PhoenixScopePlayer.PlaybackEngine`

*   **State Structure (More Explicit):**
    ```elixir
    # In PlaybackEngine
    state = %{
      session_id: String.t(),
      session_data: %{ # Loaded by DataProvider
        id: String.t(),
        events: list(map()), # List of decoded event JSON objects
        source_code_map: map(), # %{module_name_string => source_string}
        ast_map: map() # %{ast_node_id_string => location_map}
      },
      current_event_index: non_neg_integer(),
      is_playing: boolean(), # True if auto-stepping (timer-based, more advanced)
      parent_pid: pid() | nil, # PID of the PlaybackLive instance
      # Derived state, recalculated on step/seek:
      call_stack: list(String.t()), # e.g., ["MyModule.foo/1", "Another.bar/0"]
      variables: map() # %{var_name_string => value}
    }
    ```
*   **`calculate_current_state/1` - Refined Logic:**
    This function is critical. It needs to iterate through events from the beginning of the session up to `current_event_index` to reconstruct the `call_stack` and `variables`.
    ```elixir
    # lib/phoenix_scope_player/playback_engine.ex
    defp calculate_current_state(state) do
      events_to_process = Enum.slice(state.session_data.events, 0..state.current_event_index)
      # Ensure keys are atoms if that's how you access them later,
      # or consistently use string keys from JSON. Let's assume string keys.
      initial_tracking_state = %{"call_stack" => [], "variables" => %{}}

      final_tracking_state =
        Enum.reduce(events_to_process, initial_tracking_state, fn event_json, acc_tracking_state ->
          # Event data from JSON uses string keys
          event_type = Map.get(event_json, "type")
          event_data = Map.get(event_json, "data", %{})

          new_call_stack =
            case event_type do
              "FUNCTION_ENTRY" ->
                m = Map.get(event_data, "module", "UnknownModule")
                f = Map.get(event_data, "function", "unknown_function")
                a = Map.get(event_data, "arity", 0)
                ["#{m}.#{f}/#{a}" | acc_tracking_state["call_stack"]]

              "FUNCTION_EXIT" ->
                case acc_tracking_state["call_stack"] do
                  [_ | rest] -> rest
                  [] -> [] # Should not happen in a well-formed trace
                end

              _ ->
                acc_tracking_state["call_stack"]
            end

          new_variables =
            case event_type do
              "VAR_SNAPSHOT" ->
                # Variables in event_data is expected to be a map {"var_name" => value}
                Map.merge(acc_tracking_state["variables"], Map.get(event_data, "variables", %{}))

              "FUNCTION_ENTRY" ->
                # Add function arguments to variables, potentially prefixed
                args = Map.get(event_data, "args", [])
                # Create a unique scope for these args or merge them.
                # For simplicity, let's merge, but be aware of potential name clashes.
                current_scope_vars = Map.get(acc_tracking_state, "variables", %{})
                arg_vars =
                  Enum.with_index(args)
                  |> Enum.reduce(%{}, fn {val, i}, arg_acc ->
                    # Store arg names symbolically if names are not in the event
                    Map.put(arg_acc, "arg#{i}", val)
                  end)
                Map.merge(current_scope_vars, arg_vars)

              # Potentially clear variables on FUNCTION_EXIT from the current scope.
              # This requires more sophisticated scope management. For simplicity, we'll let them accumulate.
              _ ->
                acc_tracking_state["variables"]
            end

          %{"call_stack" => new_call_stack, "variables" => new_variables}
        end)

      %{state | call_stack: final_tracking_state["call_stack"], variables: final_tracking_state["variables"]}
    end
    ```
    *   **Note on Variables:** The `VAR_SNAPSHOT` event should ideally contain all *currently in-scope* variables. If it only contains changed variables, the `PlaybackEngine` would need to merge intelligently. The simple `Map.merge` assumes snapshots are comprehensive for their scope or that variables from outer scopes persist. A more advanced engine would track variable scopes tied to `FUNCTION_ENTRY`/`EXIT`.

*   **Timer for Playback:** If `is_playing: true` is to auto-step:
    ```elixir
    # In handle_cast(:play, state)
    new_state = %{state | is_playing: true}
    Process.send_after(self(), :auto_step, 1000) # 1s interval, configurable
    {:noreply, new_state}

    # In handle_cast(:pause, state)
    # Cancel any existing timer if using Process.send_after's timer reference.
    # Or, simply let the auto_step handle_info check is_playing.
    new_state = %{state | is_playing: false}
    {:noreply, new_state}

    # New handle_info
    @impl true
    def handle_info(:auto_step, state) do
      if state.is_playing and state.current_event_index + 1 < length(state.session_data.events) do
        send(self(), :step_forward_internal) # Trigger the existing step logic
        Process.send_after(self(), :auto_step, 1000) # Reschedule
      else
        # Reached end or paused
        {:noreply, %{state | is_playing: false}} # Auto-pause
      end
    end
    ```

## II. LiveView Details

### 1. `PhoenixScopePlayerWeb.PlaybackLive`

*   **Passing Data to Components:** The `assigns` passed to child LiveComponents should be specific to what they need.
    *   For `EventLogLive`: `events` (full list), `current_event_index`.
    *   For `CodeViewLive`: `code` (string of current module's source), `current_line` (integer).
    *   For `StateInspectorLive`: `variables` (map), `call_stack` (list).
*   **Deriving `current_event_module_code` and `current_event_line`**: This logic needs to be robust.
    ```elixir
    # In PlaybackLive, when :playback_update is received or on mount
    defp assign_source_code_and_line(socket, playback_engine_state_from_engine) do
      current_event_json = playback_engine_state_from_engine.current_event # This is the raw JSON map
      session_data_ref = playback_engine_state_from_engine.session_data_ref # This is the full session_data map

      current_event_data = Map.get(current_event_json || %{}, "data", %{})
      module_name = Map.get(current_event_data, "module")
      line_from_event = Map.get(current_event_data, "line") # e.g., from LINE_EXECUTION
      ast_node_id_from_event = Map.get(current_event_json || %{}, "ast_node_id")

      # 1. Get Source Code
      current_module_code =
        if module_name && session_data_ref do
          DataProvider.get_source_for_module(session_data_ref, module_name)
        else
          nil # Or a placeholder like "Source code not available for this event."
        end

      # 2. Determine Highlighted Line
      current_highlighted_line =
        cond do
          line_from_event ->
            line_from_event # Prefer line directly from event if available
          ast_node_id_from_event && session_data_ref ->
            # Fallback to ast_map if event doesn't have a line but has an AST node
            case DataProvider.get_ast_node_location(session_data_ref, ast_node_id_from_event) do
              %{"line_start" => ast_line} -> ast_line
              _ -> nil # AST node not found or doesn't have line_start
            end
          true ->
            nil # No line information available
        end

      socket
      |> assign(:current_event_module_code, current_module_code)
      |> assign(:current_event_line, current_highlighted_line)
    end
    ```
*   **Unique IDs for Components:** Ensure child LiveComponents have unique `id`s if multiple instances could appear (not an issue here, but good practice).

### 2. `PhoenixScopePlayerWeb.EventLogLive`

*   **Efficient Rendering:** For very long event logs, consider pagination or virtual scrolling (more advanced). For this demo, direct rendering is fine.
*   **Clicking an Event:**
    The `phx-click={JS.push("seek_to_event", value: %{index: index}, target: @target)}` is good.
    `@target` should be the `PlaybackLive` instance. This can be set up when `PlaybackLive` renders `EventLogLive`:
    ```html
    <!-- In PlaybackLive.render -->
    <.live_component
      module={PhoenixScopePlayerWeb.EventLogLive}
      id="event-log"
      target={@myself}  {!-- Pass PlaybackLive's pid --}
      events={@session_data.events}
      current_event_index={@current_event_index}
    />
    ```
    And `PlaybackLive` handles `handle_event("seek_to_event", %{"index" => index}, socket)`.

### 3. `PhoenixScopePlayerWeb.CodeViewLive`

*   **Line Highlighting:** The current `highlight_code/2` function is a good start.
    *   It correctly uses `Phoenix.HTML.raw` for the final output.
    *   Ensure CSS classes `bg-yellow-500 bg-opacity-30` and `text-gray-500 select-none` are defined in your `app.scss` (if using Tailwind) or your custom CSS.
*   **No Code State:** Handle the case where `code` is `nil` gracefully in the template (`<p :if={not @code}>...`)

### 4. `PhoenixScopePlayerWeb.StateInspectorLive`

*   **Tabs:** The `phx-click="set_tab"` sending an event to itself (`handle_event("set_tab", ...)` in `StateInspectorLive`) to update `@active_tab` is the correct LiveComponent pattern.
*   **Variable Display:** The `inspect(value)` is fine for a demo. For production, you might want a more structured/pretty printer for complex data types.

## III. Data Format Details (`priv/captured_data/`)

### `events.json` - More Event Type Examples for `data` field:

*   **`FUNCTION_ENTRY`**:
    ```json
    {
      "module": "MyModule", "function": "process", "arity": 2,
      "args": [{"id": 1, "status": "pending"}, "user_token_abc"]
    }
    ```
*   **`FUNCTION_EXIT`**:
    ```json
    {
      "module": "MyModule", "function": "process", "arity": 2,
      "return_value": {:ok, %{"id": 1, "status": "processed"}},
      "duration_ns": 125000000 // 125ms
    }
    ```
*   **`LINE_EXECUTION`**:
    ```json
    { "module": "MyModule", "function": "process", "line": 23 }
    ```
*   **`VAR_SNAPSHOT`**:
    ```json
    {
      "module": "MyModule", "function": "process", "line": 25,
      "variables": {
        "item": {"id": 1, "status": "pending"},
        "current_user": %{"id": "user_123", "role": "admin"},
        "retry_count": 0
      }
    }
    ```
*   **`EXPRESSION_VALUE`**:
    ```json
    {
      "module": "MyModule", "function": "process", "line": 28,
      "expression_source": "item.id == 1 and current_user.role == \"admin\"",
      "value": true
    }
    ```

### `ast_map.json`

*   The keys should be the **string representation** of `ast_node_id` as they appear in `events.json`.
*   `"line_start"` is sufficient for basic line highlighting. `line_end`, `col_start`, `col_end` allow for more precise (character-level) highlighting if the UI supports it.

## IV. Assets & Styling (Tailwind CSS Confirmation)

*   The provided `mix.exs` includes `tailwind` and `esbuild`. This is the standard setup for Phoenix 1.7+.
*   The `app.scss` with `@import "tailwindcss/*";` is correct.
*   The `Heroicons` dependency is good for icons. You'll need to ensure they are correctly rendered, e.g., `Heroicons.Solid.play/1` in HEEx. If you `use Heroicons` in `core_components.ex` or similar, you can use `<.icon name="hero-play-solid" />`. The direct module call `Heroicons.Solid.play class="h-5 w-5"/>` is also fine.

## V. General Phoenix & LiveView

*   **`core_components.ex`**: Phoenix 1.7 generates this file for common UI components (like modals, tables, icons). While not strictly necessary for this simple player, using it for things like buttons or layout elements could be beneficial if the app grows. For this scope, direct HEEx is fine.
*   **Flash Messages:** The `PlaybackLive` `mount` handles error by `put_flash`. Ensure your `root.html.heex` or `app.html.heex` has `<.flash_group flash={@flash} />` to display these.
    ```html
    <!-- lib/phoenix_scope_player_web/templates/layout/root.html.heex -->
    <body class="bg-gray-100 antialiased">
      <.flash_group flash={@flash} /> <!-- Add this -->
      <%= @inner_content %>
    </body>
    ```
*   **CSRF Token:** The `app.js` correctly sets up `csrfToken` for the `LiveSocket`.

## VI. Final Checks

*   Ensure all file paths are correct (e.g., `priv/captured_data`).
*   The sample JSON data should be syntactically correct.
*   Test with an empty `priv/captured_data` directory to see how `SessionListLive` handles it.
*   Test with a session that has no events.

These additional details should provide a clearer path for implementing the various parts of the `PhoenixScopePlayer` application. The focus remains on keeping the player simple while effectively demonstrating the utility of ElixirScope's captured data.
