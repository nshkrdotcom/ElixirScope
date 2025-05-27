defmodule CinemaDemo.TaskManager do
  @moduledoc """
  A GenServer that manages tasks and demonstrates ElixirScope's temporal debugging capabilities.
  
  This module showcases:
  - Complex state transitions
  - Nested function calls
  - Error handling patterns
  - Performance-critical operations
  """
  
  use GenServer
  require Logger
  
  defstruct [
    :tasks,
    :completed_tasks,
    :failed_tasks,
    :stats,
    :last_cleanup
  ]
  
  @type task_id :: binary()
  @type task :: %{
    id: task_id(),
    name: binary(),
    priority: :low | :medium | :high | :critical,
    created_at: integer(),
    started_at: integer() | nil,
    completed_at: integer() | nil,
    data: map(),
    retries: non_neg_integer()
  }
  
  @type state :: %__MODULE__{
    tasks: %{task_id() => task()},
    completed_tasks: [task_id()],
    failed_tasks: [task_id()],
    stats: map(),
    last_cleanup: integer()
  }
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def create_task(name, priority \\ :medium, data \\ %{}) do
    GenServer.call(__MODULE__, {:create_task, name, priority, data})
  end
  
  def start_task(task_id) do
    GenServer.call(__MODULE__, {:start_task, task_id})
  end
  
  def complete_task(task_id, result \\ :success) do
    GenServer.call(__MODULE__, {:complete_task, task_id, result})
  end
  
  def get_stats() do
    GenServer.call(__MODULE__, :get_stats)
  end
  
  def get_task(task_id) do
    GenServer.call(__MODULE__, {:get_task, task_id})
  end
  
  def list_tasks(filter \\ :all) do
    GenServer.call(__MODULE__, {:list_tasks, filter})
  end
  
  def process_batch(task_ids) when is_list(task_ids) do
    GenServer.cast(__MODULE__, {:process_batch, task_ids})
  end
  
  # Server Implementation
  
  @impl true
  def init(_opts) do
    state = %__MODULE__{
      tasks: %{},
      completed_tasks: [],
      failed_tasks: [],
      stats: initialize_stats(),
      last_cleanup: System.monotonic_time(:millisecond)
    }
    
    # Schedule periodic cleanup
    schedule_cleanup()
    
    Logger.info("TaskManager started with initial state")
    {:ok, state}
  end
  
  @impl true
  def handle_call({:create_task, name, priority, data}, _from, state) do
    task_id = generate_task_id()
    
    task = %{
      id: task_id,
      name: name,
      priority: priority,
      created_at: System.monotonic_time(:millisecond),
      started_at: nil,
      completed_at: nil,
      data: data,
      retries: 0
    }
    
    new_state = %{state | 
      tasks: Map.put(state.tasks, task_id, task),
      stats: update_stats(state.stats, :task_created)
    }
    
    Logger.info("Created task #{task_id}: #{name}")
    {:reply, {:ok, task_id}, new_state}
  end
  
  @impl true
  def handle_call({:start_task, task_id}, _from, state) do
    case Map.get(state.tasks, task_id) do
      nil ->
        {:reply, {:error, :task_not_found}, state}
      
      task ->
        if task.started_at do
          {:reply, {:error, :already_started}, state}
        else
          updated_task = %{task | started_at: System.monotonic_time(:millisecond)}
          new_state = %{state | 
            tasks: Map.put(state.tasks, task_id, updated_task),
            stats: update_stats(state.stats, :task_started)
          }
          
          # Simulate some work based on priority
          work_result = perform_task_work(updated_task)
          
          Logger.info("Started task #{task_id}")
          {:reply, {:ok, work_result}, new_state}
        end
    end
  end
  
  @impl true
  def handle_call({:complete_task, task_id, result}, _from, state) do
    case Map.get(state.tasks, task_id) do
      nil ->
        {:reply, {:error, :task_not_found}, state}
      
      task ->
        _completed_task = %{task | completed_at: System.monotonic_time(:millisecond)}
        
        {new_tasks, new_completed, new_failed, stats_key} = 
          case result do
            :success ->
              {Map.delete(state.tasks, task_id), 
               [task_id | state.completed_tasks], 
               state.failed_tasks, 
               :task_completed}
            
            {:error, _reason} ->
              if task.retries < 3 do
                # Retry the task
                retry_task = %{task | retries: task.retries + 1, started_at: nil}
                {Map.put(state.tasks, task_id, retry_task), 
                 state.completed_tasks, 
                 state.failed_tasks, 
                 :task_retried}
              else
                # Mark as failed
                {Map.delete(state.tasks, task_id), 
                 state.completed_tasks, 
                 [task_id | state.failed_tasks], 
                 :task_failed}
              end
          end
        
        new_state = %{state | 
          tasks: new_tasks,
          completed_tasks: new_completed,
          failed_tasks: new_failed,
          stats: update_stats(state.stats, stats_key)
        }
        
        Logger.info("Completed task #{task_id} with result: #{inspect(result)}")
        {:reply, :ok, new_state}
    end
  end
  
  @impl true
  def handle_call(:get_stats, _from, state) do
    current_stats = calculate_current_stats(state)
    {:reply, current_stats, state}
  end
  
  @impl true
  def handle_call({:get_task, task_id}, _from, state) do
    task = Map.get(state.tasks, task_id)
    {:reply, task, state}
  end
  
  @impl true
  def handle_call({:list_tasks, filter}, _from, state) do
    tasks = filter_tasks(state, filter)
    {:reply, tasks, state}
  end
  
  @impl true
  def handle_cast({:process_batch, task_ids}, state) do
    # Process multiple tasks in batch
    new_state = Enum.reduce(task_ids, state, fn task_id, acc_state ->
      case Map.get(acc_state.tasks, task_id) do
        nil -> acc_state
        task ->
          # Simulate batch processing
          process_single_task_in_batch(task, acc_state)
      end
    end)
    
    Logger.info("Processed batch of #{length(task_ids)} tasks")
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:cleanup, state) do
    new_state = perform_cleanup(state)
    schedule_cleanup()
    {:noreply, new_state}
  end
  
  # Private Functions
  
  defp generate_task_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
  
  defp initialize_stats do
    %{
      tasks_created: 0,
      tasks_started: 0,
      tasks_completed: 0,
      tasks_failed: 0,
      tasks_retried: 0,
      total_processing_time: 0,
      average_processing_time: 0.0
    }
  end
  
  defp update_stats(stats, event) do
    case event do
      :task_created -> %{stats | tasks_created: stats.tasks_created + 1}
      :task_started -> %{stats | tasks_started: stats.tasks_started + 1}
      :task_completed -> %{stats | tasks_completed: stats.tasks_completed + 1}
      :task_failed -> %{stats | tasks_failed: stats.tasks_failed + 1}
      :task_retried -> %{stats | tasks_retried: stats.tasks_retried + 1}
    end
  end
  
  defp perform_task_work(task) do
    # Simulate work based on priority
    work_time = case task.priority do
      :low -> 10
      :medium -> 50
      :high -> 100
      :critical -> 200
    end
    
    # Add some randomness
    actual_time = work_time + :rand.uniform(50)
    Process.sleep(actual_time)
    
    # Simulate occasional failures
    if :rand.uniform(10) == 1 do
      {:error, :random_failure}
    else
      {:ok, %{processing_time: actual_time, data_processed: map_size(task.data)}}
    end
  end
  
  defp process_single_task_in_batch(task, state) do
    # Simplified batch processing
    updated_task = %{task | started_at: System.monotonic_time(:millisecond)}
    
    %{state | 
      tasks: Map.put(state.tasks, task.id, updated_task),
      stats: update_stats(state.stats, :task_started)
    }
  end
  
  defp filter_tasks(state, filter) do
    case filter do
      :all -> Map.values(state.tasks)
      :pending -> Map.values(state.tasks) |> Enum.filter(&is_nil(&1.started_at))
      :running -> Map.values(state.tasks) |> Enum.filter(&(&1.started_at && is_nil(&1.completed_at)))
      :high_priority -> Map.values(state.tasks) |> Enum.filter(&(&1.priority in [:high, :critical]))
    end
  end
  
  defp calculate_current_stats(state) do
    active_tasks = map_size(state.tasks)
    total_completed = length(state.completed_tasks)
    total_failed = length(state.failed_tasks)
    
    Map.merge(state.stats, %{
      active_tasks: active_tasks,
      total_completed: total_completed,
      total_failed: total_failed,
      success_rate: if(total_completed + total_failed > 0, 
                      do: total_completed / (total_completed + total_failed), 
                      else: 0.0)
    })
  end
  
  defp perform_cleanup(state) do
    # Clean up old completed/failed task references
    _cutoff_time = System.monotonic_time(:millisecond) - 3600_000  # 1 hour ago
    
    new_completed = Enum.take(state.completed_tasks, 100)  # Keep last 100
    new_failed = Enum.take(state.failed_tasks, 50)  # Keep last 50
    
    new_state = %{state | 
      completed_tasks: new_completed,
      failed_tasks: new_failed,
      last_cleanup: System.monotonic_time(:millisecond)
    }
    
    Logger.debug("Performed cleanup, removed old task references")
    new_state
  end
  
  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, 300_000)  # 5 minutes
  end
end 