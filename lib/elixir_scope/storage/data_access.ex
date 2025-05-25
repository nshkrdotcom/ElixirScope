defmodule ElixirScope.Storage.DataAccess do
  @moduledoc """
  High-performance ETS-based storage for ElixirScope events.
  
  Provides multiple indexes for fast querying across different dimensions:
  - Primary index: Event ID -> Event
  - Temporal index: Timestamp -> Event ID
  - Process index: PID -> [Event IDs]
  - Function index: {Module, Function} -> [Event IDs]
  - Correlation index: Correlation ID -> [Event IDs]
  
  Designed for high write throughput and fast range queries.
  """

  alias ElixirScope.Events
  alias ElixirScope.Utils

  @type table_name :: atom()
  @type event_id :: binary()
  @type query_options :: keyword()

  defstruct [
    :name,
    :primary_table,
    :temporal_index,
    :process_index,
    :function_index,
    :correlation_index,
    :stats_table
  ]

  @type t :: %__MODULE__{
    name: table_name(),
    primary_table: :ets.tid(),
    temporal_index: :ets.tid(),
    process_index: :ets.tid(),
    function_index: :ets.tid(),
    correlation_index: :ets.tid(),
    stats_table: :ets.tid()
  }

  # Table configurations
  @primary_opts [:set, :public, {:read_concurrency, true}, {:write_concurrency, true}]
  @index_opts [:bag, :public, {:read_concurrency, true}, {:write_concurrency, true}]
  @stats_opts [:set, :public, {:read_concurrency, true}, {:write_concurrency, true}]

  @doc """
  Creates a new data access instance with ETS tables.
  
  ## Options
  - `:name` - Base name for the tables (default: generates unique name)
  - `:max_events` - Maximum number of events to store (default: 1_000_000)
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, term()}
  def new(opts \\ []) do
    name = Keyword.get(opts, :name, generate_table_name())
    max_events = Keyword.get(opts, :max_events, 1_000_000)
    
    try do
      # Create primary event storage table
      primary_table = :ets.new(:"#{name}_events", @primary_opts)
      
      # Create index tables
      temporal_index = :ets.new(:"#{name}_temporal", @index_opts)
      process_index = :ets.new(:"#{name}_process", @index_opts)
      function_index = :ets.new(:"#{name}_function", @index_opts)
      correlation_index = :ets.new(:"#{name}_correlation", @index_opts)
      
      # Create stats table
      stats_table = :ets.new(:"#{name}_stats", @stats_opts)
      
      # Initialize stats
      :ets.insert(stats_table, [
        {:total_events, 0},
        {:max_events, max_events},
        {:oldest_timestamp, nil},
        {:newest_timestamp, nil},
        {:last_cleanup, Utils.monotonic_timestamp()}
      ])
      
      storage = %__MODULE__{
        name: name,
        primary_table: primary_table,
        temporal_index: temporal_index,
        process_index: process_index,
        function_index: function_index,
        correlation_index: correlation_index,
        stats_table: stats_table
      }
      
      {:ok, storage}
    rescue
      error -> {:error, {:table_creation_failed, error}}
    end
  end

  @doc """
  Stores an event in the data access layer.
  
  Automatically creates all necessary indexes for fast querying.
  """
  @spec store_event(t(), Events.event()) :: :ok | {:error, term()}
  def store_event(%__MODULE__{} = storage, event) do
    try do
      event_id = event.id
      timestamp = event.timestamp
      
      # Store in primary table
      :ets.insert(storage.primary_table, {event_id, event})
      
      # Update temporal index
      :ets.insert(storage.temporal_index, {timestamp, event_id})
      
      # Update process index if event has PID
      case extract_pid(event) do
        nil -> :ok
        pid -> :ets.insert(storage.process_index, {pid, event_id})
      end
      
      # Update function index if event has function info
      case extract_function_info(event) do
        nil -> :ok
        {module, function} -> :ets.insert(storage.function_index, {{module, function}, event_id})
      end
      
      # Update correlation index if event has correlation ID
      case extract_correlation_id(event) do
        nil -> :ok
        correlation_id -> :ets.insert(storage.correlation_index, {correlation_id, event_id})
      end
      
      # Update statistics
      update_stats(storage, timestamp)
      
      :ok
    rescue
      error -> {:error, {:storage_failed, error}}
    end
  end

  @doc """
  Stores multiple events in batch for better performance.
  """
  @spec store_events(t(), [Events.event()]) :: {:ok, non_neg_integer()} | {:error, term()}
  def store_events(%__MODULE__{} = storage, events) when is_list(events) do
    # Handle empty list case
    if events == [] do
      {:ok, 0}
    else
      try do
        # Prepare all inserts
        primary_inserts = Enum.map(events, &{&1.id, &1})
        temporal_inserts = Enum.map(events, &{&1.timestamp, &1.id})
        
        process_inserts = events
          |> Enum.map(&{extract_pid(&1), &1.id})
          |> Enum.reject(&(elem(&1, 0) == nil))
        
        function_inserts = events
          |> Enum.map(&{extract_function_info(&1), &1.id})
          |> Enum.reject(&(elem(&1, 0) == nil))
        
        correlation_inserts = events
          |> Enum.map(&{extract_correlation_id(&1), &1.id})
          |> Enum.reject(&(elem(&1, 0) == nil))
        
        # Batch insert into all tables
        :ets.insert(storage.primary_table, primary_inserts)
        :ets.insert(storage.temporal_index, temporal_inserts)
        
        if length(process_inserts) > 0 do
          :ets.insert(storage.process_index, process_inserts)
        end
        
        if length(function_inserts) > 0 do
          :ets.insert(storage.function_index, function_inserts)
        end
        
        if length(correlation_inserts) > 0 do
          :ets.insert(storage.correlation_index, correlation_inserts)
        end
        
        # Update stats with newest timestamp and event count
        newest_timestamp = events |> Enum.map(& &1.timestamp) |> Enum.max()
        update_stats_batch(storage, newest_timestamp, length(events))
        
        {:ok, length(events)}
      rescue
        error -> {:error, {:batch_storage_failed, error}}
      end
    end
  end

  @doc """
  Retrieves an event by its ID.
  """
  @spec get_event(t(), event_id()) :: {:ok, Events.event()} | {:error, :not_found}
  def get_event(%__MODULE__{} = storage, event_id) do
    case :ets.lookup(storage.primary_table, event_id) do
      [{^event_id, event}] -> {:ok, event}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Queries events by time range.
  
  ## Options
  - `:limit` - Maximum number of events to return (default: 1000)
  - `:order` - `:asc` or `:desc` (default: `:asc`)
  """
  @spec query_by_time_range(t(), non_neg_integer(), non_neg_integer(), query_options()) :: 
    {:ok, [Events.event()]} | {:error, term()}
  def query_by_time_range(%__MODULE__{} = storage, start_time, end_time, opts \\ []) do
    limit = Keyword.get(opts, :limit, 1000)
    order = Keyword.get(opts, :order, :asc)
    
    try do
      # Get event IDs in time range
      event_ids = get_events_in_time_range(storage.temporal_index, start_time, end_time, limit, order)
      
      # Fetch actual events
      events = Enum.map(event_ids, fn event_id ->
        [{^event_id, event}] = :ets.lookup(storage.primary_table, event_id)
        event
      end)
      
      {:ok, events}
    rescue
      error -> {:error, {:query_failed, error}}
    end
  end

  @doc """
  Queries events by process ID.
  """
  @spec query_by_process(t(), pid(), query_options()) :: {:ok, [Events.event()]} | {:error, term()}
  def query_by_process(%__MODULE__{} = storage, pid, opts \\ []) do
    limit = Keyword.get(opts, :limit, 1000)
    
    try do
      # Get event IDs for this process
      event_ids = :ets.lookup(storage.process_index, pid)
        |> Enum.map(&elem(&1, 1))
        |> Enum.take(limit)
      
      # Fetch actual events
      events = Enum.map(event_ids, fn event_id ->
        [{^event_id, event}] = :ets.lookup(storage.primary_table, event_id)
        event
      end)
      
      {:ok, events}
    rescue
      error -> {:error, {:query_failed, error}}
    end
  end

  @doc """
  Queries events by function.
  """
  @spec query_by_function(t(), module(), atom(), query_options()) :: {:ok, [Events.event()]} | {:error, term()}
  def query_by_function(%__MODULE__{} = storage, module, function, opts \\ []) do
    limit = Keyword.get(opts, :limit, 1000)
    
    try do
      # Get event IDs for this function
      event_ids = :ets.lookup(storage.function_index, {module, function})
        |> Enum.map(&elem(&1, 1))
        |> Enum.take(limit)
      
      # Fetch actual events
      events = Enum.map(event_ids, fn event_id ->
        [{^event_id, event}] = :ets.lookup(storage.primary_table, event_id)
        event
      end)
      
      {:ok, events}
    rescue
      error -> {:error, {:query_failed, error}}
    end
  end

  @doc """
  Queries events by correlation ID.
  """
  @spec query_by_correlation(t(), term(), query_options()) :: {:ok, [Events.event()]} | {:error, term()}
  def query_by_correlation(%__MODULE__{} = storage, correlation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 1000)
    
    try do
      # Get event IDs for this correlation
      event_ids = :ets.lookup(storage.correlation_index, correlation_id)
        |> Enum.map(&elem(&1, 1))
        |> Enum.take(limit)
      
      # Fetch actual events
      events = Enum.map(event_ids, fn event_id ->
        [{^event_id, event}] = :ets.lookup(storage.primary_table, event_id)
        event
      end)
      
      {:ok, events}
    rescue
      error -> {:error, {:query_failed, error}}
    end
  end

  @doc """
  Gets storage statistics.
  """
  @spec get_stats(t()) :: %{
    total_events: non_neg_integer(),
    max_events: non_neg_integer(),
    oldest_timestamp: non_neg_integer() | nil,
    newest_timestamp: non_neg_integer() | nil,
    memory_usage: non_neg_integer()
  }
  def get_stats(%__MODULE__{} = storage) do
    stats = :ets.tab2list(storage.stats_table) |> Map.new()
    
    memory_usage = 
      :ets.info(storage.primary_table, :memory) +
      :ets.info(storage.temporal_index, :memory) +
      :ets.info(storage.process_index, :memory) +
      :ets.info(storage.function_index, :memory) +
      :ets.info(storage.correlation_index, :memory)
    
    Map.put(stats, :memory_usage, memory_usage * :erlang.system_info(:wordsize))
  end

  @doc """
  Cleans up old events to maintain memory bounds.
  
  Removes events older than the specified timestamp.
  """
  @spec cleanup_old_events(t(), non_neg_integer()) :: {:ok, non_neg_integer()} | {:error, term()}
  def cleanup_old_events(%__MODULE__{} = storage, cutoff_timestamp) do
    try do
      # Find old event IDs
      old_event_ids = get_events_before_timestamp(storage.temporal_index, cutoff_timestamp)
      
      # Remove from all tables
      Enum.each(old_event_ids, fn event_id ->
        # Get event to extract index keys
        case :ets.lookup(storage.primary_table, event_id) do
          [{^event_id, event}] ->
            # Remove from primary table
            :ets.delete(storage.primary_table, event_id)
            
            # Remove from indexes
            :ets.delete_object(storage.temporal_index, {event.timestamp, event_id})
            
            if pid = extract_pid(event) do
              :ets.delete_object(storage.process_index, {pid, event_id})
            end
            
            if function_info = extract_function_info(event) do
              :ets.delete_object(storage.function_index, {function_info, event_id})
            end
            
            if correlation_id = extract_correlation_id(event) do
              :ets.delete_object(storage.correlation_index, {correlation_id, event_id})
            end
            
          [] ->
            # Event already removed
            :ok
        end
      end)
      
      # Update stats
      :ets.update_counter(storage.stats_table, :total_events, -length(old_event_ids))
      :ets.insert(storage.stats_table, {:last_cleanup, Utils.monotonic_timestamp()})
      
      {:ok, length(old_event_ids)}
    rescue
      error -> {:error, {:cleanup_failed, error}}
    end
  end

  @doc """
  Destroys the storage and cleans up all ETS tables.
  """
  @spec destroy(t()) :: :ok
  def destroy(%__MODULE__{} = storage) do
    :ets.delete(storage.primary_table)
    :ets.delete(storage.temporal_index)
    :ets.delete(storage.process_index)
    :ets.delete(storage.function_index)
    :ets.delete(storage.correlation_index)
    :ets.delete(storage.stats_table)
    :ok
  end

  @doc """
  Queries events since a given timestamp.
  """
  @spec get_events_since(non_neg_integer()) :: [Events.event()]
  def get_events_since(since_timestamp) do
    # This assumes we have a global storage instance - in practice this would be managed by a GenServer
    case get_default_storage() do
      {:ok, storage} ->
        case query_by_time_range(storage, since_timestamp, Utils.monotonic_timestamp(), limit: 10_000) do
          {:ok, events} -> events
          {:error, _} -> []
        end
      {:error, _} -> []
    end
  end

  @doc """
  Checks if an event exists by ID.
  """
  @spec event_exists?(event_id()) :: boolean()
  def event_exists?(event_id) do
    case get_default_storage() do
      {:ok, storage} ->
        case get_event(storage, event_id) do
          {:ok, _} -> true
          {:error, :not_found} -> false
        end
      {:error, _} -> false
    end
  end

  @doc """
  Stores multiple events (simplified interface).
  """
  @spec store_events([Events.event()]) :: :ok | {:error, term()}
  def store_events(events) when is_list(events) do
    case get_default_storage() do
      {:ok, storage} ->
        case store_events(storage, events) do
          {:ok, _count} -> :ok
          error -> error
        end
      error -> error
    end
  end

  @doc """
  Gets the current instrumentation plan.
  """
  @spec get_instrumentation_plan() :: {:ok, map()} | {:error, :not_found}
  def get_instrumentation_plan() do
    case get_default_storage() do
      {:ok, storage} ->
        case :ets.lookup(storage.stats_table, :instrumentation_plan) do
          [{:instrumentation_plan, plan}] -> {:ok, plan}
          [] -> {:error, :not_found}
        end
      error -> error
    end
  end

  @doc """
  Stores an instrumentation plan.
  """
  @spec store_instrumentation_plan(map()) :: :ok | {:error, term()}
  def store_instrumentation_plan(plan) do
    case get_default_storage() do
      {:ok, storage} ->
        :ets.insert(storage.stats_table, {:instrumentation_plan, plan})
        :ok
      error -> error
    end
  end

  # Default storage management (simplified - in production this would be a GenServer)
  defp get_default_storage() do
    case :persistent_term.get(:elixir_scope_default_storage, nil) do
      nil ->
        case new(name: :elixir_scope_default) do
          {:ok, storage} ->
            :persistent_term.put(:elixir_scope_default_storage, storage)
            {:ok, storage}
          error -> error
        end
      storage -> {:ok, storage}
    end
  end

  # Private functions

  defp extract_pid(%Events.FunctionExecution{caller_pid: pid}), do: pid
  defp extract_pid(%Events.ProcessEvent{pid: pid}), do: pid
  defp extract_pid(%Events.MessageEvent{from_pid: pid}), do: pid
  # StateChange events are wrapped in base event structure, extract from wrapper
  defp extract_pid(%ElixirScope.Events{event_type: :state_change, pid: pid}), do: pid
  # ErrorEvent events are wrapped in base event structure, extract from wrapper
  defp extract_pid(%ElixirScope.Events{event_type: :error, pid: pid}), do: pid
  defp extract_pid(_), do: nil

  defp extract_function_info(%Events.FunctionExecution{module: module, function: function}) 
    when not is_nil(module) and not is_nil(function), do: {module, function}
  defp extract_function_info(_), do: nil

  defp extract_correlation_id(%Events.FunctionExecution{correlation_id: id}), do: id
  defp extract_correlation_id(_), do: nil

  defp update_stats(storage, timestamp) do
    :ets.update_counter(storage.stats_table, :total_events, 1)
    
    # Update oldest timestamp if this is the first event
    case :ets.lookup(storage.stats_table, :oldest_timestamp) do
      [{:oldest_timestamp, nil}] ->
        :ets.insert(storage.stats_table, {:oldest_timestamp, timestamp})
      _ ->
        :ok
    end
    
    # Always update newest timestamp
    :ets.insert(storage.stats_table, {:newest_timestamp, timestamp})
  end

  defp update_stats_batch(storage, timestamp, count) do
    :ets.update_counter(storage.stats_table, :total_events, count)
    
    # Update oldest timestamp if this is the first event
    case :ets.lookup(storage.stats_table, :oldest_timestamp) do
      [{:oldest_timestamp, nil}] ->
        :ets.insert(storage.stats_table, {:oldest_timestamp, timestamp})
      _ ->
        :ok
    end
    
    # Always update newest timestamp
    :ets.insert(storage.stats_table, {:newest_timestamp, timestamp})
  end

  defp get_events_in_time_range(temporal_table, start_time, end_time, limit, order) do
    # This is a simplified implementation
    # In a real system, you'd want more efficient range queries
    all_entries = :ets.tab2list(temporal_table)
    
    filtered_entries = all_entries
      |> Enum.filter(fn {timestamp, _} -> timestamp >= start_time and timestamp <= end_time end)
    
    sorted_entries = case order do
      :asc -> Enum.sort_by(filtered_entries, fn {timestamp, _} -> timestamp end)
      :desc -> Enum.sort_by(filtered_entries, fn {timestamp, _} -> timestamp end, :desc)
    end
    
    sorted_entries
      |> Enum.take(limit)
      |> Enum.map(&elem(&1, 1))
  end

  defp get_events_before_timestamp(temporal_table, cutoff_timestamp) do
    :ets.tab2list(temporal_table)
      |> Enum.filter(fn {timestamp, _} -> timestamp < cutoff_timestamp end)
      |> Enum.map(&elem(&1, 1))
  end

  defp generate_table_name do
    :"data_access_#{System.unique_integer([:positive])}"
  end
end 