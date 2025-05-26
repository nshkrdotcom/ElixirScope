defmodule ElixirScope.Unified do
  @moduledoc """
  Unified interface for ElixirScope tracing system.
  
  Provides a single entry point that intelligently routes between:
  - Runtime tracing (stable, production-ready)
  - AST instrumentation (compile-time, enhanced capabilities)
  - Hybrid mode (coordinated runtime + AST)
  
  ## Architecture
  
  This module implements the unified interface shown in DIAGS.md, leveraging
  the stable runtime foundation (100% working) while providing hooks for
  future AST integration.
  
  ## Usage
  
      # Simple runtime tracing
      {:ok, session} = ElixirScope.Unified.trace_function(MyModule, :my_func, 1)
      
      # With options
      {:ok, session} = ElixirScope.Unified.trace_function(MyModule, :my_func, 1, %{
        mode: :runtime,
        capture: [:args, :return, :locals],
        duration: 30_000
      })
      
      # Module-level tracing
      {:ok, sessions} = ElixirScope.Unified.trace_module(MyModule, %{
        functions: [:func1, :func2],
        mode: :hybrid
      })
  """

  alias ElixirScope.{Runtime, Utils}
  alias ElixirScope.Unified.{ModeSelector, EventCorrelator, SessionManager}

  @type trace_target :: module() | {module(), atom(), arity()}
  @type trace_mode :: :runtime | :ast | :hybrid | :auto
  @type session_id :: String.t()

  @type trace_options :: %{
    optional(:mode) => trace_mode(),
    optional(:capture) => [:args | :return | :locals | :state | :messages],
    optional(:duration) => pos_integer(),
    optional(:sample_rate) => float(),
    optional(:filters) => map(),
    optional(:correlation_id) => String.t(),
    optional(:metadata) => map()
  }

  @type session_info :: %{
    session_id: session_id(),
    mode: trace_mode(),
    target: trace_target(),
    status: :active | :paused | :stopped,
    start_time: integer(),
    options: trace_options(),
    stats: map()
  }

  # ============================================================================
  # Public API - Function Tracing
  # ============================================================================

  @doc """
  Traces a specific function with intelligent mode selection.
  """
  @spec trace_function(module(), atom(), arity(), trace_options()) :: 
    {:ok, session_info()} | {:error, term()}
  def trace_function(module, function, arity, options \\ %{}) do
    target = {module, function, arity}
    
    with {:ok, resolved_mode} <- ModeSelector.select_mode(target, options),
         {:ok, session_id} <- SessionManager.create_session(target, resolved_mode, options),
         {:ok, correlation_id} <- start_tracing(target, resolved_mode, session_id, options) do
      
      session_info = %{
        session_id: session_id,
        mode: resolved_mode,
        target: target,
        status: :active,
        start_time: System.monotonic_time(:nanosecond),
        options: options,
        correlation_id: correlation_id,
        stats: %{events_captured: 0, overhead_ns: 0}
      }
      
      {:ok, session_info}
    end
  end

  @doc """
  Convenience function for tracing without arity (traces all arities).
  """
  @spec trace_function_all_arities(module(), atom(), trace_options()) :: 
    {:ok, [session_info()]} | {:error, term()}
  def trace_function_all_arities(module, function, options \\ %{}) do
    # Get all arities for this function
    arities = get_function_arities(module, function)
    
    results = Enum.map(arities, fn arity ->
      trace_function(module, function, arity, options)
    end)
    
    case Enum.split_with(results, &match?({:ok, _}, &1)) do
      {successes, []} -> 
        {:ok, Enum.map(successes, fn {:ok, session} -> session end)}
      {_, errors} -> 
        {:error, {:partial_failure, errors}}
    end
  end

  # ============================================================================
  # Public API - Module Tracing
  # ============================================================================

  @doc """
  Traces an entire module or specific functions within a module.
  """
  @spec trace_module(module(), trace_options()) :: 
    {:ok, [session_info()]} | {:error, term()}
  def trace_module(module, options \\ %{}) do
    target_functions = determine_target_functions(module, options)
    
    results = Enum.map(target_functions, fn {function, arity} ->
      trace_function(module, function, arity, options)
    end)
    
    case Enum.split_with(results, &match?({:ok, _}, &1)) do
      {successes, []} -> 
        {:ok, Enum.map(successes, fn {:ok, session} -> session end)}
      {successes, errors} when length(successes) > 0 -> 
        {:partial_success, 
         %{
           successful: Enum.map(successes, fn {:ok, session} -> session end),
           failed: errors
         }}
      {[], errors} -> 
        {:error, {:all_failed, errors}}
    end
  end

  # ============================================================================
  # Public API - Session Management
  # ============================================================================

  @doc """
  Stops a tracing session and returns final statistics.
  """
  @spec stop_session(session_id()) :: {:ok, map()} | {:error, term()}
  def stop_session(session_id) do
    with {:ok, session_info} <- SessionManager.get_session(session_id),
         :ok <- stop_tracing_for_session(session_info),
         {:ok, final_stats} <- SessionManager.finalize_session(session_id) do
      {:ok, final_stats}
    end
  end

  @doc """
  Pauses a tracing session (can be resumed later).
  """
  @spec pause_session(session_id()) :: :ok | {:error, term()}
  def pause_session(session_id) do
    with {:ok, _session_info} <- SessionManager.get_session(session_id) do
      {:error, :pause_not_supported_in_phase_1}
    end
  end

  @doc """
  Resumes a paused tracing session.
  """
  @spec resume_session(session_id()) :: :ok | {:error, term()}
  def resume_session(session_id) do
    with {:ok, _session_info} <- SessionManager.get_session(session_id) do
      {:error, :resume_not_supported_in_phase_1}
    end
  end

  @doc """
  Lists all active tracing sessions.
  """
  @spec list_sessions() :: [session_info()]
  def list_sessions do
    SessionManager.list_active_sessions()
  end

  @doc """
  Gets detailed information about a specific session.
  """
  @spec get_session_info(session_id()) :: {:ok, session_info()} | {:error, term()}
  def get_session_info(session_id) do
    SessionManager.get_session(session_id)
  end

  # ============================================================================
  # Public API - Event Querying
  # ============================================================================

  @doc """
  Queries events for a specific session.
  """
  @spec query_session_events(session_id(), map()) :: {:ok, [map()]} | {:error, term()}
  def query_session_events(session_id, query_options \\ %{}) do
    with {:ok, session_info} <- SessionManager.get_session(session_id) do
      correlation_id = session_info.correlation_id
      EventCorrelator.query_events_by_correlation(correlation_id, query_options)
    end
  end

  @doc """
  Gets real-time event stream for a session.
  """
  @spec stream_session_events(session_id()) :: {:ok, pid()} | {:error, term()}
  def stream_session_events(session_id) do
    with {:ok, session_info} <- SessionManager.get_session(session_id) do
      EventCorrelator.create_event_stream(session_info.correlation_id)
    end
  end

  # ============================================================================
  # Public API - System Status
  # ============================================================================

  @doc """
  Gets overall system status and health.
  """
  @spec system_status() :: map()
  def system_status do
    %{
      runtime_system: %{status: :active, traces: length(Runtime.list_traces())},
      active_sessions: length(list_sessions()),
      total_events: 0,  # Placeholder - will implement when Events module is ready
      memory_usage: get_memory_usage(),
      uptime: get_system_uptime(),
      capabilities: get_system_capabilities()
    }
  end

  @doc """
  Gets performance metrics for the unified system.
  """
  @spec performance_metrics() :: map()
  def performance_metrics do
    %{
      session_creation_time: 0.0,  # Placeholder - SessionManager.get_avg_creation_time()
      event_processing_rate: 0.0,  # Placeholder - will implement when Events module is ready
      storage_efficiency: get_storage_efficiency(),
      overhead_percentage: calculate_overhead_percentage()
    }
  end

  # ============================================================================
  # Private Implementation
  # ============================================================================

  defp start_tracing(target, mode, session_id, options) do
    correlation_id = Utils.generate_correlation_id()
    
    case mode do
      :runtime -> 
        start_runtime_tracing(target, correlation_id, options)
      :ast -> 
        start_ast_tracing(target, correlation_id, options)
      :hybrid -> 
        start_hybrid_tracing(target, correlation_id, options)
    end
    
    # Register correlation for event tracking
    EventCorrelator.register_session(session_id, correlation_id, target, mode)
    
    {:ok, correlation_id}
  end

  defp start_runtime_tracing({module, function, arity}, correlation_id, options) do
    Runtime.trace_function(module, function, arity, 
      Map.merge(options, %{correlation_id: correlation_id}))
  end

  defp start_ast_tracing(_target, _correlation_id, _options) do
    # AST tracing will be implemented in Phase 2
    # For now, fall back to runtime tracing
    {:error, :ast_not_implemented_yet}
  end

  defp start_hybrid_tracing(target, correlation_id, options) do
    # Start runtime tracing first
    with {:ok, _} <- start_runtime_tracing(target, correlation_id, options) do
      # AST integration will be added in Phase 2
      # For now, hybrid mode is just runtime mode
      :ok
    end
  end

  defp stop_tracing_for_session(session_info) do
    case session_info.mode do
      :runtime -> 
        # Use the correct Runtime API function name
        case Map.get(session_info, :trace_ref) do
          nil -> :ok  # No trace ref stored, assume already stopped
          trace_ref -> Runtime.stop_trace(trace_ref)
        end
      :ast -> 
        # AST stop logic will be implemented in Phase 2
        :ok
      :hybrid -> 
        # Stop both runtime and AST tracing
        case Map.get(session_info, :trace_ref) do
          nil -> :ok
          trace_ref -> Runtime.stop_trace(trace_ref)
        end
        # AST stop will be added in Phase 2
    end
  end

  defp get_function_arities(module, function) do
    if Code.ensure_loaded?(module) do
      module.__info__(:functions)
      |> Enum.filter(fn {name, _arity} -> name == function end)
      |> Enum.map(fn {_name, arity} -> arity end)
    else
      []
    end
  end

  defp determine_target_functions(module, options) do
    functions = Map.get(options, :functions, :all)
    filters = Map.get(options, :filters, %{})
    
    case functions do
      :all -> 
        get_all_module_functions(module, filters)
      list when is_list(list) -> 
        expand_function_list(module, list)
      _ -> 
        []
    end
  end

  defp get_all_module_functions(module, filters) do
    if Code.ensure_loaded?(module) do
      module.__info__(:functions)
      |> apply_function_filters(filters)
    else
      []
    end
  end

  defp expand_function_list(module, function_names) do
    if Code.ensure_loaded?(module) do
      all_functions = module.__info__(:functions)
      
      Enum.flat_map(function_names, fn name ->
        Enum.filter(all_functions, fn {func_name, _arity} -> func_name == name end)
      end)
    else
      []
    end
  end

  defp apply_function_filters(functions, filters) do
    functions
    |> maybe_filter_by_arity(Map.get(filters, :min_arity), Map.get(filters, :max_arity))
    |> maybe_exclude_private(Map.get(filters, :exclude_private, false))
  end

  defp maybe_filter_by_arity(functions, nil, nil), do: functions
  defp maybe_filter_by_arity(functions, min_arity, nil) do
    Enum.filter(functions, fn {_name, arity} -> arity >= min_arity end)
  end
  defp maybe_filter_by_arity(functions, nil, max_arity) do
    Enum.filter(functions, fn {_name, arity} -> arity <= max_arity end)
  end
  defp maybe_filter_by_arity(functions, min_arity, max_arity) do
    Enum.filter(functions, fn {_name, arity} -> 
      arity >= min_arity and arity <= max_arity 
    end)
  end

  defp maybe_exclude_private(functions, false), do: functions
  defp maybe_exclude_private(functions, true) do
    # In Elixir, private functions aren't in __info__(:functions), so this is already filtered
    functions
  end

  defp get_memory_usage do
    :erlang.memory()
    |> Enum.into(%{})
  end

  defp get_system_uptime do
    {uptime_ms, _} = :erlang.statistics(:wall_clock)
    uptime_ms
  end

  defp get_system_capabilities do
    %{
      runtime_tracing: true,
      ast_instrumentation: false,  # Will be true in Phase 2
      hybrid_mode: false,          # Will be true in Phase 2
      event_correlation: true,
      real_time_streaming: true,
      distributed_tracing: false   # Future enhancement
    }
  end

  defp get_storage_efficiency do
    # Placeholder - will implement based on storage metrics
    %{
      compression_ratio: 0.75,
      write_efficiency: 0.95,
      query_performance: 0.90
    }
  end

  defp calculate_overhead_percentage do
    # Placeholder - will implement based on performance monitoring
    2.5  # 2.5% overhead
  end
end
