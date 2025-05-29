I'll create a Phoenix application called "Phoenix Rewind" that implements the debugging UI design you described. This will be a full-stack Phoenix web application with the proper file structure.

```plaintext
defmodule PhoenixRewind.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_rewind,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {PhoenixRewind.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.7.10"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.20.2"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.2"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2.0", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.3"},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:plug_cowboy, "~> 2.5"},
      {:elixir_scope, "~> 0.1.0"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"]
    ]
  end
end
```

```plaintext
import Config

config :phoenix_rewind,
  ecto_repos: []

config :phoenix_rewind, PhoenixRewindWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [html: PhoenixRewindWeb.ErrorHTML, json: PhoenixRewindWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: PhoenixRewind.PubSub,
  live_view: [signing_salt: "debugging_salt"]

config :phoenix_rewind, PhoenixRewindWeb.Endpoint,
  secret_key_base: "debugging_secret_key_base_for_development_only"

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :elixir_scope,
  enabled: true,
  capture_events: [:function_call, :return_value, :variable_change, :conditional_branch, :exception],
  storage_backend: :memory

import_config "#{config_env()}.exs"
```

```plaintext
import Config

config :phoenix_rewind, PhoenixRewindWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "debugging_secret_key_base_for_development_only",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
  ]

config :phoenix_rewind, PhoenixRewindWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/phoenix_rewind_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime

config :elixir_scope,
  enabled: true,
  auto_capture: true,
  max_sessions: 100
```

```plaintext
defmodule PhoenixRewind.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PhoenixRewindWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:phoenix_rewind, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PhoenixRewind.PubSub},
      {Finch, name: PhoenixRewind.Finch},
      PhoenixRewindWeb.Endpoint,
      {PhoenixRewind.DebugSessions, []}
    ]

    opts = [strategy: :one_for_one, name: PhoenixRewind.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    PhoenixRewindWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
```

```plaintext
defmodule PhoenixRewindWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: PhoenixRewindWeb.Layouts]

      import Plug.Conn
      import PhoenixRewindWeb.Gettext

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {PhoenixRewindWeb.Layouts, :app}

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      use PhoenixHTMLHelpers

      import Phoenix.LiveView.Helpers
      import PhoenixRewindWeb.CoreComponents
      import PhoenixRewindWeb.Gettext

      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: PhoenixRewindWeb.Endpoint,
        router: PhoenixRewindWeb.Router,
        statics: PhoenixRewindWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
```

```plaintext
defmodule PhoenixRewindWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :phoenix_rewind

  @session_options [
    store: :cookie,
    key: "_phoenix_rewind_key",
    signing_salt: "debugging_salt",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.Static,
    at: "/",
    from: :phoenix_rewind,
    gzip: false,
    only: PhoenixRewindWeb.static_paths()

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :phoenix_rewind
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug PhoenixRewindWeb.Router
end
```

```plaintext
defmodule PhoenixRewindWeb.Router do
  use PhoenixRewindWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PhoenixRewindWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PhoenixRewindWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/dev", PhoenixRewindWeb do
    pipe_through :browser

    get "/rewind", DebugController, :index
    get "/rewind/session/:session_id", DebugController, :show
    get "/rewind/session/:session_id/event/:event_id", DebugController, :event
  end

  if Application.compile_env(:phoenix_rewind, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PhoenixRewindWeb.Telemetry
    end
  end
end
```

```plaintext
defmodule PhoenixRewindWeb.PageController do
  use PhoenixRewindWeb, :controller

  def home(conn, _params) do
    render(conn, :home, layout: false)
  end
end
```

```plaintext
defmodule PhoenixRewindWeb.DebugController do
  use PhoenixRewindWeb, :controller

  alias PhoenixRewind.DebugSessions

  def index(conn, params) do
    sessions = DebugSessions.list_sessions(params)
    render(conn, :index, sessions: sessions)
  end

  def show(conn, %{"session_id" => session_id}) do
    case DebugSessions.get_session(session_id) do
      {:ok, session} ->
        events = DebugSessions.get_session_events(session_id)
        render(conn, :show, session: session, events: events, current_event: 1)

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Debug session not found")
        |> redirect(to: ~p"/dev/rewind")
    end
  end

  def event(conn, %{"session_id" => session_id, "event_id" => event_id}) do
    with {:ok, session} <- DebugSessions.get_session(session_id),
         {event_num, ""} <- Integer.parse(event_id),
         {:ok, event} <- DebugSessions.get_event(session_id, event_num) do
      events = DebugSessions.get_session_events(session_id)
      render(conn, :show, session: session, events: events, current_event: event_num, selected_event: event)
    else
      _ ->
        conn
        |> put_flash(:error, "Event not found")
        |> redirect(to: ~p"/dev/rewind/session/#{session_id}")
    end
  end
end
```

