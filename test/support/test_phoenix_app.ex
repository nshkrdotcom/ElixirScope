# Mock User schema
defmodule User do
  defstruct [:id, :name, :email]
end

defmodule TestPhoenixApp do
  @moduledoc """
  Test Phoenix application for validating ElixirScope integration.
  """

  use Application

  def start(_type, _args) do
    children = [
      TestPhoenixApp.Repo,
      TestPhoenixApp.Endpoint,
      {Phoenix.PubSub, name: TestPhoenixApp.PubSub}
    ]

    opts = [strategy: :one_for_one, name: TestPhoenixApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def start_link(opts \\ []) do
    start(:normal, opts)
  end
end

# Mock Repo for testing
defmodule TestPhoenixApp.Repo do
  def start_link(_opts) do
    # Mock repo that doesn't actually start a database
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def get!(User, id) do
    if id == "nonexistent", do: raise("Not found"), else: %User{id: id, name: "Test User #{id}"}
  end

  def insert(%User{}, _params) do
    {:ok, %User{id: "123", name: "New User"}}
  end

  def all(User) do
    [%User{id: "1", name: "User 1"}, %User{id: "2", name: "User 2"}]
  end

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[]]},
      type: :worker
    }
  end
end

# Mock Endpoint
defmodule TestPhoenixApp.Endpoint do
  # Don't use Phoenix.Endpoint to avoid conflicts - just create a simple mock
  def start_link(_opts \\ []) do
    # Mock endpoint
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end
  
  def init(_key, config) do
    {:ok, config}
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker
    }
  end
end

# Test Socket for Channel tests
defmodule TestSocket do
  def connect(_params, _socket) do
    {:ok, %{}}
  end
end

defmodule TestPhoenixApp.Router do
  use Phoenix.Router
  import Phoenix.Controller
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
  end

  scope "/", TestPhoenixApp do
    pipe_through :browser

    get "/users/:id", UserController, :show
    post "/users", UserController, :create
    get "/users/nonexistent", UserController, :error_test

    live "/live/counter", CounterLive
    live "/live/users", UsersLive
  end
end

defmodule TestPhoenixApp.UserController do
  use Phoenix.Controller, namespace: TestPhoenixApp
  import Plug.Conn

  def show(conn, %{"id" => id}) do
    # Simulate database lookup that will be traced
    user = TestPhoenixApp.Repo.get!(User, id)
    send_resp(conn, 200, "User: #{user.name}")
  end

  def create(conn, %{"user" => user_params}) do
    # Simulate user creation with validation
    {:ok, user} = TestPhoenixApp.Repo.insert(%User{}, user_params)
    send_resp(conn, 200, "Created: #{user.name}")
  end

  def error_test(_conn, _params) do
    # Intentionally cause error for testing
    raise "Test error for ElixirScope tracing"
  end
end

defmodule TestPhoenixApp.CounterLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, assign(socket, count: 0)}
  end

  def handle_event("increment", _params, socket) do
    new_count = socket.assigns.count + 1
    {:noreply, assign(socket, count: new_count)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <p>Count: <%= @count %></p>
      <button phx-click="increment">Increment</button>
    </div>
    """
  end
end

defmodule TestPhoenixApp.UsersLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, assign(socket, users: [])}
  end

  def handle_event("load_users", _params, socket) do
    # This will trigger Ecto queries that should be correlated
    users = TestPhoenixApp.Repo.all(User)
    {:noreply, assign(socket, users: users)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <button phx-click="load_users">Load Users</button>
      <%= for user <- @users do %>
        <p><%= user.name %></p>
      <% end %>
    </div>
    """
  end
end
