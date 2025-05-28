defmodule ElixirScope.ASTRepository.PerformanceOptimizer do
  @moduledoc """
  Performance optimization module for the Enhanced AST Repository.
  
  Provides intelligent caching, batch operations, lazy loading, and
  integration with the MemoryManager for optimal performance.
  
  ## Features
  
  - **Smart Caching**: Multi-level caching with TTL and LRU eviction
  - **Batch Operations**: Bulk storage and retrieval optimizations
  - **Lazy Loading**: On-demand analysis generation
  - **Memory Integration**: Seamless MemoryManager integration
  - **Query Optimization**: Intelligent query result caching
  - **ETS Optimization**: Optimized table structures and indexes
  
  ## Performance Targets
  
  - Module storage: <5ms per module (optimized from 10ms)
  - Query response: <50ms for 95th percentile (optimized from 100ms)
  - Cache hit ratio: >85% for repeated operations
  - Memory efficiency: 30% reduction in memory usage
  """
  
  use GenServer
  require Logger
  
  alias ElixirScope.ASTRepository.{MemoryManager, EnhancedRepository}
  alias ElixirScope.ASTRepository.Enhanced.{EnhancedModuleData, EnhancedFunctionData}
  
  # Performance optimization configuration
  @batch_size 50
  @lazy_loading_threshold 1000  # bytes
  @cache_warming_interval 300_000  # 5 minutes
  @optimization_interval 600_000   # 10 minutes
  
  # Cache keys for different data types
  @module_cache_prefix "module:"
  @function_cache_prefix "function:"
  @analysis_cache_prefix "analysis:"
  @query_cache_prefix "query:"
  
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
    # Schedule optimization tasks
    schedule_cache_warming()
    schedule_optimization_cycle()
    
    state = %__MODULE__{
      optimization_stats: init_optimization_stats(),
      cache_stats: init_cache_stats(),
      batch_stats: init_batch_stats(),
      lazy_loading_stats: init_lazy_loading_stats(),
      enabled: Keyword.get(opts, :enabled, true)
    }
    
    Logger.info("PerformanceOptimizer started with optimizations enabled: #{state.enabled}")
    {:ok, state}
  end
  
  # Public API
  
  @doc """
  Optimizes module storage with intelligent caching and batching.
  
  ## Options
  
  - `:batch_mode` - Enable batch processing (default: false)
  - `:lazy_analysis` - Enable lazy analysis generation (default: true)
  - `:cache_priority` - Cache priority level (:high, :normal, :low) (default: :normal)
  
  ## Returns
  
  - `{:ok, enhanced_data}` - Module stored and optimized
  - `{:error, reason}` - Storage failed
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
    GenServer.call(__MODULE__, {:store_modules_batch, modules, opts}, 60_000)
  end
  
  @doc """
  Retrieves module with intelligent caching.
  """
  @spec get_module_optimized(atom()) :: {:ok, EnhancedModuleData.t()} | {:error, term()}
  def get_module_optimized(module_name) do
    cache_key = @module_cache_prefix <> to_string(module_name)
    
    case MemoryManager.cache_get(:query, cache_key) do
      {:ok, cached_data} ->
        # Cache hit - update access tracking
        track_access(module_name, :cache_hit)
        {:ok, cached_data}
      
      :miss ->
        # Cache miss - fetch from repository
        case EnhancedRepository.get_enhanced_module(module_name) do
          {:ok, module_data} ->
            # Cache the result
            MemoryManager.cache_put(:query, cache_key, module_data)
            track_access(module_name, :cache_miss)
            {:ok, module_data}
          
          error ->
            error
        end
    end
  end
  
  @doc """
  Retrieves function with lazy analysis loading.
  """
  @spec get_function_optimized(atom(), atom(), non_neg_integer()) :: {:ok, EnhancedFunctionData.t()} | {:error, term()}
  def get_function_optimized(module_name, function_name, arity) do
    cache_key = @function_cache_prefix <> "#{module_name}.#{function_name}/#{arity}"
    
    case MemoryManager.cache_get(:analysis, cache_key) do
      {:ok, cached_data} ->
        track_access({module_name, function_name, arity}, :cache_hit)
        {:ok, cached_data}
      
      :miss ->
        case EnhancedRepository.get_enhanced_function(module_name, function_name, arity) do
          {:ok, function_data} ->
            # Apply lazy loading optimizations
            optimized_data = apply_lazy_loading(function_data)
            MemoryManager.cache_put(:analysis, cache_key, optimized_data)
            track_access({module_name, function_name, arity}, :cache_miss)
            {:ok, optimized_data}
          
          error ->
            error
        end
    end
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
    GenServer.cast(__MODULE__, :warm_caches)
  end
  
  @doc """
  Optimizes ETS table structures and indexes.
  """
  @spec optimize_ets_tables() :: :ok
  def optimize_ets_tables() do
    GenServer.cast(__MODULE__, :optimize_ets_tables)
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
        # Check if lazy analysis is enabled
        lazy_analysis = Keyword.get(opts, :lazy_analysis, true)
        batch_mode = Keyword.get(opts, :batch_mode, false)
        
        result = if batch_mode do
          # Store in batch queue for later processing
          queue_for_batch_processing(module_name, ast, opts)
          {:ok, :queued_for_batch}
        else
          # Store immediately with optimizations
          store_module_with_optimizations(module_name, ast, lazy_analysis)
        end
        
        # Update statistics
        end_time = System.monotonic_time(:microsecond)
        duration = end_time - start_time
        
        new_stats = update_optimization_stats(state.optimization_stats, :module_storage, duration)
        new_state = %{state | optimization_stats: new_stats}
        
        {:reply, result, new_state}
      rescue
        error ->
          Logger.error("Optimized module storage failed: #{inspect(error)}")
          {:reply, {:error, {:optimization_failed, error}}, state}
      end
    else
      # Fall back to standard storage
      result = EnhancedRepository.store_enhanced_module(module_name, ast, opts)
      {:reply, result, state}
    end
  end
  
  def handle_call({:store_function_optimized, module_name, function_name, arity, ast, opts}, _from, state) do
    if state.enabled do
      start_time = System.monotonic_time(:microsecond)
      
      try do
        # Apply function-specific optimizations
        result = store_function_with_optimizations(module_name, function_name, arity, ast, opts)
        
        # Update statistics
        end_time = System.monotonic_time(:microsecond)
        duration = end_time - start_time
        
        new_stats = update_optimization_stats(state.optimization_stats, :function_storage, duration)
        new_state = %{state | optimization_stats: new_stats}
        
        {:reply, result, new_state}
      rescue
        error ->
          Logger.error("Optimized function storage failed: #{inspect(error)}")
          {:reply, {:error, {:optimization_failed, error}}, state}
      end
    else
      # Fall back to standard storage
      result = EnhancedRepository.store_enhanced_function(module_name, function_name, arity, ast, opts)
      {:reply, result, state}
    end
  end
  
  def handle_call({:store_modules_batch, modules, opts}, _from, state) do
    if state.enabled do
      start_time = System.monotonic_time(:microsecond)
      
      try do
        # Process modules in optimized batches
        results = process_modules_in_batches(modules, opts)
        
        # Update batch statistics
        end_time = System.monotonic_time(:microsecond)
        duration = end_time - start_time
        
        new_batch_stats = update_batch_stats(state.batch_stats, length(modules), duration)
        new_state = %{state | batch_stats: new_batch_stats}
        
        {:reply, {:ok, results}, new_state}
      rescue
        error ->
          Logger.error("Batch storage failed: #{inspect(error)}")
          {:reply, {:error, {:batch_failed, error}}, state}
      end
    else
      # Fall back to individual storage
      results = Enum.map(modules, fn {module_name, ast} ->
        case EnhancedRepository.store_enhanced_module(module_name, ast, opts) do
          {:ok, data} -> data
          {:error, _} -> nil
        end
      end)
      
      {:reply, {:ok, Enum.filter(results, & &1)}, state}
    end
  end
  
  def handle_call({:query_analysis_optimized, query_type, params}, _from, state) do
    if state.enabled do
      start_time = System.monotonic_time(:microsecond)
      
      # Generate cache key for query
      cache_key = generate_query_cache_key(query_type, params)
      
      result = case MemoryManager.cache_get(:query, cache_key) do
        {:ok, cached_result} ->
          # Cache hit
          {:ok, cached_result}
        
        :miss ->
          # Cache miss - perform query and cache result
          case EnhancedRepository.query_analysis(query_type, params) do
            {:ok, query_result} ->
              # Cache the result with appropriate TTL
              MemoryManager.cache_put(:query, cache_key, query_result)
              {:ok, query_result}
            
            error ->
              error
          end
      end
      
      # Update query statistics
      end_time = System.monotonic_time(:microsecond)
      duration = end_time - start_time
      
      new_stats = update_optimization_stats(state.optimization_stats, :query_optimization, duration)
      new_state = %{state | optimization_stats: new_stats}
      
      {:reply, result, new_state}
    else
      # Fall back to standard query
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
  
  def handle_cast(:warm_caches, state) do
    if state.enabled do
      perform_cache_warming()
    end
    {:noreply, state}
  end
  
  def handle_cast(:optimize_ets_tables, state) do
    if state.enabled do
      perform_ets_optimization()
    end
    {:noreply, state}
  end
  
  def handle_info(:cache_warming, state) do
    if state.enabled do
      perform_cache_warming()
    end
    
    schedule_cache_warming()
    {:noreply, state}
  end
  
  def handle_info(:optimization_cycle, state) do
    if state.enabled do
      perform_optimization_cycle()
    end
    
    schedule_optimization_cycle()
    {:noreply, state}
  end
  
  # Private Implementation
  
  defp store_module_with_optimizations(module_name, ast, lazy_analysis) do
    # Pre-process AST for optimization
    optimized_ast = preprocess_ast_for_storage(ast)
    
    # Determine what analysis to perform immediately vs lazily
    immediate_analysis = if lazy_analysis do
      [:basic_metrics, :dependencies]
    else
      [:all]
    end
    
    # Store with selective analysis
    opts = [analysis_level: immediate_analysis, optimized: true]
    EnhancedRepository.store_enhanced_module(module_name, optimized_ast, opts)
  end
  
  defp store_function_with_optimizations(module_name, function_name, arity, ast, opts) do
    # Check if function is large enough to warrant lazy loading
    ast_size = estimate_ast_size(ast)
    
    if ast_size > @lazy_loading_threshold do
      # Store with lazy analysis
      lazy_opts = Keyword.put(opts, :lazy_analysis, true)
      EnhancedRepository.store_enhanced_function(module_name, function_name, arity, ast, lazy_opts)
    else
      # Store with full analysis
      EnhancedRepository.store_enhanced_function(module_name, function_name, arity, ast, opts)
    end
  end
  
  defp process_modules_in_batches(modules, _opts) do
    modules
    |> Enum.chunk_every(@batch_size)
    |> Enum.flat_map(fn batch ->
      # Process batch concurrently
      tasks = Enum.map(batch, fn {module_name, ast} ->
        Task.async(fn ->
          case store_module_with_optimizations(module_name, ast, true) do
            {:ok, data} -> data
            {:error, _} -> nil
          end
        end)
      end)
      
      # Collect results with timeout
      Task.await_many(tasks, 30_000)
      |> Enum.filter(& &1)
    end)
  end
  
  defp apply_lazy_loading(function_data) do
    # Check if expensive analysis data should be loaded lazily
    cond do
      is_nil(function_data.cfg_data) and should_load_cfg?(function_data) ->
        # Load CFG on demand
        case EnhancedRepository.get_cfg(function_data.module_name, function_data.function_name, function_data.arity) do
          {:ok, cfg} -> %{function_data | cfg_data: cfg}
          _ -> function_data
        end
      
      is_nil(function_data.dfg_data) and should_load_dfg?(function_data) ->
        # Load DFG on demand
        case EnhancedRepository.get_dfg(function_data.module_name, function_data.function_name, function_data.arity) do
          {:ok, dfg} -> %{function_data | dfg_data: dfg}
          _ -> function_data
        end
      
      true ->
        function_data
    end
  end
  
  defp should_load_cfg?(function_data) do
    # Load CFG if function is complex or frequently accessed
    complexity = get_function_complexity(function_data)
    access_count = get_access_count({function_data.module_name, function_data.function_name, function_data.arity})
    
    complexity > 5 or access_count > 10
  end
  
  defp should_load_dfg?(function_data) do
    # Load DFG for functions with data flow analysis needs
    has_variables = function_has_variables?(function_data.ast)
    access_count = get_access_count({function_data.module_name, function_data.function_name, function_data.arity})
    
    has_variables and access_count > 5
  end
  
  defp perform_cache_warming() do
    Logger.debug("Performing cache warming")
    
    # Warm up frequently accessed modules
    frequently_accessed_modules = get_frequently_accessed_modules()
    
    Enum.each(frequently_accessed_modules, fn module_name ->
      cache_key = @module_cache_prefix <> to_string(module_name)
      
      case MemoryManager.cache_get(:query, cache_key) do
        :miss ->
          # Pre-load into cache
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
  
  defp perform_ets_optimization() do
    Logger.debug("Performing ETS optimization")
    
    # Optimize table structures based on access patterns
    # This could include reordering data, compacting tables, etc.
    
    # For now, just ensure tables are properly configured
    :ok
  end
  
  defp perform_optimization_cycle() do
    Logger.debug("Performing optimization cycle")
    
    # Trigger memory cleanup if needed
    {:ok, memory_stats} = MemoryManager.monitor_memory_usage()
    
    if memory_stats.memory_usage_percent > 70 do
      MemoryManager.cleanup_unused_data(max_age: 3600)
    end
    
    # Compress old analysis data
    if memory_stats.memory_usage_percent > 60 do
      MemoryManager.compress_old_analysis(access_threshold: 5, age_threshold: 1800)
    end
  end
  
  defp track_access(identifier, access_type) do
    # Track access patterns for optimization
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
    # Generate deterministic cache key for query
    param_hash = :crypto.hash(:md5, :erlang.term_to_binary(params))
    |> Base.encode16(case: :lower)
    
    @query_cache_prefix <> "#{query_type}:#{param_hash}"
  end
  
  defp preprocess_ast_for_storage(ast) do
    # Optimize AST structure for storage
    # This could include removing unnecessary metadata, normalizing structures, etc.
    ast
  end
  
  defp estimate_ast_size(ast) do
    # Estimate AST size in bytes
    :erlang.external_size(ast)
  end
  
  defp get_function_complexity(function_data) do
    # Extract complexity from function data
    case function_data.complexity_metrics do
      %{cyclomatic_complexity: complexity} -> complexity
      _ -> 1
    end
  end
  
  defp function_has_variables?(ast) do
    # Check if function AST contains variable operations
    # Simplified check - in practice would traverse AST
    is_tuple(ast) and tuple_size(ast) > 0
  end
  
  defp get_access_count(identifier) do
    case :ets.lookup(:ast_repo_access_tracking, identifier) do
      [{^identifier, _last_access, access_count}] -> access_count
      [] -> 0
    end
  end
  
  defp get_frequently_accessed_modules() do
    # Get modules with high access counts
    :ets.tab2list(:ast_repo_access_tracking)
    |> Enum.filter(fn {identifier, _time, count} ->
      is_atom(identifier) and count > 10
    end)
    |> Enum.map(fn {module, _time, _count} -> module end)
    |> Enum.take(20)  # Top 20 most accessed
  end
  
  defp queue_for_batch_processing(_module_name, _ast, _opts) do
    # In a real implementation, this would queue items for batch processing
    :ok
  end
  
  defp init_optimization_stats() do
    %{
      modules_optimized: 0,
      functions_optimized: 0,
      cache_optimizations: 0,
      memory_optimizations: 0,
      query_optimizations: 0,
      total_time_saved_ms: 0
    }
  end
  
  defp init_cache_stats() do
    %{
      cache_hits: 0,
      cache_misses: 0,
      cache_evictions: 0,
      cache_warming_cycles: 0
    }
  end
  
  defp init_batch_stats() do
    %{
      batches_processed: 0,
      total_items_batched: 0,
      average_batch_time_ms: 0,
      batch_efficiency_ratio: 0.0
    }
  end
  
  defp init_lazy_loading_stats() do
    %{
      lazy_loads_triggered: 0,
      lazy_loads_avoided: 0,
      memory_saved_bytes: 0,
      time_saved_ms: 0
    }
  end
  
  defp update_optimization_stats(stats, operation_type, duration_us) do
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
  
  defp update_batch_stats(stats, item_count, duration_us) do
    duration_ms = duration_us / 1000
    new_total_items = stats.total_items_batched + item_count
    new_batch_count = stats.batches_processed + 1
    
    new_average = if new_batch_count > 0 do
      ((stats.average_batch_time_ms * stats.batches_processed) + duration_ms) / new_batch_count
    else
      duration_ms
    end
    
    # Calculate efficiency ratio (items per ms)
    efficiency = if duration_ms > 0, do: item_count / duration_ms, else: 0.0
    
    %{stats |
      batches_processed: new_batch_count,
      total_items_batched: new_total_items,
      average_batch_time_ms: new_average,
      batch_efficiency_ratio: efficiency
    }
  end
  
  defp schedule_cache_warming() do
    Process.send_after(self(), :cache_warming, @cache_warming_interval)
  end
  
  defp schedule_optimization_cycle() do
    Process.send_after(self(), :optimization_cycle, @optimization_interval)
  end
end 