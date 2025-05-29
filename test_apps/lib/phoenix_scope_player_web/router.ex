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

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PhoenixScopePlayerWeb do
    pipe_through :browser

    live "/", SessionListLive
    live "/sessions/:id", PlaybackLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", PhoenixScopePlayerWeb do
  #   pipe_through :api
  # end
end 