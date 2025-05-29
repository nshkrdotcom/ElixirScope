defmodule ElixirScope.ASTRepository.MemoryManager.Monitor do
  @moduledoc """
  Memory monitoring subsystem for tracking repository memory usage.

  Provides real-time memory statistics and historical tracking
  for the AST Repository system.
  """

  use GenServer
  require Logger

  # ETS table for memory statistics
  @memory_stats_table :ast_repo_memory_stats

  @type memory_stats :: %{
    total_memory: non_neg_integer(),
    repository_memory: non_neg_integer(),
    cache_memory: non_neg_integer(),
    ets_memory: non_neg_integer(),
    process_memory: non_neg_integer(),
    memory_usage_percent: float(),
    available_memory: non_neg_integer()
  }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # Initialize ETS table for memory statistics
    :ets.new(@memory_stats_table, [:named_table, :public, :set])
    {:ok, %{}}
  end

  def handle_call(:collect_memory_stats, _from, state) do
    case collect_memory_stats() do
      {:ok, stats} -> {:reply, {:ok, stats}, state}
      error -> {:reply, error, state}
    end
  end

  def handle_call(_request, _from, state) do
    {:reply, {:error, :unknown_call}, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @doc """
  Collects comprehensive memory statistics.
  """
  @spec collect_memory_stats() :: {:ok, memory_stats()} | {:error, term()}
  def collect_memory_stats() do
    try do
      # Get system memory info
      memory_info = :erlang.memory()
      total_memory = Keyword.get(memory_info, :total, 0)

      # Get repository-specific memory usage
      repository_memory = calculate_repository_memory()
      cache_memory = calculate_cache_memory()
      ets_memory = Keyword.get(memory_info, :ets, 0)
      process_memory = Keyword.get(memory_info, :processes, 0)

      # Calculate available system memory
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
        Logger.error("Memory collection failed: #{inspect(error)}")
        {:error, {:memory_collection_failed, error}}
    end
  end

  @doc """
  Gets historical memory statistics.
  """
  @spec get_historical_stats(non_neg_integer()) :: list(memory_stats())
  def get_historical_stats(limit \\ 100) do
    case :ets.lookup(@memory_stats_table, :memory_stats) do
      [] -> []
      records ->
        records
        |> Enum.sort_by(fn {_, _, timestamp} -> timestamp end, :desc)
        |> Enum.take(limit)
        |> Enum.map(fn {_, stats, _} -> stats end)
    end
  end

  # Private Implementation

  defp calculate_repository_memory() do
    # Calculate memory used by Enhanced Repository ETS tables
    tables = [
      :enhanced_ast_repository,
      :runtime_correlator_main,
      :runtime_correlator_context_cache,
      :runtime_correlator_trace_cache
    ]

    Enum.reduce(tables, 0, fn table, acc ->
      case :ets.info(table, :memory) do
        :undefined -> acc
        memory -> acc + memory * :erlang.system_info(:wordsize)
      end
    end)
  end

  defp calculate_cache_memory() do
    cache_tables = [
      :ast_repo_query_cache,
      :ast_repo_analysis_cache,
      :ast_repo_cpg_cache
    ]

    Enum.reduce(cache_tables, 0, fn table, acc ->
      case :ets.info(table, :memory) do
        :undefined -> acc
        memory -> acc + memory * :erlang.system_info(:wordsize)
      end
    end)
  end

  defp get_available_system_memory() do
    # System memory detection with fallbacks
    case :os.type() do
      {:unix, :linux} ->
        get_linux_memory()
      {:unix, :darwin} ->
        get_macos_memory()
      {:win32, _} ->
        get_windows_memory()
      _ ->
        # Default fallback (8GB)
        8 * 1024 * 1024 * 1024
    end
  end

  defp get_linux_memory() do
    case File.read("/proc/meminfo") do
      {:ok, content} ->
        parse_meminfo(content)
      {:error, _} ->
        # Fallback to reasonable default
        8 * 1024 * 1024 * 1024
    end
  end

  defp get_macos_memory() do
    # Try to use system_profiler or sysctl
    case System.cmd("sysctl", ["-n", "hw.memsize"], stderr_to_stdout: true) do
      {output, 0} ->
        case Integer.parse(String.trim(output)) do
          {bytes, _} -> bytes
          _ -> 8 * 1024 * 1024 * 1024
        end
      _ ->
        8 * 1024 * 1024 * 1024
    end
  rescue
    _ ->
      8 * 1024 * 1024 * 1024
  end

  defp get_windows_memory() do
    # Windows memory detection would require WMI or system calls
    # For now, use a reasonable default
    8 * 1024 * 1024 * 1024
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
end
