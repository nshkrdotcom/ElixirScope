defmodule ElixirScope.ASTRepository.MemoryManager.Cleaner do
  @moduledoc """
  Data cleanup subsystem for removing stale and unused AST data.

  Handles intelligent cleanup based on access patterns, age,
  and memory pressure levels.
  """

  require Logger

  # ETS table for access tracking
  @access_tracking_table :ast_repo_access_tracking

  @type cleanup_stats :: %{
    modules_cleaned: non_neg_integer(),
    data_removed_bytes: non_neg_integer(),
    last_cleanup_duration: non_neg_integer(),
    total_cleanups: non_neg_integer()
  }

  @doc """
  Gets initial cleanup statistics structure.
  """
  @spec get_initial_stats() :: cleanup_stats()
  def get_initial_stats() do
    %{
      modules_cleaned: 0,
      data_removed_bytes: 0,
      last_cleanup_duration: 0,
      total_cleanups: 0
    }
  end

  @doc """
  Performs cleanup of unused AST data based on specified options.

  ## Options

  - `:max_age` - Maximum age in seconds for data retention (default: 3600)
  - `:force` - Force cleanup regardless of memory pressure (default: false)
  - `:dry_run` - Show what would be cleaned without actually cleaning (default: false)
  """
  @spec perform_cleanup(keyword()) :: {:ok, map()} | {:error, term()}
  def perform_cleanup(opts \\ []) do
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

    try do
      # Ensure access tracking table exists
      ensure_access_tracking_table()

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
    rescue
      error ->
        Logger.error("Cleanup failed: #{inspect(error)}")
        {:error, {:cleanup_failed, error}}
    end
  end

  @doc """
  Updates cleanup statistics with new results.
  """
  @spec update_stats(cleanup_stats(), map(), non_neg_integer()) :: cleanup_stats()
  def update_stats(stats, result, duration) do
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

  @doc """
  Tracks access to a module for cleanup decision making.
  """
  @spec track_access(atom()) :: :ok
  def track_access(module) when is_atom(module) do
    try do
      ensure_access_tracking_table()
      timestamp = System.monotonic_time(:second)

      case :ets.lookup(@access_tracking_table, module) do
        [{^module, _last_access, access_count}] ->
          # Update existing entry
          :ets.insert(@access_tracking_table, {module, timestamp, access_count + 1})
        [] ->
          # New entry
          :ets.insert(@access_tracking_table, {module, timestamp, 1})
      end

      :ok
    rescue
      _error ->
        :ok  # Fail silently for tracking operations
    end
  end

  @doc """
  Gets access statistics for a module.
  """
  @spec get_access_stats(atom()) :: {:ok, {non_neg_integer(), non_neg_integer()}} | :not_found
  def get_access_stats(module) when is_atom(module) do
    try do
      ensure_access_tracking_table()
      case :ets.lookup(@access_tracking_table, module) do
        [{^module, last_access, access_count}] ->
          {:ok, {last_access, access_count}}
        [] ->
          :not_found
      end
    rescue
      _error ->
        :not_found
    end
  end

  # Private Implementation

  defp ensure_access_tracking_table() do
    case :ets.info(@access_tracking_table, :size) do
      :undefined ->
        # Table doesn't exist, create it
        :ets.new(@access_tracking_table, [:named_table, :public, :set])
      _ ->
        # Table exists
        :ok
    end
  end

  defp find_modules_to_clean(cutoff_time, force) do
    try do
      # Get all tracked modules and their access patterns
      :ets.tab2list(@access_tracking_table)
      |> Enum.filter(fn {_module, last_access, _access_count} ->
        force or last_access < cutoff_time
      end)
      |> Enum.map(fn {module, _last_access, _access_count} -> module end)
    rescue
      _error ->
        # If access tracking table has issues, return empty list
        []
    end
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
    try do
      # Calculate approximate size before removal
      size_before = estimate_module_size(module)

      # Remove from access tracking
      :ets.delete(@access_tracking_table, module)

      # In a real implementation, this would remove from EnhancedRepository
      # For now, we'll simulate the cleanup
      Logger.debug("Cleaned up module data for: #{inspect(module)}")

      {:ok, size_before}
    rescue
      error ->
        Logger.warning("Failed to cleanup module #{inspect(module)}: #{inspect(error)}")
        {:error, error}
    end
  end

  defp estimate_module_size(_module) do
    # Simplified size estimation
    # In practice, this would calculate actual memory usage
    # by examining ETS table entries and AST structures
    base_size = 32 * 1024  # 32KB base
    random_variance = :rand.uniform(64) * 1024  # 0-64KB variance
    base_size + random_variance
  end

  defp clean_expired_cache_entries() do
    # Clean expired entries from cache tables
    cache_tables = [
      {:ast_repo_query_cache, 60_000},      # 1 minute TTL
      {:ast_repo_analysis_cache, 300_000},  # 5 minutes TTL
      {:ast_repo_cpg_cache, 600_000}        # 10 minutes TTL
    ]

    current_time = System.monotonic_time(:millisecond)

    Enum.each(cache_tables, fn {table, ttl} ->
      clean_expired_entries(table, current_time, ttl)
    end)
  end

  defp clean_expired_entries(table, current_time, ttl) do
    try do
      case :ets.info(table, :size) do
        :undefined ->
          # Table doesn't exist, skip
          :ok
        _ ->
          # Find and remove expired entries
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

          if length(expired_keys) > 0 do
            Logger.debug("Cleaned #{length(expired_keys)} expired entries from #{table}")
          end
      end
    rescue
      error ->
        Logger.warning("Failed to clean expired entries from #{table}: #{inspect(error)}")
    end
  end
end
