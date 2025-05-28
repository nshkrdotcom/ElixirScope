defmodule ElixirScope.Storage.EventStore do
  @moduledoc """
  High-performance event storage with ETS-based indexing.
  
  Provides fast storage and retrieval of events with multiple indexing strategies
  for optimal query performance. Integrates with existing DataAccess and 
  TemporalBridge systems.
  """
  
  use GenServer
  
  defstruct [
    :name,
    :primary_table,
    :temporal_index,
    :process_index,
    :function_index,
    :event_counter
  ]
  
  #############################################################################
  # Public API
  #############################################################################
  
  @doc """
  Starts the EventStore GenServer.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  @doc """
  Stores an event in the EventStore.
  """
  def store_event(store, event) do
    GenServer.call(store, {:store_event, event})
  end
  
  @doc """
  Queries events based on filters.
  """
  def query_events(store, filters) do
    GenServer.call(store, {:query_events, filters})
  end
  
  @doc """
  Gets indexing statistics.
  """
  def get_index_stats(store) do
    GenServer.call(store, :get_index_stats)
  end
  
  @doc """
  Gets events via DataAccess interface for integration testing.
  """
  def get_events_via_data_access(store) do
    GenServer.call(store, :get_events_via_data_access)
  end
  
  #############################################################################
  # GenServer Callbacks
  #############################################################################
  
  @impl true
  def init(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    
    # Create unique table names for this instance
    primary_table = :"#{name}_events"
    temporal_index = :"#{name}_temporal_idx"
    process_index = :"#{name}_process_idx"
    function_index = :"#{name}_function_idx"
    
    # Create ETS tables
    :ets.new(primary_table, [:ordered_set, :public, :named_table])
    :ets.new(temporal_index, [:ordered_set, :public, :named_table])
    :ets.new(process_index, [:bag, :public, :named_table])
    :ets.new(function_index, [:bag, :public, :named_table])
    
    state = %__MODULE__{
      name: name,
      primary_table: primary_table,
      temporal_index: temporal_index,
      process_index: process_index,
      function_index: function_index,
      event_counter: 0
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:store_event, event}, _from, state) do
    # Generate simpler unique key for primary storage
    event_key = state.event_counter
    
    # Store in primary table
    :ets.insert(state.primary_table, {event_key, event})
    
    # Update indexes
    update_indexes(state, event_key, event)
    
    # Increment counter
    new_state = %{state | event_counter: state.event_counter + 1}
    
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call({:query_events, filters}, _from, state) do
    events = execute_query(state, filters)
    {:reply, {:ok, events}, state}
  end
  
  @impl true
  def handle_call(:get_index_stats, _from, state) do
    stats = %{
      temporal_index_size: :ets.info(state.temporal_index, :size),
      process_index_size: :ets.info(state.process_index, :size),
      function_index_size: :ets.info(state.function_index, :size),
      primary_table_size: :ets.info(state.primary_table, :size)
    }
    
    {:reply, stats, state}
  end
  
  @impl true
  def handle_call(:get_events_via_data_access, _from, state) do
    # Integration with existing DataAccess - for now just return all events
    all_events = :ets.tab2list(state.primary_table)
    events = Enum.map(all_events, fn {_key, event} -> event end)
    
    {:reply, {:ok, events}, state}
  end
  
  @impl true
  def terminate(_reason, state) do
    # Clean up ETS tables
    :ets.delete(state.primary_table)
    :ets.delete(state.temporal_index)
    :ets.delete(state.process_index)
    :ets.delete(state.function_index)
    :ok
  end
  
  #############################################################################
  # Private Functions
  #############################################################################
  
  defp update_indexes(state, event_key, event) do
    # Batch all index updates into a single operation list
    index_updates = [
      # Temporal index: {timestamp, event_key}
      {state.temporal_index, {event.timestamp, event_key}},
      # Process index: {pid, event_key}
      {state.process_index, {event.pid, event_key}}
    ]
    
    # Add function index if module and function are present
    index_updates = case event do
      %{module: module, function: function} when not is_nil(module) and not is_nil(function) ->
        arity = Map.get(event, :arity, 0)
        function_sig = {module, function, arity}  # Use tuple instead of string
        [{state.function_index, {function_sig, event_key}} | index_updates]
      _ ->
        index_updates
    end
    
    # Add event type index if present
    index_updates = case Map.get(event, :event_type) do
      nil -> index_updates
      event_type -> [{state.function_index, {event_type, event_key}} | index_updates]
    end
    
    # Perform all inserts
    Enum.each(index_updates, fn {table, record} ->
      :ets.insert(table, record)
    end)
  end
  
  defp execute_query(state, filters) do
    # Determine the best index to use
    event_keys = case determine_optimal_index(filters) do
      {:temporal, since, until} ->
        query_temporal_range(state, since, until)
      
      {:process, pid} ->
        query_by_process(state, pid)
      
      {:event_type, event_type} ->
        query_by_event_type(state, event_type)
      
      :full_scan ->
        query_all_events(state)
    end
    
    # Retrieve events and apply additional filters
    events = Enum.map(event_keys, fn key ->
      [{^key, event}] = :ets.lookup(state.primary_table, key)
      event
    end)
    
    # Apply post-filtering
    events
    |> apply_filters(filters)
    |> apply_limit(get_limit(filters))
    |> Enum.sort_by(& &1.timestamp)
  end
  
  defp determine_optimal_index(filters) when is_map(filters) do
    cond do
      Map.has_key?(filters, :timestamp_since) or Map.has_key?(filters, :timestamp_until) ->
        since = Map.get(filters, :timestamp_since, 0)
        until = Map.get(filters, :timestamp_until, :infinity)
        {:temporal, since, until}
      
      Map.has_key?(filters, :since) or Map.has_key?(filters, :until) ->
        since = Map.get(filters, :since, 0)
        until = Map.get(filters, :until, :infinity)
        {:temporal, since, until}
      
      Map.has_key?(filters, :pid) ->
        {:process, Map.get(filters, :pid)}
      
      Map.has_key?(filters, :event_type) ->
        {:event_type, Map.get(filters, :event_type)}
      
      true ->
        :full_scan
    end
  end
  
  defp determine_optimal_index(filters) when is_list(filters) do
    cond do
      Keyword.has_key?(filters, :since) or Keyword.has_key?(filters, :until) ->
        since = Keyword.get(filters, :since, 0)
        until = Keyword.get(filters, :until, :infinity)
        {:temporal, since, until}
      
      Keyword.has_key?(filters, :pid) ->
        {:process, Keyword.get(filters, :pid)}
      
      Keyword.has_key?(filters, :event_type) ->
        {:event_type, Keyword.get(filters, :event_type)}
      
      true ->
        :full_scan
    end
  end
  
  defp query_temporal_range(state, since, until) do
    # Query temporal index for events in time range
    since = if since == :infinity, do: :infinity, else: since
    until = if until == :infinity, do: :infinity, else: until
    
    :ets.select(state.temporal_index, [
      {{:"$1", :"$2"}, 
       [{:andalso, {:>=, :"$1", since}, {:"=<", :"$1", until}}], 
       [:"$2"]}
    ])
  end
  
  defp query_by_process(state, pid) do
    case :ets.lookup(state.process_index, pid) do
      [] -> []
      results -> Enum.map(results, fn {^pid, event_key} -> event_key end)
    end
  end
  
  defp query_by_event_type(state, event_type) do
    case :ets.lookup(state.function_index, event_type) do
      [] -> []
      results -> Enum.map(results, fn {^event_type, event_key} -> event_key end)
    end
  end
  
  defp query_all_events(state) do
    :ets.select(state.primary_table, [{{:"$1", :"$2"}, [], [:"$1"]}])
  end
  
  defp apply_filters(events, filters) when is_map(filters) do
    events
    |> filter_by_pid(Map.get(filters, :pid))
    |> filter_by_event_type(Map.get(filters, :event_type))
    |> filter_by_time_range(Map.get(filters, :since), Map.get(filters, :until))
    |> filter_by_time_range(Map.get(filters, :timestamp_since), Map.get(filters, :timestamp_until))
  end
  
  defp apply_filters(events, filters) when is_list(filters) do
    events
    |> filter_by_pid(Keyword.get(filters, :pid))
    |> filter_by_event_type(Keyword.get(filters, :event_type))
    |> filter_by_time_range(Keyword.get(filters, :since), Keyword.get(filters, :until))
  end
  
  defp filter_by_pid(events, nil), do: events
  defp filter_by_pid(events, pid) do
    Enum.filter(events, fn event -> event.pid == pid end)
  end
  
  defp filter_by_event_type(events, nil), do: events
  defp filter_by_event_type(events, event_type) do
    Enum.filter(events, fn event -> 
      Map.get(event, :event_type) == event_type 
    end)
  end
  
  defp filter_by_time_range(events, nil, nil), do: events
  defp filter_by_time_range(events, since, until) do
    since = since || 0
    until = until || :infinity
    
    Enum.filter(events, fn event ->
      timestamp = event.timestamp
      (since == 0 or timestamp >= since) and 
      (until == :infinity or timestamp <= until)
    end)
  end
  
  defp apply_limit(events, nil), do: events
  defp apply_limit(events, limit) when is_integer(limit) and limit > 0 do
    Enum.take(events, limit)
  end
  defp apply_limit(events, _), do: events
  
  defp get_limit(filters) when is_map(filters) do
    Map.get(filters, :limit)
  end
  
  defp get_limit(filters) when is_list(filters) do
    Keyword.get(filters, :limit)
  end
end 