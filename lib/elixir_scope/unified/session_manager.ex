defmodule ElixirScope.Unified.SessionManager do
  @moduledoc """
  Session management for ElixirScope unified tracing.
  
  Handles the lifecycle of tracing sessions including:
  - Session creation and ID generation
  - Session state tracking and updates
  - Session cleanup and finalization
  - Performance metrics collection
  - Session persistence and recovery
  
  ## Session Lifecycle
  
  1. **Creation**: Generate session ID, validate options, initialize state
  2. **Active**: Track events, update statistics, monitor health
  3. **Paused**: Temporarily suspend tracing while maintaining state
  4. **Finalization**: Collect final stats, cleanup resources, archive data
  """

  use GenServer
  
  alias ElixirScope.{Utils, Events, Storage}

  @type session_id :: String.t()
  @type trace_target :: {module(), atom(), arity()} | module()
  @type trace_mode :: :runtime | :ast | :hybrid
  @type session_status :: :active | :paused | :stopped | :error

  @type session_state :: %{
    session_id: session_id(),
    target: trace_target(),
    mode: trace_mode(),
    status: session_status(),
    correlation_id: String.t(),
    start_time: integer(),
    end_time: integer() | nil,
    options: map(),
    stats: map(),
    metadata: map()
  }

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Starts the session manager.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Creates a new tracing session.
  
  ## Examples
  
      {:ok, session_id} = create_session({MyModule, :func, 2}, :runtime, %{})
      {:ok, session_id} = create_session(MyModule, :hybrid, %{duration: 30_000})
  """
  @spec create_session(trace_target(), trace_mode(), map()) :: 
    {:ok, session_id()} | {:error, term()}
  def create_session(target, mode, options \\ %{}) do
    GenServer.call(__MODULE__, {:create_session, target, mode, options})
  end

  @doc """
  Gets information about a specific session.
  """
  @spec get_session(session_id()) :: {:ok, session_state()} | {:error, term()}
  def get_session(session_id) do
    GenServer.call(__MODULE__, {:get_session, session_id})
  end

  @doc """
  Updates session status and statistics.
  """
  @spec update_session(session_id(), map()) :: :ok | {:error, term()}
  def update_session(session_id, updates) do
    GenServer.call(__MODULE__, {:update_session, session_id, updates})
  end

  @doc """
  Finalizes a session and returns final statistics.
  """
  @spec finalize_session(session_id()) :: {:ok, map()} | {:error, term()}
  def finalize_session(session_id) do
    GenServer.call(__MODULE__, {:finalize_session, session_id})
  end

  @doc """
  Lists all active sessions.
  """
  @spec list_active_sessions() :: [session_state()]
  def list_active_sessions do
    GenServer.call(__MODULE__, :list_active_sessions)
  end

  @doc """
  Gets average session creation time for performance monitoring.
  """
  @spec get_avg_creation_time() :: float()
  def get_avg_creation_time do
    GenServer.call(__MODULE__, :get_avg_creation_time)
  end

  @doc """
  Cleans up expired or orphaned sessions.
  """
  @spec cleanup_sessions() :: {:ok, integer()}
  def cleanup_sessions do
    GenServer.call(__MODULE__, :cleanup_sessions)
  end

  # ============================================================================
  # GenServer Implementation
  # ============================================================================

  @impl true
  def init(_opts) do
    state = %{
      sessions: %{},
      creation_times: [],
      total_sessions_created: 0,
      cleanup_timer: schedule_cleanup()
    }
    
    {:ok, state}
  end

  @impl true
  def handle_call({:create_session, target, mode, options}, _from, state) do
    start_time = System.monotonic_time(:nanosecond)
    
    case create_session_internal(target, mode, options) do
      {:ok, session_id, session_state} ->
        creation_time = System.monotonic_time(:nanosecond) - start_time
        
        new_state = %{
          state |
          sessions: Map.put(state.sessions, session_id, session_state),
          creation_times: [creation_time | Enum.take(state.creation_times, 99)],
          total_sessions_created: state.total_sessions_created + 1
        }
        
        {:reply, {:ok, session_id}, new_state}
      
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:get_session, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil -> {:reply, {:error, :session_not_found}, state}
      session_state -> {:reply, {:ok, session_state}, state}
    end
  end

  @impl true
  def handle_call({:update_session, session_id, updates}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}
      
      session_state ->
        updated_session = Map.merge(session_state, updates)
        new_sessions = Map.put(state.sessions, session_id, updated_session)
        {:reply, :ok, %{state | sessions: new_sessions}}
    end
  end

  @impl true
  def handle_call({:finalize_session, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}
      
      session_state ->
        final_stats = finalize_session_internal(session_state)
        
        # Archive session data
        archived_session = %{
          session_state |
          status: :stopped,
          end_time: System.monotonic_time(:nanosecond),
          final_stats: final_stats
        }
        
        # Remove from active sessions
        new_sessions = Map.delete(state.sessions, session_id)
        
        # Store in persistent storage for historical analysis
        store_archived_session(archived_session)
        
        {:reply, {:ok, final_stats}, %{state | sessions: new_sessions}}
    end
  end

  @impl true
  def handle_call(:list_active_sessions, _from, state) do
    active_sessions = 
      state.sessions
      |> Map.values()
      |> Enum.filter(fn session -> session.status in [:active, :paused] end)
    
    {:reply, active_sessions, state}
  end

  @impl true
  def handle_call(:get_avg_creation_time, _from, state) do
    avg_time = case state.creation_times do
      [] -> 0.0
      times -> Enum.sum(times) / length(times)
    end
    
    {:reply, avg_time, state}
  end

  @impl true
  def handle_call(:cleanup_sessions, _from, state) do
    {cleaned_count, remaining_sessions} = cleanup_expired_sessions(state.sessions)
    
    new_state = %{state | sessions: remaining_sessions}
    {:reply, {:ok, cleaned_count}, new_state}
  end

  @impl true
  def handle_info(:cleanup_timer, state) do
    # Periodic cleanup of expired sessions
    {_cleaned_count, remaining_sessions} = cleanup_expired_sessions(state.sessions)
    
    new_state = %{
      state |
      sessions: remaining_sessions,
      cleanup_timer: schedule_cleanup()
    }
    
    {:noreply, new_state}
  end

  # ============================================================================
  # Private Implementation
  # ============================================================================

  defp create_session_internal(target, mode, options) do
    session_id = generate_session_id()
    correlation_id = Utils.generate_correlation_id()
    
    session_state = %{
      session_id: session_id,
      target: target,
      mode: mode,
      status: :active,
      correlation_id: correlation_id,
      start_time: System.monotonic_time(:nanosecond),
      end_time: nil,
      options: options,
      stats: initialize_session_stats(),
      metadata: %{
        created_by: self(),
        elixir_scope_version: Application.spec(:elixir_scope, :vsn),
        environment: Mix.env()
      }
    }
    
    {:ok, session_id, session_state}
  end

  defp generate_session_id do
    # Generate a unique session ID
    timestamp = System.system_time(:nanosecond)
    random = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
    "session_#{timestamp}_#{random}"
  end

  defp initialize_session_stats do
    %{
      events_captured: 0,
      events_processed: 0,
      events_dropped: 0,
      total_overhead_ns: 0,
      avg_overhead_per_event_ns: 0,
      memory_usage_bytes: 0,
      last_activity: System.monotonic_time(:nanosecond)
    }
  end

  defp finalize_session_internal(session_state) do
    duration_ns = System.monotonic_time(:nanosecond) - session_state.start_time
    
    %{
      session_id: session_state.session_id,
      target: session_state.target,
      mode: session_state.mode,
      duration_ns: duration_ns,
      duration_ms: duration_ns / 1_000_000,
      total_events: session_state.stats.events_captured,
      events_per_second: calculate_events_per_second(session_state.stats.events_captured, duration_ns),
      total_overhead_ns: session_state.stats.total_overhead_ns,
      overhead_percentage: calculate_overhead_percentage(session_state.stats.total_overhead_ns, duration_ns),
      memory_peak_bytes: session_state.stats.memory_usage_bytes,
      success_rate: calculate_success_rate(session_state.stats),
      performance_grade: calculate_performance_grade(session_state)
    }
  end

  defp calculate_events_per_second(event_count, duration_ns) when duration_ns > 0 do
    event_count / (duration_ns / 1_000_000_000)
  end
  defp calculate_events_per_second(_event_count, _duration_ns), do: 0.0

  defp calculate_overhead_percentage(overhead_ns, total_duration_ns) when total_duration_ns > 0 do
    (overhead_ns / total_duration_ns) * 100
  end
  defp calculate_overhead_percentage(_overhead_ns, _total_duration_ns), do: 0.0

  defp calculate_success_rate(stats) do
    total_events = stats.events_captured + stats.events_dropped
    
    if total_events > 0 do
      (stats.events_processed / total_events) * 100
    else
      100.0
    end
  end

  defp calculate_performance_grade(session_state) do
    overhead_pct = calculate_overhead_percentage(
      session_state.stats.total_overhead_ns,
      System.monotonic_time(:nanosecond) - session_state.start_time
    )
    
    success_rate = calculate_success_rate(session_state.stats)
    
    cond do
      overhead_pct < 2.0 and success_rate > 99.0 -> :excellent
      overhead_pct < 5.0 and success_rate > 95.0 -> :good
      overhead_pct < 10.0 and success_rate > 90.0 -> :acceptable
      overhead_pct < 20.0 and success_rate > 80.0 -> :poor
      true -> :unacceptable
    end
  end

  defp cleanup_expired_sessions(sessions) do
    current_time = System.monotonic_time(:nanosecond)
    max_session_age = Application.get_env(:elixir_scope, :max_session_age_ms, 3_600_000) * 1_000_000
    
    {expired, active} = Enum.split_with(sessions, fn {_id, session} ->
      session_age = current_time - session.start_time
      session_age > max_session_age or session.status == :error
    end)
    
    # Archive expired sessions before removing them
    Enum.each(expired, fn {_id, session} ->
      store_archived_session(session)
    end)
    
    {length(expired), Map.new(active)}
  end

  defp store_archived_session(session) do
    # Store session data for historical analysis
    # This could be enhanced to use a dedicated archival storage
    try do
      Events.emit_session_archived(%{
        session_id: session.session_id,
        target: session.target,
        mode: session.mode,
        duration_ns: (session.end_time || System.monotonic_time(:nanosecond)) - session.start_time,
        final_stats: Map.get(session, :final_stats, %{}),
        archived_at: System.monotonic_time(:nanosecond)
      })
    rescue
      _ -> :ok  # Don't fail session cleanup if archival fails
    end
  end

  defp schedule_cleanup do
    cleanup_interval = Application.get_env(:elixir_scope, :session_cleanup_interval_ms, 300_000)
    Process.send_after(self(), :cleanup_timer, cleanup_interval)
  end
end 