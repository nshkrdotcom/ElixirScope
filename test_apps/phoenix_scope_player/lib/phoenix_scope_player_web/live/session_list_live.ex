defmodule PhoenixScopePlayerWeb.SessionListLive do
  use PhoenixScopePlayerWeb, :live_view
  alias PhoenixScopePlayer.DataProvider

  def mount(_params, _session, socket) do
    sessions = DataProvider.list_sessions()
    {:ok, assign(socket, sessions: sessions)}
  end

  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-base font-semibold leading-6 text-gray-900">Debug Sessions</h1>
          <p class="mt-2 text-sm text-gray-700">A list of all available debug sessions for playback.</p>
        </div>
      </div>
      <div class="mt-8 flow-root">
        <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
          <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
            <%= if @sessions == [] do %>
              <div class="text-center py-12">
                <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
                <h3 class="mt-2 text-sm font-medium text-gray-900">No debug sessions</h3>
                <p class="mt-1 text-sm text-gray-500">No debug sessions have been captured yet.</p>
              </div>
            <% else %>
              <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 sm:rounded-lg">
                <table class="min-w-full divide-y divide-gray-300">
                  <thead class="bg-gray-50">
                    <tr>
                      <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6">Session Name</th>
                      <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Date</th>
                      <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Description</th>
                      <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-6">
                        <span class="sr-only">View</span>
                      </th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-200 bg-white">
                    <%= for session <- @sessions do %>
                      <tr class="group hover:bg-gray-50 cursor-pointer" phx-click={JS.navigate(~p"/sessions/#{session["id"]}")}>
                        <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6"><%= session["name"] %></td>
                        <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500"><%= session["date"] %></td>
                        <td class="px-3 py-4 text-sm text-gray-500 max-w-md truncate"><%= session["description"] %></td>
                        <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                          <span class="text-indigo-600 group-hover:text-indigo-900">View<span class="sr-only">, <%= session["name"] %></span></span>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end 