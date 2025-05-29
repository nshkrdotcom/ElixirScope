defmodule PhoenixScopePlayer.PlaybackEngine.Engine do
  @moduledoc """
  GenServer that manages the playback state for a debugging session.
  Handles playback controls, state management, and event processing.
  """
  use GenServer
  require Logger
  alias PhoenixScopePlayer.PlaybackEngine.Registry

  @type state :: %{
    session_id: String.t(),
    session_data: %{
      id: String.t(),
      events: list(map()),
      source_code_map: map(),
      ast_map: map()
    },
    current_event_index: non_neg_integer(),
    is_playing: boolean(),
    parent_pid: pid() | nil,
    call_stack: list(String.t()),
    variables: map(),
    playback_speed: float(),
    timer_ref: reference() | nil
  }

  # Client API

  @doc """
  Starts a new PlaybackEngine for a session
  """
  def start_link(session_id) when is_binary(session_id) do
    GenServer.start_link(__MODULE__, session_id, name: Registry.via_tuple(session_id))
  end

  @doc """
  Starts playback at the current speed
  """
  def play(session_id), do: GenServer.cast(Registry.via_tuple(session_id), :play)

  @doc """
  Pauses playback
  """
  def pause(session_id), do: GenServer.cast(Registry.via_tuple(session_id), :pause)

  @doc """
  Steps forward one event
  """
  def step_forward(session_id), do: GenServer.cast(Registry.via_tuple(session_id), :step_forward)

  @doc """
  Steps backward one event
  """
  def step_backward(session_id), do: GenServer.cast(Registry.via_tuple(session_id), :step_backward)

  @doc """
  Seeks to a specific event index
  """
  def seek_to(session_id, event_index) when is_integer(event_index) and event_index >= 0 do
    GenServer.cast(Registry.via_tuple(session_id), {:seek_to, event_index})
  end

  @doc """
  Sets the playback speed (1.0 is normal speed)
  """
  def set_speed(session_id, speed) when is_float(speed) and speed > 0 do
    GenServer.cast(Registry.via_tuple(session_id), {:set_speed, speed})
  end

  @doc """
  Gets the current state of the playback engine
  """
  def get_state(session_id) do
    GenServer.call(Registry.via_tuple(session_id), :get_state)
  end

  # Server Callbacks

  @impl true
  def init(session_id) do
    state = %{
      session_id: session_id,
      session_data: %{
        id: session_id,
        events: [],
        source_code_map: %{},
        ast_map: %{}
      },
      current_event_index: 0,
      is_playing: false,
      parent_pid: nil,
      call_stack: [],
      variables: %{},
      playback_speed: 1.0,
      timer_ref: nil
    }

    {:ok, state, {:continue, :load_session}}
  end

  @impl true
  def handle_continue(:load_session, state) do
    # TODO: Load session data from DataProvider
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast(:play, %{is_playing: true} = state), do: {:noreply, state}
  def handle_cast(:play, state) do
    timer_ref = schedule_next_event(state)
    {:noreply, %{state | is_playing: true, timer_ref: timer_ref}}
  end

  @impl true
  def handle_cast(:pause, %{is_playing: false} = state), do: {:noreply, state}
  def handle_cast(:pause, %{timer_ref: timer_ref} = state) do
    if timer_ref, do: Process.cancel_timer(timer_ref)
    {:noreply, %{state | is_playing: false, timer_ref: nil}}
  end

  @impl true
  def handle_cast(:step_forward, state) do
    state = do_step_forward(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:step_backward, state) do
    state = do_step_backward(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:seek_to, index}, state) do
    state = do_seek_to(state, index)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:set_speed, speed}, state) do
    {:noreply, %{state | playback_speed: speed}}
  end

  @impl true
  def handle_info(:process_next_event, state) do
    state = do_step_forward(state)
    timer_ref = if state.is_playing, do: schedule_next_event(state), else: nil
    {:noreply, %{state | timer_ref: timer_ref}}
  end

  # Private Functions

  defp schedule_next_event(%{playback_speed: speed}) do
    # Base interval is 100ms, adjusted by playback speed
    interval = trunc(100 / speed)
    Process.send_after(self(), :process_next_event, interval)
  end

  defp do_step_forward(%{current_event_index: index, session_data: %{events: events}} = state) do
    if index < length(events) - 1 do
      new_index = index + 1
      event = Enum.at(events, new_index)
      state
      |> update_state_for_event(event)
      |> Map.put(:current_event_index, new_index)
    else
      %{state | is_playing: false}
    end
  end

  defp do_step_backward(%{current_event_index: index} = state) when index > 0 do
    # TODO: Implement backward stepping by replaying from start to target index
    %{state | current_event_index: index - 1}
  end
  defp do_step_backward(state), do: state

  defp do_seek_to(state, target_index) do
    # TODO: Implement seeking by replaying from start to target index
    %{state | current_event_index: target_index}
  end

  defp update_state_for_event(state, event) do
    # TODO: Implement state updates based on event type
    state
  end
end 