defmodule ElixirScope.ASTRepository.MemoryManager do
  @moduledoc """
  Main memory management coordinator for the Enhanced AST Repository.

  Orchestrates memory monitoring, cleanup, compression, and caching
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

  ## Examples

      # Start memory monitoring
      {:ok, _pid} = MemoryManager.start_link()

      # Monitor memory usage
      {:ok, stats} = MemoryManager.monitor_memory_usage()

      # Cleanup unused data
      :ok = MemoryManager.cleanup_unused_data(max_age: 3600)
  """

  use GenServer
  require Logger

  alias ElixirScope.ASTRepository.MemoryManager.{
    Monitor,
    Cleaner,
    Compressor,
    CacheManager,
    PressureHandler
  }

  # Configuration
  @memory_check_interval 30_000      # 30 seconds
  @cleanup_interval 300_000          # 5 minutes
  @compression_interval 600_000      # 10 minutes

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

  @type memory_stats :: Monitor.memory_stats()
  @type cache_stats :: CacheManager.cache_stats()
  @type cleanup_stats :: Cleaner.cleanup_stats()
  @type compression_stats :: Compressor.compression_stats()

  # GenServer API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    # Schedule periodic tasks
    schedule_memory_check()
    schedule_cleanup()
    schedule_compression()

    state = %__MODULE__{
      memory_stats: %{},
      cache_stats: CacheManager.get_initial_stats(),
      cleanup_stats: Cleaner.get_initial_stats(),
      compression_stats: Compressor.get_initial_stats(),
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
  """
  @spec monitor_memory_usage() :: {:ok, memory_stats()} | {:error, term()}
  def monitor_memory_usage() do
    GenServer.call(__MODULE__, :monitor_memory_usage)
  end

  @doc """
  Cleans up unused AST data based on access patterns and age.
  """
  @spec cleanup_unused_data(keyword()) :: :ok | {:error, term()}
  def cleanup_unused_data(opts \\ []) do
    GenServer.call(__MODULE__, {:cleanup_unused_data, opts}, 30_000)
  end

  @doc """
  Compresses infrequently accessed analysis data.
  """
  @spec compress_old_analysis(keyword()) :: {:ok, compression_stats()} | {:error, term()}
  def compress_old_analysis(opts \\ []) do
    GenServer.call(__MODULE__, {:compress_old_analysis, opts}, 30_000)
  end

  @doc """
  Implements LRU (Least Recently Used) cache for query optimization.
  """
  @spec implement_lru_cache(atom(), keyword()) :: :ok | {:error, term()}
  def implement_lru_cache(cache_type, opts \\ []) do
    GenServer.call(__MODULE__, {:implement_lru_cache, cache_type, opts})
  end

  @doc """
  Handles memory pressure situations with appropriate response levels.
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

  # Cache API (delegated to CacheManager)

  @doc """
  Gets a value from the specified cache.
  """
  @spec cache_get(atom(), term()) :: {:ok, term()} | :miss
  def cache_get(cache_type, key) do
    CacheManager.get(cache_type, key)
  end

  @doc """
  Puts a value in the specified cache.
  """
  @spec cache_put(atom(), term(), term()) :: :ok
  def cache_put(cache_type, key, value) do
    CacheManager.put(cache_type, key, value)
  end

  @doc """
  Clears the specified cache.
  """
  @spec cache_clear(atom()) :: :ok
  def cache_clear(cache_type) do
    CacheManager.clear(cache_type)
  end

  # GenServer Callbacks

  def handle_call(:monitor_memory_usage, _from, state) do
    case Monitor.collect_memory_stats() do
      {:ok, memory_stats} ->
        new_state = %{state | memory_stats: memory_stats}
        {:reply, {:ok, memory_stats}, new_state}
      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:cleanup_unused_data, opts}, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    case Cleaner.perform_cleanup(opts) do
      {:ok, cleanup_result} ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        new_cleanup_stats = Cleaner.update_stats(state.cleanup_stats, cleanup_result, duration)
        new_state = %{state |
          cleanup_stats: new_cleanup_stats,
          last_cleanup: end_time
        }

        # Return the cleanup result, not just :ok
        {:reply, {:ok, cleanup_result}, new_state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:compress_old_analysis, opts}, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    case Compressor.perform_compression(opts) do
      {:ok, compression_result} ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        new_compression_stats = Compressor.update_stats(state.compression_stats, compression_result, duration)
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
    case CacheManager.configure_cache(cache_type, opts) do
      :ok ->
        {:reply, :ok, state}
      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:memory_pressure_handler, pressure_level}, _from, state) do
    case PressureHandler.handle_pressure(pressure_level) do
      :ok ->
        new_state = %{state | pressure_level: pressure_level}
        {:reply, :ok, new_state}
      error ->
        {:reply, error, state}
    end
  end

  def handle_call(:get_stats, _from, state) do
    cache_stats = CacheManager.get_stats()

    stats = %{
      memory: state.memory_stats,
      cache: cache_stats,
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
      case Monitor.collect_memory_stats() do
        {:ok, memory_stats} ->
          # Check for memory pressure
          pressure_level = PressureHandler.determine_pressure_level(memory_stats.memory_usage_percent)

          if pressure_level != :normal and pressure_level != state.pressure_level do
            Logger.warning("Memory pressure detected: #{pressure_level} (#{memory_stats.memory_usage_percent}%)")
            PressureHandler.handle_pressure(pressure_level)
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
    Cleaner.perform_cleanup([max_age: 3600])

    schedule_cleanup()
    {:noreply, state}
  end

  def handle_info(:compression, state) do
    # Perform automatic compression
    Compressor.perform_compression([access_threshold: 5, age_threshold: 1800])

    schedule_compression()
    {:noreply, state}
  end

  # Private Implementation

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
