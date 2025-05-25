Here's a comprehensive runtime instrumentation API design for ElixirScope:

## Core Runtime Instrumentation API

```elixir
defmodule ElixirScope.Runtime do
  @moduledoc """
  Runtime instrumentation API for dynamic debugging without recompilation.
  
  Provides multiple levels of instrumentation from lightweight tracing
  to full execution capture with state reconstruction.
  """

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
  def trace(module, opts \\ []) do
    # Implementation would set up BEAM tracing
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
  def trace_function(module, function, arity, opts \\ []) do
    # Implementation
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
  def trace_process(pid, opts \\ []) do
    # Implementation
  end

  @doc """
  Stop tracing for a given reference.
  """
  @spec stop_trace(trace_ref()) :: :ok
  def stop_trace(trace_ref) do
    # Implementation
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
  def instrument(module, opts \\ []) do
    # Would use hot code loading
  end

  # ============================================================================
  # Query & Control API
  # ============================================================================

  @doc """
  Query what's currently being traced.
  
  ## Examples
  
      ElixirScope.Runtime.list_traces()
      # => [
      #   %{ref: #Ref<>, module: MyApp.Users, level: :detailed, started: ~U[...]},
      #   %{ref: #Ref<>, pid: #PID<0.123.0>, include: [:all], started: ~U[...]}
      # ]
  """
  @spec list_traces() :: [trace_info()]
  def list_traces() do
    # Implementation
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
  def adjust_trace(trace_ref, adjustments) do
    # Implementation
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
  def trace_when(module, function, opts) do
    # Implementation
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
  @spec trace_anomalies(anomaly_type(), keyword()) :: {:ok, monitor_ref()} | {:error, term()}
  def trace_anomalies(type, opts) do
    # Implementation
  end

  # ============================================================================
  # Pattern-Based Tracing
  # ============================================================================

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
    # Implementation
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
    # Implementation
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
  @spec replay_to(session_id(), timestamp() | checkpoint_id(), keyword()) :: 
    {:ok, state()} | {:error, term()}
  def replay_to(session_id, target, opts \\ []) do
    # Implementation
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
  @spec set_limits(keyword()) :: :ok
  def set_limits(limits) do
    # Implementation
  end

  @doc """
  Emergency stop all tracing.
  """
  @spec emergency_stop() :: {:ok, stopped_count :: integer()}
  def emergency_stop() do
    # Implementation
  end
end
```

## Supporting Modules

```elixir
defmodule ElixirScope.Runtime.Matchers do
  @moduledoc """
  Pattern matching DSL for runtime tracing conditions.
  """

  @doc """
  Build match specifications for efficient BEAM tracing.
  
  ## Examples
  
      import ElixirScope.Runtime.Matchers
      
      # Match specific argument patterns
      match_spec do
        args [user_id, action] when is_binary(user_id) and action in [:delete, :suspend]
        return_value {:error, reason} when is_atom(reason)
      end
  """
  defmacro match_spec(do: block) do
    # Compile to BEAM match specifications
  end
end

defmodule ElixirScope.Runtime.Replay do
  @moduledoc """
  Time-travel debugging engine.
  """

  @doc """
  Create a checkpoint of current system state.
  """
  def checkpoint(session_id, opts \\ []) do
    # Capture process states, ETS tables, etc.
  end

  @doc """
  Step through execution history.
  """
  def step_forward(session_id, opts \\ []) do
    # Replay next event
  end

  def step_backward(session_id, opts \\ []) do
    # Undo last event using inverse operations
  end
end

defmodule ElixirScope.Runtime.Sampling do
  @moduledoc """
  Intelligent sampling strategies for production tracing.
  """

  @doc """
  Adaptive sampling based on system load.
  """
  def adaptive_sampler(opts) do
    fn ->
      load = :cpu_sup.util()
      cond do
        load > 80 -> 0.001  # 0.1% when high load
        load > 50 -> 0.01   # 1% when moderate load  
        true -> 0.1         # 10% when low load
      end
    end
  end

  @doc """
  Tail-based sampling - trace full request if it's interesting.
  """
  def tail_sampler(opts) do
    fn events ->
      cond do
        any_errors?(events) -> 1.0
        slow_request?(events, opts[:latency_threshold]) -> 1.0
        true -> opts[:base_rate] || 0.01
      end
    end
  end
end
```

## Interactive Debugging API

```elixir
defmodule ElixirScope.Runtime.Interactive do
  @moduledoc """
  IEx integration for interactive debugging sessions.
  """

  @doc """
  Start an interactive debugging session.
  
  ## In IEx:
  
      iex> import ElixirScope.Runtime.Interactive
      iex> debug MyApp.BuggyModule do
      ...>   trace_calls()
      ...>   on {:error, _} -> start_recording()
      ...>   on {:crash, _} -> capture_state()
      ...> end
  """
  defmacro debug(module, do: block) do
    # Implementation
  end

  @doc """
  Set a runtime breakpoint.
  
      iex> break MyModule.function/2, 
      ...>   when: fn [x, _y] -> x > 100 end,
      ...>   do: :inspect_state
  """
  defmacro break(mfa, opts) do
    # Implementation
  end
end
```

## Key Design Principles

1. **Progressive Enhancement**: Start with cheap tracing, add detail as needed
2. **Production Safety**: Built-in limits, circuit breakers, and emergency stops  
3. **Zero Config**: Sensible defaults that work in production
4. **Composable**: Mix and match different tracing strategies
5. **Time-Travel Native**: State capture and replay as first-class features

This API would make ElixirScope much more practical for real-world debugging while maintaining the performance focus of the current design.