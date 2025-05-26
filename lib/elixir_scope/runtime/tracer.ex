defmodule ElixirScope.Runtime.Tracer do
  @moduledoc """
  Individual tracer process using BEAM's built-in tracing primitives.
  
  Responsibilities:
  - Set up BEAM trace patterns using :dbg.tp/2, :dbg.p/2
  - Receive and process trace messages
  - Convert trace messages to ElixirScope.Events
  - Manage correlation IDs and call stacks per PID
  - Forward events to Ingestor
  """
  
  use GenServer
  require Logger

  # Conditional compilation for :dbg module availability
  @compile (if Code.ensure_loaded?(:dbg) == {:module, :dbg} do
    []
  else
    [
      {:no_warn_undefined, {:dbg, :start, 0}},
      {:no_warn_undefined, {:dbg, :tp, 3}},
      {:no_warn_undefined, {:dbg, :tp, 4}},
      {:no_warn_undefined, {:dbg, :p, 2}},
      {:no_warn_undefined, {:dbg, :ctp, 0}}
    ]
  end)

  alias ElixirScope.Events
  alias ElixirScope.Capture.Ingestor

  defstruct [
    :tracer_id,
    :active_traces,
    :ingestor_buffer,
    :call_stacks,
    :correlation_counters,
    :trace_flags,
    :dbg_available,
    :stats
  ]

  @type trace_ref :: reference()
  @type trace_target :: module() | {module(), atom()} | {module(), atom(), arity()} | pid()

  # --- Public API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def start_trace(tracer_pid, trace_ref, target, opts) do
    GenServer.call(tracer_pid, {:start_trace, trace_ref, target, opts})
  end

  def stop_trace(tracer_pid, trace_ref) do
    GenServer.call(tracer_pid, {:stop_trace, trace_ref})
  end

  def adjust_trace_parameters(tracer_pid, trace_ref, adjustments) do
    GenServer.call(tracer_pid, {:adjust_trace, trace_ref, adjustments})
  end

  def start_pattern_trace(tracer_pid, trace_ref, pattern, opts) do
    GenServer.call(tracer_pid, {:start_pattern_trace, trace_ref, pattern, opts})
  end

  def apply_runtime_plan(tracer_pid, runtime_plan) do
    GenServer.cast(tracer_pid, {:apply_runtime_plan, runtime_plan})
  end

  def stop_all_traces(tracer_pid) do
    GenServer.call(tracer_pid, :stop_all_traces)
  end

  def get_stats(tracer_pid) do
    GenServer.call(tracer_pid, :get_stats)
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(opts) do
    tracer_id = Keyword.get(opts, :tracer_id, generate_tracer_id())
    ingestor_buffer = Keyword.get(opts, :ingestor_buffer)

    # Initialize :dbg if not already started (gracefully handle if unavailable)
    dbg_available = case ensure_dbg_started() do
      :ok -> true
      {:error, _} -> false
    end

    state = %__MODULE__{
      tracer_id: tracer_id,
      active_traces: %{}, # trace_ref => %{target: ..., opts: ..., dbg_refs: [...]}
      ingestor_buffer: ingestor_buffer,
      call_stacks: %{}, # pid => [call_stack]
      correlation_counters: %{}, # pid => counter
      trace_flags: [:call, :return_to, :timestamp],
      dbg_available: dbg_available,
      stats: %{
        traces_started: 0,
        traces_stopped: 0,
        events_processed: 0,
        errors: 0
      }
    }

    Logger.debug("Tracer #{tracer_id} started")
    {:ok, state}
  end

  @impl true
  def handle_call({:start_trace, trace_ref, target, opts}, _from, state) do
    case setup_beam_trace(target, opts, state) do
      {:ok, dbg_refs} ->
        trace_info = %{
          target: target,
          opts: opts,
          dbg_refs: dbg_refs,
          started_at: DateTime.utc_now()
        }
        
        new_active_traces = Map.put(state.active_traces, trace_ref, trace_info)
        new_stats = Map.update!(state.stats, :traces_started, &(&1 + 1))
        
        Logger.debug("Tracer #{state.tracer_id} started trace #{inspect(trace_ref)} for #{inspect(target)}")
        {:reply, :ok, %{state | active_traces: new_active_traces, stats: new_stats}}
        
      {:error, reason} = error ->
        new_stats = Map.update!(state.stats, :errors, &(&1 + 1))
        Logger.warning("Failed to setup BEAM trace for #{inspect(target)}: #{inspect(reason)}")
        {:reply, error, %{state | stats: new_stats}}
    end
  end

  @impl true
  def handle_call({:stop_trace, trace_ref}, _from, state) do
    case Map.get(state.active_traces, trace_ref) do
      nil ->
        {:reply, {:error, :trace_not_found}, state}
        
      trace_info ->
        # Clean up BEAM tracing
        cleanup_beam_trace(trace_info.dbg_refs)
        
        new_active_traces = Map.delete(state.active_traces, trace_ref)
        new_stats = Map.update!(state.stats, :traces_stopped, &(&1 + 1))
        
        Logger.debug("Tracer #{state.tracer_id} stopped trace #{inspect(trace_ref)}")
        {:reply, :ok, %{state | active_traces: new_active_traces, stats: new_stats}}
    end
  end

  @impl true
  def handle_call({:adjust_trace, trace_ref, adjustments}, _from, state) do
    case Map.get(state.active_traces, trace_ref) do
      nil ->
        {:reply, {:error, :trace_not_found}, state}
        
      trace_info ->
        # For now, just update the options - full implementation would
        # adjust the actual BEAM trace parameters
        new_opts = Keyword.merge(trace_info.opts, adjustments)
        updated_trace_info = %{trace_info | opts: new_opts}
        new_active_traces = Map.put(state.active_traces, trace_ref, updated_trace_info)
        
        Logger.debug("Adjusted trace #{inspect(trace_ref)} parameters")
        {:reply, :ok, %{state | active_traces: new_active_traces}}
    end
  end

  @impl true
  def handle_call({:start_pattern_trace, trace_ref, pattern, opts}, _from, state) do
    # Pattern tracing would use different BEAM primitives
    case setup_pattern_trace(pattern, opts, state) do
      {:ok, dbg_refs} ->
        trace_info = %{
          target: {:pattern, pattern},
          opts: opts,
          dbg_refs: dbg_refs,
          started_at: DateTime.utc_now()
        }
        
        new_active_traces = Map.put(state.active_traces, trace_ref, trace_info)
        new_stats = Map.update!(state.stats, :traces_started, &(&1 + 1))
        
        {:reply, :ok, %{state | active_traces: new_active_traces, stats: new_stats}}
        
      error ->
        new_stats = Map.update!(state.stats, :errors, &(&1 + 1))
        {:reply, error, %{state | stats: new_stats}}
    end
  end

  @impl true
  def handle_call(:stop_all_traces, _from, state) do
    # Stop all active traces
    Enum.each(state.active_traces, fn {_trace_ref, trace_info} ->
      cleanup_beam_trace(trace_info.dbg_refs)
    end)
    
    stopped_count = map_size(state.active_traces)
    new_stats = Map.update!(state.stats, :traces_stopped, &(&1 + stopped_count))
    
    Logger.debug("Tracer #{state.tracer_id} stopped all #{stopped_count} traces")
    {:reply, :ok, %{state | active_traces: %{}, stats: new_stats}}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    enhanced_stats = Map.merge(state.stats, %{
      active_traces_count: map_size(state.active_traces),
      call_stacks_tracked: map_size(state.call_stacks),
      tracer_id: state.tracer_id
    })
    {:reply, {:ok, enhanced_stats}, state}
  end

  @impl true
  def handle_cast({:apply_runtime_plan, runtime_plan}, state) do
    # Apply global settings from the runtime plan
    new_trace_flags = Map.get(runtime_plan, :global_trace_flags, state.trace_flags)
    
    # Could also apply sampling rates, filtering, etc.
    Logger.debug("Applied runtime plan to tracer #{state.tracer_id}")
    {:noreply, %{state | trace_flags: new_trace_flags}}
  end

  # Handle trace messages from BEAM
  @impl true
  def handle_info({:trace_ts, pid, :call, {module, function, args}, timestamp}, state) do
    correlation_id = get_or_create_correlation_id(pid, state)
    
    # Create function entry event
    event = %Events.FunctionEntry{
      module: module,
      function: function,
      args: args,
      pid: pid,
      correlation_id: correlation_id,
      timestamp: timestamp,
      wall_time: System.system_time(:microsecond)
    }
    
    # Update call stack
    new_call_stacks = update_call_stack(state.call_stacks, pid, {:enter, {module, function}})
    
    # Forward to ingestor
    forward_event_to_ingestor(event, state.ingestor_buffer)
    
    new_stats = Map.update!(state.stats, :events_processed, &(&1 + 1))
    {:noreply, %{state | call_stacks: new_call_stacks, stats: new_stats}}
  end

  @impl true
  def handle_info({:trace_ts, pid, :return_to, {module, function, arity}, timestamp}, state) do
    correlation_id = get_or_create_correlation_id(pid, state)
    
    # Create function exit event
    event = %Events.FunctionExit{
      module: module,
      function: function,
      arity: arity,
      pid: pid,
      correlation_id: correlation_id,
      timestamp: timestamp,
      wall_time: System.system_time(:microsecond)
    }
    
    # Update call stack
    new_call_stacks = update_call_stack(state.call_stacks, pid, {:exit, {module, function}})
    
    # Forward to ingestor
    forward_event_to_ingestor(event, state.ingestor_buffer)
    
    new_stats = Map.update!(state.stats, :events_processed, &(&1 + 1))
    {:noreply, %{state | call_stacks: new_call_stacks, stats: new_stats}}
  end

  @impl true
  def handle_info({:trace_ts, pid, :send, message, to_pid, timestamp}, state) do
    correlation_id = get_or_create_correlation_id(pid, state)
    
    # Create message send event
    event = %Events.MessageSent{
      from_pid: pid,
      to_pid: to_pid,
      message: message,
      correlation_id: correlation_id,
      timestamp: timestamp,
      wall_time: System.system_time(:microsecond)
    }
    
    forward_event_to_ingestor(event, state.ingestor_buffer)
    
    new_stats = Map.update!(state.stats, :events_processed, &(&1 + 1))
    {:noreply, %{state | stats: new_stats}}
  end

  @impl true
  def handle_info({:trace_ts, pid, :receive, message, timestamp}, state) do
    correlation_id = get_or_create_correlation_id(pid, state)
    
    # Create message receive event
    event = %Events.MessageReceived{
      pid: pid,
      message: message,
      correlation_id: correlation_id,
      timestamp: timestamp,
      wall_time: System.system_time(:microsecond)
    }
    
    forward_event_to_ingestor(event, state.ingestor_buffer)
    
    new_stats = Map.update!(state.stats, :events_processed, &(&1 + 1))
    {:noreply, %{state | stats: new_stats}}
  end

  # Handle other trace messages
  @impl true
  def handle_info({:trace_ts, _pid, _type, _data, _timestamp} = trace_msg, state) do
    Logger.debug("Unhandled trace message: #{inspect(trace_msg)}")
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # --- Private Helper Functions ---

  defp ensure_dbg_started() do
    case Code.ensure_loaded(:dbg) do
      {:module, :dbg} ->
        case :dbg.start() do
          {:ok, _} -> :ok
          {:error, :already_started} -> :ok
          error -> 
            Logger.error("Failed to start :dbg: #{inspect(error)}")
            error
        end
      {:error, :nofile} ->
        Logger.warning(":dbg module not available - tracing will use fallback methods")
        {:error, :dbg_unavailable}
    end
  rescue
    error ->
      Logger.warning("Exception checking :dbg availability: #{inspect(error)}")
      {:error, :dbg_unavailable}
  end

  defp setup_beam_trace(target, opts, state) do
    if not state.dbg_available do
      Logger.warning("Cannot setup BEAM trace - :dbg not available, using fallback")
      {:ok, [:fallback_trace]}
    else
      try do
        dbg_refs = case target do
          module when is_atom(module) ->
            setup_module_trace(module, opts, state)
            
          {module, function, arity} ->
            setup_function_trace(module, function, arity, opts, state)
            
          pid when is_pid(pid) ->
            setup_process_trace(pid, opts, state)
            
          _ ->
            {:error, :invalid_target}
        end
        
        case dbg_refs do
          {:error, _} = error -> error
          refs when is_list(refs) -> {:ok, refs}
          ref -> {:ok, [ref]}
        end
      rescue
        error ->
          Logger.error("Exception setting up BEAM trace: #{inspect(error)}")
          {:error, {:exception, error}}
      end
    end
  end

  defp setup_module_trace(module, opts, _state) do
    # Set up tracing for all functions in a module
    trace_level = Keyword.get(opts, :level, :basic)
    
    try do
      case trace_level do
        :basic ->
          # Just function calls
          :dbg.tp(module, :_, [])
          
        :detailed ->
          # Function calls and returns
          :dbg.tp(module, :_, [])
          :dbg.tp(module, :_, :return_trace)
          
        :full ->
          # Everything including arguments and return values
          :dbg.tp(module, :_, [{:_, [], [{:return_trace}]}])
      end
      
      # Return a reference (simplified - real implementation would track multiple refs)
      [make_ref()]
    rescue
      error ->
        Logger.warning("Failed to setup module trace for #{module}: #{inspect(error)}")
        {:error, :trace_setup_failed}
    end
  end

  defp setup_function_trace(module, function, arity, opts, _state) do
    # Set up tracing for a specific function
    try do
      match_spec = build_match_spec(opts)
      :dbg.tp(module, function, arity, match_spec)
      [make_ref()]
    rescue
      error ->
        Logger.warning("Failed to setup function trace for #{module}.#{function}/#{arity}: #{inspect(error)}")
        {:error, :trace_setup_failed}
    end
  end

  defp setup_process_trace(pid, opts, state) do
    # Set up process-level tracing
    try do
      trace_flags = Keyword.get(opts, :trace_flags, state.trace_flags)
      :dbg.p(pid, trace_flags)
      [make_ref()]
    rescue
      error ->
        Logger.warning("Failed to setup process trace for #{inspect(pid)}: #{inspect(error)}")
        {:error, :trace_setup_failed}
    end
  end

  defp setup_pattern_trace(pattern, _opts, _state) do
    # Pattern-based tracing would be more complex
    # For now, just return a placeholder
    Logger.info("Pattern trace setup for #{inspect(pattern)} - not fully implemented")
    {:ok, [make_ref()]}
  end

  defp cleanup_beam_trace(dbg_refs) do
    # Clean up BEAM tracing - simplified implementation
    # Real implementation would track and clean up specific trace points
    Enum.each(dbg_refs, fn _ref ->
      # :dbg.ctp() or specific cleanup based on what was set up
      :ok
    end)
  end

  defp build_match_spec(opts) do
    # Build BEAM match specification from options
    # This is a simplified version - real implementation would be more sophisticated
    case Keyword.get(opts, :match) do
      nil -> []
      match_fun when is_function(match_fun) ->
        # Convert function to match spec (complex transformation)
        []
      match_spec when is_list(match_spec) ->
        match_spec
    end
  end

  defp get_or_create_correlation_id(pid, state) do
    case Map.get(state.correlation_counters, pid) do
      nil ->
        # Create new correlation ID for this PID
        correlation_id = "#{state.tracer_id}-#{:erlang.phash2(pid)}-1"
        correlation_id
        
      counter ->
        # Use existing counter
        "#{state.tracer_id}-#{:erlang.phash2(pid)}-#{counter}"
    end
  end

  defp update_call_stack(call_stacks, pid, operation) do
    current_stack = Map.get(call_stacks, pid, [])
    
    new_stack = case operation do
      {:enter, mfa} -> [mfa | current_stack]
      {:exit, _mfa} -> 
        case current_stack do
          [_head | tail] -> tail
          [] -> []
        end
    end
    
    Map.put(call_stacks, pid, new_stack)
  end

  defp forward_event_to_ingestor(event, ingestor_buffer) do
    if ingestor_buffer do
      # Use the existing Ingestor API to forward the event
      Ingestor.ingest_generic_event(
        ingestor_buffer,
        event.__struct__,
        Map.from_struct(event),
        event.pid,
        event.correlation_id,
        event.timestamp,
        event.wall_time
      )
    else
      Logger.debug("No ingestor buffer available, dropping event: #{inspect(event)}")
    end
  end

  defp generate_tracer_id() do
    "tracer-#{:erlang.unique_integer([:positive])}"
  end

  @doc """
  Checks if :dbg module is available for tracing.
  """
  def check_dbg_availability do
    case Code.ensure_loaded(:dbg) do
      {:module, :dbg} -> :ok
      {:error, :nofile} -> {:error, :dbg_unavailable}
    end
  end
end 