defmodule PhoenixScopePlayerWeb.SessionListLive do
  use PhoenixScopePlayerWeb, :live_view
  alias PhoenixScopePlayer.DataProvider

  @impl true
  def mount(_params, _session, socket) do
    sessions = DataProvider.list_sessions()
    {:ok, assign(socket, sessions: sessions)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      <div class="px-4 py-6 sm:px-0">
        <h1 class="text-2xl font-semibold text-gray-900">Debug Sessions</h1>
        
        <div class="mt-6 grid gap-5 max-w-lg mx-auto lg:grid-cols-3 lg:max-w-none">
          <%= for session <- @sessions do %>
            <div class="flex flex-col rounded-lg shadow-lg overflow-hidden">
              <div class="flex-1 bg-white p-6 flex flex-col justify-between">
                <div class="flex-1">
                  <p class="text-sm font-medium text-indigo-600">
                    <%= session.trigger %>
                  </p>
                  <div class="block mt-2">
                    <p class="text-xl font-semibold text-gray-900">
                      <%= session.name %>
                    </p>
                    <p class="mt-3 text-base text-gray-500">
                      <%= session.description %>
                    </p>
                  </div>
                </div>
                <div class="mt-6 flex items-center">
                  <div class="flex-shrink-0">
                    <span class="text-sm font-medium text-gray-500">
                      <%= session.event_count %> events
                    </span>
                  </div>
                  <div class="ml-auto">
                    <.link
                      navigate={~p"/sessions/#{session.id}"}
                      class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700"
                    >
                      View Session
                    </.link>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end 