defmodule ElixirScope.ASTRepository.QueryBuilder.Cache do
  @moduledoc """
  Handles query result caching with TTL and cleanup.
  """

  use GenServer
  require Logger

  @table_name :query_cache
  @performance_table :query_performance

  # Query cache TTL in milliseconds (5 minutes)
  @cache_ttl 300_000

  defstruct [
    :cache_stats,
    :performance_stats,
    :cleanup_timer
  ]

  # GenServer API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # Create ETS tables for caching
    :ets.new(@table_name, [:named_table, :public, :set, {:read_concurrency, true}])
    :ets.new(@performance_table, [:named_table, :public, :set, {:read_concurrency, true}])

    # Schedule cache cleanup
    timer = Process.send_after(self(), :cleanup_cache, @cache_ttl)

    state = %__MODULE__{
      cache_stats: %{hits: 0, misses: 0},
      performance_stats: %{total_queries: 0, avg_time: 0},
      cleanup_timer: timer
    }

    Logger.info("QueryBuilder Cache started")
    {:ok, state}
  end

  def handle_info(:cleanup_cache, state) do
    cleanup_expired_cache()
    timer = Process.send_after(self(), :cleanup_cache, @cache_ttl)
    {:noreply, %{state | cleanup_timer: timer}}
  end

  def handle_call({:get, cache_key}, _from, state) do
    case check_cache(cache_key) do
      {:hit, result} ->
        updated_stats = update_cache_stats(state.cache_stats, :hit)
        {:reply, {:hit, result}, %{state | cache_stats: updated_stats}}

      :miss ->
        updated_stats = update_cache_stats(state.cache_stats, :miss)
        {:reply, :miss, %{state | cache_stats: updated_stats}}
    end
  end

  def handle_call({:put, cache_key, result}, _from, state) do
    cache_result(cache_key, result)
    {:reply, :ok, state}
  end

  def handle_call(:get_stats, _from, state) do
    stats = %{
      cache: state.cache_stats,
      performance: state.performance_stats
    }
    {:reply, {:ok, stats}, state}
  end

  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(@table_name)
    updated_stats = %{hits: 0, misses: 0}
    {:reply, :ok, %{state | cache_stats: updated_stats}}
  end

  def handle_call({:record_performance, execution_time}, _from, state) do
    updated_stats = update_performance_stats(state.performance_stats, execution_time)
    {:reply, :ok, %{state | performance_stats: updated_stats}}
  end

  # Public API

  @doc """
  Gets a cached result for the given cache key.
  """
  @spec get(String.t()) :: {:hit, term()} | :miss
  def get(cache_key) do
    GenServer.call(__MODULE__, {:get, cache_key})
  end

  @doc """
  Caches a result with the given cache key.
  """
  @spec put(String.t(), term()) :: :ok
  def put(cache_key, result) do
    GenServer.call(__MODULE__, {:put, cache_key, result})
  end

  @doc """
  Gets cache and performance statistics.
  """
  @spec get_stats() :: {:ok, map()}
  def get_stats() do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Clears all cached results.
  """
  @spec clear() :: :ok
  def clear() do
    GenServer.call(__MODULE__, :clear)
  end

  @doc """
  Records the execution time of a query for performance tracking.
  """
  @spec record_performance(non_neg_integer()) :: :ok
  def record_performance(execution_time) do
    GenServer.call(__MODULE__, {:record_performance, execution_time})
  end

  # Private helper functions

  defp check_cache(cache_key) do
    case :ets.lookup(@table_name, cache_key) do
      [{^cache_key, result, timestamp}] ->
        if System.monotonic_time(:millisecond) - timestamp < @cache_ttl do
          {:hit, result}
        else
          :ets.delete(@table_name, cache_key)
          :miss
        end

      [] -> :miss
    end
  end

  defp cache_result(cache_key, result) do
    timestamp = System.monotonic_time(:millisecond)
    :ets.insert(@table_name, {cache_key, result, timestamp})
  end

  defp cleanup_expired_cache() do
    current_time = System.monotonic_time(:millisecond)

    :ets.foldl(fn {key, _result, timestamp}, acc ->
      if current_time - timestamp >= @cache_ttl do
        :ets.delete(@table_name, key)
      end
      acc
    end, nil, @table_name)
  end

  defp update_cache_stats(stats, :hit) do
    %{stats | hits: stats.hits + 1}
  end

  defp update_cache_stats(stats, :miss) do
    %{stats | misses: stats.misses + 1}
  end

  defp update_performance_stats(stats, execution_time) do
    new_total = stats.total_queries + 1
    new_avg = (stats.avg_time * stats.total_queries + execution_time) / new_total

    %{
      total_queries: new_total,
      avg_time: new_avg
    }
  end
end
