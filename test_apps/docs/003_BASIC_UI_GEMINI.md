Okay, I will implement the `PhoenixScopePlayer` example application as described. This application will serve as a UI to play back pre-recorded debugging sessions captured by ElixirScope.

Here's the directory structure and content for the `PhoenixScopePlayer` application:

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
│   │   ├── data_provider.ex
│   │   └── playback_engine.ex
│   └── phoenix_scope_player_web/
│       ├── components/
│       │   ├── code_view_live.ex
│       │   ├── event_log_live.ex
│       │   └── state_inspector_live.ex
│       ├── live/
│       │   ├── playback_live.ex
│       │   └── session_list_live.ex
│       ├── router.ex
│       └── templates/
│           ├── layout/
│           │   ├── app.html.heex
│           │   ├── live.html.heex
│           │   └── root.html.heex
│           ├── components/
│           │   ├── code_view_live.html.heex
│           │   ├── event_log_live.html.heex
│           │   └── state_inspector_live.html.heex
│           ├── playback/
│           │   └── show.html.heex
│           └── session_list/
│               └── index.html.heex
├── priv/
│   ├── captured_data/
│   │   └── sample_session_1/
│   │       ├── ast_map.json
│   │       ├── events.json
│   │       ├── metadata.json
│   │       └── source_code.json
│   └── static/
│       └── favicon.ico
├── mix.exs
└── README.md
```

---
**`phoenix_scope_player/mix.exs`**:
```elixir
defmodule PhoenixScopePlayer.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_scope_player,
      version: "0.1.0",
      elixir: "~> 1.15", # Or your Elixir version
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {PhoenixScopePlayer.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.11"},
      {:phoenix_live_view, "~> 0.20.2"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      # {:phoenix_live_dashboard, "~> 0.8.3"}, # Optional
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2.0", runtime: Mix.env() == :dev},
      {:jason, "~> 1.2"},
      {:heroicons, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:plug_cowboy, "~> 2.5"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "assets.deploy"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"]
    ]
  end
end
```

---
**`phoenix_scope_player/lib/phoenix_scope_player/application.ex`**:
```elixir
defmodule PhoenixScopePlayer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      # PhoenixScopePlayerWeb.Telemetry, # Uncomment if you have telemetry
      # Start the PubSub system
      {Phoenix.PubSub, name: PhoenixScopePlayer.PubSub},
      # Start the Endpoint (http/https)
      PhoenixScopePlayerWeb.Endpoint
      # Start a worker by calling: PhoenixScopePlayer.Worker.start_link(arg)
      # {PhoenixScopePlayer.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PhoenixScopePlayer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenevertheapplicationisupdated.
  @impl true
  def config_change(changed, _new, _removed) do
    PhoenixScopePlayerWeb.Endpoint.config_change(changed, _new, _removed)
    :ok
  end
end
```

---
**`phoenix_scope_player/lib/phoenix_scope_player_web/router.ex`**:
```elixir
defmodule PhoenixScopePlayerWeb.Router do
  use PhoenixScopePlayerWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PhoenixScopePlayerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # pipeline :api do
  #   plug :accepts, ["json"]
  # end

  scope "/", PhoenixScopePlayerWeb do
    pipe_through :browser

    live "/", SessionListLive, :index
    live "/session/:session_id/play", PlaybackLive, :show
  end

  # Other scopes may use custom stacks.
  # scope "/api", PhoenixScopePlayerWeb do
  #   pipe_through :api
  # end
end
```

---
**`phoenix_scope_player/lib/phoenix_scope_player/data_provider.ex`**:
```elixir
defmodule PhoenixScopePlayer.DataProvider do
  @moduledoc """
  Loads and serves pre-captured ElixirScope session data.
  """

  @captured_data_path "priv/captured_data"

  def list_sessions do
    sessions_path = Path.join([File.cwd!(), @captured_data_path, "*"])

    Path.wildcard(sessions_path)
    |> Enum.filter(&File.dir?/1)
    |> Enum.map(fn session_dir ->
      session_id = Path.basename(session_dir)
      metadata = load_json(session_dir, "metadata.json", %{})
      events = load_json(session_dir, "events.json", [])

      %{
        id: session_id,
        name: Map.get(metadata, "name", session_id),
        description: Map.get(metadata, "description", "N/A"),
        timestamp: Map.get(metadata, "timestamp", "N/A"),
        event_count: length(events)
      }
    end)
    |> Enum.sort_by(& &1.name)
  end

  def get_session_data(session_id) do
    session_dir = Path.join([File.cwd!(), @captured_data_path, session_id])

    if File.dir?(session_dir) do
      events = load_json(session_dir, "events.json", [])
      source_code_map = load_json(session_dir, "source_code.json", %{})
      ast_map = load_json(session_dir, "ast_map.json", %{})

      {:ok,
       %{
         id: session_id,
         events: events,
         source_code_map: source_code_map,
         ast_map: ast_map
       }}
    else
      {:error, :not_found}
    end
  end

  defp load_json(dir, file_name, default_value) do
    file_path = Path.join(dir, file_name)

    if File.exists?(file_path) do
      case File.read(file_path) do
        {:ok, content} -> Jason.decode!(content)
        {:error, _reason} -> default_value
      end
    else
      default_value
    end
  end

  def get_source_for_module(session_data, module_name) when is_map(session_data) do
    Map.get(session_data.source_code_map, module_name)
  end

  def get_ast_node_location(session_data, ast_node_id) when is_map(session_data) do
    Map.get(session_data.ast_map, to_string(ast_node_id))
  end
end
```

---
**`phoenix_scope_player/lib/phoenix_scope_player/playback_engine.ex`**:
```elixir
defmodule PhoenixScopePlayer.PlaybackEngine do
  use GenServer

  alias PhoenixScopePlayer.DataProvider

  # Client API
  def start_link(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    GenServer.start_link(__MODULE__, session_id, name: via_session_id(session_id))
  end

  def get_current_playback_state(pid_or_session_id) do
    GenServer.call(pid_or_session_id_to_via(pid_or_session_id), :get_current_playback_state)
  end

  def play(pid_or_session_id) do
    GenServer.cast(pid_or_session_id_to_via(pid_or_session_id), :play)
  end

  def pause(pid_or_session_id) do
    GenServer.cast(pid_or_session_id_to_via(pid_or_session_id), :pause)
  end

  def step_forward(pid_or_session_id) do
    GenServer.cast(pid_or_session_id_to_via(pid_or_session_id), :step_forward)
  end

  def step_backward(pid_or_session_id) do
    GenServer.cast(pid_or_session_id_to_via(pid_or_session_id), :step_backward)
  end

  def seek_to_start(pid_or_session_id) do
    GenServer.cast(pid_or_session_id_to_via(pid_or_session_id), :seek_to_start)
  end

  def seek_to_end(pid_or_session_id) do
    GenServer.cast(pid_or_session_id_to_via(pid_or_session_id), :seek_to_end)
  end

  def seek_to_event_index(pid_or_session_id, index) do
    GenServer.cast(pid_or_session_id_to_via(pid_or_session_id), {:seek_to_event_index, index})
  end

  defp via_session_id(session_id) do
    {:via, Registry, {PhoenixScopePlayer.PlaybackEngine.Registry, session_id}}
  end

  defp pid_or_session_id_to_via(pid_or_session_id) when is_pid(pid_or_session_id), do: pid_or_session_id
  defp pid_or_session_id_to_via(session_id), do: via_session_id(session_id)


  # Server Callbacks
  @impl true
  def init(session_id) do
    case DataProvider.get_session_data(session_id) do
      {:ok, session_data} ->
        state = %{
          session_id: session_id,
          session_data: session_data,
          current_event_index: 0,
          is_playing: false,
          parent_pid: nil, # To be set by PlaybackLive
          call_stack: [],
          variables: %{}
        }
        {:ok, state, {:continue, :calculate_current_state_and_notify}}

      {:error, reason} ->
        {:stop, {:initialization_failed, reason}}
    end
  end

  @impl true
  def handle_continue(:calculate_current_state_and_notify, state) do
    new_state = calculate_current_state(state)
    notify_parent(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_current_playback_state, _from, state) do
    reply_data = %{
      current_event: get_current_event(state),
      current_event_index: state.current_event_index,
      total_events: length(state.session_data.events),
      is_playing: state.is_playing,
      call_stack: state.call_stack,
      variables: state.variables
    }
    {:reply, {:ok, reply_data}, state}
  end

  @impl true
  def handle_cast(:play, state) do
    new_state = %{state | is_playing: true}
    # In a real app, you'd start a timer here to auto-step
    # For simplicity, play/pause only affects button state for now.
    # Or, it could trigger a single step_forward.
    # Let's make it trigger a step_forward if not already at the end.
    if get_current_event(new_state) != nil, do: send(self(), :step_forward_internal)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:pause, state) do
    new_state = %{state | is_playing: false}
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:step_forward, state) do
    send(self(), :step_forward_internal)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:step_backward, state) send(self(), :step_backward_internal)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:seek_to_start, state) do
    new_state = %{state | current_event_index: 0}
    |> calculate_current_state()
    notify_parent(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:seek_to_end, state) do
    total_events = length(state.session_data.events)
    new_index = if total_events > 0, do: total_events - 1, else: 0
    new_state = %{state | current_event_index: new_index}
    |> calculate_current_state()
    notify_parent(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:seek_to_event_index, index}, state) when is_integer(index) do
    total_events = length(state.session_data.events)
    new_index =
      cond do
        index < 0 -> 0
        index >= total_events && total_events > 0 -> total_events - 1
        index >= total_events && total_events == 0 -> 0
        true -> index
      end
    new_state = %{state | current_event_index: new_index}
    |> calculate_current_state()

    notify_parent(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:subscribe_parent, parent_pid}, state) do
    {:noreply, %{state | parent_pid: parent_pid}}
  end


  @impl true
  def handle_info(:step_forward_internal, state) do
    total_events = length(state.session_data.events)
    new_index =
      if state.current_event_index + 1 < total_events do
        state.current_event_index + 1
      else
        state.current_event_index # Stay at the end
      end

    new_state = %{state | current_event_index: new_index}
    |> calculate_current_state()

    notify_parent(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:step_backward_internal, state) do
    new_index =
      if state.current_event_index - 1 >= 0 do
        state.current_event_index - 1
      else
        0 # Stay at the start
      end
    new_state = %{state | current_event_index: new_index}
    |> calculate_current_state()

    notify_parent(new_state)
    {:noreply, new_state}
  end

  defp get_current_event(state) do
    Enum.at(state.session_data.events, state.current_event_index)
  end

  defp calculate_current_state(state) do
    # Iterate events up to current_event_index to build call_stack and variables
    # This is a simplified approach. A more robust one would be more complex.
    events_to_process = Enum.slice(state.session_data.events, 0..state.current_event_index)
    initial_acc = %{call_stack: [], variables: %{}}

    processed_state =
      Enum.reduce(events_to_process, initial_acc, fn event_map, acc ->
        event = Map.get(event_map, "data", %{}) # Events are maps with string keys from JSON
        event_type = Map.get(event_map, "type")

        new_call_stack =
          case event_type do
            "FUNCTION_ENTRY" ->
              func_call = "#{Map.get(event, "module", "Unknown")}.#{Map.get(event, "function", "unknown")}/#{Map.get(event, "arity", 0)}"
              [func_call | acc.call_stack]
            "FUNCTION_EXIT" ->
              case acc.call_stack do
                [_ | rest] -> rest
                [] -> []
              end
            _ -> acc.call_stack
          end

        new_variables =
          case event_type do
            "VAR_SNAPSHOT" ->
              # Assuming variables is a map like {"var_name" => value}
              Map.merge(acc.variables, Map.get(event, "variables", %{}))
            "FUNCTION_ENTRY" ->
              # Add args as variables, potentially prefixed
              args = Map.get(event, "args", [])
              arg_vars = Enum.with_index(args)
              |> Enum.reduce(%{}, fn {val, i}, arg_acc ->
                Map.put(arg_acc, "arg_#{i}", val) # Store as strings for simplicity
              end)
              Map.merge(acc.variables, arg_vars)

            _ -> acc.variables
          end
          %{call_stack: new_call_stack, variables: new_variables}
      end)

    %{state | call_stack: processed_state.call_stack, variables: processed_state.variables}
  end

  defp notify_parent(state) do
    if state.parent_pid do
      playback_state_for_client = %{
        current_event: get_current_event(state),
        current_event_index: state.current_event_index,
        total_events: length(state.session_data.events),
        is_playing: state.is_playing,
        call_stack: state.call_stack,
        variables: state.variables,
        session_data_ref: state.session_data # For PlaybackLive to access source_code_map etc.
      }
      send(state.parent_pid, {:playback_update, playback_state_for_client})
    end
  end
