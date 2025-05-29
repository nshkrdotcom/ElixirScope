defmodule ElixirScope.ASTRepository.MemoryManager.PressureHandler do
  @moduledoc """
  Memory pressure handling subsystem for responding to memory constraints.

  Implements multi-level memory pressure handling from cache clearing
  to emergency cleanup and garbage collection.
  """

  require Logger

  alias ElixirScope.ASTRepository.MemoryManager.{CacheManager, Cleaner, Compressor}

  # Memory pressure thresholds (percentage of available memory)
  @memory_pressure_level_1 80
  @memory_pressure_level_2 90
  @memory_pressure_level_3 95
  @memory_pressure_level_4 98

  @doc """
  Determines the memory pressure level based on memory usage percentage.

  ## Pressure Levels

  - `:normal` - Below 80% memory usage
  - `:level_1` - 80-89% memory usage (Clear query caches)
  - `:level_2` - 90-94% memory usage (Compress old analysis data)
  - `:level_3` - 95-97% memory usage (Remove unused module data)
  - `:level_4` - 98%+ memory usage (Emergency cleanup and GC)
  """
  @spec determine_pressure_level(float()) :: atom()
  def determine_pressure_level(memory_usage_percent) do
    cond do
      memory_usage_percent >= @memory_pressure_level_4 -> :level_4
      memory_usage_percent >= @memory_pressure_level_3 -> :level_3
      memory_usage_percent >= @memory_pressure_level_2 -> :level_2
      memory_usage_percent >= @memory_pressure_level_1 -> :level_1
      true -> :normal
    end
  end

  @doc """
  Handles memory pressure situations with appropriate response levels.

  Each level implements progressively more aggressive memory management
  strategies to reduce memory usage.
  """
  @spec handle_pressure(atom()) :: :ok | {:error, term()}
  def handle_pressure(pressure_level) do
    Logger.info("Handling memory pressure: #{pressure_level}")

    try do
      case pressure_level do
        :level_1 ->
          handle_level_1_pressure()

        :level_2 ->
          handle_level_2_pressure()

        :level_3 ->
          handle_level_3_pressure()

        :level_4 ->
          handle_level_4_pressure()

        :normal ->
          # No action needed for normal pressure
          :ok

        _ ->
          Logger.warning("Unknown pressure level: #{pressure_level}")
          :ok
      end
    rescue
      error ->
        Logger.error("Failed to handle memory pressure #{pressure_level}: #{inspect(error)}")
        {:error, {:pressure_handling_failed, error}}
    end
  end

  @doc """
  Gets memory pressure thresholds configuration.
  """
  @spec get_pressure_thresholds() :: map()
  def get_pressure_thresholds() do
    %{
      level_1: @memory_pressure_level_1,
      level_2: @memory_pressure_level_2,
      level_3: @memory_pressure_level_3,
      level_4: @memory_pressure_level_4
    }
  end

  @doc """
  Estimates memory that would be freed by each pressure level.
  """
  @spec estimate_memory_savings(atom()) :: {:ok, non_neg_integer()} | {:error, term()}
  def estimate_memory_savings(pressure_level) do
    try do
      savings = case pressure_level do
        :level_1 ->
          estimate_cache_memory(:query)

        :level_2 ->
          estimate_cache_memory(:query) + estimate_compression_savings()

        :level_3 ->
          estimate_cache_memory(:query) +
          estimate_cache_memory(:analysis) +
          estimate_cleanup_savings()

        :level_4 ->
          estimate_cache_memory(:query) +
          estimate_cache_memory(:analysis) +
          estimate_cache_memory(:cpg) +
          estimate_cleanup_savings() +
          estimate_gc_savings()

        _ ->
          0
      end

      {:ok, savings}
    rescue
      error ->
        {:error, error}
    end
  end

  # Private Implementation

  defp handle_level_1_pressure() do
    # Level 1: Clear query caches (80% memory usage)
    Logger.info("Level 1 pressure: Clearing query caches")

    CacheManager.clear(:query)

    # Log memory savings
    log_pressure_action("Level 1", "Cleared query caches")
    :ok
  end

  defp handle_level_2_pressure() do
    # Level 2: Clear query caches and compress old analysis (90% memory usage)
    Logger.info("Level 2 pressure: Clearing caches and compressing old analysis")

    # Clear query caches
    CacheManager.clear(:query)

    # Compress old analysis data
    case Compressor.perform_compression([access_threshold: 3, age_threshold: 900]) do
      {:ok, stats} ->
        Logger.info("Compression saved #{stats.space_saved_bytes} bytes (#{Float.round(stats.compression_ratio * 100, 1)}% ratio)")
      {:error, reason} ->
        Logger.warning("Compression failed: #{inspect(reason)}")
    end

    log_pressure_action("Level 2", "Cleared caches and compressed old analysis")
    :ok
  end

  defp handle_level_3_pressure() do
    # Level 3: Clear all caches and remove unused module data (95% memory usage)
    Logger.info("Level 3 pressure: Clearing all caches and removing unused data")

    # Clear query and analysis caches
    CacheManager.clear(:query)
    CacheManager.clear(:analysis)

    # Perform aggressive cleanup
    case Cleaner.perform_cleanup([max_age: 1800, force: true]) do
      {:ok, stats} ->
        Logger.info("Cleanup removed #{stats[:modules_cleaned] || 0} modules, #{stats[:data_removed_bytes] || 0} bytes")
      {:error, reason} ->
        Logger.warning("Cleanup failed: #{inspect(reason)}")
    end

    log_pressure_action("Level 3", "Cleared all caches and removed unused data")
    :ok
  end

  defp handle_level_4_pressure() do
    # Level 4: Emergency cleanup and garbage collection (98% memory usage)
    Logger.warning("Level 4 pressure: Emergency cleanup and GC")

    # Clear all caches
    CacheManager.clear(:query)
    CacheManager.clear(:analysis)
    CacheManager.clear(:cpg)

    # Emergency cleanup with very short retention
    case Cleaner.perform_cleanup([max_age: 900, force: true]) do
      {:ok, stats} ->
        Logger.info("Emergency cleanup removed #{stats[:modules_cleaned] || 0} modules")
      {:error, reason} ->
        Logger.warning("Emergency cleanup failed: #{inspect(reason)}")
    end

    # Force garbage collection
    perform_aggressive_gc()

    log_pressure_action("Level 4", "Emergency cleanup and GC performed")
    :ok
  end

  defp perform_aggressive_gc() do
    Logger.info("Performing aggressive garbage collection")

    # Force GC on current process
    :erlang.garbage_collect()

    # Force GC on all processes (be careful in production)
    gc_count = 0
    for pid <- Process.list() do
      if Process.alive?(pid) do
        try do
          :erlang.garbage_collect(pid)
          gc_count = gc_count + 1
        rescue
          _ -> :ok  # Ignore errors for dead/system processes
        end
      end
    end

    Logger.info("Garbage collected #{gc_count} processes")
  end

  defp estimate_cache_memory(cache_type) do
    # Estimate memory used by a specific cache type
    table = case cache_type do
      :query -> :ast_repo_query_cache
      :analysis -> :ast_repo_analysis_cache
      :cpg -> :ast_repo_cpg_cache
    end

    case :ets.info(table, :memory) do
      :undefined -> 0
      memory -> memory * :erlang.system_info(:wordsize)
    end
  end

  defp estimate_compression_savings() do
    # Estimate memory savings from compression
    # Based on typical compression ratios of 65% (35% savings)
    access_table = :ast_repo_access_tracking

    case :ets.info(access_table, :size) do
      :undefined -> 0
      size ->
        # Estimate 64KB average per module, 35% compression savings
        estimated_module_size = 64 * 1024
        compression_savings_ratio = 0.35
        div(size * estimated_module_size * compression_savings_ratio, 2)  # Conservative estimate
    end
  end

  defp estimate_cleanup_savings() do
    # Estimate memory savings from cleanup
    access_table = :ast_repo_access_tracking

    case :ets.info(access_table, :size) do
      :undefined -> 0
      size ->
        # Estimate cleanup will remove ~25% of tracked modules
        estimated_module_size = 64 * 1024
        cleanup_ratio = 0.25
        div(size * estimated_module_size * cleanup_ratio, 1)
    end
  end

  defp estimate_gc_savings() do
    # Estimate memory savings from garbage collection
    # Based on typical GC recovery of 10-20% of process memory
    memory_info = :erlang.memory()
    process_memory = Keyword.get(memory_info, :processes, 0)
    div(process_memory, 8)  # Conservative 12.5% estimate
  end

  defp log_pressure_action(level, action) do
    # Log pressure handling action with timestamp
    timestamp = System.monotonic_time(:millisecond)
    Logger.info("Memory pressure #{level}: #{action} at #{timestamp}")

    # Could also store in ETS for pressure handling history
    try do
      case :ets.info(:ast_repo_pressure_log, :size) do
        :undefined ->
          :ets.new(:ast_repo_pressure_log, [:named_table, :public, :ordered_set])
        _ -> :ok
      end

      :ets.insert(:ast_repo_pressure_log, {timestamp, level, action})

      # Keep only last 100 entries
      case :ets.info(:ast_repo_pressure_log, :size) do
        size when size > 100 ->
          # Remove oldest entries
          oldest_keys = :ets.foldl(fn {key, _, _}, acc -> [key | acc] end, [], :ast_repo_pressure_log)
          |> Enum.sort()
          |> Enum.take(size - 100)

          Enum.each(oldest_keys, fn key ->
            :ets.delete(:ast_repo_pressure_log, key)
          end)
        _ -> :ok
      end
    rescue
      _error -> :ok  # Fail silently for logging operations
    end
  end
end
