defmodule ElixirScope.ASTRepository.RuntimeCorrelator.CacheManager do
  @moduledoc """
  Cache management for the RuntimeCorrelator system.

  Handles ETS table creation, cache operations, and TTL management
  for correlation data and execution traces.
  """

  @context_cache :runtime_correlator_context_cache
  @trace_cache :runtime_correlator_trace_cache

  # Cache TTL (5 minutes)
  @cache_ttl 300_000

  @doc """
  Initializes all ETS tables for caching.
  """
  def init_tables do
    init_table(@context_cache, "context cache")
    init_table(@trace_cache, "trace cache")
  end

  @doc """
  Generates a cache key for event correlation.
  """
  def generate_correlation_cache_key(event) when is_nil(event) do
    "nil_event_#{System.unique_integer()}"
  end

  def generate_correlation_cache_key(event) when is_map(event) do
    module = Map.get(event, :module, "unknown")
    function = Map.get(event, :function, "unknown")
    arity = Map.get(event, :arity, 0)
    line = Map.get(event, :line, 0)

    "#{module}.#{function}/#{arity}:#{line}"
  end

  def generate_correlation_cache_key(_event) do
    "invalid_event_#{System.unique_integer()}"
  end

  @doc """
  Gets an item from the context cache.
  """
  def get_from_context_cache(cache_key) do
    case :ets.lookup(@context_cache, cache_key) do
      [{^cache_key, {ast_context, timestamp}}] ->
        if System.monotonic_time(:millisecond) - timestamp < @cache_ttl do
          {:ok, ast_context}
        else
          # Cache expired
          :ets.delete(@context_cache, cache_key)
          :cache_miss
        end

      [] ->
        :cache_miss
    end
  end

  @doc """
  Puts an item in the context cache.
  """
  def put_in_context_cache(cache_key, ast_context) do
    timestamp = System.monotonic_time(:millisecond)
    :ets.insert(@context_cache, {cache_key, {ast_context, timestamp}})
  end

  @doc """
  Gets an item from the trace cache.
  """
  def get_from_trace_cache(cache_key) do
    case :ets.lookup(@trace_cache, cache_key) do
      [{^cache_key, {trace, timestamp}}] ->
        if System.monotonic_time(:millisecond) - timestamp < @cache_ttl do
          {:ok, trace}
        else
          # Cache expired
          :ets.delete(@trace_cache, cache_key)
          :cache_miss
        end

      [] ->
        :cache_miss
    end
  end

  @doc """
  Puts an item in the trace cache.
  """
  def put_in_trace_cache(cache_key, trace) do
    timestamp = System.monotonic_time(:millisecond)
    :ets.insert(@trace_cache, {cache_key, {trace, timestamp}})
  end

  @doc """
  Clears all caches.
  """
  def clear_all_caches do
    :ets.delete_all_objects(@context_cache)
    :ets.delete_all_objects(@trace_cache)
  end

  @doc """
  Gets cache statistics.
  """
  def get_cache_stats do
    context_size = :ets.info(@context_cache, :size) || 0
    trace_size = :ets.info(@trace_cache, :size) || 0

    %{
      context_cache_size: context_size,
      trace_cache_size: trace_size,
      total_size: context_size + trace_size
    }
  end

  @doc """
  Performs cache cleanup by removing expired entries.
  """
  def cleanup_expired_entries do
    current_time = System.monotonic_time(:millisecond)

    cleanup_table(@context_cache, current_time)
    cleanup_table(@trace_cache, current_time)
  end

  # Private Functions

  defp init_table(table_name, description) do
    try do
      :ets.new(table_name, [:named_table, :public, :set, {:read_concurrency, true}])
    rescue
      ArgumentError ->
        # Table already exists, clear it
        :ets.delete_all_objects(table_name)
    end
  end

  defp cleanup_table(table_name, current_time) do
    # Get all keys that are expired
    expired_keys = :ets.select(table_name, [
      {{:"$1", {:"$2", :"$3"}},
       [{:<, {:+, :"$3", @cache_ttl}, current_time}],
       [:"$1"]}
    ])

    # Delete expired entries
    Enum.each(expired_keys, fn key ->
      :ets.delete(table_name, key)
    end)

    length(expired_keys)
  end
end
