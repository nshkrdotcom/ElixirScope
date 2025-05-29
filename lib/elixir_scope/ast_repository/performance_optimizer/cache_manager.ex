# ==============================================================================
# Cache Management Component
# ==============================================================================

defmodule ElixirScope.ASTRepository.PerformanceOptimizer.CacheManager do
  @moduledoc """
  Manages intelligent caching with TTL and LRU eviction policies.
  """

  use GenServer
  require Logger

  alias ElixirScope.ASTRepository.{MemoryManager, EnhancedRepository}

  @module_cache_prefix "module:"
  @function_cache_prefix "function:"
  @query_cache_prefix "query:"
  @cache_warming_interval 300_000  # 5 minutes

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    schedule_cache_warming()
    {:ok, %{}}
  end

  @doc """
  Retrieves module with intelligent caching.
  """
  @spec get_module_cached(atom()) :: {:ok, term()} | {:error, term()}
  def get_module_cached(module_name) do
    cache_key = @module_cache_prefix <> to_string(module_name)

    case MemoryManager.cache_get(:query, cache_key) do
      {:ok, cached_data} ->
        track_access(module_name, :cache_hit)
        {:ok, cached_data}

      :miss ->
        case EnhancedRepository.get_enhanced_module(module_name) do
          {:ok, module_data} ->
            MemoryManager.cache_put(:query, cache_key, module_data)
            track_access(module_name, :cache_miss)
            {:ok, module_data}

          error ->
            error
        end
    end
  end

  @doc """
  Performs optimized analysis queries with result caching.
  """
  @spec query_with_cache(atom(), map()) :: {:ok, term()} | {:error, term()}
  def query_with_cache(query_type, params) do
    cache_key = generate_query_cache_key(query_type, params)

    case MemoryManager.cache_get(:query, cache_key) do
      {:ok, cached_result} ->
        {:ok, cached_result}

      :miss ->
        case EnhancedRepository.query_analysis(query_type, params) do
          {:ok, query_result} ->
            MemoryManager.cache_put(:query, cache_key, query_result)
            {:ok, query_result}

          error ->
            error
        end
    end
  end

  @doc """
  Warms up caches with frequently accessed data.
  """
  @spec warm_caches() :: :ok
  def warm_caches() do
    GenServer.cast(__MODULE__, :warm_caches)
  end

  def handle_cast(:warm_caches, state) do
    perform_cache_warming()
    {:noreply, state}
  end

  def handle_info(:cache_warming, state) do
    perform_cache_warming()
    schedule_cache_warming()
    {:noreply, state}
  end

  # Private implementation
  defp perform_cache_warming() do
    Logger.debug("Performing cache warming")

    frequently_accessed_modules = get_frequently_accessed_modules()

    Enum.each(frequently_accessed_modules, fn module_name ->
      cache_key = @module_cache_prefix <> to_string(module_name)

      case MemoryManager.cache_get(:query, cache_key) do
        :miss ->
          case EnhancedRepository.get_enhanced_module(module_name) do
            {:ok, module_data} ->
              MemoryManager.cache_put(:query, cache_key, module_data)
            _ ->
              :ok
          end
        _ ->
          :ok
      end
    end)
  end

  defp track_access(identifier, access_type) do
    current_time = System.monotonic_time(:second)

    case :ets.lookup(:ast_repo_access_tracking, identifier) do
      [{^identifier, _last_access, access_count}] ->
        new_count = if access_type == :cache_hit, do: access_count + 1, else: access_count
        :ets.insert(:ast_repo_access_tracking, {identifier, current_time, new_count})

      [] ->
        :ets.insert(:ast_repo_access_tracking, {identifier, current_time, 1})
    end
  end

  defp generate_query_cache_key(query_type, params) do
    param_hash = :crypto.hash(:md5, :erlang.term_to_binary(params))
    |> Base.encode16(case: :lower)

    @query_cache_prefix <> "#{query_type}:#{param_hash}"
  end

  defp get_frequently_accessed_modules() do
    :ets.tab2list(:ast_repo_access_tracking)
    |> Enum.filter(fn {identifier, _time, count} ->
      is_atom(identifier) and count > 10
    end)
    |> Enum.map(fn {module, _time, _count} -> module end)
    |> Enum.take(20)
  end

  defp schedule_cache_warming() do
    Process.send_after(self(), :cache_warming, @cache_warming_interval)
  end
end
