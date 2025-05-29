defmodule ElixirScope.Capture.TemporalBridgeEnhancement.CacheManager do
  @moduledoc """
  Cache management for TemporalBridgeEnhancement.

  Handles ETS table creation, caching operations, and cache invalidation
  for enhanced state reconstruction and execution traces.
  """

  @ast_state_cache :temporal_bridge_ast_state_cache
  @execution_trace_cache :temporal_bridge_execution_trace_cache

  # Cache TTL (2 minutes)
  @cache_ttl 120_000

  @doc """
  Creates an ETS table, handling existing tables gracefully.
  """
  @spec create_table(atom()) :: atom()
  def create_table(table_name) do
    try do
      :ets.new(table_name, [:named_table, :public, :set, {:read_concurrency, true}])
    rescue
      ArgumentError ->
        # Table already exists, clear it
        :ets.delete_all_objects(table_name)
        table_name
    end
  end

  @doc """
  Initializes all cache tables.
  """
  @spec init_caches() :: :ok
  def init_caches() do
    create_table(@ast_state_cache)
    create_table(@execution_trace_cache)
    :ok
  end

  @doc """
  Gets a cached state with TTL check.
  """
  @spec get_cached_state(String.t(), non_neg_integer()) ::
    {:hit, any()} | {:miss, :not_found | :expired | :table_not_found}
  def get_cached_state(session_id, timestamp) do
    cache_key = "#{session_id}:#{timestamp}"

    try do
      case :ets.lookup(@ast_state_cache, cache_key) do
        [{^cache_key, {enhanced_state, cached_timestamp}}] ->
          if System.monotonic_time(:millisecond) - cached_timestamp < @cache_ttl do
            {:hit, enhanced_state}
          else
            :ets.delete(@ast_state_cache, cache_key)
            {:miss, :expired}
          end

        [] ->
          {:miss, :not_found}
      end
    rescue
      ArgumentError ->
        {:miss, :table_not_found}
    end
  end

  @doc """
  Caches a state with current timestamp.
  """
  @spec cache_state(String.t(), non_neg_integer(), any()) :: :ok
  def cache_state(session_id, timestamp, enhanced_state) do
    cache_key = "#{session_id}:#{timestamp}"
    cache_timestamp = System.monotonic_time(:millisecond)

    try do
      :ets.insert(@ast_state_cache, {cache_key, {enhanced_state, cache_timestamp}})
      :ok
    rescue
      ArgumentError ->
        # Table doesn't exist, create it and try again
        create_table(@ast_state_cache)
        :ets.insert(@ast_state_cache, {cache_key, {enhanced_state, cache_timestamp}})
        :ok
    end
  end

  @doc """
  Gets a cached execution trace with TTL check.
  """
  @spec get_cached_trace(String.t(), non_neg_integer(), non_neg_integer()) ::
    {:hit, any()} | {:miss, :not_found | :expired | :table_not_found}
  def get_cached_trace(session_id, start_time, end_time) do
    cache_key = "trace:#{session_id}:#{start_time}:#{end_time}"

    try do
      case :ets.lookup(@execution_trace_cache, cache_key) do
        [{^cache_key, {trace, cached_timestamp}}] ->
          if System.monotonic_time(:millisecond) - cached_timestamp < @cache_ttl do
            {:hit, trace}
          else
            :ets.delete(@execution_trace_cache, cache_key)
            {:miss, :expired}
          end

        [] ->
          {:miss, :not_found}
      end
    rescue
      ArgumentError ->
        {:miss, :table_not_found}
    end
  end

  @doc """
  Caches an execution trace with current timestamp.
  """
  @spec cache_trace(String.t(), non_neg_integer(), non_neg_integer(), any()) :: :ok
  def cache_trace(session_id, start_time, end_time, trace) do
    cache_key = "trace:#{session_id}:#{start_time}:#{end_time}"
    cache_timestamp = System.monotonic_time(:millisecond)

    try do
      :ets.insert(@execution_trace_cache, {cache_key, {trace, cache_timestamp}})
      :ok
    rescue
      ArgumentError ->
        # Table doesn't exist, create it and try again
        create_table(@execution_trace_cache)
        :ets.insert(@execution_trace_cache, {cache_key, {trace, cache_timestamp}})
        :ok
    end
  end

  @doc """
  Clears all caches.
  """
  @spec clear_all_caches() :: :ok
  def clear_all_caches() do
    try do
      :ets.delete_all_objects(@ast_state_cache)
    rescue
      ArgumentError -> :ok  # Table doesn't exist, that's fine
    end

    try do
      :ets.delete_all_objects(@execution_trace_cache)
    rescue
      ArgumentError -> :ok  # Table doesn't exist, that's fine
    end

    :ok
  end

  @doc """
  Gets cache statistics.
  """
  @spec get_cache_stats() :: map()
  def get_cache_stats() do
    state_cache_size = try do
      :ets.info(@ast_state_cache, :size) || 0
    rescue
      ArgumentError -> 0
    end

    trace_cache_size = try do
      :ets.info(@execution_trace_cache, :size) || 0
    rescue
      ArgumentError -> 0
    end

    state_cache_memory = try do
      :ets.info(@ast_state_cache, :memory) || 0
    rescue
      ArgumentError -> 0
    end

    trace_cache_memory = try do
      :ets.info(@execution_trace_cache, :memory) || 0
    rescue
      ArgumentError -> 0
    end

    %{
      state_cache_size: state_cache_size,
      trace_cache_size: trace_cache_size,
      state_cache_memory: state_cache_memory,
      trace_cache_memory: trace_cache_memory
    }
  end
end
