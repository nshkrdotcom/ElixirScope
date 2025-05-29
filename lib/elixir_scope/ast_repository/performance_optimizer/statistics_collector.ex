# ==============================================================================
# Statistics Collection Component
# ==============================================================================

defmodule ElixirScope.ASTRepository.PerformanceOptimizer.StatisticsCollector do
  @moduledoc """
  Collects and manages performance optimization statistics.
  """

  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    {:ok, %{}}
  end

  @doc """
  Initializes optimization statistics structure.
  """
  @spec init_optimization_stats() :: map()
  def init_optimization_stats() do
    %{
      modules_optimized: 0,
      functions_optimized: 0,
      cache_optimizations: 0,
      memory_optimizations: 0,
      query_optimizations: 0,
      total_time_saved_ms: 0
    }
  end

  @doc """
  Initializes cache statistics structure.
  """
  @spec init_cache_stats() :: map()
  def init_cache_stats() do
    %{
      cache_hits: 0,
      cache_misses: 0,
      cache_evictions: 0,
      cache_warming_cycles: 0
    }
  end

  @doc """
  Initializes batch statistics structure.
  """
  @spec init_batch_stats() :: map()
  def init_batch_stats() do
    %{
      batches_processed: 0,
      total_items_batched: 0,
      average_batch_time_ms: 0,
      batch_efficiency_ratio: 0.0
    }
  end

  @doc """
  Initializes lazy loading statistics structure.
  """
  @spec init_lazy_loading_stats() :: map()
  def init_lazy_loading_stats() do
    %{
      lazy_loads_triggered: 0,
      lazy_loads_avoided: 0,
      memory_saved_bytes: 0,
      time_saved_ms: 0
    }
  end

  @doc """
  Updates optimization statistics with new operation data.
  """
  @spec update_optimization_stats(map(), atom(), number()) :: map()
  def update_optimization_stats(stats, operation_type, duration_us) do
    duration_ms = duration_us / 1000

    case operation_type do
      :module_storage ->
        %{stats |
          modules_optimized: stats.modules_optimized + 1,
          total_time_saved_ms: stats.total_time_saved_ms + max(0, 10 - duration_ms)
        }

      :function_storage ->
        %{stats |
          functions_optimized: stats.functions_optimized + 1,
          total_time_saved_ms: stats.total_time_saved_ms + max(0, 20 - duration_ms)
        }

      :query_optimization ->
        %{stats |
          query_optimizations: stats.query_optimizations + 1,
          total_time_saved_ms: stats.total_time_saved_ms + max(0, 100 - duration_ms)
        }

      _ ->
        stats
    end
  end
end
