defmodule ElixirScope.ASTRepository.MemoryManager.Supervisor do
  @moduledoc """
  Supervisor for the Memory Manager subsystem.

  Manages the lifecycle of all memory management components including
  the main memory manager, monitor, and cache manager processes.
  """

  use Supervisor
  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    # Extract configuration options
    monitoring_enabled = Keyword.get(opts, :monitoring_enabled, true)
    cache_enabled = Keyword.get(opts, :cache_enabled, true)

    Logger.info("Starting Memory Manager Supervisor with monitoring=#{monitoring_enabled}, cache=#{cache_enabled}")

    children = build_children(monitoring_enabled, cache_enabled, opts)

    # Use :one_for_one strategy - if one child fails, only restart that child
    # This is appropriate since the components are relatively independent
    Supervisor.init(children, strategy: :one_for_one, max_restarts: 5, max_seconds: 30)
  end

  @doc """
  Gets the current status of all supervised processes.
  """
  @spec get_status() :: map()
  def get_status() do
    children = Supervisor.which_children(__MODULE__)

    status = Enum.reduce(children, %{}, fn {id, pid, type, modules}, acc ->
      child_status = if is_pid(pid) and Process.alive?(pid) do
        :running
      else
        :stopped
      end

      Map.put(acc, id, %{
        pid: pid,
        type: type,
        modules: modules,
        status: child_status
      })
    end)

    %{
      supervisor_pid: self(),
      children: status,
      total_children: length(children),
      running_children: Enum.count(status, fn {_, %{status: s}} -> s == :running end)
    }
  end

  @doc """
  Restarts a specific child process by ID.
  """
  @spec restart_child(atom()) :: :ok | {:error, term()}
  def restart_child(child_id) do
    case Supervisor.restart_child(__MODULE__, child_id) do
      {:ok, _pid} ->
        Logger.info("Successfully restarted #{child_id}")
        :ok
      {:ok, _pid, _info} ->
        Logger.info("Successfully restarted #{child_id}")
        :ok
      {:error, reason} ->
        Logger.error("Failed to restart #{child_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Stops a specific child process by ID.
  """
  @spec stop_child(atom()) :: :ok | {:error, term()}
  def stop_child(child_id) do
    case Supervisor.terminate_child(__MODULE__, child_id) do
      :ok ->
        Logger.info("Successfully stopped #{child_id}")
        :ok
      {:error, reason} ->
        Logger.error("Failed to stop #{child_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private Implementation

  defp build_children(monitoring_enabled, cache_enabled, opts) do
    # Build children in dependency order (dependencies first)
    children = []

    # Add Cache Manager first if caching is enabled (MemoryManager depends on it)
    children = if cache_enabled do
      [{ElixirScope.ASTRepository.MemoryManager.CacheManager, []} | children]
    else
      children
    end

    # Add Monitor if monitoring is enabled
    children = if monitoring_enabled do
      [{ElixirScope.ASTRepository.MemoryManager.Monitor, []} | children]
    else
      children
    end

    # Add main Memory Manager last (depends on others)
    children = [
      {ElixirScope.ASTRepository.MemoryManager,
      [monitoring_enabled: monitoring_enabled] ++ opts} | children
    ]

    # Return in correct startup order (dependencies first)
    Enum.reverse(children)
  end
end