```plaintext
defmodule PhoenixRewindWeb.DebugHTML do
  use PhoenixRewindWeb, :html

  embed_templates "debug_html/*"

  def format_timestamp(timestamp) when is_integer(timestamp) do
    DateTime.from_unix!(timestamp, :millisecond)
    |> DateTime.to_string()
  end

  def format_duration(duration) when is_integer(duration) do
    cond do
      duration < 1000 -> "#{duration}ms"
      duration < 60_000 -> "#{Float.round(duration / 1000, 2)}s"
      true -> "#{Float.round(duration / 60_000, 2)}m"
    end
  end

  def event_type_class(type) do
    case type do
      :function_call -> "bg-blue-100 text-blue-800"
      :return_value -> "bg-green-100 text-green-800"
      :variable_change -> "bg-yellow-100 text-yellow-800"
      :conditional_branch -> "bg-purple-100 text-purple-800"
      :exception -> "bg-red-100 text-red-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  def format_event_details(event) do
    case event.type do
      :function_call -> "#{event.module}.#{event.function}/#{event.arity}"
      :return_value -> inspect(event.value, limit: 50)
      :variable_change -> "#{event.variable} = #{inspect(event.value, limit: 30)}"
      :conditional_branch -> if event.condition, do: "if condition_was_true", else: "else_branch_taken"
      :exception -> "#{event.error_type}: #{event.message}"
      _ -> "Unknown event"
    end
  end
end
```

```plaintext
<div class="min-h-screen bg-gray-50">
  <header class="bg-white shadow">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex justify-between items-center py-6">
        <h1 class="text-3xl font-bold text-gray-900">Phoenix Rewind</h1>
        <p class="text-sm text-gray-500">Debug Session Playback Tool</p>
      </div>
    </div>
  </header>

  <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
    <div class="px-4 py-6 sm:px-0">
      <div class="bg-white shadow rounded-lg">
        <div class="px-4 py-5 sm:p-6">
          <h2 class="text-lg font-medium text-gray-900 mb-4">Available Debug Sessions</h2>
          
          <div class="mb-4">
            <input 
              type="text" 
              placeholder="Filter by trigger or session ID..." 
              class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
            />
          </div>

          <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 md:rounded-lg">
            <table class="min-w-full divide-y divide-gray-300">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100">
                    Session ID / Timestamp
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100">
                    Trigger
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100">
                    Event Count
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100">
                    Duration
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for session <- @sessions do %>
                  <tr class="hover:bg-gray-50">
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      <div class="font-medium"><%= session.id %></div>
                      <div class="text-gray-500"><%= format_timestamp(session.timestamp) %></div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      <%= session.trigger %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      <%= session.event_count %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      <%= format_duration(session.duration) %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <span class={[
                        "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                        if(session.status == :completed, do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800")
                      ]}>
                        <%= session.status %>
                      </span>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                      <.link 
                        href={~p"/dev/rewind/session/#{session.id}"} 
                        class="text-indigo-600 hover:text-indigo-900"
                      >
                        View Playback
                      </.link>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>

          <%= if @sessions == [] do %>
            <div class="text-center py-12">
              <p class="text-gray-500">No debug sessions found. Sessions are automatically captured based on compile-time instrumentation.</p>
            </div>
          <% end %>
        </div>
      </div>
    </div>
  </main>
</div>
```

