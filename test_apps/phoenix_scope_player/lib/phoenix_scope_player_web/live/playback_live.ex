defmodule PhoenixScopePlayerWeb.PlaybackLive do
  use PhoenixScopePlayerWeb, :live_view
  alias PhoenixScopePlayer.DataProvider
  require Logger

  def mount(%{"id" => session_id}, _session, socket) do
    Logger.info("Mounting PlaybackLive with session_id: #{session_id}")
    
    case DataProvider.get_session_data(session_id) do
      {:ok, session_data} ->
        Logger.info("Got session data: #{inspect(session_data, pretty: true)}")
        events = session_data["events"] || []
        current_event = List.first(events)
        
        Logger.info("Events count: #{length(events)}")
        Logger.info("First event: #{inspect(current_event)}")

        {:ok, assign(socket,
          session_id: session_id,
          session_data: session_data,
          current_event_index: 0,
          current_event: current_event,
          total_events: length(events),
          current_file: nil,
          current_file_content: nil,
          show_instrumentation: false
        )}
      
      {:error, :not_found} ->
        Logger.error("Session not found: #{session_id}")
        {:ok, socket
        |> put_flash(:error, "Session not found")
        |> redirect(to: ~p"/")}
    end
  end

  def handle_event("next_event", _, socket) do
    %{current_event_index: index, session_data: data} = socket.assigns
    events = data["events"] || []
    next_index = min(index + 1, length(events) - 1)
    
    Logger.info("Moving to next event: #{next_index} of #{length(events)}")
    
    {:noreply, assign(socket,
      current_event_index: next_index,
      current_event: Enum.at(events, next_index)
    )}
  end

  def handle_event("prev_event", _, socket) do
    %{current_event_index: index, session_data: data} = socket.assigns
    events = data["events"] || []
    prev_index = max(index - 1, 0)
    
    Logger.info("Moving to previous event: #{prev_index} of #{length(events)}")
    
    {:noreply, assign(socket,
      current_event_index: prev_index,
      current_event: Enum.at(events, prev_index)
    )}
  end

  def handle_event("toggle_instrumentation", _, socket) do
    {:noreply, assign(socket, show_instrumentation: !socket.assigns.show_instrumentation)}
  end

  def handle_event("select_file", %{"file" => file}, socket) do
    Logger.info("Selecting file: #{file}")
    content = get_in(socket.assigns.session_data, ["source_code", "files", file, "content"])
    Logger.info("Got content: #{inspect(String.slice(content || "", 0..100))}...")
    
    {:noreply, assign(socket,
      current_file: file,
      current_file_content: content
    )}
  end

  def render(assigns) do
    ~H"""
    <div class="px-4 sm:px-6 lg:px-8">
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-base font-semibold leading-6 text-gray-900">Session Playback</h1>
          <p class="mt-2 text-sm text-gray-700">
            <%= @session_data["metadata"]["name"] %>
          </p>
        </div>
        <div class="mt-4 sm:ml-16 sm:mt-0">
          <button
            type="button"
            class="rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white hover:bg-indigo-500"
            phx-click="toggle_instrumentation"
          >
            <%= if @show_instrumentation, do: "Hide", else: "Show" %> Instrumentation
          </button>
        </div>
      </div>

      <div class="mt-8 flow-root">
        <div class="flex items-center space-x-3">
          <button
            type="button"
            class="inline-flex items-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
            phx-click="prev_event"
            disabled={@current_event_index == 0}
          >
            <svg class="h-5 w-5 text-gray-400" viewBox="0 0 20 20" fill="currentColor">
              <path d="M12.707 5.293a1 1 0 010 1.414L9.414 10l3.293 3.293a1 1 0 01-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z" />
            </svg>
            Previous
          </button>
          <button
            type="button"
            class="inline-flex items-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
            phx-click="next_event"
            disabled={@current_event_index == @total_events - 1}
          >
            Next
            <svg class="h-5 w-5 text-gray-400" viewBox="0 0 20 20" fill="currentColor">
              <path d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" />
            </svg>
          </button>
        </div>
        <div class="text-sm text-gray-500">
          Event <%= @current_event_index + 1 %> of <%= @total_events %>
        </div>

        <div class="mt-4 grid grid-cols-1 gap-4 lg:grid-cols-2">
          <div class="rounded-lg border border-gray-300 bg-white shadow">
            <div class="px-4 py-5 sm:p-6">
              <h3 class="text-base font-semibold leading-6 text-gray-900">Source Code</h3>
              <div class="mt-2">
                <div class="flex space-x-2 mb-2">
                  <%= for {file, _} <- get_in(@session_data, ["source_code", "files"]) || %{} do %>
                    <button
                      type="button"
                      class={"px-2 py-1 text-sm rounded #{if @current_file == file, do: "bg-indigo-600 text-white", else: "bg-gray-100 text-gray-700 hover:bg-gray-200"}"}
                      phx-click="select_file"
                      phx-value-file={file}
                    >
                      <%= file |> String.split(".") |> List.last() |> String.capitalize() %>
                    </button>
                  <% end %>
                </div>
                <pre class="mt-1 overflow-auto rounded-md bg-gray-900 p-4 text-sm text-gray-300">
                  <code class="language-elixir"><%= @current_file_content || "Select a file to view its source code" %></code>
                </pre>
              </div>
            </div>
          </div>

          <div class="rounded-lg border border-gray-300 bg-white shadow">
            <div class="px-4 py-5 sm:p-6">
              <h3 class="text-base font-semibold leading-6 text-gray-900">Event Details</h3>
              <div class="mt-2">
                <%= if @current_event do %>
                  <div class="mb-4">
                    <div class="font-medium text-gray-700">Type</div>
                    <div class="text-sm text-gray-900"><%= @current_event["type"] %></div>
                  </div>
                  <div class="mb-4">
                    <div class="font-medium text-gray-700">Function</div>
                    <div class="text-sm text-gray-900"><%= @current_event["module"] %>.<%= @current_event["function"] %></div>
                  </div>
                  <%= if @current_event["args"] do %>
                    <div class="mb-4">
                      <div class="font-medium text-gray-700">Arguments</div>
                      <div class="text-sm text-gray-900"><%= inspect(@current_event["args"]) %></div>
                    </div>
                  <% end %>
                  <%= if @current_event["return_value"] do %>
                    <div class="mb-4">
                      <div class="font-medium text-gray-700">Return Value</div>
                      <div class="text-sm text-gray-900"><%= @current_event["return_value"] %></div>
                    </div>
                  <% end %>
                  <%= if @current_event["pid"] do %>
                    <div class="mb-4">
                      <div class="font-medium text-gray-700">Process ID</div>
                      <div class="text-sm text-gray-900"><%= @current_event["pid"] %></div>
                    </div>
                  <% end %>
                  <%= if @current_event["timestamp"] do %>
                    <div class="mb-4">
                      <div class="font-medium text-gray-700">Timestamp</div>
                      <div class="text-sm text-gray-900"><%= @current_event["timestamp"] %></div>
                    </div>
                  <% end %>
                  <%= if @current_event["call_stack"] && @current_event["call_stack"] != [] do %>
                    <div class="mb-4">
                      <div class="font-medium text-gray-700">Call Stack</div>
                      <div class="text-sm text-gray-900">
                        <%= for call <- @current_event["call_stack"] do %>
                          <div class="pl-4 border-l-2 border-gray-200"><%= call %></div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                <% else %>
                  <div class="text-sm text-gray-500">No event selected</div>
                <% end %>
              </div>
            </div>
          </div>

          <%= if @show_instrumentation do %>
            <div class="lg:col-span-2 rounded-lg border border-gray-300 bg-white shadow">
              <div class="px-4 py-5 sm:p-6">
                <h3 class="text-base font-semibold leading-6 text-gray-900">Instrumentation Details</h3>
                <div class="mt-2 prose">
                  <p>This demo shows how ElixirScope instruments code to capture execution data:</p>
                  <ul>
                    <li><strong>Function Entry/Exit:</strong> Captured using Erlang's built-in tracing</li>
                    <li><strong>Variable State:</strong> Tracked at key points in the code</li>
                    <li><strong>Source Code:</strong> Original source is preserved for context</li>
                  </ul>
                  <p class="text-sm text-gray-500">The instrumentation is handled by the <code>PhoenixScopePlayer.Instrumentation</code> module.</p>
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