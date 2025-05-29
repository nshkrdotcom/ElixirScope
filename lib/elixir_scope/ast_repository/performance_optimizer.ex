# ==============================================================================
# Main Performance Optimizer Coordinator
# ==============================================================================

defmodule ElixirScope.ASTRepository.PerformanceOptimizer do
  @moduledoc """
  Main coordinator for performance optimization features.

  Delegates specialized optimization tasks to focused components while
  maintaining a unified interface for the repository system.
  """

  use GenServer
  require Logger

  alias ElixirScope.ASTRepository.{MemoryManager, EnhancedRepository}
  alias ElixirScope.ASTRepository.Enhanced.{EnhancedModuleData, EnhancedFunctionData}
  alias ElixirScope.ASTRepository.PerformanceOptimizer.{
    CacheManager,
    BatchProcessor,
    LazyLoader,
    OptimizationScheduler,
    StatisticsCollector
  }

  defstruct [
    :optimization_stats,
    :cache_stats,
    :batch_stats,
    :lazy_loading_stats,
    :enabled
  ]

  @type optimization_stats :: %{
    modules_optimized: non_neg_integer(),
    functions_optimized: non_neg_integer(),
    cache_optimizations: non_neg_integer(),
    memory_optimizations: non_neg_integer(),
    query_optimizations: non_neg_integer(),
    total_time_saved_ms: non_neg_integer()
  }

  # GenServer API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    # Initialize components
    {:ok, _} = CacheManager.start_link(opts)
    {:ok, _} = BatchProcessor.start_link(opts)
    {:ok, _} = LazyLoader.start_link(opts)
    {:ok, _} = OptimizationScheduler.start_link(opts)
    {:ok, _} = StatisticsCollector.start_link(opts)

    state = %__MODULE__{
      optimization_stats: StatisticsCollector.init_optimization_stats(),
      cache_stats: StatisticsCollector.init_cache_stats(),
      batch_stats: StatisticsCollector.init_batch_stats(),
      lazy_loading_stats: StatisticsCollector.init_lazy_loading_stats(),
      enabled: Keyword.get(opts, :enabled, true)
    }

    Logger.info("PerformanceOptimizer started with optimizations enabled: #{state.enabled}")
    {:ok, state}
  end

  # Public API

  @doc """
  Optimizes module storage with intelligent caching and batching.
  """
  @spec store_module_optimized(atom(), term(), keyword()) :: {:ok, EnhancedModuleData.t()} | {:error, term()}
  def store_module_optimized(module_name, ast, opts \\ []) do
    GenServer.call(__MODULE__, {:store_module_optimized, module_name, ast, opts})
  end

  @doc """
  Optimizes function storage with CFG/DFG lazy loading.
  """
  @spec store_function_optimized(atom(), atom(), non_neg_integer(), term(), keyword()) ::
    {:ok, EnhancedFunctionData.t()} | {:error, term()}
  def store_function_optimized(module_name, function_name, arity, ast, opts \\ []) do
    GenServer.call(__MODULE__, {:store_function_optimized, module_name, function_name, arity, ast, opts})
  end

  @doc """
  Performs batch storage operations for multiple modules.
  """
  @spec store_modules_batch([{atom(), term()}], keyword()) :: {:ok, [EnhancedModuleData.t()]} | {:error, term()}
  def store_modules_batch(modules, opts \\ []) do
    BatchProcessor.process_modules(modules, opts)
  end

  @doc """
  Retrieves module with intelligent caching.
  """
  @spec get_module_optimized(atom()) :: {:ok, EnhancedModuleData.t()} | {:error, term()}
  def get_module_optimized(module_name) do
    CacheManager.get_module_cached(module_name)
  end

  @doc """
  Retrieves function with lazy analysis loading.
  """
  @spec get_function_optimized(atom(), atom(), non_neg_integer()) :: {:ok, EnhancedFunctionData.t()} | {:error, term()}
  def get_function_optimized(module_name, function_name, arity) do
    LazyLoader.get_function_lazy(module_name, function_name, arity)
  end

  @doc """
  Performs optimized analysis queries with result caching.
  """
  @spec query_analysis_optimized(atom(), map()) :: {:ok, term()} | {:error, term()}
  def query_analysis_optimized(query_type, params) do
    GenServer.call(__MODULE__, {:query_analysis_optimized, query_type, params})
  end

  @doc """
  Warms up caches with frequently accessed data.
  """
  @spec warm_caches() :: :ok
  def warm_caches() do
    CacheManager.warm_caches()
  end

  @doc """
  Optimizes ETS table structures and indexes.
  """
  @spec optimize_ets_tables() :: :ok
  def optimize_ets_tables() do
    OptimizationScheduler.optimize_ets_tables()
  end

  @doc """
  Gets comprehensive optimization statistics.
  """
  @spec get_optimization_stats() :: {:ok, map()}
  def get_optimization_stats() do
    GenServer.call(__MODULE__, :get_optimization_stats)
  end

  @doc """
  Enables or disables performance optimizations.
  """
  @spec set_optimization_enabled(boolean()) :: :ok
  def set_optimization_enabled(enabled) do
    GenServer.call(__MODULE__, {:set_optimization_enabled, enabled})
  end

  # GenServer Callbacks

  def handle_call({:store_module_optimized, module_name, ast, opts}, _from, state) do
    if state.enabled do
      start_time = System.monotonic_time(:microsecond)

      try do
        lazy_analysis = Keyword.get(opts, :lazy_analysis, true)
        batch_mode = Keyword.get(opts, :batch_mode, false)

        result = if batch_mode do
          BatchProcessor.queue_module(module_name, ast, opts)
          {:ok, :queued_for_batch}
        else
          store_module_with_optimizations(module_name, ast, lazy_analysis)
        end

        end_time = System.monotonic_time(:microsecond)
        duration = end_time - start_time

        new_stats = StatisticsCollector.update_optimization_stats(state.optimization_stats, :module_storage, duration)
        new_state = %{state | optimization_stats: new_stats}

        {:reply, result, new_state}
      rescue
        error ->
          Logger.error("Optimized module storage failed: #{inspect(error)}")
          {:reply, {:error, {:optimization_failed, error}}, state}
      end
    else
      result = EnhancedRepository.store_enhanced_module(module_name, ast, opts)
      {:reply, result, state}
    end
  end

  def handle_call({:store_function_optimized, module_name, function_name, arity, ast, opts}, _from, state) do
    if state.enabled do
      start_time = System.monotonic_time(:microsecond)

      try do
        result = LazyLoader.store_function_lazy(module_name, function_name, arity, ast, opts)

        end_time = System.monotonic_time(:microsecond)
        duration = end_time - start_time

        new_stats = StatisticsCollector.update_optimization_stats(state.optimization_stats, :function_storage, duration)
        new_state = %{state | optimization_stats: new_stats}

        {:reply, result, new_state}
      rescue
        error ->
          Logger.error("Optimized function storage failed: #{inspect(error)}")
          {:reply, {:error, {:optimization_failed, error}}, state}
      end
    else
      result = EnhancedRepository.store_enhanced_function(module_name, function_name, arity, ast, opts)
      {:reply, result, state}
    end
  end

  def handle_call({:query_analysis_optimized, query_type, params}, _from, state) do
    if state.enabled do
      start_time = System.monotonic_time(:microsecond)

      result = CacheManager.query_with_cache(query_type, params)

      end_time = System.monotonic_time(:microsecond)
      duration = end_time - start_time

      new_stats = StatisticsCollector.update_optimization_stats(state.optimization_stats, :query_optimization, duration)
      new_state = %{state | optimization_stats: new_stats}

      {:reply, result, new_state}
    else
      result = EnhancedRepository.query_analysis(query_type, params)
      {:reply, result, state}
    end
  end

  def handle_call(:get_optimization_stats, _from, state) do
    stats = %{
      optimization: state.optimization_stats,
      cache: state.cache_stats,
      batch: state.batch_stats,
      lazy_loading: state.lazy_loading_stats,
      enabled: state.enabled
    }

    {:reply, {:ok, stats}, state}
  end

  def handle_call({:set_optimization_enabled, enabled}, _from, state) do
    new_state = %{state | enabled: enabled}
    Logger.info("Performance optimizations #{if enabled, do: "enabled", else: "disabled"}")
    {:reply, :ok, new_state}
  end

  # Private helpers
  defp store_module_with_optimizations(module_name, ast, lazy_analysis) do
    optimized_ast = preprocess_ast_for_storage(ast)

    immediate_analysis = if lazy_analysis do
      [:basic_metrics, :dependencies]
    else
      [:all]
    end

    opts = [analysis_level: immediate_analysis, optimized: true]
    EnhancedRepository.store_enhanced_module(module_name, optimized_ast, opts)
  end

  defp preprocess_ast_for_storage(ast) do
    # Optimize AST structure for storage
    ast
  end
end
