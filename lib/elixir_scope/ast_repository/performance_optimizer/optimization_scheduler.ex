# ==============================================================================
# Optimization Scheduler Component
# ==============================================================================

defmodule ElixirScope.ASTRepository.PerformanceOptimizer.OptimizationScheduler do
  @moduledoc """
  Schedules and manages periodic optimization tasks.
  """

  use GenServer
  require Logger

  alias ElixirScope.ASTRepository.MemoryManager

  @optimization_interval 600_000   # 10 minutes

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    schedule_optimization_cycle()
    {:ok, %{}}
  end

  @doc """
  Optimizes ETS table structures and indexes.
  """
  @spec optimize_ets_tables() :: :ok
  def optimize_ets_tables() do
    GenServer.cast(__MODULE__, :optimize_ets_tables)
  end

  def handle_cast(:optimize_ets_tables, state) do
    perform_ets_optimization()
    {:noreply, state}
  end

  def handle_info(:optimization_cycle, state) do
    perform_optimization_cycle()
    schedule_optimization_cycle()
    {:noreply, state}
  end

  # Private implementation
  defp perform_ets_optimization() do
    Logger.debug("Performing ETS optimization")
    # Placeholder for ETS optimization logic
    :ok
  end

  defp perform_optimization_cycle() do
    Logger.debug("Performing optimization cycle")

    {:ok, memory_stats} = MemoryManager.monitor_memory_usage()

    if memory_stats.memory_usage_percent > 70 do
      MemoryManager.cleanup_unused_data(max_age: 3600)
    end

    if memory_stats.memory_usage_percent > 60 do
      MemoryManager.compress_old_analysis(access_threshold: 5, age_threshold: 1800)
    end
  end

  defp schedule_optimization_cycle() do
    Process.send_after(self(), :optimization_cycle, @optimization_interval)
  end
end