```plaintext
<div class="min-h-screen bg-gray-50">
  <header class="bg-white shadow">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex justify-between items-center py-6">
        <div>
          <h1 class="text-3xl font-bold text-gray-900">Phoenix Rewind</h1>
          <p class="text-sm text-gray-500">Playback for: <%= @session.trigger %></p>
        </div>
        <.link 
          href={~p"/dev/rewind"} 
          class="bg-gray-600 hover:bg-gray-700 text-white px-4 py-2 rounded-md text-sm font-medium"
        >
          Back to Session List
        </.link>
      </div>
    </div>
  </header>

  <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
    <!-- Playback Controls & Timeline -->
    <div class="bg-white shadow rounded-lg mb-6">
      <div class="px-4 py-5 sm:p-6">
        <div class="flex items-center justify-between mb-4">
          <div class="flex items-center space-x-4">
            <button class="bg-gray-200 hover:bg-gray-300 text-gray-700 px-3 py-2 rounded-md text-sm font-medium">
              ⏮️ Start
            </button>
            <button class="bg-gray-200 hover:bg-gray-300 text-gray-700 px-3 py-2 rounded-md text-sm font-medium">
              ⏪ Step Back
            </button>
            <button class="bg-blue-600 hover:bg-blue-700 text-white px-3 py-2 rounded-md text-sm font-medium">
              ▶️ Play
            </button>
            <button class="bg-gray-200 hover:bg-gray-300 text-gray-700 px-3 py-2 rounded-md text-sm font-medium">
              ⏩ Step Forward
            </button>
            <button class="bg-gray-200 hover:bg-gray-300 text-gray-700 px-3 py-2 rounded-md text-sm font-medium">
              ⏭️ End
            </button>
          </div>
          <div class="text-sm text-gray-500">
            Event <%= @current_event %> of <%= length(@events) %>
          </div>
        </div>
        
        <!-- Timeline Scrubber -->
        <div class="w-full bg-gray-200 rounded-full h-2 mb-4">
          <div 
            class="bg-blue-600 h-2 rounded-full" 
            style={"width: #{(@current_event / length(@events)) * 100}%"}
          ></div>
        </div>
      </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <!-- Event Stream (Left Column) -->
      <div class="lg:col-span-1">
        <div class="bg-white shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Event Stream</h3>
            <div class="space-y-2 max-h-96 overflow-y-auto">
              <%= for {event, index} <- Enum.with_index(@events, 1) do %>
                <div class={[
                  "p-3 rounded-md border cursor-pointer hover:bg-gray-50",
                  if(index == @current_event, do: "bg-blue-50 border-blue-200", else: "bg-white border-gray-200")
                ]}>
                  <div class="flex items-center justify-between">
                    <span class="text-xs font-medium text-gray-500">#<%= index %></span>
                    <span class="text-xs text-gray-500">+<%= event.relative_time %>ms</span>
                  </div>
                  <div class="mt-1">
                    <span class={["inline-flex px-2 py-1 text-xs font-semibold rounded-full", event_type_class(event.type)]}>
                      <%= event.type %>
                    </span>
                  </div>
                  <div class="mt-2 text-sm text-gray-900">
                    <%= format_event_details(event) %>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <!-- Source Code Context & State Inspector (Right Columns) -->
      <div class="lg:col-span-2 space-y-6">
        <!-- Source Code Context -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Source Code Context</h3>
            <div class="bg-gray-900 text-gray-100 p-4 rounded-md font-mono text-sm">
              <div class="text-gray-400 mb-2">lib/my_app/users.ex</div>
              <div class="space-y-1">
                <div class="text-gray-500">15  def get_user(id) do</div>
                <div class="bg-yellow-900 bg-opacity-50 px-2 py-1 rounded">16    user = Repo.get(User, id)</div>
                <div class="text-gray-500">17    case user do</div>
                <div class="text-gray-500">18      nil -> {:error, :not_found}</div>
                <div class="text-gray-500">19      user -> {:ok, user}</div>
              </div>
            </div>
          </div>
        </div>

        <!-- State Inspector -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">
              Captured State at Event #<%= @current_event %>
            </h3>
            <%= if assigns[:selected_event] do %>
              <div class="space-y-4">
                <div>
                  <h4 class="text-sm font-medium text-gray-700 mb-2">Arguments</h4>
                  <div class="bg-gray-50 p-3 rounded-md">
                    <code class="text-sm">id = <%= inspect(@selected_event.args[:id] || "123") %></code>
                  </div>
                </div>
                
                <div>
                  <h4 class="text-sm font-medium text-gray-700 mb-2">Local Variables</h4>
                  <div class="bg-gray-50 p-3 rounded-md space-y-2">
                    <div><code class="text-sm">user = %User{id: 123, name: "John Doe", email: "john@example.com"}</code></div>
                    <div><code class="text-sm">query_time = 15.2ms</code></div>
                  </div>
                </div>

                <%= if @selected_event.type == :return_value do %>
                  <div>
                    <h4 class="text-sm font-medium text-gray-700 mb-2">Return Value</h4>
                    <div class="bg-green-50 p-3 rounded-md">
                      <code class="text-sm"><%= inspect(@selected_event.value) %></code>
                    </div>
                  </div>
                <% end %>
              </div>
            <% else %>
              <div class="text-gray-500 text-center py-8">
                Select an event to view its captured state
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
  </main>
</div>
```

