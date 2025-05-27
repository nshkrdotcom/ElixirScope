defmodule ElixirScope.Core.EventManager do
  @moduledoc """
  Manages runtime event querying and filtering.
  
  Bridges RuntimeCorrelator with main API to provide user-facing event querying
  capabilities. This module translates high-level query requests into specific
  RuntimeCorrelator operations.
  """
  
  alias ElixirScope.ASTRepository.RuntimeCorrelator
  alias ElixirScope.Storage.EventStore
  alias ElixirScope.Query.Engine
  alias ElixirScope.Utils
  
  @type event_query :: [
    pid: pid() | :all,
    event_type: atom() | :all,
    since: integer() | DateTime.t(),
    until: integer() | DateTime.t(),
    limit: pos_integer()
  ]
  
  @doc """
  Gets events based on query criteria.
  
  Delegates to RuntimeCorrelator for actual event retrieval and applies
  filtering based on the query parameters.
  """
  @spec get_events(event_query()) :: {:ok, [map()]} | {:error, term()}
  def get_events(opts \\ []) do
    # Try to use the new EventStore first
    case get_default_event_store() do
      {:ok, store} ->
        # Use the new Query Engine and EventStore
        case Engine.execute_query(store, opts) do
          {:ok, events} -> {:ok, events}
          {:error, reason} -> {:error, reason}
        end
      
      {:error, :no_store} ->
        # Fall back to RuntimeCorrelator if EventStore is not available
        fallback_to_runtime_correlator(opts)
    end
  end
  
  @doc """
  Gets events with a specific query filter.
  
  Provides more advanced querying capabilities with custom filter functions.
  """
  @spec get_events_with_query(map() | function()) :: {:ok, [map()]} | {:error, term()}
  def get_events_with_query(query) when is_map(query) do
    # Convert map query to keyword list
    opts = Map.to_list(query)
    get_events(opts)
  end
  
  def get_events_with_query(query_fn) when is_function(query_fn, 1) do
    # Get all events and apply custom filter function
    case get_events([]) do
      {:ok, events} ->
        filtered_events = Enum.filter(events, query_fn)
        {:ok, filtered_events}
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  def get_events_with_query(_query) do
    {:error, :invalid_query_format}
  end
  
  @doc """
  Gets events for a specific AST node.
  
  Provides direct access to AST-correlated events through RuntimeCorrelator.
  """
  @spec get_events_for_ast_node(binary()) :: {:ok, [map()]} | {:error, term()}
  def get_events_for_ast_node(ast_node_id) when is_binary(ast_node_id) do
    case RuntimeCorrelator.get_events_for_ast_node(ast_node_id) do
      {:ok, events} -> {:ok, events}
      {:error, reason} -> {:error, {:ast_query_failed, reason}}
    end
  end
  
  @doc """
  Gets correlation statistics from RuntimeCorrelator.
  """
  @spec get_correlation_statistics() :: {:ok, map()} | {:error, term()}
  def get_correlation_statistics do
    case RuntimeCorrelator.get_statistics() do
      {:ok, stats} -> {:ok, stats}
      {:error, reason} -> {:error, {:stats_unavailable, reason}}
    end
  end
  
  #############################################################################
  # Private Helper Functions
  #############################################################################
  
  defp extract_time_range(opts) do
    current_time = Utils.monotonic_timestamp()
    
    # Default to last hour if no time range specified
    default_start = current_time - (60 * 60 * 1000)  # 1 hour ago
    default_end = current_time
    
    start_time = case Keyword.get(opts, :since) do
      nil -> default_start
      %DateTime{} = dt -> DateTime.to_unix(dt, :millisecond)
      timestamp when is_integer(timestamp) -> timestamp
      _ -> default_start
    end
    
    end_time = case Keyword.get(opts, :until) do
      nil -> default_end
      %DateTime{} = dt -> DateTime.to_unix(dt, :millisecond)
      timestamp when is_integer(timestamp) -> timestamp
      _ -> default_end
    end
    
    {start_time, end_time}
  end
  
  defp apply_filters(events, opts) do
    events
    |> filter_by_pid(Keyword.get(opts, :pid))
    |> filter_by_event_type(Keyword.get(opts, :event_type))
    |> apply_limit(Keyword.get(opts, :limit))
  end
  
  defp filter_by_pid(events, nil), do: events
  defp filter_by_pid(events, :all), do: events
  defp filter_by_pid(events, target_pid) when is_pid(target_pid) do
    Enum.filter(events, fn event ->
      case Map.get(event, :pid) do
        ^target_pid -> true
        _ -> false
      end
    end)
  end
  
  defp filter_by_event_type(events, nil), do: events
  defp filter_by_event_type(events, :all), do: events
  defp filter_by_event_type(events, target_type) when is_atom(target_type) do
    Enum.filter(events, fn event ->
      case Map.get(event, :event_type) do
        ^target_type -> true
        _ -> false
      end
    end)
  end
  
  defp apply_limit(events, nil), do: events
  defp apply_limit(events, limit) when is_integer(limit) and limit > 0 do
    Enum.take(events, limit)
  end
  defp apply_limit(events, _), do: events
  
  defp get_default_event_store do
    # Try to find a running EventStore process
    # In test mode, look for test stores
    if Application.get_env(:elixir_scope, :test_mode, false) do
      # In test mode, try to find any test store
      case :ets.whereis(:test_api_store_events) do
        :undefined ->
          # Look for any test store
          case find_test_event_store() do
            nil -> {:error, :no_store}
            store -> {:ok, store}
          end
        _table ->
          # Found a test store, but we need the process
          case find_test_event_store() do
            nil -> {:error, :no_store}
            store -> {:ok, store}
          end
      end
    else
      # In production mode, look for the main EventStore
      case Process.whereis(EventStore) do
        nil -> {:error, :no_store}
        store -> {:ok, store}
      end
    end
  end
  
  defp find_test_event_store do
    # Find any running EventStore process for testing
    Process.list()
    |> Enum.find(fn pid ->
      case Process.info(pid, :dictionary) do
        {:dictionary, dict} ->
          case Keyword.get(dict, :"$initial_call") do
            {ElixirScope.Storage.EventStore, :init, 1} -> true
            _ -> false
          end
        _ -> false
      end
    end)
  end
  
  defp fallback_to_runtime_correlator(opts) do
    # Original RuntimeCorrelator logic as fallback
    case Process.whereis(RuntimeCorrelator) do
      nil ->
        {:error, :not_running}
      
      _pid ->
        try do
          case RuntimeCorrelator.health_check() do
            {:ok, %{status: :healthy}} ->
              {start_time, end_time} = extract_time_range(opts)
              
              case RuntimeCorrelator.query_temporal_events(start_time, end_time) do
                {:ok, events} ->
                  filtered_events = apply_filters(events, opts)
                  {:ok, filtered_events}
                
                {:error, _reason} ->
                  {:error, :runtime_correlator_error}
              end
            
            {:ok, %{status: _status}} ->
              {:error, :runtime_correlator_unhealthy}
            
            {:error, _reason} ->
              {:error, :runtime_correlator_error}
          end
        rescue
          _error -> {:error, :runtime_correlator_unavailable}
        end
    end
  end
end 