defmodule ElixirScope.Runtime.Safety do
  @moduledoc """
  Production safety controls and circuit breakers for runtime tracing.
  
  This module provides mechanisms to protect production systems from
  the overhead of runtime tracing by implementing circuit breakers,
  resource monitoring, and emergency stop functionality.
  """

  use GenServer
  require Logger

  # Conditional compilation for :cpu_sup module availability
  @compile (if Code.ensure_loaded?(:cpu_sup) == {:module, :cpu_sup} do
    []
  else
    [
      {:no_warn_undefined, {:cpu_sup, :util, 0}},
      {:no_warn_undefined, {:cpu_sup, :avg1, 0}},
      {:no_warn_undefined, {:cpu_sup, :avg5, 0}},
      {:no_warn_undefined, {:cpu_sup, :avg15, 0}}
    ]
  end)

  @default_limits %{
    max_traced_processes: 1000,
    max_events_per_second: 10_000,
    max_memory_usage_mb: 500,
    max_cpu_usage_percent: 10,
    max_trace_duration_ms: 300_000,  # 5 minutes
    emergency_stop_threshold: 0.95
  }

  @circuit_breaker_defaults %{
    failure_threshold: 5,
    recovery_timeout: 30_000,
    half_open_max_calls: 3
  }

  # Client API

  @doc """
  Starts the safety manager.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Sets global safety limits for runtime tracing.
  
  ## Examples
  
      iex> set_limits(%{max_traced_processes: 500, max_events_per_second: 5000})
      :ok
  """
  def set_limits(limits) do
    GenServer.call(__MODULE__, {:set_limits, limits})
  end

  @doc """
  Gets current safety limits.
  """
  def get_limits do
    GenServer.call(__MODULE__, :get_limits)
  end

  @doc """
  Checks if it's safe to start a new trace.
  """
  def safe_to_trace?(trace_type \\ :general) do
    GenServer.call(__MODULE__, {:safe_to_trace, trace_type})
  end

  @doc """
  Registers a new active trace.
  """
  def register_trace(trace_id, trace_info) do
    GenServer.call(__MODULE__, {:register_trace, trace_id, trace_info})
  end

  @doc """
  Unregisters an active trace.
  """
  def unregister_trace(trace_id) do
    GenServer.call(__MODULE__, {:unregister_trace, trace_id})
  end

  @doc """
  Records an event for rate limiting.
  """
  def record_event(event_type \\ :general) do
    GenServer.cast(__MODULE__, {:record_event, event_type})
  end

  @doc """
  Triggers an emergency stop of all tracing.
  """
  def emergency_stop(reason \\ "Manual emergency stop") do
    GenServer.call(__MODULE__, {:emergency_stop, reason})
  end

  @doc """
  Checks if the system is in emergency stop mode.
  """
  def emergency_stopped? do
    GenServer.call(__MODULE__, :emergency_stopped)
  end

  @doc """
  Resets the emergency stop state.
  """
  def reset_emergency_stop do
    GenServer.call(__MODULE__, :reset_emergency_stop)
  end

  @doc """
  Gets current safety statistics.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Creates a circuit breaker for a specific operation.
  """
  def create_circuit_breaker(name, opts \\ []) do
    config = Map.merge(@circuit_breaker_defaults, Map.new(opts))
    
    %{
      name: name,
      state: :closed,
      failure_count: 0,
      last_failure_time: nil,
      config: config,
      stats: %{
        total_calls: 0,
        successful_calls: 0,
        failed_calls: 0,
        circuit_opens: 0
      }
    }
  end

  @doc """
  Executes a function with circuit breaker protection.
  """
  def with_circuit_breaker(circuit_breaker, fun) do
    case circuit_breaker.state do
      :closed ->
        execute_with_breaker(circuit_breaker, fun)
      
      :open ->
        if should_attempt_reset?(circuit_breaker) do
          execute_half_open(circuit_breaker, fun)
        else
          {:error, :circuit_open}
        end
      
      :half_open ->
        execute_half_open(circuit_breaker, fun)
    end
  end

  @doc """
  Monitors resource usage and triggers safety measures if needed.
  """
  def monitor_resources do
    GenServer.cast(__MODULE__, :monitor_resources)
  end

  @doc """
  Checks if a specific resource limit has been exceeded.
  """
  def resource_limit_exceeded?(resource) do
    GenServer.call(__MODULE__, {:resource_limit_exceeded, resource})
  end

  @doc """
  Creates a resource monitor for a specific metric.
  """
  def create_resource_monitor(metric, threshold, action) do
    %{
      metric: metric,
      threshold: threshold,
      action: action,
      last_check: System.monotonic_time(:millisecond),
      violations: 0,
      active: true
    }
  end

  @doc """
  Applies a safety action (reduce tracing, stop traces, etc.).
  """
  def apply_safety_action(action, context \\ %{}) do
    GenServer.call(__MODULE__, {:apply_safety_action, action, context})
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    limits = Map.merge(@default_limits, Map.new(Keyword.get(opts, :limits, [])))
    
    # Start periodic resource monitoring
    :timer.send_interval(5000, :monitor_resources)
    
    state = %{
      limits: limits,
      active_traces: %{},
      event_counts: %{},
      last_event_reset: System.monotonic_time(:millisecond),
      emergency_stopped: false,
      emergency_reason: nil,
      circuit_breakers: %{},
      resource_monitors: create_default_monitors(limits),
      stats: %{
        traces_started: 0,
        traces_stopped: 0,
        traces_rejected: 0,
        emergency_stops: 0,
        resource_violations: 0
      }
    }
    
    {:ok, state}
  end

  @impl true
  def handle_call({:set_limits, new_limits}, _from, state) do
    updated_limits = Map.merge(state.limits, new_limits)
    updated_monitors = update_monitors_for_limits(state.resource_monitors, updated_limits)
    
    new_state = %{state | 
      limits: updated_limits,
      resource_monitors: updated_monitors
    }
    
    Logger.info("Safety limits updated: #{inspect(new_limits)}")
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_limits, _from, state) do
    {:reply, state.limits, state}
  end

  @impl true
  def handle_call({:safe_to_trace, trace_type}, _from, state) do
    safe = is_safe_to_trace?(state, trace_type)
    {:reply, safe, state}
  end

  @impl true
  def handle_call({:register_trace, trace_id, trace_info}, _from, state) do
    if is_safe_to_trace?(state, :general) do
      updated_traces = Map.put(state.active_traces, trace_id, %{
        info: trace_info,
        started_at: System.monotonic_time(:millisecond),
        events_count: 0
      })
      
      updated_stats = %{state.stats | traces_started: state.stats.traces_started + 1}
      
      new_state = %{state | 
        active_traces: updated_traces,
        stats: updated_stats
      }
      
      {:reply, :ok, new_state}
    else
      updated_stats = %{state.stats | traces_rejected: state.stats.traces_rejected + 1}
      new_state = %{state | stats: updated_stats}
      {:reply, {:error, :safety_limit_exceeded}, new_state}
    end
  end

  @impl true
  def handle_call({:unregister_trace, trace_id}, _from, state) do
    updated_traces = Map.delete(state.active_traces, trace_id)
    updated_stats = %{state.stats | traces_stopped: state.stats.traces_stopped + 1}
    
    new_state = %{state | 
      active_traces: updated_traces,
      stats: updated_stats
    }
    
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:emergency_stop, reason}, _from, state) do
    Logger.warning("Emergency stop triggered: #{reason}")
    
    # Stop all active traces
    Enum.each(state.active_traces, fn {trace_id, _} ->
      ElixirScope.Runtime.stop_trace(trace_id)
    end)
    
    updated_stats = %{state.stats | emergency_stops: state.stats.emergency_stops + 1}
    
    new_state = %{state |
      emergency_stopped: true,
      emergency_reason: reason,
      active_traces: %{},
      stats: updated_stats
    }
    
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:emergency_stopped, _from, state) do
    {:reply, state.emergency_stopped, state}
  end

  @impl true
  def handle_call(:reset_emergency_stop, _from, state) do
    Logger.info("Emergency stop reset")
    
    new_state = %{state |
      emergency_stopped: false,
      emergency_reason: nil
    }
    
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    current_stats = Map.merge(state.stats, %{
      active_traces_count: map_size(state.active_traces),
      emergency_stopped: state.emergency_stopped,
      current_event_rate: calculate_current_event_rate(state)
    })
    
    {:reply, current_stats, state}
  end

  @impl true
  def handle_call({:resource_limit_exceeded, resource}, _from, state) do
    exceeded = check_resource_limit(state, resource)
    {:reply, exceeded, state}
  end

  @impl true
  def handle_call({:apply_safety_action, action, context}, _from, state) do
    new_state = execute_safety_action(state, action, context)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_cast({:record_event, event_type}, state) do
    now = System.monotonic_time(:millisecond)
    
    # Reset counters if needed (every minute)
    state = maybe_reset_event_counters(state, now)
    
    # Increment event counter
    current_count = Map.get(state.event_counts, event_type, 0)
    updated_counts = Map.put(state.event_counts, event_type, current_count + 1)
    
    new_state = %{state | event_counts: updated_counts}
    
    # Check if we're exceeding event rate limits
    if exceeds_event_rate_limit?(new_state) do
      Logger.warning("Event rate limit exceeded, applying safety measures")
      GenServer.cast(self(), {:apply_safety_action, :reduce_tracing, %{reason: :event_rate_limit}})
    end
    
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:monitor_resources, state) do
    new_state = check_all_resource_monitors(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:apply_safety_action, action, context}, state) do
    new_state = execute_safety_action(state, action, context)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:monitor_resources, state) do
    new_state = check_all_resource_monitors(state)
    {:noreply, new_state}
  end

  # Private functions

  defp is_safe_to_trace?(state, _trace_type) do
    cond do
      state.emergency_stopped ->
        false
      
      map_size(state.active_traces) >= state.limits.max_traced_processes ->
        false
      
      exceeds_event_rate_limit?(state) ->
        false
      
      exceeds_memory_limit?(state) ->
        false
      
      exceeds_cpu_limit?(state) ->
        false
      
      true ->
        true
    end
  end

  defp exceeds_event_rate_limit?(state) do
    total_events = Enum.sum(Map.values(state.event_counts))
    total_events > state.limits.max_events_per_second
  end

  defp exceeds_memory_limit?(state) do
    memory_info = :erlang.memory()
    total_memory_mb = memory_info[:total] / (1024 * 1024)
    total_memory_mb > state.limits.max_memory_usage_mb
  end

  @doc """
  Checks if CPU usage exceeds the limit.
  """
  def exceeds_cpu_limit?(_state \\ %{}) do
    # Simplified CPU check - in production, use proper monitoring
    case :cpu_sup.util() do
      {:error, _} -> false
      usage when is_number(usage) -> usage > 80.0  # Basic threshold
      _ -> false
    end
  rescue
    _ -> false
  end

  defp maybe_reset_event_counters(state, now) do
    time_since_reset = now - state.last_event_reset
    
    if time_since_reset >= 60_000 do  # Reset every minute
      %{state |
        event_counts: %{},
        last_event_reset: now
      }
    else
      state
    end
  end

  defp calculate_current_event_rate(state) do
    total_events = Enum.sum(Map.values(state.event_counts))
    now = System.monotonic_time(:millisecond)
    time_window = now - state.last_event_reset
    
    if time_window > 0 do
      (total_events * 1000) / time_window
    else
      0
    end
  end

  defp create_default_monitors(limits) do
    [
      create_resource_monitor(:memory, limits.max_memory_usage_mb, :reduce_tracing),
      create_resource_monitor(:cpu, limits.max_cpu_usage_percent, :reduce_tracing),
      create_resource_monitor(:event_rate, limits.max_events_per_second, :reduce_sampling)
    ]
  end

  defp update_monitors_for_limits(monitors, new_limits) do
    Enum.map(monitors, fn monitor ->
      case monitor.metric do
        :memory -> %{monitor | threshold: new_limits.max_memory_usage_mb}
        :cpu -> %{monitor | threshold: new_limits.max_cpu_usage_percent}
        :event_rate -> %{monitor | threshold: new_limits.max_events_per_second}
        _ -> monitor
      end
    end)
  end

  defp check_all_resource_monitors(state) do
    {violations, updated_monitors} = 
      Enum.map_reduce(state.resource_monitors, [], fn monitor, acc_violations ->
        case check_resource_monitor(monitor) do
          {:violation, updated_monitor, violation_info} ->
            {updated_monitor, [violation_info | acc_violations]}
          
          {:ok, updated_monitor} ->
            {updated_monitor, acc_violations}
        end
      end)
    
    # Apply safety actions for violations
    new_state = Enum.reduce(violations, state, fn violation, acc_state ->
      context = Map.get(violation, :context, %{})
      execute_safety_action(acc_state, violation.action, context)
    end)
    
    %{new_state | resource_monitors: updated_monitors}
  end

  defp check_resource_monitor(monitor) do
    current_value = get_current_resource_value(monitor.metric)
    
    if current_value > monitor.threshold do
      violation_info = %{
        metric: monitor.metric,
        current_value: current_value,
        threshold: monitor.threshold,
        action: monitor.action,
        context: %{violation_time: System.monotonic_time(:millisecond)}
      }
      
      updated_monitor = %{monitor | 
        violations: monitor.violations + 1,
        last_check: System.monotonic_time(:millisecond)
      }
      
      {:violation, updated_monitor, violation_info}
    else
      updated_monitor = %{monitor | last_check: System.monotonic_time(:millisecond)}
      {:ok, updated_monitor}
    end
  end

  @doc """
  Gets the current value for a specific resource metric.
  """
  def get_current_resource_value(:memory) do
    memory_info = :erlang.memory()
    memory_info[:total] / (1024 * 1024)  # Convert to MB
  end

  def get_current_resource_value(:cpu) do
    case :cpu_sup.util() do
      {:error, _} -> 0.0
      usage when is_number(usage) -> usage
      _ -> 0.0
    end
  rescue
    _ -> 0.0
  end

  def get_current_resource_value(:event_rate) do
    # This would integrate with actual event counting
    0
  end

  def get_current_resource_value(_), do: 0

  defp check_resource_limit(state, resource) do
    case resource do
      :memory -> exceeds_memory_limit?(state)
      :cpu -> exceeds_cpu_limit?(state)
      :event_rate -> exceeds_event_rate_limit?(state)
      :traced_processes -> map_size(state.active_traces) >= state.limits.max_traced_processes
      _ -> false
    end
  end

  @doc """
  Executes a safety action with the given context.
  """
  def execute_safety_action(state, action, context) do
    Logger.warning("Executing safety action: #{action}, context: #{inspect(context)}")
    
    case action do
      :reduce_tracing ->
        # Reduce number of active traces by stopping some
        traces_to_stop = div(map_size(state.active_traces), 2)
        stop_oldest_traces(state, traces_to_stop)
      
      :reduce_sampling ->
        # Notify sampling system to reduce rates
        ElixirScope.Runtime.Sampling.update_config(:global, %{base_rate: 0.01})
        state
      
      :emergency_stop ->
        # Trigger emergency stop
        handle_call({:emergency_stop, "Resource limit exceeded"}, nil, state)
        |> elem(2)  # Extract new state
      
      _ ->
        state
    end
  end

  defp stop_oldest_traces(state, count) do
    oldest_traces = 
      state.active_traces
      |> Enum.sort_by(fn {_id, trace_info} -> trace_info.started_at end)
      |> Enum.take(count)
    
    Enum.each(oldest_traces, fn {trace_id, _} ->
      ElixirScope.Runtime.stop_trace(trace_id)
    end)
    
    updated_traces = 
      Enum.reduce(oldest_traces, state.active_traces, fn {trace_id, _}, acc ->
        Map.delete(acc, trace_id)
      end)
    
    %{state | active_traces: updated_traces}
  end

  defp execute_with_breaker(circuit_breaker, fun) do
    try do
      result = fun.()
      updated_breaker = record_success(circuit_breaker)
      {:ok, result, updated_breaker}
    rescue
      error ->
        updated_breaker = record_failure(circuit_breaker)
        {:error, error, updated_breaker}
    end
  end

  defp execute_half_open(circuit_breaker, fun) do
    case execute_with_breaker(circuit_breaker, fun) do
      {:ok, result, updated_breaker} ->
        # Success in half-open state, close the circuit
        closed_breaker = %{updated_breaker | state: :closed, failure_count: 0}
        {:ok, result, closed_breaker}
      
      {:error, error, updated_breaker} ->
        # Failure in half-open state, open the circuit again
        opened_breaker = %{updated_breaker | state: :open}
        {:error, error, opened_breaker}
    end
  end

  defp should_attempt_reset?(circuit_breaker) do
    case circuit_breaker.last_failure_time do
      nil -> false
      last_failure ->
        now = System.monotonic_time(:millisecond)
        (now - last_failure) >= circuit_breaker.config.recovery_timeout
    end
  end

  defp record_success(circuit_breaker) do
    updated_stats = %{circuit_breaker.stats |
      total_calls: circuit_breaker.stats.total_calls + 1,
      successful_calls: circuit_breaker.stats.successful_calls + 1
    }
    
    %{circuit_breaker | stats: updated_stats}
  end

  defp record_failure(circuit_breaker) do
    updated_stats = %{circuit_breaker.stats |
      total_calls: circuit_breaker.stats.total_calls + 1,
      failed_calls: circuit_breaker.stats.failed_calls + 1
    }
    
    new_failure_count = circuit_breaker.failure_count + 1
    
    updated_breaker = %{circuit_breaker |
      failure_count: new_failure_count,
      last_failure_time: System.monotonic_time(:millisecond),
      stats: updated_stats
    }
    
    if new_failure_count >= circuit_breaker.config.failure_threshold do
      # Open the circuit
      opened_stats = %{updated_stats | circuit_opens: updated_stats.circuit_opens + 1}
      %{updated_breaker | state: :open, stats: opened_stats}
    else
      updated_breaker
    end
  end

  @doc """
  Checks CPU monitoring availability.
  """
  def check_cpu_monitoring do
    case Code.ensure_loaded(:cpu_sup) do
      {:module, :cpu_sup} -> :ok
      {:error, :nofile} -> {:error, :cpu_sup_unavailable}
    end
  end
end 