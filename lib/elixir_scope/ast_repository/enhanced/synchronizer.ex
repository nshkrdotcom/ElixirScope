defmodule ElixirScope.ASTRepository.Enhanced.Synchronizer do
  @moduledoc """
  File synchronizer for enhanced AST repository.
  """
  
  use GenServer
  require Logger
  
  alias ElixirScope.ASTRepository.Enhanced.{Repository, ProjectPopulator}
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end
  
  def stop(pid) do
    GenServer.stop(pid)
  end
  
  def get_status(pid) do
    GenServer.call(pid, :get_status)
  end
  
  def sync_file(pid, file_path) do
    GenServer.call(pid, {:sync_file, file_path})
  end
  
  def sync_file_deletion(pid, file_path) do
    GenServer.call(pid, {:sync_file_deletion, file_path})
  end
  
  def sync_files(pid, file_paths) do
    GenServer.call(pid, {:sync_files, file_paths})
  end
  
  def init(opts) do
    repository = Keyword.get(opts, :repository)
    batch_size = Keyword.get(opts, :batch_size, 10)
    
    Logger.debug("Synchronizer starting with repository: #{inspect(repository)}")
    
    state = %{
      repository: repository,
      batch_size: batch_size,
      status: :ready,
      sync_count: 0,
      error_count: 0,
      last_sync_time: nil
    }
    
    {:ok, state}
  end
  
  def handle_call(:get_status, _from, state) do
    status = %{
      status: state.status,
      repository_pid: state.repository,
      sync_count: state.sync_count,
      error_count: state.error_count,
      last_sync_time: state.last_sync_time
    }
    {:reply, {:ok, status}, state}
  end
  
  def handle_call({:sync_file, file_path}, _from, state) do
    Logger.debug("Synchronizer: Starting sync for file: #{file_path}")
    start_time = System.monotonic_time(:microsecond)
    
    if File.exists?(file_path) do
      Logger.debug("Synchronizer: File exists, proceeding with parse and analyze")
      
      case ProjectPopulator.parse_and_analyze_file(file_path) do
        {:ok, module_data} ->
          Logger.debug("Synchronizer: Parse successful for module: #{inspect(module_data.module_name)}")
          Logger.debug("Synchronizer: Module data keys: #{inspect(Map.keys(module_data))}")
          Logger.debug("Synchronizer: Function count: #{map_size(module_data.functions)}")
          
          try do
            Logger.debug("Synchronizer: Attempting to store module in repository: #{inspect(state.repository)}")
            
            # Check if repository is alive
            if Process.alive?(state.repository) do
              Logger.debug("Synchronizer: Repository process is alive")
            else
              Logger.error("Synchronizer: Repository process is not alive!")
              {:reply, {:error, :repository_unavailable}, 
               update_state_with_error(state)}
            end
            
            case Repository.store_module(state.repository, module_data) do
              :ok -> 
                Logger.debug("Synchronizer: Module stored successfully")
                
                # Verify storage by attempting retrieval
                case Repository.get_module(state.repository, module_data.module_name) do
                  {:ok, retrieved_data} ->
                    Logger.debug("Synchronizer: Module retrieval verification successful")
                    Logger.debug("Synchronizer: Retrieved module name: #{inspect(retrieved_data.module_name)}")
                  {:error, reason} ->
                    Logger.error("Synchronizer: Module retrieval verification failed: #{inspect(reason)}")
                end
                
                end_time = System.monotonic_time(:microsecond)
                duration = end_time - start_time
                Logger.debug("Synchronizer: Sync completed in #{duration / 1000}ms")
                
                {:reply, :ok, update_state_with_success(state)}
              
              error -> 
                Logger.error("Synchronizer: Repository storage failed: #{inspect(error)}")
                {:reply, error, update_state_with_error(state)}
            end
          rescue
            e ->
              Logger.error("Synchronizer: Exception during repository storage: #{Exception.message(e)}")
              Logger.error("Synchronizer: Exception stacktrace: #{Exception.format_stacktrace(__STACKTRACE__)}")
              {:reply, {:error, {:repository_storage_failed, Exception.message(e)}}, 
               update_state_with_error(state)}
          catch
            :exit, reason ->
              Logger.error("Synchronizer: Exit during repository storage: #{inspect(reason)}")
              {:reply, {:error, :repository_unavailable}, 
               update_state_with_error(state)}
          end
        
        {:error, :parse_error} ->
          Logger.warning("Synchronizer: Parse error for file: #{file_path}")
          {:reply, {:error, :parse_error}, update_state_with_error(state)}
        
        {:error, {:ast_parsing_failed, file_path, reason}} ->
          Logger.warning("Synchronizer: AST parsing failed for file: #{file_path}, reason: #{inspect(reason)}")
          # For backward compatibility with tests, return simplified error for parse failures
          {:reply, {:error, :parse_error}, update_state_with_error(state)}
        
        {:error, {:parse_and_analyze_failed, reason}} ->
          Logger.warning("Synchronizer: Parse and analyze failed, reason: #{inspect(reason)}")
          {:reply, {:error, :parse_error}, update_state_with_error(state)}
        
        {:error, reason} ->
          Logger.error("Synchronizer: Unexpected error during parse: #{inspect(reason)}")
          {:reply, {:error, reason}, update_state_with_error(state)}
      end
    else
      Logger.warning("Synchronizer: File does not exist: #{file_path}")
      {:reply, {:error, :file_not_found}, update_state_with_error(state)}
    end
  end
  
  def handle_call({:sync_file_deletion, file_path}, _from, state) do
    Logger.debug("Synchronizer: File deletion sync for: #{file_path}")
    
    # Find modules associated with this file path
    case Repository.get_all_modules(state.repository) do
      {:ok, modules} ->
        # Find module(s) with matching file path
        modules_to_delete = Enum.filter(modules, fn module_data ->
          module_data.file_path == file_path
        end)
        
        case modules_to_delete do
          [] ->
            Logger.debug("Synchronizer: No modules found for deleted file: #{file_path}")
            {:reply, :ok, state}
          
          modules ->
            # Delete all modules associated with this file
            delete_results = Enum.map(modules, fn module_data ->
              Logger.debug("Synchronizer: Deleting module #{inspect(module_data.module_name)} for file: #{file_path}")
              Repository.delete_module(state.repository, module_data.module_name)
            end)
            
            # Check if all deletions were successful
            if Enum.all?(delete_results, &(&1 == :ok)) do
              Logger.debug("Synchronizer: Successfully deleted #{length(modules)} module(s) for file: #{file_path}")
              {:reply, :ok, state}
            else
              Logger.error("Synchronizer: Some module deletions failed for file: #{file_path}")
              {:reply, {:error, :deletion_failed}, update_state_with_error(state)}
            end
        end
      
      {:error, reason} ->
        Logger.error("Synchronizer: Failed to get modules for deletion sync: #{inspect(reason)}")
        {:reply, {:error, :repository_unavailable}, update_state_with_error(state)}
    end
  end
  
  def handle_call({:sync_files, file_paths}, _from, state) do
    Logger.debug("Synchronizer: Batch sync starting for #{length(file_paths)} files")
    start_time = System.monotonic_time(:microsecond)
    
    results = Enum.with_index(file_paths)
    |> Enum.map(fn {file_path, index} ->
      Logger.debug("Synchronizer: Processing batch file #{index + 1}/#{length(file_paths)}: #{file_path}")
      
      if File.exists?(file_path) do
        case ProjectPopulator.parse_and_analyze_file(file_path) do
          {:ok, module_data} ->
            Logger.debug("Synchronizer: Batch parse successful for module: #{inspect(module_data.module_name)}")
            
            try do
              case Repository.store_module(state.repository, module_data) do
                :ok -> 
                  Logger.debug("Synchronizer: Batch module stored successfully: #{inspect(module_data.module_name)}")
                  {:ok, module_data}  # Return success with data for batch tests
                error -> 
                  Logger.error("Synchronizer: Batch storage failed for #{file_path}: #{inspect(error)}")
                  error
              end
            rescue
              e ->
                Logger.error("Synchronizer: Batch exception for #{file_path}: #{Exception.message(e)}")
                {:error, {:repository_storage_failed, Exception.message(e)}}
            catch
              :exit, reason ->
                Logger.error("Synchronizer: Batch exit for #{file_path}: #{inspect(reason)}")
                {:error, {:repository_unavailable, reason}}
            end
          
          {:error, :parse_error} ->
            Logger.warning("Synchronizer: Batch parse error for: #{file_path}")
            {:error, :parse_error}
          
          {:error, {:ast_parsing_failed, file_path, reason}} ->
            Logger.warning("Synchronizer: Batch AST parsing failed for: #{file_path}, reason: #{inspect(reason)}")
            {:error, :parse_error}  # Simplified for test compatibility
          
          {:error, {:parse_and_analyze_failed, reason}} ->
            Logger.warning("Synchronizer: Batch parse and analyze failed for: #{file_path}, reason: #{inspect(reason)}")
            {:error, :parse_error}
          
          {:error, reason} ->
            Logger.error("Synchronizer: Batch unexpected error for #{file_path}: #{inspect(reason)}")
            {:error, reason}
        end
      else
        Logger.warning("Synchronizer: Batch file does not exist: #{file_path}")
        {:error, :file_not_found}
      end
    end)
    
    end_time = System.monotonic_time(:microsecond)
    duration = end_time - start_time
    
    success_count = Enum.count(results, &match?({:ok, _}, &1))
    error_count = length(results) - success_count
    
    Logger.debug("Synchronizer: Batch sync completed in #{duration / 1000}ms")
    Logger.debug("Synchronizer: Batch results - Success: #{success_count}, Errors: #{error_count}")
    
    new_state = %{state | 
      sync_count: state.sync_count + success_count,
      error_count: state.error_count + error_count,
      last_sync_time: DateTime.utc_now()
    }
    
    {:reply, {:ok, results}, new_state}
  end
  
  # Helper functions for state management
  defp update_state_with_success(state) do
    %{state | 
      sync_count: state.sync_count + 1,
      last_sync_time: DateTime.utc_now()
    }
  end
  
  defp update_state_with_error(state) do
    %{state | 
      error_count: state.error_count + 1,
      last_sync_time: DateTime.utc_now()
    }
  end
end 