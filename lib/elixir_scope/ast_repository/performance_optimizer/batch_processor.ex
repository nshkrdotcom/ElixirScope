# ==============================================================================
# Batch Processing Component
# ==============================================================================

defmodule ElixirScope.ASTRepository.PerformanceOptimizer.BatchProcessor do
  @moduledoc """
  Handles batch operations for improved throughput and efficiency.
  """

  use GenServer
  require Logger

  alias ElixirScope.ASTRepository.EnhancedRepository

  @batch_size 50

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    {:ok, %{queue: [], processing: false}}
  end

  @doc """
  Processes multiple modules in optimized batches.
  """
  @spec process_modules([{atom(), term()}], keyword()) :: {:ok, [term()]} | {:error, term()}
  def process_modules(modules, opts) do
    GenServer.call(__MODULE__, {:process_modules, modules, opts}, 60_000)
  end

  @doc """
  Queues a module for batch processing.
  """
  @spec queue_module(atom(), term(), keyword()) :: :ok
  def queue_module(module_name, ast, opts) do
    GenServer.cast(__MODULE__, {:queue_module, module_name, ast, opts})
  end

  def handle_call({:process_modules, modules, _opts}, _from, state) do
    try do
      results = process_modules_in_batches(modules)
      {:reply, {:ok, results}, state}
    rescue
      error ->
        Logger.error("Batch processing failed: #{inspect(error)}")
        {:reply, {:error, {:batch_failed, error}}, state}
    end
  end

  def handle_cast({:queue_module, module_name, ast, opts}, state) do
    new_queue = [{module_name, ast, opts} | state.queue]
    new_state = %{state | queue: new_queue}

    # Process queue if it reaches batch size
    if length(new_queue) >= @batch_size do
      spawn(fn -> process_queued_modules(new_queue) end)
      {:noreply, %{new_state | queue: [], processing: true}}
    else
      {:noreply, new_state}
    end
  end

  # Private implementation
  defp process_modules_in_batches(modules) do
    modules
    |> Enum.chunk_every(@batch_size)
    |> Enum.flat_map(fn batch ->
      tasks = Enum.map(batch, fn {module_name, ast} ->
        Task.async(fn ->
          case store_module_optimized(module_name, ast) do
            {:ok, data} -> data
            {:error, _} -> nil
          end
        end)
      end)

      Task.await_many(tasks, 30_000)
      |> Enum.filter(& &1)
    end)
  end

  defp process_queued_modules(queue) do
    queue
    |> Enum.map(fn {module_name, ast, opts} ->
      case EnhancedRepository.store_enhanced_module(module_name, ast, opts) do
        {:ok, data} -> data
        {:error, _} -> nil
      end
    end)
    |> Enum.filter(& &1)
  end

  defp store_module_optimized(module_name, ast) do
    opts = [analysis_level: [:basic_metrics, :dependencies], optimized: true]
    EnhancedRepository.store_enhanced_module(module_name, ast, opts)
  end
end
