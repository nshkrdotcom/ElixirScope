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
  use Phoenix.Controller

  def show(conn, %{"id" => id}) do
    # Simulate database lookup that will be traced
    user = TestPhoenixApp.Repo.get!(User, id)
    render(conn, "show.html", user: user)
  end

  def create(conn, %{"user" => user_params}) do
    # Simulate user creation with validation
    case TestPhoenixApp.Repo.insert(%User{}, user_params) do
      {:ok, user} ->
        render(conn, "show.html", user: user)
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def error_test(conn, _params) do
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