end

defmodule PhoenixScopePlayer.PlaybackEngine.Registry do
  use Registry, keys: :unique, name: __MODULE__
end
```

---
**`phoenix_scope_player/lib/phoenix_scope_player_web/live/session_list_live.ex`**:
```elixir
defmodule PhoenixScopePlayerWeb.SessionListLive do
  use PhoenixScopePlayerWeb, :live_view

  alias PhoenixScopePlayer.DataProvider

  @impl true
  def mount(_params, _session, socket) do
    sessions = DataProvider.list_sessions()
    {:ok, assign(socket, sessions: sessions)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-3xl font-bold mb-6">ElixirScope - Debug Session Playback</h1>

      <.link navigate={~p"/"} class="text-sm text-zinc-500 hover:text-zinc-700 pb-4 block">
        &larr; Refresh Session List
      </.link>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <div :if={@sessions == []} class="col-span-full text-center text-gray-500">
          <p>No debug sessions found in <code>priv/captured_data/</code>.</p>
          <p>Please add some session data to see them listed here.</p>
          <p class="mt-2 text-sm">
            Example: Create <code>priv/captured_data/my_session/events.json</code>, etc.
          </p>
        </div>
        <div
          :for={session <- @sessions}
          id={"session-#{session.id}"}
          class="border rounded-lg p-6 shadow-lg hover:shadow-xl transition-shadow bg-white"
        >
          <h2 class="text-xl font-semibold mb-2"><%= session.name %></h2>
          <p class="text-gray-600 text-sm mb-1">ID: <%= session.id %></p>
          <p class="text-gray-700 mb-3 h-16 overflow-y-auto text-sm"><%= session.description %></p>
          <div class="text-xs text-gray-500 mb-4">
            <p>Events: <%= session.event_count %></p>
            <p :if={session.timestamp != "N/A"}>Captured: <%= session.timestamp %></p>
          </div>
          <.link
            navigate={~p"/session/#{session.id}/play"}
            class="block w-full text-center bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded transition-colors"
          >
            Load & Play
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
```

---
**`phoenix_scope_player/lib/phoenix_scope_player_web/live/playback_live.ex`**:
```elixir
defmodule PhoenixScopePlayerWeb.PlaybackLive do
  use PhoenixScopePlayerWeb, :live_view

  alias PhoenixScopePlayer.PlaybackEngine
  alias PhoenixScopePlayer.DataProvider # To get source/AST info

  @impl true
  def mount(%{"session_id" => session_id}, _session, socket) do
    # Ensure the PlaybackEngine.Registry is started
    # This is typically done in application.ex if it's a top-level supervisor
    # For this example, we'll assume it's running.
    # If not, you'd need: Supervisor.start_link([PhoenixScopePlayer.PlaybackEngine.Registry], strategy: :one_for_one)

    {:ok, engine_pid} = PlaybackEngine.start_link(session_id: session_id)
    GenServer.cast(engine_pid, {:subscribe_parent, self()})

    case PlaybackEngine.get_current_playback_state(engine_pid) do
      {:ok, initial_playback_state} ->
        socket =
          socket
          |> assign(session_id: session_id)
          |> assign_playback_state(initial_playback_state)
          |> assign_source_code_and_line(initial_playback_state)

        {:ok, socket, temporary_assigns: [current_event_module_code: nil, current_event_line: nil]}

      {:error, _reason} ->
        socket =
          socket
          |> put_flash(:error, "Failed to load session: #{session_id}")
          |> assign(session_id: session_id, current_event: nil, error: true)
        {:ok, socket}
    end
  end


  defp assign_playback_state(socket, playback_state) do
    socket
    |> assign(
      current_event: playback_state.current_event,
      current_event_index: playback_state.current_event_index,
      total_events: playback_state.total_events,
      is_playing: playback_state.is_playing,
      call_stack: playback_state.call_stack,
      variables: playback_state.variables,
      # session_data contains events, source_code_map, ast_map
      session_data: playback_state.session_data_ref
    )
  end

  defp assign_source_code_and_line(socket, playback_state) do
    current_event_data = Map.get(playback_state.current_event || %{}, "data", %{})
    module_name = Map.get(current_event_data, "module")
    line = Map.get(current_event_data, "line") # For LINE_EXECUTION, VAR_SNAPSHOT
    ast_node_id = Map.get(playback_state.current_event || %{}, "ast_node_id")

    current_event_module_code =
      if module_name && playback_state.session_data_ref do
        DataProvider.get_source_for_module(playback_state.session_data_ref, module_name)
      else
        nil
      end

    # Prefer line from event data, fallback to AST map if available
    current_event_line =
      cond do
        line ->
          line
        ast_node_id && playback_state.session_data_ref ->
          case DataProvider.get_ast_node_location(playback_state.session_data_ref, ast_node_id) do
            %{"line_start" => ast_line} -> ast_line
            _ -> nil
          end
        true ->
          nil
      end

    socket
    |> assign(current_event_module_code: current_event_module_code)
    |> assign(current_event_line: current_event_line)
  end

  @impl true
  def handle_info({:playback_update, playback_state}, socket) do
    socket =
      socket
      |> assign_playback_state(playback_state)
      |> assign_source_code_and_line(playback_state)
    {:noreply, socket}
  end

  @impl true
  def handle_event("play", _value, socket) do
    PlaybackEngine.play(socket.assigns.session_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("pause", _value, socket) do
    PlaybackEngine.pause(socket.assigns.session_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("step_forward", _value, socket) do
    PlaybackEngine.step_forward(socket.assigns.session_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("step_backward", _value, socket) do
    PlaybackEngine.step_backward(socket.assigns.session_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("seek_to_start", _value, socket) do
    PlaybackEngine.seek_to_start(socket.assigns.session_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("seek_to_end", _value, socket) do
    PlaybackEngine.seek_to_end(socket.assigns.session_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("seek_to_event", %{"index" => index_str}, socket) do
    case Integer.parse(index_str) do
      {index, ""} -> PlaybackEngine.seek_to_event_index(socket.assigns.session_id, index)
      _ -> :ok # Ignore invalid index
    end
    {:noreply, socket}
  end


  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col">
      <header class="bg-gray-800 text-white p-4 shadow-md">
        <div class="container mx-auto flex justify-between items-center">
          <h1 class="text-xl font-semibold">
            <.link navigate={~p"/"} class="hover:text-gray-300">ElixirScope Player</.link>
            <span :if={@session_id}>- Session: <%= @session_id %></span>
          </h1>
          <div :if={@current_event} class="text-sm">
            Event <%= @current_event_index + 1 %> / <%= @total_events %>
          </div>
        </div>
      </header>

      <div :if={assigns[:error]} class="p-4 text-red-700 bg-red-100 border border-red-400 rounded">
        Error loading session. Please <.link navigate={~p"/"}>select another session</.link>.
      </div>

      <div :if={@current_event} class="flex-grow flex flex-col md:flex-row overflow-hidden">
        {!-- Panel 2: Event Log --}
        <div class="w-full md:w-1/3 lg:w-1/4 h-1/2 md:h-full overflow-y-auto p-4 border-r border-gray-300 bg-gray-50">
          <.live_component
            module={PhoenixScopePlayerWeb.EventLogLive}
            id="event-log"
            session_id={@session_id}
            events={@session_data.events}
            current_event_index={@current_event_index}
          />
        </div>

        {!-- Main Content Area --}
        <div class="w-full md:w-2/3 lg:w-3/4 flex flex-col h-1/2 md:h-full overflow-hidden">
          {!-- Panel 3: Code View --}
          <div class="flex-grow overflow-y-auto p-4 border-b md:border-b-0 md:border-r border-gray-300">
            <.live_component
              module={PhoenixScopePlayerWeb.CodeViewLive}
              id="code-view"
              code={@current_event_module_code}
              current_line={@current_event_line}
              event_type={Map.get(@current_event, "type")}
            />
          </div>

          {!-- Panel 4: State Inspector --}
          <div class="h-1/3 md:h-1/2 lg:h-1/3 overflow-y-auto p-4 bg-gray-100">
            <.live_component
              module={PhoenixScopePlayerWeb.StateInspectorLive}
              id="state-inspector"
              variables={@variables}
              call_stack={@call_stack}
            />
          </div>
        </div>
      </div>

      <footer :if={@current_event} class="bg-gray-200 p-4 border-t border-gray-300 shadow-inner">
        <div class="container mx-auto flex items-center justify-center space-x-2 md:space-x-4">
          <button phx-click="seek_to_start" class="px-3 py-2 bg-gray-600 text-white rounded hover:bg-gray-700 disabled:opacity-50" disabled={@current_event_index == 0}>
            <Heroicons.Solid.backward class="h-5 w-5"/> <span class="sr-only">Start</span>
          </button>
          <button phx-click="step_backward" class="px-3 py-2 bg-gray-600 text-white rounded hover:bg-gray-700 disabled:opacity-50" disabled={@current_event_index == 0}>
             <Heroicons.Solid.chevron_left class="h-5 w-5"/> <span class="sr-only">Back</span>
          </button>
          <button :if={!@is_playing} phx-click="play" class="px-3 py-2 bg-green-500 text-white rounded hover:bg-green-600 disabled:opacity-50" disabled={@current_event_index + 1 >= @total_events}>
            <Heroicons.Solid.play class="h-5 w-5"/> <span class="sr-only">Play</span>
          </button>
          <button :if={@is_playing} phx-click="pause" class="px-3 py-2 bg-yellow-500 text-white rounded hover:bg-yellow-600">
            <Heroicons.Solid.pause class="h-5 w-5"/> <span class="sr-only">Pause</span>
          </button>
          <button phx-click="step_forward" class="px-3 py-2 bg-gray-600 text-white rounded hover:bg-gray-700 disabled:opacity-50" disabled={@current_event_index + 1 >= @total_events}>
            <Heroicons.Solid.chevron_right class="h-5 w-5"/> <span class="sr-only">Forward</span>
          </button>
          <button phx-click="seek_to_end" class="px-3 py-2 bg-gray-600 text-white rounded hover:bg-gray-700 disabled:opacity-50" disabled={@current_event_index + 1 >= @total_events}>
            <Heroicons.Solid.forward class="h-5 w-5"/> <span class="sr-only">End</span>
          </button>
        </div>
      </footer>
    </div>
    """
  end
end
```

---
**`phoenix_scope_player/lib/phoenix_scope_player_web/components/event_log_live.ex`**:
```elixir
defmodule PhoenixScopePlayerWeb.EventLogLive do
  use PhoenixScopePlayerWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="text-lg font-semibold mb-3 sticky top-0 bg-gray-50 py-2">Event Log</h2>
      <ul class="space-y-1 text-xs">
        <li :if={@events == []} class="text-gray-500">No events in this session.</li>
        <li
          :for={{event, index} <- Enum.with_index(@events)}
          id={"event-item-#{index}"}
          phx-click={JS.push("seek_to_event", value: %{index: index}, target: @target)}
          class={[
            "p-2 border-l-4 rounded cursor-pointer hover:bg-gray-200 transition-colors",
            index == @current_event_index && "border-blue-500 bg-blue-100",
            index != @current_event_index && "border-transparent"
          ]}
        >
          <div class="font-mono font-semibold text-blue-700"><%= Map.get(event, "type", "UNKNOWN_EVENT") %></div>
          <div class="text-gray-600">
            <span>TS: <%= Map.get(event, "timestamp_ns", "N/A") %></span>
            <span :if={Map.get(event, "ast_node_id")} class="ml-2">Node: <%= Map.get(event, "ast_node_id") %></span>
          </div>
          <pre class="mt-1 text-gray-800 bg-gray-100 p-1 rounded overflow-x-auto"><%= format_event_data(Map.get(event, "data", %{})) %></pre>
        </li>
      </ul>
    </div>
    """
  end

  defp format_event_data(data) when is_map(data) do
    data
    |> Jason.encode!(pretty: true)
    |> String.slice(0, 200) # Truncate for display
    |> then(&(&1 <> if String.length(&1) == 200, do: "...", else: ""))

  end
  defp format_event_data(other), do: inspect(other)

end
```

---
**`phoenix_scope_player/lib/phoenix_scope_player_web/components/code_view_live.ex`**:
```elixir
defmodule PhoenixScopePlayerWeb.CodeViewLive do
  use PhoenixScopePlayerWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="text-lg font-semibold mb-3">Code View
        <span :if={@event_type} class="text-sm font-normal text-gray-500">(Event: <%= @event_type %>)</span>
      </h2>
      <div :if={@code} class="bg-gray-800 text-white p-4 rounded-md overflow-x-auto text-sm font-mono">
        <pre><code><%= highlight_code(@code, @current_line) %></code></pre>
      </div>
      <p :if={not @code} class="text-gray-500">No code to display for the current event.</p>
    </div>
    """
  end

  defp highlight_code(code, current_line) when is_binary(code) do
    code
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.map(fn {line_content, line_num} ->
      highlight_class = if line_num == current_line, do: "bg-yellow-500 bg-opacity-30", else: ""
      line_num_str = String.pad_leading(to_string(line_num), 3)
      # Using Phoenix.HTML.raw to prevent HEEx from escaping the span for highlighting
      # Be cautious with raw if content is user-generated. Here it's from priv/
      Phoenix.HTML.raw(~s|<span class="#{highlight_class}"><span class="text-gray-500 select-none"><%= line_num_str %> | </span><%= Phoenix.HTML.html_escape(line_content) %></span>|)
    end)
    |> Enum.join("\n")
    |> Phoenix.HTML.safe_to_string() # Convert list of safe strings to a single safe string
    |> then(&Phoenix.HTML.raw(&1)) # Ensure the final output is treated as raw HTML
  end
  defp highlight_code(_, _), do: ""
end
```

---
**`phoenix_scope_player/lib/phoenix_scope_player_web/components/state_inspector_live.ex`**:
```elixir
defmodule PhoenixScopePlayerWeb.StateInspectorLive do
  use PhoenixScopePlayerWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok, assign(socket, active_tab: :variables)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="mb-3 border-b border-gray-300">
        <nav class="-mb-px flex space-x-4" aria-label="Tabs">
          <button
            phx-click="set_tab"
            phx-value-tab="variables"
            class={tab_class(:variables, @active_tab)}
          >
            Variables
          </button>
          <button
            phx-click="set_tab"
            phx-value-tab="call_stack"
            class={tab_class(:call_stack, @active_tab)}
          >
            Call Stack
          </button>
        </nav>
      </div>

      <div :if={@active_tab == :variables}>
        <h3 class="text-md font-semibold mb-2">Local Variables</h3>
        <div :if={Enum.empty?(@variables)} class="text-gray-500 text-sm">No variables captured at this point.</div>
        <ul class="space-y-1 text-xs font-mono">
          <li :for={{var_name, value} <- @variables}>
            <span class="text-purple-600"><%= var_name %>:</span>
            <pre class="inline bg-gray-200 p-0.5 rounded"><%= inspect(value) %></pre>
          </li>
        </ul>
      </div>

      <div :if={@active_tab == :call_stack}>
        <h3 class="text-md font-semibold mb-2">Call Stack</h3>
        <div :if={Enum.empty?(@call_stack)} class="text-gray-500 text-sm">Call stack is empty.</div>
        <ul class="space-y-1 text-xs font-mono">
          <li :for={func_call <- @call_stack}><%= func_call %></li>
        </ul>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("set_tab", %{"tab" => tab_name}, socket) do
    {:noreply, assign(socket, active_tab: String.to_atom(tab_name))}
  end

  defp tab_class(tab_key, active_tab) do
    base = "px-3 py-2 font-medium text-sm rounded-t-md "
    if tab_key == active_tab do
      base <> "border-blue-500 border-b-0 text-blue-600"
    else
      base <> "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
    end
  end
end
```

---
**`phoenix_scope_player/lib/phoenix_scope_player_web/templates/layout/root.html.heex`**:
```html
<!DOCTYPE html>
<html lang="en" class="[scrollbar-gutter:stable]">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="csrf-token" content={get_csrf_token()} />
    <.live_title suffix=" · PhoenixScopePlayer">
      <%= assigns[:page_title] || "Player" %>
    </.live_title>
    <link phx-track-static rel="stylesheet" href={~p"/assets/app.css"} />
    <script defer phx-track-static type="text/javascript" src={~p"/assets/app.js"}>
    </script>
  </head>
  <body class="bg-gray-100 antialiased">
    <%= @inner_content %>
  </body>
</html>
```
---
**`phoenix_scope_player/lib/phoenix_scope_player_web/templates/layout/app.html.heex`**:
(For non-LiveView controllers, if any were used. In this setup, it might be unused or identical to `root.html.heex`)
```html
<%= @inner_content %>
```
---
**`phoenix_scope_player/lib/phoenix_scope_player_web/templates/layout/live.html.heex`**:
(This is the default for LiveViews, often just `@inner_content`)
```html
<%= @inner_content %>
```

---
**`phoenix_scope_player/lib/phoenix_scope_player_web/templates/session_list/index.html.heex`**:
(Content is now directly within `SessionListLive.render/1`)

---
**`phoenix_scope_player/lib/phoenix_scope_player_web/templates/playback/show.html.heex`**:
(Content is now directly within `PlaybackLive.render/1`)

---
**`phoenix_scope_player/lib/phoenix_scope_player_web/templates/components/code_view_live.html.heex`**:
(Content is now directly within `CodeViewLive.render/1`)

---
**`phoenix_scope_player/lib/phoenix_scope_player_web/templates/components/event_log_live.html.heex`**:
(Content is now directly within `EventLogLive.render/1`)

---
**`phoenix_scope_player/lib/phoenix_scope_player_web/templates/components/state_inspector_live.html.heex`**:
(Content is now directly within `StateInspectorLive.render/1`)

---
**`phoenix_scope_player/assets/js/app.js`**:
```javascript
// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  // hooks: Hooks, // Add hooks if you have any
})

// Show progress bar on LiveView load
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
```

---
**`phoenix_scope_player/assets/css/app.scss`**:
(Assuming Tailwind CSS is set up as per Phoenix 1.7+)
```scss
@import "tailwindcss/base";
@import "tailwindcss/components";
@import "tailwindcss/utilities";

/* This file is for your custom CSS */
```
If not using Tailwind, you'd add basic CSS here:
```css
/* Basic Reset & Body */
body { margin: 0; font-family: sans-serif; line-height: 1.5; color: #333; background-color: #f4f7f6; }
.container { max-width: 1200px; margin: 0 auto; padding: 1rem; }

/* Header */
header { background-color: #2c3e50; color: white; padding: 1rem; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
header h1 { margin: 0; font-size: 1.5rem; }
header a { color: white; text-decoration: none; }
header a:hover { color: #bdc3c7; }

/* Session List */
.session-list .session-item { background-color: white; border: 1px solid #e0e0e0; border-radius: 4px; padding: 1.5rem; margin-bottom: 1rem; box-shadow: 0 1px 3px rgba(0,0,0,0.05); }
.session-list .session-item h2 { margin-top: 0; font-size: 1.25rem; color: #3498db; }
.session-list .session-item p { margin-bottom: 0.5rem; font-size: 0.9rem; color: #555; }
.session-list .session-item .meta { font-size: 0.8rem; color: #7f8c8d; margin-bottom: 1rem; }
.session-list .session-item .play-button { display: inline-block; background-color: #3498db; color: white; padding: 0.5rem 1rem; border-radius: 4px; text-decoration: none; font-weight: bold; }
.session-list .session-item .play-button:hover { background-color: #2980b9; }

/* Playback View */
.playback-view { display: flex; flex-direction: column; height: calc(100vh - 60px); /* Adjust based on header height */ }
.playback-view .panels-container { display: flex; flex-grow: 1; overflow: hidden; }
.playback-view .event-log-panel { width: 25%; overflow-y: auto; padding: 1rem; border-right: 1px solid #ddd; background-color: #f9f9f9; }
.playback-view .main-content-panel { width: 75%; display: flex; flex-direction: column; }
.playback-view .code-view-panel { flex-grow: 1; overflow-y: auto; padding: 1rem; font-family: monospace; font-size: 0.9rem; }
.playback-view .state-inspector-panel { height: 33%; overflow-y: auto; padding: 1rem; border-top: 1px solid #ddd; background-color: #f0f0f0; }

.event-log-panel ul { list-style: none; padding: 0; margin: 0; }
.event-log-panel li { padding: 0.5rem; border-bottom: 1px solid #eee; cursor: pointer; }
.event-log-panel li:hover { background-color: #e9e9e9; }
.event-log-panel li.active { background-color: #d1eaff; border-left: 3px solid #3498db; }
.event-log-panel .event-type { font-weight: bold; color: #2980b9; }
.event-log-panel .event-data { font-size: 0.8rem; color: #555; word-break: break-all; }

.code-view-panel pre { margin: 0; }
.code-view-panel .highlighted-line { background-color: rgba(255, 255, 0, 0.3); display: block; }
.code-view-panel .line-number { color: #999; display: inline-block; width: 3em; text-align: right; padding-right: 1em; user-select: none; }


.state-inspector-panel .tabs button { padding: 0.5rem 1rem; border: 1px solid #ccc; background: #eee; cursor: pointer; }
.state-inspector-panel .tabs button.active { background: #fff; border-bottom-color: #fff; }
.state-inspector-panel .tab-content { padding-top: 0.5rem; }
.state-inspector-panel ul { list-style: none; padding: 0; margin: 0; font-size: 0.85rem; }
.state-inspector-panel li { margin-bottom: 0.3rem; }
.state-inspector-panel .var-name { color: #c0392b; font-weight: bold; }

/* Controls Footer */
.controls-footer { background-color: #ecf0f1; padding: 1rem; border-top: 1px solid #ccc; text-align: center; }
.controls-footer button { background-color: #7f8c8d; color: white; border: none; padding: 0.5rem 1rem; margin: 0 0.3rem; border-radius: 4px; cursor: pointer; }
.controls-footer button:hover { background-color: #566573; }
.controls-footer button:disabled { background-color: #bdc3c7; cursor: not-allowed; }
.controls-footer button.play { background-color: #2ecc71; }
.controls-footer button.play:hover { background-color: #27ae60; }
.controls-footer button.pause { background-color: #f39c12; }
.controls-footer button.pause:hover { background-color: #d35400; }

/* Basic styles for Heroicons if not using Tailwind */
.h-5 { height: 1.25rem; }
.w-5 { width: 1.25rem; }
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border-width: 0;
}
```

---
**`phoenix_scope_player/priv/static/favicon.ico`**:
(Placeholder - you would add an actual favicon file here)

---
**`phoenix_scope_player/priv/captured_data/sample_session_1/metadata.json`**:
```json
{
  "name": "Simple Calculation Demo",
  "description": "Traces a simple function call: MyDemo.Calculator.add(5, 3). Shows function entry, arguments, line execution, variable snapshot, and return value.",
  "timestamp": "2024-05-27T10:00:00Z"
}
```

---
**`phoenix_scope_player/priv/captured_data/sample_session_1/events.json`**:
```json
[
  {
    "id": "evt_001",
    "timestamp_ns": 1678886400100000000,
    "type": "FUNCTION_ENTRY",
    "ast_node_id": "MyDemo.Calculator:add:0",
    "data": {
      "module": "MyDemo.Calculator",
      "function": "add",
      "arity": 2,
      "args": [5, 3]
    }
  },
  {
    "id": "evt_002",
    "timestamp_ns": 1678886400100100000,
    "type": "LINE_EXECUTION",
    "ast_node_id": "MyDemo.Calculator:add:1",
    "data": {
      "module": "MyDemo.Calculator",
      "function": "add",
      "line": 3
    }
  },
  {
    "id": "evt_003",
    "timestamp_ns": 1678886400100200000,
    "type": "VAR_SNAPSHOT",
    "ast_node_id": "MyDemo.Calculator:add:2",
    "data": {
      "module": "MyDemo.Calculator",
      "function": "add",
      "line": 3,
      "variables": {"a": 5, "b": 3}
    }
  },
  {
    "id": "evt_004",
    "timestamp_ns": 1678886400100300000,
    "type": "EXPRESSION_VALUE",
    "ast_node_id": "MyDemo.Calculator:add:3",
    "data": {
      "module": "MyDemo.Calculator",
      "function": "add",
      "line": 4,
      "expression_source": "a + b",
      "value": 8
    }
  },
  {
    "id": "evt_005",
    "timestamp_ns": 1678886400100400000,
    "type": "VAR_SNAPSHOT",
    "ast_node_id": "MyDemo.Calculator:add:4",
    "data": {
      "module": "MyDemo.Calculator",
      "function": "add",
      "line": 4,
      "variables": {"a": 5, "b": 3, "result": 8}
    }
  },
  {
    "id": "evt_006",
    "timestamp_ns": 1678886400100500000,
    "type": "LINE_EXECUTION",
    "ast_node_id": "MyDemo.Calculator:add:5",
    "data": {
      "module": "MyDemo.Calculator",
      "function": "add",
      "line": 5
    }
  },
  {
    "id": "evt_007",
    "timestamp_ns": 1678886400100600000,
    "type": "FUNCTION_EXIT",
    "ast_node_id": "MyDemo.Calculator:add:0",
    "data": {
      "module": "MyDemo.Calculator",
      "function": "add",
      "arity": 2,
      "return_value": 8,
      "duration_ns": 600000
    }
  }
]
```

---
**`phoenix_scope_player/priv/captured_data/sample_session_1/source_code.json`**:
```json
{
  "MyDemo.Calculator": "defmodule MyDemo.Calculator do\n  @doc \"\"\"\n  Adds two numbers.\n  \"\"\"\n  def add(a, b) do\n    result = a + b\n    result\n  end\nend\n"
}
```

---
**`phoenix_scope_player/priv/captured_data/sample_session_1/ast_map.json`**:
```json
{
  "MyDemo.Calculator:add:0": { "file_path": "lib/my_demo/calculator.ex", "module": "MyDemo.Calculator", "function": "add", "line_start": 4, "line_end": 6 },
  "MyDemo.Calculator:add:1": { "file_path": "lib/my_demo/calculator.ex", "module": "MyDemo.Calculator", "function": "add", "line_start": 4, "line_end": 4 },
  "MyDemo.Calculator:add:2": { "file_path": "lib/my_demo/calculator.ex", "module": "MyDemo.Calculator", "function": "add", "line_start": 4, "line_end": 4 },
  "MyDemo.Calculator:add:3": { "file_path": "lib/my_demo/calculator.ex", "module": "MyDemo.Calculator", "function": "add", "line_start": 5, "line_end": 5 },
  "MyDemo.Calculator:add:4": { "file_path": "lib/my_demo/calculator.ex", "module": "MyDemo.Calculator", "function": "add", "line_start": 5, "line_end": 5 },
  "MyDemo.Calculator:add:5": { "file_path": "lib/my_demo/calculator.ex", "module": "MyDemo.Calculator", "function": "add", "line_start": 6, "line_end": 6 }
}
```

---
**`phoenix_scope_player/README.md`**:
(This will be the content from the prompt's "DESIGN SPEC: ..." section, formatted as a README)
```markdown
# PhoenixScopePlayer

**Version:** 0.1.0 (Sample Application)

## Purpose

`PhoenixScopePlayer` is a simple Phoenix-based UI sample application designed to demonstrate the playback of debugging information. This information is assumed to be captured by ElixirScope's compile-time instrumentation from another Elixir application.

## Core Concept

The `PhoenixScopePlayer` app simulates loading a pre-captured debugging "session". It then allows users to "play back" this session, visualizing the sequence of events, code execution flow, and variable states over time. This application serves as a *viewer/player* and is not a live debugger itself. It showcases how data captured by ElixirScope can be utilized for rich, offline debugging experiences.

## Features & UI Design

The application is centered around two main views for selecting and playing back debugging sessions.

### 1. Session Selection View (`/`)

*   **Purpose:** Allows the user to choose a pre-recorded debugging session to play back.
*   **Elements:**
    *   **Header:** "ElixirScope - Debug Session Playback"
    *   **List of available sessions:** Sourced from `priv/captured_data/`. Each session item displays:
        *   Session Name/ID (derived from directory name)
        *   Brief Description (e.g., "Execution of MyModule.calculate/2" - can be part of session metadata)
        *   Timestamp of capture (if available in metadata)
        *   Number of events in the session.
    *   A **"Load & Play" button** next to each session.
*   **Interaction:** Clicking "Load & Play" navigates to the Playback View for the selected session.

### 2. Playback View (`/session/:session_id/play`)

*   **Purpose:** The main interface for replaying and inspecting a selected debugging session.
*   **Layout:** A multi-panel layout.
    *   **Panel 1: Timeline & Controls (Top or Bottom Bar)**
        *   **Controls:**
            *   Play/Pause Button
            *   Step Forward Button (event by event)
            *   Step Backward Button (event by event)
            *   Go to Start Button
            *   Go to End Button
            *   (Optional) Playback Speed Control (e.g., 1x, 2x, 0.5x)
        *   **Timeline Display:**
            *   Simple textual display: "Event X / Y" (e.g., "Event 57 / 342")
            *   (Optional advanced: A visual slider or progress bar).
    *   **Panel 2: Event Log (Left or Main Panel)**
        *   **Content:** A chronological, scrollable list of captured events.
        *   **Each Event Item Displays:**
            *   Timestamp (relative or absolute)
            *   Event Type (e.g., `FUNCTION_ENTRY`, `LINE_EXECUTION`, `VAR_SNAPSHOT`, `EXPRESSION_VALUE`, `FUNCTION_EXIT`)
            *   Key Information (e.g., `MyModule.my_func/2`, `Line: 42`, `Var: x = 10`, `Expr: a + b => 15`)
            *   (Optional) AST Node ID (for debugging the player itself, perhaps hidden by default).
        *   **Interaction:** Clicking an event in the log seeks playback to that event, updating other panels. The currently active event is highlighted.
    *   **Panel 3: Code View (Right or Main Panel)**
        *   **Content:** Displays the source code of the module/function relevant to the current event.
        *   **Highlighting:** The line of code corresponding to the current event is highlighted.
        *   **Navigation:** If a function call event occurs, the Code View could switch to display the called function's source (if available in the pre-captured data).
    *   **Panel 4: State Inspector (Right Panel, below Code View or Tabbed)**
        *   **Variables Tab:**
            *   Displays local variables and their values as captured by `VAR_SNAPSHOT` events at the current timeline point.
            *   Format: `variable_name: value`.
        *   **Call Stack Tab (Simplified):**
            *   Displays a simplified call stack based on `FUNCTION_ENTRY` and `FUNCTION_EXIT` events.
            *   Format: List of `Module.function/arity`.
        *   **(Optional) Expression Values Tab:**
            *   Displays values of traced expressions if `EXPRESSION_VALUE` events are present.
            *   Format: `expression_source: value`.

### User Flow

1.  User visits the root URL (`/`).
2.  User sees the **Session Selection View**.
3.  User clicks "Load & Play" for a desired session.
4.  User is navigated to the **Playback View** (`/session/:session_id/play`).
5.  The Playback View loads the first event of the session. All panels (Code View, Event Log, State Inspector) populate accordingly.
6.  User interacts with timeline controls (Play, Pause, Step Forward, Step Backward, etc.).
7.  As the timeline progresses:
    *   The Event Log scrolls and highlights the current event.
    *   The Code View updates to show the relevant source code and highlights the current execution line.
    *   The State Inspector updates to show variable values and call stack information pertinent to that point in time.

### Simplicity Considerations

*   **Pre-recorded Data:** The application works with pre-recorded session data, not live debugging information.
*   **Read-Only Interface:** The UI is for playback and inspection only.
*   **Core Data Focus:** Prioritizes displaying function calls, line executions, and variable states.
*   **Minimalist Styling:** Emphasis on functional clarity over complex aesthetics.

## Technical Design & Architecture

This application is built using Phoenix and leverages Phoenix LiveView for its interactive UI components.

### Directory Structure

(Refer to the main generated output for the detailed directory structure.)

### Key Module Responsibilities

*   **`PhoenixScopePlayer.DataProvider`**:
    *   `list_sessions()`: Returns metadata for all sessions in `priv/captured_data/`.
    *   `get_session_data(session_id)`: Loads `events.json`, `source_code.json`, and `ast_map.json` for a given session.
    *   `get_source_for_module(session_data, module_name)`: Retrieves source for a module within a session.
    *   `get_ast_node_location(session_data, ast_node_id)`: Maps an AST Node ID to its source location.

*   **`PhoenixScopePlayer.PlaybackEngine` (GenServer)**:
    *   Manages the state for a single playback session (current event index, play/pause status).
    *   Handles playback controls: `play`, `pause`, `step_forward`, `step_backward`, `seek_to_event_index`.
    *   Calculates the current variable state and call stack based on events up to the current index.
    *   Notifies its parent LiveView (`PlaybackLive`) of state changes.

*   **`PhoenixScopePlayerWeb.SessionListLive` (LiveView)**:
    *   Uses `DataProvider.list_sessions()` to display available sessions.
    *   Handles "Load & Play" events to navigate to the `PlaybackLive` view.

*   **`PhoenixScopePlayerWeb.PlaybackLive` (LiveView - Main Playback UI)**:
    *   Mounts by starting a `PlaybackEngine` for the selected session.
    *   Loads initial data (first event, source code) via `DataProvider` and `PlaybackEngine`.
    *   Renders the multi-panel layout, passing data to child LiveView components.
    *   Handles timeline control events, sending commands to its `PlaybackEngine`.
    *   Receives updates from `PlaybackEngine` (`handle_info`) and updates its assigns to re-render UI panels.

*   **Child LiveView Components (e.g., `CodeViewLive`, `EventLogLive`, `StateInspectorLive`)**:
    *   Receive data (current event, code, variables, etc.) as assigns from `PlaybackLive`.
    *   Render their specific UI panel.
    *   `EventLogLive` can send "seek" events back to `PlaybackLive` when an event item is clicked.

## Data Format for Captured Sessions

The application expects pre-captured session data to be located in `priv/captured_data/`. Each session should be in its own subdirectory (e.g., `session_1`, `sample_session_1`).

Each session directory must contain the following JSON files:

*   **`metadata.json`** (Optional but Recommended):
    *   Contains metadata about the session.
    *   Example:
        ```json
        {
          "name": "Simple Function Execution",
          "description": "Traces the execution of MyDemoModule.calculate(5, 3).",
          "timestamp": "2023-10-27T10:30:00Z",
          "tags": ["demo", "calculation"]
        }
        ```

*   **`events.json`**:
    *   An array of event objects, chronologically ordered.
    *   Each event object structure should follow ElixirScope's captured event format, typically including:
        ```json
        {
          "id": "evt_unique_id_123",
          "timestamp_ns": 1678886400123456789,
          "type": "EVENT_TYPE_STRING",
          "ast_node_id": "node_abc_001", // Optional
          "data": { /* Event-specific data */ }
        }
        ```
    *   **Supported Event Types (examples):**
        *   `FUNCTION_ENTRY`: `data: {module, function, arity, args}`
        *   `FUNCTION_EXIT`: `data: {module, function, arity, return_value, duration_ns}`
        *   `LINE_EXECUTION`: `data: {module, function, line}`
        *   `VAR_SNAPSHOT`: `data: {module, function, line, variables: {name: value, ...}}`
        *   `EXPRESSION_VALUE`: `data: {module, function, line, expression_source, value}`

*   **`source_code.json`**:
    *   A JSON object mapping module names (as strings) to their full source code (as strings).
    *   Example:
        ```json
        {
          "MyModule": "defmodule MyModule do\n  # ... code ...\nend"
        }
        ```

*   **`ast_map.json`** (Optional, for enhanced source correlation):
    *   A JSON object mapping `ast_node_id` to their source location details.
    *   Example:
        ```json
        {
          "node_abc_001": {
            "file_path": "lib/my_module.ex",
            "module": "MyModule",
            "line_start": 10,
            "line_end": 12
          }
        }
        ```

## Setup & Running

This is a standard Phoenix application.

1.  **Navigate to the application directory:**
    ```bash
    cd path/to/elixir_scope/test_apps/phoenix_scope_player
    ```

2.  **Install Dependencies:**
    ```bash
    mix deps.get
    ```

3.  **Prepare Sample Data:**
    *   Ensure you have sample session data in `priv/captured_data/`.
    *   For example, create `priv/captured_data/sample_session_1/` and populate it with `events.json`, `source_code.json`, `metadata.json`, and `ast_map.json` as per the "Data Format" section. The repository includes an example `sample_session_1`.

4.  **Run Phoenix Server:**
    ```bash
    mix phx.server
    ```

5.  Open your browser and navigate to `http://localhost:4000`.

## Future Enhancements / Considerations

*   **Advanced Timeline:** A visual timeline slider for easier navigation.
*   **Search/Filter Events:** Ability to search or filter the event log.
*   **Performance Optimization:** For very large session files (e.g., lazy loading events).
```

This provides a foundational Phoenix application that can play back ElixirScope session data. Further refinements would involve more robust error handling, more sophisticated state calculation in `PlaybackEngine`, and richer UI interactions.
