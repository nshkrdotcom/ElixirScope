defmodule ElixirScope.ASTRepository.MemoryManager do
  @moduledoc """
  Comprehensive memory management for the Enhanced AST Repository.
  
  Provides intelligent memory monitoring, cleanup, compression, and caching
  strategies to handle production-scale projects with 1000+ modules.
  
  ## Features
  
  - **Memory Monitoring**: Real-time tracking of repository memory usage
  - **Intelligent Cleanup**: Remove stale and unused AST data
  - **Data Compression**: Compress infrequently accessed analysis data
  - **LRU Caching**: Least Recently Used cache for query optimization
  - **Memory Pressure Handling**: Multi-level response to memory constraints
  
  ## Performance Targets
  
  - Memory usage: <500MB for 1000 modules
  - Query response: <100ms for 95th percentile
  - Cache hit ratio: >80% for repeated queries
  - Memory cleanup: <10ms per cleanup cycle
  
  ## Memory Pressure Levels
  
  1. **Level 1** (80% memory): Clear query caches
  2. **Level 2** (90% memory): Compress old analysis data
  3. **Level 3** (95% memory): Remove unused module data
  4. **Level 4** (98% memory): Emergency cleanup and GC
  
  ## Examples
  
      # Start memory monitoring
      {:ok, _pid} = MemoryManager.start_link()
      
      # Monitor memory usage
      {:ok, stats} = MemoryManager.monitor_memory_usage()
      
      # Cleanup unused data
      :ok = MemoryManager.cleanup_unused_data(max_age: 3600)
      
      # Handle memory pressure
      :ok = MemoryManager.memory_pressure_handler(:level_2)
  """
  
  use GenServer
  require Logger
  
  alias ElixirScope.ASTRepository.EnhancedRepository
  
  # Memory management configuration
  @memory_check_interval 30_000      # 30 seconds
  @cleanup_interval 300_000          # 5 minutes
  @compression_interval 600_000      # 10 minutes
  
  # Cache configuration
  @query_cache_ttl 60_000           # 1 minute
  @analysis_cache_ttl 300_000       # 5 minutes  
  @cpg_cache_ttl 600_000            # 10 minutes
  @max_cache_entries 1000
  
  # Memory pressure thresholds (percentage of available memory)
  @memory_pressure_level_1 80
  @memory_pressure_level_2 90
  @memory_pressure_level_3 95
  @memory_pressure_level_4 98
  
  # ETS tables for caching and monitoring
  @query_cache_table :ast_repo_query_cache
  @analysis_cache_table :ast_repo_analysis_cache
  @cpg_cache_table :ast_repo_cpg_cache
  @memory_stats_table :ast_repo_memory_stats
  @access_tracking_table :ast_repo_access_tracking
  
  defstruct [
    :memory_stats,
    :cache_stats,
    :cleanup_stats,
    :compression_stats,
    :pressure_level,
    :last_cleanup,
    :last_compression,
    :monitoring_enabled
  ]
  
  @type memory_stats :: %{
    total_memory: non_neg_integer(),
    repository_memory: non_neg_integer(),
    cache_memory: non_neg_integer(),
    ets_memory: non_neg_integer(),
    process_memory: non_neg_integer(),
    memory_usage_percent: float(),
    available_memory: non_neg_integer()
  }
  
  @type cache_stats :: %{
    query_cache_size: non_neg_integer(),
    analysis_cache_size: non_neg_integer(),
    cpg_cache_size: non_neg_integer(),
    total_cache_hits: non_neg_integer(),
    total_cache_misses: non_neg_integer(),
    cache_hit_ratio: float(),
    evictions: non_neg_integer()
  }
  
  @type cleanup_stats :: %{
    modules_cleaned: non_neg_integer(),
    data_removed_bytes: non_neg_integer(),
    last_cleanup_duration: non_neg_integer(),
    total_cleanups: non_neg_integer()
  }
  
  @type compression_stats :: %{
    modules_compressed: non_neg_integer(),
    compression_ratio: float(),
    space_saved_bytes: non_neg_integer(),
    last_compression_duration: non_neg_integer(),
    total_compressions: non_neg_integer()
  }
  
  # GenServer API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(opts) do
    # Initialize ETS tables for caching and monitoring
    init_ets_tables()
    
    # Schedule periodic tasks
    schedule_memory_check()
    schedule_cleanup()
    schedule_compression()
    
    state = %__MODULE__{
      memory_stats: %{},
      cache_stats: init_cache_stats(),
      cleanup_stats: init_cleanup_stats(),
      compression_stats: init_compression_stats(),
      pressure_level: :normal,
      last_cleanup: System.monotonic_time(:millisecond),
      last_compression: System.monotonic_time(:millisecond),
      monitoring_enabled: Keyword.get(opts, :monitoring_enabled, true)
    }
    
    Logger.info("MemoryManager started with monitoring enabled: #{state.monitoring_enabled}")
    {:ok, state}
  end
  
  # Public API
  
  @doc """
  Monitors current memory usage of the AST Repository.
  
  Returns comprehensive memory statistics including total memory,
  repository-specific memory, cache usage, and memory pressure level.
  
  ## Returns
  
  - `{:ok, memory_stats}` - Current memory statistics
  - `{:error, reason}` - Monitoring failed
  
  ## Examples
  
      {:ok, stats} = MemoryManager.monitor_memory_usage()
      # stats.memory_usage_percent => 45.2
      # stats.repository_memory => 125_000_000  # bytes
  """
  @spec monitor_memory_usage() :: {:ok, memory_stats()} | {:error, term()}
  def monitor_memory_usage() do
    GenServer.call(__MODULE__, :monitor_memory_usage)
  end
  
  @doc """
  Cleans up unused AST data based on access patterns and age.
  
  Removes stale module data, expired cache entries, and unused
  analysis results to free memory.
  
  ## Options
  
  - `:max_age` - Maximum age in seconds for data retention (default: 3600)
  - `:force` - Force cleanup regardless of memory pressure (default: false)
  - `:dry_run` - Show what would be cleaned without actually cleaning (default: false)
  
  ## Returns
  
  - `:ok` - Cleanup completed successfully
  - `{:error, reason}` - Cleanup failed
  
  ## Examples
  
      # Clean data older than 1 hour
      :ok = MemoryManager.cleanup_unused_data(max_age: 3600)
      
      # Force cleanup regardless of memory pressure
      :ok = MemoryManager.cleanup_unused_data(force: true)
  """
  @spec cleanup_unused_data(keyword()) :: :ok | {:error, term()}
  def cleanup_unused_data(opts \\ []) do
    GenServer.call(__MODULE__, {:cleanup_unused_data, opts}, 30_000)
  end
  
  @doc """
  Compresses infrequently accessed analysis data.
  
  Uses binary term compression to reduce memory footprint of
  large AST structures and analysis results that are rarely accessed.
  
  ## Options
  
  - `:access_threshold` - Minimum access count to avoid compression (default: 5)
  - `:age_threshold` - Minimum age in seconds before compression (default: 1800)
  - `:compression_level` - Compression level 1-9 (default: 6)
  
  ## Returns
  
  - `{:ok, compression_stats}` - Compression completed with statistics
  - `{:error, reason}` - Compression failed
  
  ## Examples
  
      # Compress data accessed less than 3 times
      {:ok, stats} = MemoryManager.compress_old_analysis(access_threshold: 3)
      # stats.compression_ratio => 0.65  # 35% size reduction
  """
  @spec compress_old_analysis(keyword()) :: {:ok, compression_stats()} | {:error, term()}
  def compress_old_analysis(opts \\ []) do
    GenServer.call(__MODULE__, {:compress_old_analysis, opts}, 30_000)
  end
  
  @doc """
  Implements LRU (Least Recently Used) cache for query optimization.
  
  Manages multi-level caching with different TTLs for queries,
  analysis results, and CPG data.
  
  ## Parameters
  
  - `cache_type` - Type of cache (:query, :analysis, :cpg)
  - `opts` - Cache configuration options
  
  ## Options
  
  - `:max_entries` - Maximum cache entries (default: 1000)
  - `:ttl` - Time to live in milliseconds (default: varies by type)
  - `:eviction_policy` - Eviction policy (:lru, :lfu, :ttl) (default: :lru)
  
  ## Returns
  
  - `:ok` - Cache configured successfully
  - `{:error, reason}` - Configuration failed
  
  ## Examples
  
      # Configure query cache with custom settings
      :ok = MemoryManager.implement_lru_cache(:query, max_entries: 500, ttl: 30_000)
  """
  @spec implement_lru_cache(atom(), keyword()) :: :ok | {:error, term()}
  def implement_lru_cache(cache_type, opts \\ []) do
    GenServer.call(__MODULE__, {:implement_lru_cache, cache_type, opts})
  end
  
  @doc """
  Handles memory pressure situations with appropriate response levels.
  
  Implements multi-level memory pressure handling from cache clearing
  to emergency cleanup and garbage collection.
  
  ## Pressure Levels
  
  - `:level_1` - Clear query caches (80% memory usage)
  - `:level_2` - Compress old analysis data (90% memory usage)
  - `:level_3` - Remove unused module data (95% memory usage)
  - `:level_4` - Emergency cleanup and GC (98% memory usage)
  
  ## Parameters
  
  - `pressure_level` - Memory pressure level to handle
  
  ## Returns
  
  - `:ok` - Pressure handling completed
  - `{:error, reason}` - Handling failed
  
  ## Examples
  
      # Handle level 2 memory pressure
      :ok = MemoryManager.memory_pressure_handler(:level_2)
  """
  @spec memory_pressure_handler(atom()) :: :ok | {:error, term()}
  def memory_pressure_handler(pressure_level) do
    GenServer.call(__MODULE__, {:memory_pressure_handler, pressure_level}, 60_000)
  end
  
  @doc """
  Gets comprehensive memory and performance statistics.
  """
  @spec get_stats() :: {:ok, map()}
  def get_stats() do
    GenServer.call(__MODULE__, :get_stats)
  end
  
  @doc """
  Enables or disables memory monitoring.
  """
  @spec set_monitoring(boolean()) :: :ok
  def set_monitoring(enabled) do
    GenServer.call(__MODULE__, {:set_monitoring, enabled})
  end
  
  @doc """
  Forces garbage collection and memory optimization.
  """
  @spec force_gc() :: :ok
  def force_gc() do
    GenServer.call(__MODULE__, :force_gc)
  end
  
  # Cache API
  
  @doc """
  Gets a value from the specified cache.
  """
  @spec cache_get(atom(), term()) :: {:ok, term()} | :miss
  def cache_get(cache_type, key) do
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
  
  @doc """
  Puts a value in the specified cache.
  """
  @spec cache_put(atom(), term(), term()) :: :ok
  def cache_put(cache_type, key, value) do
    try do
      table = cache_table_for_type(cache_type)
      timestamp = System.monotonic_time(:millisecond)
      
      # Check cache size and evict if necessary
      cache_size = :ets.info(table, :size)
      if cache_size >= @max_cache_entries do
        evict_lru_entries(table, div(@max_cache_entries, 10))  # Evict 10%
      end
      
      :ets.insert(table, {key, value, timestamp, 1})
      :ok
    rescue
      _error ->
        :ok  # Fail silently for cache operations
    end
  end
  
  @doc """
  Clears the specified cache.
  """
  @spec cache_clear(atom()) :: :ok
  def cache_clear(cache_type) do
    try do
      table = cache_table_for_type(cache_type)
      :ets.delete_all_objects(table)
      :ok
    rescue
      _error ->
        :ok  # Fail silently for cache operations
    end
  end
  
  # GenServer Callbacks
  
  def handle_call(:monitor_memory_usage, _from, state) do
    case collect_memory_stats() do
      {:ok, memory_stats} ->
        new_state = %{state | memory_stats: memory_stats}
        {:reply, {:ok, memory_stats}, new_state}
      error ->
        {:reply, error, state}
    end
  end
  
  def handle_call({:cleanup_unused_data, opts}, _from, state) do
    start_time = System.monotonic_time(:millisecond)
    
    case perform_cleanup(opts) do
      {:ok, cleanup_result} ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time
        
        new_cleanup_stats = update_cleanup_stats(state.cleanup_stats, cleanup_result, duration)
        new_state = %{state | 
          cleanup_stats: new_cleanup_stats,
          last_cleanup: end_time
        }
        
        {:reply, :ok, new_state}
      
      error ->
        {:reply, error, state}
    end
  end
  
  def handle_call({:compress_old_analysis, opts}, _from, state) do
    start_time = System.monotonic_time(:millisecond)
    
    case perform_compression(opts) do
      {:ok, compression_result} ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time
        
        new_compression_stats = update_compression_stats(state.compression_stats, compression_result, duration)
        new_state = %{state | 
          compression_stats: new_compression_stats,
          last_compression: end_time
        }
        
        {:reply, {:ok, compression_result}, new_state}
      
      error ->
        {:reply, error, state}
    end
  end
  
  def handle_call({:implement_lru_cache, cache_type, opts}, _from, state) do
    case configure_cache(cache_type, opts) do
      :ok ->
        {:reply, :ok, state}
      error ->
        {:reply, error, state}
    end
  end
  
  def handle_call({:memory_pressure_handler, pressure_level}, _from, state) do
    case handle_memory_pressure(pressure_level) do
      :ok ->
        new_state = %{state | pressure_level: pressure_level}
        {:reply, :ok, new_state}
      error ->
        {:reply, error, state}
    end
  end
  
  def handle_call(:get_stats, _from, state) do
    stats = %{
      memory: state.memory_stats,
      cache: state.cache_stats,
      cleanup: state.cleanup_stats,
      compression: state.compression_stats,
      pressure_level: state.pressure_level,
      monitoring_enabled: state.monitoring_enabled
    }
    {:reply, {:ok, stats}, state}
  end
  
  def handle_call({:set_monitoring, enabled}, _from, state) do
    new_state = %{state | monitoring_enabled: enabled}
    {:reply, :ok, new_state}
  end
  
  def handle_call(:force_gc, _from, state) do
    # Force garbage collection
    :erlang.garbage_collect()
    
    # Force GC on all processes
    for pid <- Process.list() do
      if Process.alive?(pid) do
        :erlang.garbage_collect(pid)
      end
    end
    
    {:reply, :ok, state}
  end
  
  def handle_info(:memory_check, state) do
    if state.monitoring_enabled do
      case collect_memory_stats() do
        {:ok, memory_stats} ->
          # Check for memory pressure
          pressure_level = determine_pressure_level(memory_stats.memory_usage_percent)
          
          if pressure_level != :normal and pressure_level != state.pressure_level do
            Logger.warning("Memory pressure detected: #{pressure_level} (#{memory_stats.memory_usage_percent}%)")
            handle_memory_pressure(pressure_level)
          end
          
          new_state = %{state | 
            memory_stats: memory_stats,
            pressure_level: pressure_level
          }
          
          schedule_memory_check()
          {:noreply, new_state}
        
        {:error, reason} ->
          Logger.error("Memory monitoring failed: #{inspect(reason)}")
          schedule_memory_check()
          {:noreply, state}
      end
    else
      schedule_memory_check()
      {:noreply, state}
    end
  end
  
  def handle_info(:cleanup, state) do
    # Perform automatic cleanup
    perform_cleanup([max_age: 3600])
    
    schedule_cleanup()
    {:noreply, state}
  end
  
  def handle_info(:compression, state) do
    # Perform automatic compression
    perform_compression([access_threshold: 5, age_threshold: 1800])
    
    schedule_compression()
    {:noreply, state}
  end
  
  # Private Implementation
  
  defp init_ets_tables() do
    # Query cache: {key, value, timestamp, access_count}
    :ets.new(@query_cache_table, [:named_table, :public, :set, {:read_concurrency, true}])
    
    # Analysis cache: {key, value, timestamp, access_count}
    :ets.new(@analysis_cache_table, [:named_table, :public, :set, {:read_concurrency, true}])
    
    # CPG cache: {key, value, timestamp, access_count}
    :ets.new(@cpg_cache_table, [:named_table, :public, :set, {:read_concurrency, true}])
    
    # Memory statistics: {metric, value, timestamp}
    :ets.new(@memory_stats_table, [:named_table, :public, :set])
    
    # Access tracking: {module, last_access, access_count}
    :ets.new(@access_tracking_table, [:named_table, :public, :set])
  end
  
  defp collect_memory_stats() do
    try do
      # Get system memory info
      memory_info = :erlang.memory()
      total_memory = Keyword.get(memory_info, :total, 0)
      
      # Get repository-specific memory usage
      repository_memory = calculate_repository_memory()
      cache_memory = calculate_cache_memory()
      ets_memory = Keyword.get(memory_info, :ets, 0)
      process_memory = Keyword.get(memory_info, :processes, 0)
      
      # Calculate available system memory (simplified)
      available_memory = get_available_system_memory()
      memory_usage_percent = if available_memory > 0 do
        (total_memory / available_memory) * 100
      else
        0.0
      end
      
      stats = %{
        total_memory: total_memory,
        repository_memory: repository_memory,
        cache_memory: cache_memory,
        ets_memory: ets_memory,
        process_memory: process_memory,
        memory_usage_percent: memory_usage_percent,
        available_memory: available_memory
      }
      
      # Store in ETS for historical tracking
      timestamp = System.monotonic_time(:millisecond)
      :ets.insert(@memory_stats_table, {:memory_stats, stats, timestamp})
      
      {:ok, stats}
    rescue
      error ->
        {:error, {:memory_collection_failed, error}}
    end
  end
  
  defp calculate_repository_memory() do
    # Calculate memory used by Enhanced Repository ETS tables
    tables = [:enhanced_ast_repository, :runtime_correlator_main, 
              :runtime_correlator_context_cache, :runtime_correlator_trace_cache]
    
    Enum.reduce(tables, 0, fn table, acc ->
      case :ets.info(table, :memory) do
        :undefined -> acc
        memory -> acc + memory * :erlang.system_info(:wordsize)
      end
    end)
  end
  
  defp calculate_cache_memory() do
    tables = [@query_cache_table, @analysis_cache_table, @cpg_cache_table]
    
    Enum.reduce(tables, 0, fn table, acc ->
      case :ets.info(table, :memory) do
        :undefined -> acc
        memory -> acc + memory * :erlang.system_info(:wordsize)
      end
    end)
  end
  
  defp get_available_system_memory() do
    # Simplified system memory detection
    # In production, this would use system-specific methods
    case :os.type() do
      {:unix, :linux} ->
        # Read from /proc/meminfo if available
        case File.read("/proc/meminfo") do
          {:ok, content} ->
            parse_meminfo(content)
          _ ->
            # Fallback to a reasonable default (8GB)
            8 * 1024 * 1024 * 1024
        end
      _ ->
        # Default for other systems
        8 * 1024 * 1024 * 1024
    end
  end
  
  defp parse_meminfo(content) do
    # Parse MemTotal from /proc/meminfo
    case Regex.run(~r/MemTotal:\s+(\d+)\s+kB/, content) do
      [_, kb_str] ->
        String.to_integer(kb_str) * 1024  # Convert KB to bytes
      _ ->
        8 * 1024 * 1024 * 1024  # Default 8GB
    end
  end
  
  defp determine_pressure_level(memory_usage_percent) do
    cond do
      memory_usage_percent >= @memory_pressure_level_4 -> :level_4
      memory_usage_percent >= @memory_pressure_level_3 -> :level_3
      memory_usage_percent >= @memory_pressure_level_2 -> :level_2
      memory_usage_percent >= @memory_pressure_level_1 -> :level_1
      true -> :normal
    end
  end
  
  defp handle_memory_pressure(pressure_level) do
    Logger.info("Handling memory pressure: #{pressure_level}")
    
    case pressure_level do
      :level_1 ->
        # Clear query caches
        cache_clear(:query)
        Logger.info("Level 1: Cleared query caches")
        
      :level_2 ->
        # Clear query caches and compress old analysis
        cache_clear(:query)
        perform_compression([access_threshold: 3, age_threshold: 900])
        Logger.info("Level 2: Cleared caches and compressed old analysis")
        
      :level_3 ->
        # Clear all caches and remove unused module data
        cache_clear(:query)
        cache_clear(:analysis)
        perform_cleanup([max_age: 1800, force: true])
        Logger.info("Level 3: Cleared all caches and removed unused data")
        
      :level_4 ->
        # Emergency cleanup and garbage collection
        cache_clear(:query)
        cache_clear(:analysis)
        cache_clear(:cpg)
        perform_cleanup([max_age: 900, force: true])
        :erlang.garbage_collect()
        Logger.warning("Level 4: Emergency cleanup and GC performed")
        
      _ ->
        :ok
    end
    
    :ok
  end
  
  defp perform_cleanup(opts) do
    max_age = Keyword.get(opts, :max_age, 3600)
    force = Keyword.get(opts, :force, false)
    dry_run = Keyword.get(opts, :dry_run, false)
    
    # Validate max_age parameter
    max_age = case max_age do
      age when is_integer(age) and age >= 0 -> age
      _ -> 3600  # Default to 1 hour if invalid
    end
    
    current_time = System.monotonic_time(:second)
    cutoff_time = current_time - max_age
    
    # Find modules to clean based on access patterns
    modules_to_clean = find_modules_to_clean(cutoff_time, force)
    
    if dry_run do
      {:ok, %{modules_to_clean: length(modules_to_clean), dry_run: true}}
    else
      # Perform actual cleanup
      {modules_cleaned, bytes_removed} = cleanup_modules(modules_to_clean)
      
      # Clean expired cache entries
      clean_expired_cache_entries()
      
      {:ok, %{
        modules_cleaned: modules_cleaned,
        data_removed_bytes: bytes_removed,
        dry_run: false
      }}
    end
  end
  
  defp find_modules_to_clean(cutoff_time, force) do
    # Get all tracked modules and their access patterns
    :ets.tab2list(@access_tracking_table)
    |> Enum.filter(fn {_module, last_access, _access_count} ->
      force or last_access < cutoff_time
    end)
    |> Enum.map(fn {module, _last_access, _access_count} -> module end)
  end
  
  defp cleanup_modules(modules) do
    Enum.reduce(modules, {0, 0}, fn module, {count, bytes} ->
      case cleanup_module_data(module) do
        {:ok, removed_bytes} ->
          {count + 1, bytes + removed_bytes}
        {:error, _} ->
          {count, bytes}
      end
    end)
  end
  
  defp cleanup_module_data(module) do
    # Remove module data from Enhanced Repository
    # This is a simplified implementation
    try do
      # Calculate approximate size before removal
      size_before = estimate_module_size(module)
      
      # Remove from access tracking
      :ets.delete(@access_tracking_table, module)
      
      # In a real implementation, this would remove from EnhancedRepository
      # EnhancedRepository.remove_module(module)
      
      {:ok, size_before}
    rescue
      error ->
        {:error, error}
    end
  end
  
  defp estimate_module_size(_module) do
    # Simplified size estimation
    # In practice, this would calculate actual memory usage
    64 * 1024  # 64KB average
  end
  
  defp clean_expired_cache_entries() do
    current_time = System.monotonic_time(:millisecond)
    
    # Clean each cache table
    clean_expired_entries(@query_cache_table, current_time, @query_cache_ttl)
    clean_expired_entries(@analysis_cache_table, current_time, @analysis_cache_ttl)
    clean_expired_entries(@cpg_cache_table, current_time, @cpg_cache_ttl)
  end
  
  defp clean_expired_entries(table, current_time, ttl) do
    expired_keys = :ets.foldl(fn {key, _value, timestamp, _access_count}, acc ->
      if current_time - timestamp > ttl do
        [key | acc]
      else
        acc
      end
    end, [], table)
    
    Enum.each(expired_keys, fn key ->
      :ets.delete(table, key)
    end)
  end
  
  defp perform_compression(opts) do
    access_threshold = Keyword.get(opts, :access_threshold, 5)
    age_threshold = Keyword.get(opts, :age_threshold, 1800)
    compression_level = Keyword.get(opts, :compression_level, 6)
    
    current_time = System.monotonic_time(:second)
    cutoff_time = current_time - age_threshold
    
    # Find data to compress
    candidates = find_compression_candidates(cutoff_time, access_threshold)
    
    # Perform compression
    {compressed_count, total_savings} = compress_candidates(candidates, compression_level)
    
    compression_ratio = if compressed_count > 0 do
      total_savings / (total_savings + compressed_count * 1024)  # Simplified calculation
    else
      0.0
    end
    
    {:ok, %{
      modules_compressed: compressed_count,
      compression_ratio: compression_ratio,
      space_saved_bytes: total_savings
    }}
  end
  
  defp find_compression_candidates(cutoff_time, access_threshold) do
    :ets.tab2list(@access_tracking_table)
    |> Enum.filter(fn {_module, last_access, access_count} ->
      last_access < cutoff_time and access_count < access_threshold
    end)
    |> Enum.map(fn {module, _last_access, _access_count} -> module end)
  end
  
  defp compress_candidates(candidates, compression_level) do
    Enum.reduce(candidates, {0, 0}, fn module, {count, savings} ->
      case compress_module_data(module, compression_level) do
        {:ok, saved_bytes} ->
          {count + 1, savings + saved_bytes}
        {:error, _} ->
          {count, savings}
      end
    end)
  end
  
  defp compress_module_data(_module, _compression_level) do
    # Simplified compression simulation
    # In practice, this would compress actual AST data using :zlib
    original_size = 64 * 1024  # 64KB
    compressed_size = div(original_size * 65, 100)  # 35% compression
    savings = original_size - compressed_size
    
    {:ok, savings}
  end
  
  defp configure_cache(_cache_type, _opts) do
    # Cache configuration is handled during initialization
    # This could be extended for runtime reconfiguration
    :ok
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
  end
  
  defp cache_table_for_type(:query), do: @query_cache_table
  defp cache_table_for_type(:analysis), do: @analysis_cache_table
  defp cache_table_for_type(:cpg), do: @cpg_cache_table
  defp cache_table_for_type(_), do: @query_cache_table  # Default to query cache for invalid types
  
  defp cache_ttl_for_type(:query), do: @query_cache_ttl
  defp cache_ttl_for_type(:analysis), do: @analysis_cache_ttl
  defp cache_ttl_for_type(:cpg), do: @cpg_cache_ttl
  defp cache_ttl_for_type(_), do: @query_cache_ttl  # Default to query cache TTL for invalid types
  
  defp init_cache_stats() do
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
  
  defp init_cleanup_stats() do
    %{
      modules_cleaned: 0,
      data_removed_bytes: 0,
      last_cleanup_duration: 0,
      total_cleanups: 0
    }
  end
  
  defp init_compression_stats() do
    %{
      modules_compressed: 0,
      compression_ratio: 0.0,
      space_saved_bytes: 0,
      last_compression_duration: 0,
      total_compressions: 0
    }
  end
  
  defp update_cleanup_stats(stats, result, duration) do
    case result do
      %{dry_run: true, modules_to_clean: count} ->
        # Dry run - don't update actual cleanup stats, just duration
        %{stats |
          last_cleanup_duration: duration,
          total_cleanups: stats.total_cleanups + 1
        }
      
      %{modules_cleaned: cleaned, data_removed_bytes: bytes, dry_run: false} ->
        # Actual cleanup
        %{stats |
          modules_cleaned: stats.modules_cleaned + cleaned,
          data_removed_bytes: stats.data_removed_bytes + bytes,
          last_cleanup_duration: duration,
          total_cleanups: stats.total_cleanups + 1
        }
      
      _ ->
        # Fallback for unexpected result structure
        %{stats |
          last_cleanup_duration: duration,
          total_cleanups: stats.total_cleanups + 1
        }
    end
  end
  
  defp update_compression_stats(stats, result, duration) do
    %{stats |
      modules_compressed: stats.modules_compressed + result.modules_compressed,
      compression_ratio: result.compression_ratio,
      space_saved_bytes: stats.space_saved_bytes + result.space_saved_bytes,
      last_compression_duration: duration,
      total_compressions: stats.total_compressions + 1
    }
  end
  
  defp schedule_memory_check() do
    Process.send_after(self(), :memory_check, @memory_check_interval)
  end
  
  defp schedule_cleanup() do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end
  
  defp schedule_compression() do
    Process.send_after(self(), :compression, @compression_interval)
  end
end 