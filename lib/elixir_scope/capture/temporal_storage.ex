defmodule ElixirScope.Capture.TemporalStorage do
  @moduledoc """
  Temporal storage for events with AST correlation and time-based indexing.
  
  Provides efficient storage and querying of events with temporal ordering
  and AST node correlation for Cinema Debugger functionality.
  
  ## Features
  
  - Time-ordered event storage
  - AST node correlation tracking
  - Efficient time-range queries
  - Memory-efficient indexing
  
  ## Usage
  
      {:ok, storage} = TemporalStorage.start_link()
      
      event = %{
        timestamp: 1000,
        ast_node_id: "node1", 
        correlation_id: "corr1",
        data: %{...}
      }
      
      :ok = TemporalStorage.store_event(storage, event)
      
      {:ok, events} = TemporalStorage.get_events_in_range(storage, 1000, 2000)
  """
  
  use GenServer
  require Logger
  
  alias ElixirScope.Utils
  
  @type event :: %{
    timestamp: integer(),
    ast_node_id: binary() | nil,
    correlation_id: binary() | nil,
    data: term()
  }
  
  @type storage_ref :: pid() | atom()
  @type time_range :: {integer(), integer()}
  
  defstruct [
    :storage_id,
    :events_table,        # ETS table for events: {timestamp, event_id, event}
    :ast_index,          # ETS table for AST correlation: {ast_node_id, [event_ids]}
    :correlation_index,  # ETS table for correlation: {correlation_id, [event_ids]}
    :stats,             # Storage statistics
    :config             # Configuration options
  ]
  
  @type t :: %__MODULE__{}
  
  # Default configuration
  @default_config %{
    max_events: 100_000,
    cleanup_interval: 60_000,
    enable_ast_indexing: true,
    enable_correlation_indexing: true
  }
  
  #############################################################################
  # Public API
  #############################################################################
  
  @doc """
  Starts a new TemporalStorage process.
  
  ## Options
  
  - `:name` - Process name (optional)
  - `:max_events` - Maximum events to store (default: 100,000)
  - `:cleanup_interval` - Cleanup interval in ms (default: 60,000)
  
  ## Examples
  
      {:ok, storage} = TemporalStorage.start_link()
      {:ok, storage} = TemporalStorage.start_link(name: :my_storage)
  """
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end
  
  @doc """
  Stores an event with temporal indexing.
  
  Events are automatically indexed by timestamp and optionally by
  AST node ID and correlation ID for efficient querying.
  
  ## Examples
  
      event = %{
        timestamp: Utils.monotonic_timestamp(),
        ast_node_id: "function_def_123",
        correlation_id: "exec_456",
        data: %{function: :my_function, args: [1, 2, 3]}
      }
      
      :ok = TemporalStorage.store_event(storage, event)
  """
  @spec store_event(storage_ref(), event()) :: :ok | {:error, term()}
  def store_event(storage, event) do
    GenServer.call(storage, {:store_event, event})
  end
  
  @doc """
  Retrieves events within a time range, ordered chronologically.
  
  ## Examples
  
      # Get events from last 5 seconds
      now = Utils.monotonic_timestamp()
      {:ok, events} = TemporalStorage.get_events_in_range(storage, now - 5000, now)
      
      # Get all events in a specific window
      {:ok, events} = TemporalStorage.get_events_in_range(storage, 1000, 2000)
  """
  @spec get_events_in_range(storage_ref(), integer(), integer()) :: {:ok, [event()]} | {:error, term()}
  def get_events_in_range(storage, start_time, end_time) do
    GenServer.call(storage, {:get_events_in_range, start_time, end_time})
  end
  
  @doc """
  Gets events associated with a specific AST node.
  
  ## Examples
  
      {:ok, events} = TemporalStorage.get_events_for_ast_node(storage, "function_def_123")
  """
  @spec get_events_for_ast_node(storage_ref(), binary()) :: {:ok, [event()]} | {:error, term()}
  def get_events_for_ast_node(storage, ast_node_id) do
    GenServer.call(storage, {:get_events_for_ast_node, ast_node_id})
  end
  
  @doc """
  Gets events associated with a specific correlation ID.
  
  ## Examples
  
      {:ok, events} = TemporalStorage.get_events_for_correlation(storage, "exec_456")
  """
  @spec get_events_for_correlation(storage_ref(), binary()) :: {:ok, [event()]} | {:error, term()}
  def get_events_for_correlation(storage, correlation_id) do
    GenServer.call(storage, {:get_events_for_correlation, correlation_id})
  end
  
  @doc """
  Gets all events in chronological order.
  
  ## Examples
  
      {:ok, all_events} = TemporalStorage.get_all_events(storage)
  """
  @spec get_all_events(storage_ref()) :: {:ok, [event()]} | {:error, term()}
  def get_all_events(storage) do
    GenServer.call(storage, :get_all_events)
  end
  
  @doc """
  Gets storage statistics.
  
  ## Examples
  
      {:ok, stats} = TemporalStorage.get_stats(storage)
      # %{
      #   total_events: 1234,
      #   memory_usage: 5678,
      #   oldest_event: 1000,
      #   newest_event: 2000
      # }
  """
  @spec get_stats(storage_ref()) :: {:ok, map()} | {:error, term()}
  def get_stats(storage) do
    GenServer.call(storage, :get_stats)
  end
  
  #############################################################################
  # GenServer Implementation
  #############################################################################
  
  @impl true
  def init(opts) do
    config = Map.merge(@default_config, Map.new(opts))
    
    case create_storage_state(config) do
      {:ok, state} ->
        # Schedule periodic cleanup if configured
        if config.cleanup_interval > 0 do
          schedule_cleanup(config.cleanup_interval)
        end
        
        Logger.info("TemporalStorage started with config: #{inspect(config)}")
        {:ok, state}
      
      {:error, reason} ->
        Logger.error("Failed to initialize TemporalStorage: #{inspect(reason)}")
        {:stop, reason}
    end
  end
  
  @impl true
  def handle_call({:store_event, event}, _from, state) do
    case store_event_impl(state, event) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:get_events_in_range, start_time, end_time}, _from, state) do
    case get_events_in_range_impl(state, start_time, end_time) do
      {:ok, events} ->
        {:reply, {:ok, events}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:get_events_for_ast_node, ast_node_id}, _from, state) do
    case get_events_for_ast_node_impl(state, ast_node_id) do
      {:ok, events} ->
        {:reply, {:ok, events}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:get_events_for_correlation, correlation_id}, _from, state) do
    case get_events_for_correlation_impl(state, correlation_id) do
      {:ok, events} ->
        {:reply, {:ok, events}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call(:get_all_events, _from, state) do
    case get_all_events_impl(state) do
      {:ok, events} ->
        {:reply, {:ok, events}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = calculate_stats(state)
    {:reply, {:ok, stats}, state}
  end
  
  @impl true
  def handle_info(:cleanup, state) do
    new_state = perform_cleanup(state)
    schedule_cleanup(state.config.cleanup_interval)
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end
  
  #############################################################################
  # Private Implementation
  #############################################################################
  
  defp create_storage_state(config) do
    try do
      storage_id = Utils.generate_id()
      
      # Create ETS tables for efficient storage and indexing
      events_table = :ets.new(:temporal_events, [:ordered_set, :public, {:read_concurrency, true}])
      ast_index = :ets.new(:ast_index, [:bag, :public, {:read_concurrency, true}])
      correlation_index = :ets.new(:correlation_index, [:bag, :public, {:read_concurrency, true}])
      
      state = %__MODULE__{
        storage_id: storage_id,
        events_table: events_table,
        ast_index: ast_index,
        correlation_index: correlation_index,
        stats: %{
          total_events: 0,
          oldest_event: nil,
          newest_event: nil,
          created_at: Utils.wall_timestamp()
        },
        config: config
      }
      
      {:ok, state}
    rescue
      error -> {:error, {:initialization_failed, error}}
    end
  end
  
  defp store_event_impl(state, event) do
    try do
      # Validate event structure
      timestamp = Map.get(event, :timestamp) || Utils.monotonic_timestamp()
      event_id = Utils.generate_id()
      
      # Normalize event structure
      normalized_event = %{
        timestamp: timestamp,
        event_id: event_id,
        ast_node_id: Map.get(event, :ast_node_id),
        correlation_id: Map.get(event, :correlation_id),
        data: Map.get(event, :data, event)
      }
      
      # Store in main events table (ordered by timestamp)
      :ets.insert(state.events_table, {timestamp, event_id, normalized_event})
      
      # Update indexes if enabled
      if state.config.enable_ast_indexing and normalized_event.ast_node_id do
        :ets.insert(state.ast_index, {normalized_event.ast_node_id, event_id})
      end
      
      if state.config.enable_correlation_indexing and normalized_event.correlation_id do
        :ets.insert(state.correlation_index, {normalized_event.correlation_id, event_id})
      end
      
      # Update statistics
      new_stats = update_stats(state.stats, normalized_event)
      new_state = %{state | stats: new_stats}
      
      {:ok, new_state}
    rescue
      error -> {:error, {:store_failed, error}}
    end
  end
  
  defp get_events_in_range_impl(state, start_time, end_time) do
    try do
      # Query events table for time range (ETS ordered_set makes this efficient)
      events = :ets.select(state.events_table, [
        {{:"$1", :"$2", :"$3"}, 
         [{:andalso, {:>=, :"$1", start_time}, {:"=<", :"$1", end_time}}], 
         [:"$3"]}
      ])
      
      # Events are already ordered by timestamp due to ordered_set
      {:ok, events}
    rescue
      error -> {:error, {:query_failed, error}}
    end
  end
  
  defp get_events_for_ast_node_impl(state, ast_node_id) do
    try do
      # Get event IDs from AST index
      event_ids = :ets.lookup(state.ast_index, ast_node_id)
                  |> Enum.map(fn {_, event_id} -> event_id end)
      
      # Retrieve events and sort by timestamp
      events = get_events_by_ids(state, event_ids)
               |> Enum.sort_by(& &1.timestamp)
      
      {:ok, events}
    rescue
      error -> {:error, {:query_failed, error}}
    end
  end
  
  defp get_events_for_correlation_impl(state, correlation_id) do
    try do
      # Get event IDs from correlation index
      event_ids = :ets.lookup(state.correlation_index, correlation_id)
                  |> Enum.map(fn {_, event_id} -> event_id end)
      
      # Retrieve events and sort by timestamp
      events = get_events_by_ids(state, event_ids)
               |> Enum.sort_by(& &1.timestamp)
      
      {:ok, events}
    rescue
      error -> {:error, {:query_failed, error}}
    end
  end
  
  defp get_all_events_impl(state) do
    try do
      # Get all events from events table (already ordered by timestamp)
      events = :ets.select(state.events_table, [
        {{:"$1", :"$2", :"$3"}, [], [:"$3"]}
      ])
      
      {:ok, events}
    rescue
      error -> {:error, {:query_failed, error}}
    end
  end
  
  defp get_events_by_ids(state, event_ids) do
    Enum.flat_map(event_ids, fn event_id ->
      case :ets.match(state.events_table, {:"$1", event_id, :"$2"}) do
        [[_timestamp, event]] -> [event]
        [] -> []
      end
    end)
  end
  
  defp update_stats(stats, event) do
    %{stats |
      total_events: stats.total_events + 1,
      oldest_event: min_timestamp(stats.oldest_event, event.timestamp),
      newest_event: max_timestamp(stats.newest_event, event.timestamp)
    }
  end
  
  defp min_timestamp(nil, timestamp), do: timestamp
  defp min_timestamp(current, timestamp), do: min(current, timestamp)
  
  defp max_timestamp(nil, timestamp), do: timestamp
  defp max_timestamp(current, timestamp), do: max(current, timestamp)
  
  defp calculate_stats(state) do
    memory_usage = :ets.info(state.events_table, :memory) +
                   :ets.info(state.ast_index, :memory) +
                   :ets.info(state.correlation_index, :memory)
    
    Map.merge(state.stats, %{
      memory_usage: memory_usage,
      events_table_size: :ets.info(state.events_table, :size),
      ast_index_size: :ets.info(state.ast_index, :size),
      correlation_index_size: :ets.info(state.correlation_index, :size)
    })
  end
  
  defp perform_cleanup(state) do
    # TODO: Implement cleanup logic based on max_events config
    # For now, just return the state unchanged
    state
  end
  
  defp schedule_cleanup(interval) do
    Process.send_after(self(), :cleanup, interval)
  end
end 