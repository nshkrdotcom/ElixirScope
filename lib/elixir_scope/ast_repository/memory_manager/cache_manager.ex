defmodule ElixirScope.ASTRepository.MemoryManager.CacheManager do
  @moduledoc """
  Multi-level caching system with LRU eviction for the AST Repository.

  Manages query caches, analysis caches, and CPG caches with different
  TTLs and eviction policies.
  """

  use GenServer
  require Logger

  # Cache configuration
  @query_cache_ttl 60_000           # 1 minute
  @analysis_cache_ttl 300_000       # 5 minutes
  @cpg_cache_ttl 600_000            # 10 minutes
  @max_cache_entries 1000

  # ETS tables for caching
  @query_cache_table :ast_repo_query_cache
  @analysis_cache_table :ast_repo_analysis_cache
  @cpg_cache_table :ast_repo_cpg_cache

  @type cache_stats :: %{
    query_cache_size: non_neg_integer(),
    analysis_cache_size: non_neg_integer(),
    cpg_cache_size: non_neg_integer(),
    total_cache_hits: non_neg_integer(),
    total_cache_misses: non_neg_integer(),
    cache_hit_ratio: float(),
    evictions: non_neg_integer()
  }

  defstruct [
    :cache_hits,
    :cache_misses,
    :evictions
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    init_cache_tables()

    state = %__MODULE__{
      cache_hits: 0,
      cache_misses: 0,
      evictions: 0
    }

    {:ok, state}
  end

  @doc """
  Gets a value from the specified cache.
  """
  @spec get(atom(), term()) :: {:ok, term()} | :miss
  def get(cache_type, key) do
    GenServer.call(__MODULE__, {:get, cache_type, key})
  end

  @doc """
  Puts a value in the specified cache.
  """
  @spec put(atom(), term(), term()) :: :ok
  def put(cache_type, key, value) do
    GenServer.call(__MODULE__, {:put, cache_type, key, value})
  end

  @doc """
  Clears the specified cache.
  """
  @spec clear(atom()) :: :ok
  def clear(cache_type) do
    GenServer.call(__MODULE__, {:clear, cache_type})
  end

  @doc """
  Gets cache statistics.
  """
  @spec get_stats() :: cache_stats()
  def get_stats() do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Gets initial cache statistics structure.
  """
  @spec get_initial_stats() :: cache_stats()
  def get_initial_stats() do
    %{
      query_cache_size: 0,
      analysis_cache_size: 0,
      cpg_cache_size: 0,
      total_cache_hits: 0,
      total_cache_misses: 0,
      cache_hit_ratio: 0.0,
      evictions: 0
    }
  end

  @doc """
  Configures cache settings for a specific cache type.
  """
  @spec configure_cache(atom(), keyword()) :: :ok | {:error, term()}
  def configure_cache(cache_type, opts) do
    GenServer.call(__MODULE__, {:configure_cache, cache_type, opts})
  end

  # GenServer Callbacks

  def handle_call({:get, cache_type, key}, _from, state) do
    case cache_get_internal(cache_type, key) do
      {:ok, value} ->
        new_state = %{state | cache_hits: state.cache_hits + 1}
        {:reply, {:ok, value}, new_state}
      :miss ->
        new_state = %{state | cache_misses: state.cache_misses + 1}
        {:reply, :miss, new_state}
    end
  end

  def handle_call({:put, cache_type, key, value}, _from, state) do
    evictions = cache_put_internal(cache_type, key, value)
    new_state = %{state | evictions: state.evictions + evictions}
    {:reply, :ok, new_state}
  end

  def handle_call({:clear, cache_type}, _from, state) do
    cache_clear_internal(cache_type)
    {:reply, :ok, state}
  end

  def handle_call(:get_stats, _from, state) do
    stats = %{
      query_cache_size: get_cache_size(@query_cache_table),
      analysis_cache_size: get_cache_size(@analysis_cache_table),
      cpg_cache_size: get_cache_size(@cpg_cache_table),
      total_cache_hits: state.cache_hits,
      total_cache_misses: state.cache_misses,
      cache_hit_ratio: calculate_hit_ratio(state.cache_hits, state.cache_misses),
      evictions: state.evictions
    }
    {:reply, stats, state}
  end

  def handle_call({:configure_cache, _cache_type, _opts}, _from, state) do
    # Cache configuration could be implemented here for runtime changes
    # For now, configuration is handled during initialization
    {:reply, :ok, state}
  end

  # Private Implementation

  defp init_cache_tables() do
    # Query cache: {key, value, timestamp, access_count}
    :ets.new(@query_cache_table, [:named_table, :public, :set, {:read_concurrency, true}])

    # Analysis cache: {key, value, timestamp, access_count}
    :ets.new(@analysis_cache_table, [:named_table, :public, :set, {:read_concurrency, true}])

    # CPG cache: {key, value, timestamp, access_count}
    :ets.new(@cpg_cache_table, [:named_table, :public, :set, {:read_concurrency, true}])
  end

  defp cache_get_internal(cache_type, key) do
    try do
      table = cache_table_for_type(cache_type)
      case :ets.lookup(table, key) do
        [{^key, value, timestamp, _access_count}] ->
          ttl = cache_ttl_for_type(cache_type)
          if System.monotonic_time(:millisecond) - timestamp < ttl do
            # Update access count and timestamp
            :ets.update_counter(table, key, {4, 1})
            :ets.update_element(table, key, {3, System.monotonic_time(:millisecond)})
            {:ok, value}
          else
            # Expired entry
            :ets.delete(table, key)
            :miss
          end
        [] ->
          :miss
      end
    rescue
      _error ->
        :miss
    end
  end

  defp cache_put_internal(cache_type, key, value) do
    try do
      table = cache_table_for_type(cache_type)
      timestamp = System.monotonic_time(:millisecond)

      # Check cache size and evict if necessary
      cache_size = :ets.info(table, :size)
      evictions = if cache_size >= @max_cache_entries do
        evict_lru_entries(table, div(@max_cache_entries, 10))  # Evict 10%
      else
        0
      end

      :ets.insert(table, {key, value, timestamp, 1})
      evictions
    rescue
      _error ->
        0  # Fail silently for cache operations
    end
  end

  defp cache_clear_internal(cache_type) do
    try do
      table = cache_table_for_type(cache_type)
      :ets.delete_all_objects(table)
      :ok
    rescue
      _error ->
        :ok  # Fail silently for cache operations
    end
  end

  defp evict_lru_entries(table, count) do
    # Get entries sorted by access time (oldest first)
    entries = :ets.tab2list(table)
    |> Enum.sort_by(fn {_key, _value, timestamp, _access_count} -> timestamp end)
    |> Enum.take(count)

    # Remove oldest entries
    Enum.each(entries, fn {key, _value, _timestamp, _access_count} ->
      :ets.delete(table, key)
    end)

    length(entries)
  end

  defp get_cache_size(table) do
    case :ets.info(table, :size) do
      :undefined -> 0
      size -> size
    end
  end

  defp calculate_hit_ratio(hits, misses) do
    total = hits + misses
    if total > 0 do
      hits / total
    else
      0.0
    end
  end

  defp cache_table_for_type(:query), do: @query_cache_table
  defp cache_table_for_type(:analysis), do: @analysis_cache_table
  defp cache_table_for_type(:cpg), do: @cpg_cache_table
  defp cache_table_for_type(_), do: @query_cache_table  # Default fallback

  defp cache_ttl_for_type(:query), do: @query_cache_ttl
  defp cache_ttl_for_type(:analysis), do: @analysis_cache_ttl
  defp cache_ttl_for_type(:cpg), do: @cpg_cache_ttl
  defp cache_ttl_for_type(_), do: @query_cache_ttl  # Default fallback
end