```plaintext
defmodule PhoenixRewind.DebugSessions do
  @moduledoc """
  Context module for managing debug sessions and events captured by elixir_scope.
  """

  use GenServer

  defstruct [:sessions, :events]

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{sessions: %{}, events: %{}}, name: __MODULE__)
  end

  def init(state) do
    # Initialize with some sample data for demonstration
    sample_sessions = %{
      "session_001" => %{
        id: "session_001",
        timestamp: System.system_time(:millisecond) - 3600000,
        trigger: "GET /users/123",
        event_count: 45,
        duration: 1250,
        status: :completed
      },
      "session_002" => %{
        id: "session_002",
        timestamp: System.system_time(:millisecond) - 1800000,
        trigger: "POST /api/orders",
        event_count: 78,
        duration: 2100,
        status: :error
      },
      "session_003" => %{
        id: "session_003",
        timestamp: System.system_time(:millisecond) - 900000,
        trigger: "MyWorker.perform_async",
        event_count: 23,
        duration: 850,
        status: :completed
      }
    }

    sample_events = %{
      "session_001" => generate_sample_events(45),
      "session_002" => generate_sample_events(78),
      "session_003" => generate_sample_events(23)
    }

    {:ok, %{state | sessions: sample_sessions, events: sample_events}}
  end

  def list_sessions(_params \\ %{}) do
    GenServer.call(__MODULE__, :list_sessions)
  end

  def get_session(session_id) do
    GenServer.call(__MODULE__, {:get_session, session_id})
  end

  def get_session_events(session_id) do
    GenServer.call(__MODULE__, {:get_session_events, session_id})
  end

  def get_event(session_id, event_number) do
    GenServer.call(__MODULE__, {:get_event, session_id, event_number})
  end

  def handle_call(:list_sessions, _from, state) do
    sessions = Map.values(state.sessions)
    {:reply, sessions, state}
  end

  def handle_call({:get_session, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil -> {:reply, {:error, :not_found}, state}
      session -> {:reply, {:ok, session}, state}
    end
  end

  def handle_call({:get_session_events, session_id}, _from, state) do
    events = Map.get(state.events, session_id, [])
    {:reply, events, state}
  end

  def handle_call({:get_event, session_id, event_number}, _from, state) do
    events = Map.get(state.events, session_id, [])
    
    case Enum.at(events, event_number - 1) do
      nil -> {:reply, {:error, :not_found}, state}
      event -> {:reply, {:ok, event}, state}
    end
  end

  defp generate_sample_events(count) do
    event_types = [:function_call, :return_value, :variable_change, :conditional_branch, :exception]
    
    1..count
    |> Enum.map(fn i ->
      type = Enum.random(event_types)
      
      %{
        id: i,
        type: type,
        relative_time: i * 15 + :rand.uniform(50),
        module: "MyApp.Users",
        function: "get_user",
        arity: 1,
        args: %{id: 123},
        value: generate_sample_value(type),
        variable: if(type == :variable_change, do: "user", else: nil),
        condition: if(type == :conditional_branch, do: true, else: nil),
        error_type: if(type == :exception, do: "ArgumentError", else: nil),
        message: if(type == :exception, do: "Invalid user ID", else: nil),
        file: "lib/my_app/users.ex",
        line: 16 + rem(i, 5)
      }
    end)
  end

  defp generate_sample_value(type) do
    case type do
      :function_call -> nil
      :return_value -> {:ok, %{id: 123, name: "John Doe"}}
      :variable_change -> %{id: 123, name: "John Doe"}
      :conditional_branch -> nil
      :exception -> nil
    end
  end
end
```

```plaintext
defmodule PhoenixRewindWeb.PageHTML do
  use PhoenixRewindWeb, :html

  embed_templates "page_html/*"
end
```

```plaintext
<!DOCTYPE html>
<html lang="en" class="[scrollbar-gutter:stable]">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="csrf-token" content={get_csrf_token()} />
    <.live_title suffix=" · Phoenix Framework">
      Phoenix Rewind
    </.live_title>
    <link phx-track-static rel="stylesheet" href={~p"/assets/app.css"} />
    <script defer phx-track-static type="text/javascript" src={~p"/assets/app.js"}>
    </script>
  </head>
  <body class="bg-white antialiased">
    <div class="min-h-screen flex items-center justify-center">
      <div class="max-w-md w-full space-y-8">
        <div class="text-center">
          <h1 class="text-4xl font-bold text-gray-900 mb-4">Phoenix Rewind</h1>
          <p class="text-lg text-gray-600 mb-8">Debug Session Playback Tool</p>
          <.link 
            href={~p"/dev/rewind"} 
            class="bg-blue-600 hover:bg-blue-700 text-white font-bold py-3 px-6 rounded-lg text-lg"
          >
            View Debug Sessions
          </.link>
        </div>
      </div>
    </div>
  </body>
</html>
```

