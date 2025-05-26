defmodule ElixirScope.Runtime do
  @moduledoc """
  Runtime instrumentation API for dynamic debugging without recompilation.
  
  Provides multiple levels of instrumentation from lightweight tracing
  to full execution capture with state reconstruction. Enhanced from
  OPUS_PROD_RUNTIME_INSTRUMENTATION_API_SKETCH.md for production use.
  """

  # Suppress warnings for future phase dependencies
  @compile {:no_warn_undefined, {ElixirScope.TimeTravel.ReplayEngine, :replay_to, 3}}

  alias ElixirScope.Runtime.Controller

  @type trace_ref :: reference()
  @type session_id :: String.t()
  @type trace_target :: module() | {module(), atom()} | {module(), atom(), arity()} | pid()
  @type trace_level :: :basic | :detailed | :full
  @type anomaly_type :: :latency | :memory | :cpu | :errors
  @type pattern :: term()

  # ============================================================================
  # Basic Tracing API
  # ============================================================================

  @doc """
  Start tracing a module with specified options.
  
  ## Examples
      
      # Basic function call tracing
      ElixirScope.Runtime.trace(MyApp.UserService)
      
      # Detailed tracing with arguments and returns
      ElixirScope.Runtime.trace(MyApp.UserService, 
        level: :detailed,
        includes: [:args, :returns, :exceptions]
      )
      
      # Trace specific functions only
      ElixirScope.Runtime.trace(MyApp.UserService,
        only: [:get_user, :update_user],
        level: :full
      )
      
      # Trace with sampling
      ElixirScope.Runtime.trace(MyApp.Orders,
        sample_rate: 0.1,  # 10% of calls
        when: fn(mod, fun, args) -> 
          match?({:error, _}, List.first(args)) 
        end
      )
  """
  @spec trace(module(), keyword()) :: {:ok, trace_ref()} | {:error, term()}
  def trace(module, opts \\ []) when is_atom(module) do
    Controller.start_trace(module, opts)
  end

  @doc """
  Trace specific functions with fine-grained control.
  
  ## Examples
  
      # Trace with custom match spec
      ElixirScope.Runtime.trace_function(MyCache, :get, 1,
        match: fn
          [key] when byte_size(key) > 100 -> true
          _ -> false
        end,
        capture: [:args, :returns, :timing]
      )
      
      # Trace with state capture
      ElixirScope.Runtime.trace_function(MyGenServer, :handle_call, 3,
        capture: [:state_before, :state_after, :state_diff],
        include_caller: true
      )
  """
  @spec trace_function(module(), atom(), arity(), keyword()) :: {:ok, trace_ref()} | {:error, term()}
  def trace_function(module, function, arity, opts \\ []) 
      when is_atom(module) and is_atom(function) and is_integer(arity) do
    target = {module, function, arity}
    Controller.start_trace(target, opts)
  end

  @doc """
  Trace a running process and all its activities.
  
  ## Examples
  
      # Trace everything about a process
      ElixirScope.Runtime.trace_process(pid,
        include: [:messages, :state_changes, :calls],
        include_children: true
      )
      
      # Trace with time window
      ElixirScope.Runtime.trace_process(pid,
        duration: {5, :minutes},
        stop_on: fn event -> 
          match?(%{type: :exception}, event)
        end
      )
  """
  @spec trace_process(pid(), keyword()) :: {:ok, trace_ref()} | {:error, term()}
  def trace_process(pid, opts \\ []) when is_pid(pid) do
    Controller.start_trace(pid, opts)
  end

  @doc """
  Stop tracing for a given reference.
  """
  @spec stop_trace(trace_ref()) :: :ok | {:error, term()}
  def stop_trace(trace_ref) when is_reference(trace_ref) do
    Controller.stop_trace(trace_ref)
  end

  @doc """
  Query what's currently being traced.
  
  ## Examples
  
      ElixirScope.Runtime.list_traces()
      # => [
      #   %{ref: #Ref<>, module: MyApp.Users, level: :detailed, started: ~U[...]},
      #   %{ref: #Ref<>, pid: #PID<0.123.0>, include: [:all], started: ~U[...]}
      # ]
  """
  @spec list_traces() :: [map()]
  def list_traces() do
    Controller.list_active_traces()
  end

  @doc """
  Adjust tracing parameters at runtime.
  
  ## Examples
  
      # Increase detail level when errors occur
      ElixirScope.Runtime.adjust_trace(ref,
        level: :full,
        sample_rate: 1.0
      )
      
      # Reduce tracing under load
      ElixirScope.Runtime.adjust_trace(ref,
        sample_rate: 0.01,
        only: [:critical_functions]
      )
  """
  @spec adjust_trace(trace_ref(), keyword()) :: :ok | {:error, term()}
  def adjust_trace(trace_ref, adjustments) when is_reference(trace_ref) do
    Controller.adjust_trace_parameters(trace_ref, adjustments)
  end

  # ============================================================================
  # Advanced Instrumentation API
  # ============================================================================

  @doc """
  Instrument a module with custom code injection at runtime.
  
  ## Examples
  
      # Add timing to all functions
      ElixirScope.Runtime.instrument(MyModule,
        before_each: &ElixirScope.Timer.start/3,
        after_each: &ElixirScope.Timer.stop/4
      )
      
      # Add state tracking to GenServer
      ElixirScope.Runtime.instrument(MyGenServer,
        wrap: [
          handle_call: &ElixirScope.StateTracker.wrap_call/2,
          handle_cast: &ElixirScope.StateTracker.wrap_cast/2
        ]
      )
  """
  @spec instrument(module(), keyword()) :: {:ok, :instrumented} | {:error, term()}
  def instrument(module, _opts \\ []) when is_atom(module) do
    # Would use hot code loading - implementation in Phase 6
    {:error, :not_implemented_yet}
  end

  # ============================================================================
  # Conditional & Smart Tracing
  # ============================================================================

  @doc """
  Set up conditional breakpoint-style tracing.
  
  ## Examples
  
      # Start detailed tracing when condition is met
      ElixirScope.Runtime.trace_when(MyApp.Orders, :place_order,
        condition: fn(_mod, _fun, [order]) ->
          order.total > 10_000
        end,
        then: [
          level: :full,
          include_call_stack: true,
          trace_related_processes: true
        ]
      )
  """
  @spec trace_when(module(), atom(), keyword()) :: {:ok, trace_ref()} | {:error, term()}
  def trace_when(module, function, opts) when is_atom(module) and is_atom(function) do
    target = {module, function}
    enhanced_opts = Keyword.put(opts, :conditional, true)
    Controller.start_trace(target, enhanced_opts)
  end

  @doc """
  Automatically trace anomalies.
  
  ## Examples
  
      # Trace functions that exceed latency thresholds
      ElixirScope.Runtime.trace_anomalies(:latency,
        threshold: {100, :milliseconds},
        action: :enable_full_tracing,
        duration: {5, :minutes}
      )
      
      # Trace memory spikes
      ElixirScope.Runtime.trace_anomalies(:memory,
        threshold: {:increase, 50, :percent},
        action: fn anomaly ->
          trace_process(anomaly.pid, level: :full)
        end
      )
  """
  @spec trace_anomalies(anomaly_type(), keyword()) :: {:ok, reference()} | {:error, term()}
  def trace_anomalies(type, opts) when type in [:latency, :memory, :cpu, :errors] do
    Controller.start_anomaly_monitoring(type, opts)
  end

  @doc """
  Trace based on message patterns.
  
  ## Examples
  
      # Trace all GenServer calls matching a pattern
      ElixirScope.Runtime.trace_pattern(
        {:call, {pid, _ref}, {:get_user, user_id}},
        capture: [:full_message, :sender, :receiver],
        include_response: true
      )
      
      # Trace Phoenix requests matching pattern
      ElixirScope.Runtime.trace_pattern(
        {:http, :post, "/api/orders", %{total: total}} when total > 1000,
        include: [:full_request, :processing_chain, :response]
      )
  """
  @spec trace_pattern(pattern(), keyword()) :: {:ok, trace_ref()} | {:error, term()}
  def trace_pattern(pattern, opts \\ []) do
    Controller.start_pattern_trace(pattern, opts)
  end

  # ============================================================================
  # Time-Travel Debugging API
  # ============================================================================

  @doc """
  Enable state capture for time-travel debugging.
  
  ## Examples
  
      # Capture state snapshots for specific processes
      ElixirScope.Runtime.enable_time_travel(MyGenServer,
        snapshot_interval: {1, :second},
        max_snapshots: 1000,
        include_ets: true
      )
      
      # Capture with triggers
      ElixirScope.Runtime.enable_time_travel(MyApp.Cart,
        snapshot_on: [:state_change, :handle_call, :handle_cast],
        compress: true
      )
  """
  @spec enable_time_travel(module() | pid(), keyword()) :: {:ok, session_id()} | {:error, term()}
  def enable_time_travel(target, opts \\ []) do
    Controller.enable_time_travel_capture(target, opts)
  end

  @doc """
  Replay execution to a specific point in time.
  
  ## Examples
  
      # Go back to specific timestamp
      ElixirScope.Runtime.replay_to(session_id, ~U[2024-01-20 10:30:00])
      
      # Step backwards through execution
      ElixirScope.Runtime.step_back(session_id, events: 10)
      
      # Replay with modifications
      ElixirScope.Runtime.replay_to(session_id, checkpoint_id,
        modify: fn state ->
          put_in(state.users[user_id].balance, 1000)
        end
      )
  """
  @spec replay_to(session_id(), DateTime.t() | String.t(), keyword()) :: 
    {:ok, term()} | {:error, term()}
  def replay_to(session_id, target, opts \\ []) when is_binary(session_id) do
    ElixirScope.TimeTravel.ReplayEngine.replay_to(session_id, target, opts)
  end

  # ============================================================================
  # Production Safety API
  # ============================================================================

  @doc """
  Set global tracing limits and safety controls.
  
  ## Examples
  
      ElixirScope.Runtime.set_limits(
        max_events_per_second: 100_000,
        max_memory: {500, :megabytes},
        max_trace_duration: {1, :hour},
        auto_stop_on: [
          {:cpu_usage, ">", 80},
          {:memory_usage, ">", 90}
        ]
      )
  """
  @spec set_limits(keyword()) :: :ok | {:error, term()}
  def set_limits(limits) when is_list(limits) do
    Controller.set_global_limits(limits)
  end

  @doc """
  Emergency stop all tracing.
  """
  @spec emergency_stop() :: {:ok, stopped_count :: integer()}
  def emergency_stop() do
    Controller.emergency_stop_all_tracing()
  end

  @doc """
  Check if runtime tracing is globally enabled.
  """
  @spec enabled?() :: boolean()
  def enabled?() do
    Controller.globally_enabled?()
  end

  @doc """
  Enable or disable runtime tracing globally.
  """
  @spec set_enabled(boolean()) :: :ok
  def set_enabled(enabled) when is_boolean(enabled) do
    Controller.set_global_tracing_status(enabled)
  end

  @doc """
  Checks if the current environment is compatible with ElixirScope runtime tracing.
  """
  @spec check_environment_compatibility() :: :ok | {:error, term()}
  def check_environment_compatibility do
    otp_version = System.otp_release() |> String.to_integer()
    
    if otp_version < 24 do
      {:error, :otp_version_too_old}
    else
      :ok
    end
  end
end 