defmodule PhoenixScopePlayerWeb.PlaybackLive do
  use PhoenixScopePlayerWeb, :live_view
  alias PhoenixScopePlayer.{DataProvider, PlaybackEngine}

  @impl true
  def mount(%{"id" => session_id}, _session, socket) do
    case DataProvider.get_session_data(session_id) do
      {:ok, session_data} ->
        {:ok, assign(socket,
          session_id: session_id,
          session_data: session_data,
          current_event: nil,
          current_event_index: 0
        )}
      
      {:error, :not_found} ->
        {:ok, socket
        |> put_flash(:error, "Session not found")
        |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      <div class="px-4 py-6 sm:px-0">
        <h1 class="text-2xl font-semibold text-gray-900">Debug Session Playback</h1>
        <div class="mt-6">
          <p>Session ID: <%= @session_id %></p>
          <p>Event Count: <%= length(@session_data.events) %></p>
        </div>
      </div>
    </div>
    """
  end
end 