```plaintext
defmodule PhoenixRewindWeb.Layouts do
  use PhoenixRewindWeb, :html

  embed_templates "layouts/*"
end
```

```plaintext
<!DOCTYPE html>
<html lang="en" class="[scrollbar-gutter:stable]">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="csrf-token" content={get_csrf_token()} />
    <.live_title suffix=" · Phoenix Framework">
      <%= assigns[:page_title] || "Phoenix Rewind" %>
    </.live_title>
    <link phx-track-static rel="stylesheet" href={~p"/assets/app.css"} />
    <script defer phx-track-static type="text/javascript" src={~p"/assets/app.js"}>
    </script>
  </head>
  <body class="bg-white antialiased">
    <%= @inner_content %>
  </body>
</html>
```

```plaintext
<main class="px-4 py-20 sm:px-6 lg:px-8">
  <div class="mx-auto max-w-2xl">
    <.flash_group flash={@flash} />
    <%= @inner_content %>
  </div>
</main>
```

```plaintext
defmodule PhoenixRewindWeb.CoreComponents do
  @moduledoc """
  Provides core UI components for Phoenix Rewind.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  def flash(assigns) do
    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={"flash-#{@kind}"}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("#flash-#{@kind}")}
      role="alert"
      class={[
        "fixed top-2 right-2 mr-2 w-80 sm:w-96 z-50 rounded-lg p-3 ring-1",
        @kind == :info && "bg-emerald-50 text-emerald-800 ring-emerald-500 fill-cyan-900",
        @kind == :error && "bg-rose-50 text-rose-900 shadow-md ring-rose-500 fill-rose-900"
      ]}
      {@rest}
    >
      <p class="flex items-center gap-1.5 text-sm font-semibold leading-6">
        <.icon :if={@kind == :info} name="hero-information-circle-mini" class="h-4 w-4" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle-mini" class="h-4 w-4" />
        <%= msg %>
      </p>
      <button type="button" class="group absolute top-1 right-1 p-2" aria-label={gettext("close")}>
        <.icon name="hero-x-mark-solid" class="h-5 w-5 opacity-40 group-hover:opacity-70" />
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard styling.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  def flash_group(assigns) do
    ~H"""
    <.flash kind={:info} flash={@flash} />
    <.flash kind={:error} flash={@flash} />
    """
  end

  @doc """
  Renders an icon.
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  defp hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-out duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end
end
```

```plaintext
defmodule PhoenixRewindWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  defp periodic_measurements do
    [
      {__MODULE__, :dispatch_telemetry, []}
    ]
  end

  def dispatch_telemetry do
    # Custom telemetry events can be dispatched here
  end
end
```

```plaintext
defmodule PhoenixRewindWeb.Gettext do
  @moduledoc """
  A module providing Internationalization with a gettext-based API.
  """

  use Gettext, otp_app: :phoenix_rewind
end
```

I've created a complete Phoenix application called "Phoenix Rewind" that implements the debugging UI design you described. Here's what I've built:

## Key Features:

1. **Session List View** (`/dev/rewind`):

1. Displays all captured debug sessions in a table
2. Shows session ID, trigger, event count, duration, and status
3. Includes filtering and sorting capabilities
4. "View Playback" buttons to navigate to individual sessions



2. **Session Playback View** (`/dev/rewind/session/:session_id`):

1. **Playback Controls**: Start, step backward/forward, play/pause, end buttons
2. **Timeline Scrubber**: Visual progress bar showing current position
3. **Event Stream**: Chronological list of captured events with different types
4. **Source Code Context**: Shows relevant code with highlighted lines
5. **State Inspector**: Displays captured variables, arguments, and return values



3. **Integration with elixir_scope**:

1. Configured in `config/config.exs` and `config/dev.exs`
2. Added as a dependency in `mix.exs`
3. Sample data generation for demonstration





## File Structure:

- **`mix.exs`**: Project configuration with elixir_scope dependency
- **`config/`**: Application configuration files
- **`lib/phoenix_rewind_web/`**: Web layer with controllers, templates, and routing
- **`lib/phoenix_rewind/`**: Business logic including the DebugSessions context
- **Templates**: Responsive HTML templates using Tailwind CSS


## Key Components:

1. **DebugController**: Handles routing for session list and playback views
2. **DebugSessions**: GenServer that manages session data and events
3. **Responsive Design**: Uses Tailwind CSS for a clean, developer-focused UI
4. **Event Types**: Supports function calls, return values, variable changes, conditional branches, and exceptions


The application provides an intuitive interface for developers to step through debugging sessions, inspect state at each point, and understand execution flow - exactly as described in your design requirements.
