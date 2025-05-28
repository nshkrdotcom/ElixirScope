defmodule ElixirScope.ASTRepository.Synchronizer do
  @moduledoc """
  Handles incremental synchronization of the AST Repository based on
  file change events received from the FileWatcher.

  It re-parses/re-analyzes changed files and updates the Repository,
  ensuring data consistency.
  """

  require Logger

  alias ElixirScope.ASTRepository.Repository
  alias ElixirScope.ASTRepository.ASTAnalyzer
  alias ElixirScope.ASTRepository.ProjectPopulator # For some utility functions like module name extraction
  alias ElixirScope.ASTRepository.EnhancedModuleData
  alias ElixirScope.ASTRepository.FileChangeEvent # Assuming this struct is defined

  @type sync_options :: [
    {:repo_pid, pid() | atom()} |
    {:analysis_opts, keyword()} # Options to pass to ASTAnalyzer
  ]

  @type individual_sync_result :: %{
    file_path: String.t(),
    status: :updated | :created | :deleted | :unchanged | :error,
    module_name: atom() | nil,
    reason: term() | nil # If status is :error
  }

  @type batch_sync_result :: %{
    total_changes_processed: non_neg_integer(),
    successful_syncs: non_neg_integer(),
    failed_syncs: non_neg_integer(),
    results: [individual_sync_result()],
    duration_ms: non_neg_integer()
  }

  @doc """
  Synchronizes a batch of file changes with the AST Repository.
  This is typically called by the FileWatcher.
  """
  @spec sync_changes_batch(changes :: [FileChangeEvent.t()], opts :: sync_options()) ::
          {:ok, batch_sync_result()} | {:error, term()}
  def sync_changes_batch(changes, opts \\ []) do
    start_time = System.monotonic_time()
    repo_pid = Keyword.get(opts, :repo_pid, Repository) # Default to registered name
    analysis_opts = Keyword.get(opts, :analysis_opts, [])

    # Process changes. Can be done sequentially or in parallel for independent files.
    # For simplicity, sequential processing for now. Parallelism adds complexity
    # regarding inter-module dependencies if a re-analysis triggers wider updates.
    results = Enum.map(changes, fn change_event ->
      sync_single_change_event(change_event, repo_pid, analysis_opts)
    end)

    duration_ms = System.monotonic_time() - start_time |> System.convert_time_unit(:native, :millisecond)

    final_result = %{
      total_changes_processed: length(changes),
      successful_syncs: Enum.count(results, &(&1.status in [:updated, :created, :deleted, :unchanged])),
      failed_syncs: Enum.count(results, &(&1.status == :error)),
      results: results,
      duration_ms: duration_ms
    }
    {:ok, final_result}
  end


  @doc """
  Synchronizes a single file change event.
  """
  @spec sync_single_change_event(change :: FileChangeEvent.t(), repo_pid :: pid() | atom(), analysis_opts :: keyword()) ::
          individual_sync_result()
  def sync_single_change_event(
        %ElixirScope.ASTRepository.FileChangeEvent{file_path: file_path, event_type: event_type, old_path: old_path},
        repo_pid,
        analysis_opts
      ) do

    base_result = %{file_path: file_path, module_name: nil, reason: nil}

    case event_type do
      :created ->
        handle_file_created(file_path, repo_pid, analysis_opts, base_result)
      :modified ->
        handle_file_modified(file_path, repo_pid, analysis_opts, base_result)
      :deleted ->
        handle_file_deleted(file_path, repo_pid, base_result)
      :renamed ->
        # A rename is a delete of old_path and create of file_path
        # More complex if module name changes and affects other modules.
        # For now, treat as delete + create.
        _delete_res = handle_file_deleted(old_path, repo_pid, %{base_result | file_path: old_path})
        handle_file_created(file_path, repo_pid, analysis_opts, base_result)
      _ ->
        %{base_result | status: :error, reason: {:unknown_event_type, event_type}}
    end
  catch
    exception ->
      stacktrace = __STACKTRACE__
      Logger.error("Unexpected error during sync for #{file_path} (#{event_type}): #{inspect(exception)}\n#{Exception.format_stacktrace(stacktrace)}")
      %{base_result | status: :error, reason: {:unexpected_exception, exception}}
  end


  # --- Event Handlers ---

  defp handle_file_created(file_path, repo_pid, analysis_opts, base_result) do
    Logger.info("Synchronizer: File created - #{file_path}")
    # Similar logic to ProjectPopulator.process_single_file
    try do
      content = File.read!(file_path)
      {:ok, quoted_ast} = Code.string_to_quoted(content, path: file_path, trimmer: &(&1))
      module_name = ProjectPopulator.extract_module_name_from_ast(quoted_ast) || ProjectPopulator.module_name_from_path(file_path)

      if module_name do
        case ASTAnalyzer.analyze_module_ast(quoted_ast, module_name, file_path, analysis_opts) do
          {:ok, %EnhancedModuleData{} = enhanced_module_data} ->
            case Repository.store_module(repo_pid, enhanced_module_data) do
              :ok -> %{base_result | status: :created, module_name: module_name}
              {:error, store_reason} -> %{base_result | status: :error, module_name: module_name, reason: {:store_failed, store_reason}}
            end
          {:error, analysis_reason} -> %{base_result | status: :error, module_name: module_name, reason: {:analysis_failed, analysis_reason}}
        end
      else
        %{base_result | status: :error, reason: :module_name_extraction_failed}
      end
    rescue
      File.Error -> %{base_result | status: :error, reason: :file_read_error}
      TokenMissingError -> %{base_result | status: :error, reason: :parsing_error_token}
      CompileError -> %{base_result | status: :error, reason: :parsing_error_compile}
      exception -> %{base_result | status: :error, reason: {:unexpected_exception_created, exception}}
    end
  end

  defp handle_file_modified(file_path, repo_pid, analysis_opts, base_result) do
    Logger.info("Synchronizer: File modified - #{file_path}")
    # Check if the file content actually changed using hash, if available from FileChangeEvent
    # Or, get current module data, compare hash, then re-analyze if different.
    # For simplicity, re-analyze and store. Repository.store_module should overwrite.

    # Get existing module name if file was already tracked
    {:ok, old_module_name} = Repository.get_module_by_filepath(repo_pid, file_path)
    |> case do
      {:ok, %EnhancedModuleData{module_name: mn}} -> {:ok, mn} # If it returns full data
      {:ok, mn} when is_atom(mn) -> {:ok, mn} # If it returns just name
      _ -> {:error, :not_previously_tracked}
    end

    try do
      content = File.read!(file_path)
      new_file_hash = :crypto.hash(:sha256, content) |> Base.encode16()

      # Optional: Compare with stored hash to avoid re-processing identical content
      # if {:ok, %EnhancedModuleData{file_hash: old_hash}} <- Repository.get_module(repo_pid, old_module_name),
      #    old_hash == new_file_hash do
      #   Logger.debug("Synchronizer: File content unchanged (hash match) for #{file_path}")
      #   return %{base_result | status: :unchanged, module_name: old_module_name}
      # end

      {:ok, quoted_ast} = Code.string_to_quoted(content, path: file_path, trimmer: &(&1))
      current_module_name = ProjectPopulator.extract_module_name_from_ast(quoted_ast) || ProjectPopulator.module_name_from_path(file_path)

      if current_module_name do
        # Handle module rename: if current_module_name != old_module_name and old_module_name != nil
        if old_module_name && current_module_name != old_module_name do
          Logger.info("Synchronizer: Module in #{file_path} renamed from #{inspect(old_module_name)} to #{inspect(current_module_name)}")
          # Delete old module entry
          Repository.delete_module(repo_pid, old_module_name)
          # Cascading updates for callers of old_module_name would be complex here.
          # A full re-analysis or a more sophisticated dependency update is needed for true rename handling.
        end

        case ASTAnalyzer.analyze_module_ast(quoted_ast, current_module_name, file_path, analysis_opts) do
          {:ok, %EnhancedModuleData{} = enhanced_module_data_stub} ->
            # Ensure the new hash is part of the data to be stored
            enhanced_module_data = %{enhanced_module_data_stub | file_hash: new_file_hash}
            case Repository.store_module(repo_pid, enhanced_module_data) do
              :ok ->
                # TODO: Trigger re-analysis of modules that depended on the old version of this module.
                # This is where cross-module dependency tracking becomes critical.
                # For now, just update the module itself.
                %{base_result | status: :updated, module_name: current_module_name}
              {:error, store_reason} -> %{base_result | status: :error, module_name: current_module_name, reason: {:store_failed, store_reason}}
            end
          {:error, analysis_reason} -> %{base_result | status: :error, module_name: current_module_name, reason: {:analysis_failed, analysis_reason}}
        end
      else
        # Module name couldn't be extracted, might be a script or non-module file now
        # If it was previously a module, delete it.
        if old_module_name, do: Repository.delete_module(repo_pid, old_module_name)
        %{base_result | status: :error, reason: :module_name_extraction_failed_on_modify}
      end
    rescue
      File.Error -> %{base_result | status: :error, reason: :file_read_error}
      TokenMissingError -> %{base_result | status: :error, reason: :parsing_error_token}
      CompileError -> %{base_result | status: :error, reason: :parsing_error_compile}
      exception -> %{base_result | status: :error, reason: {:unexpected_exception_modified, exception}}
    end
  end

  defp handle_file_deleted(file_path, repo_pid, base_result) do
    Logger.info("Synchronizer: File deleted - #{file_path}")
    # Find the module associated with this file_path from the repository index
    case Repository.get_module_by_filepath(repo_pid, file_path) do
      {:ok, %EnhancedModuleData{module_name: module_name}} -> # If get_module_by_filepath returns full data
        delete_and_log(repo_pid, module_name, file_path, base_result)
      {:ok, module_name} when is_atom(module_name) -> # If it returns just the name
        delete_and_log(repo_pid, module_name, file_path, base_result)
      {:error, :not_found} ->
        # File was not tracked or already deleted, consider it a success for idempotency
        Logger.debug("Synchronizer: Deleted file #{file_path} was not found in repository or already processed.")
        %{base_result | status: :deleted, reason: :not_found_in_repo} # Or :unchanged if preferred
      {:error, reason} ->
        %{base_result | status: :error, reason: {:get_module_by_filepath_failed, reason}}
    end
  end

  defp delete_and_log(repo_pid, module_name, file_path, base_result) do
    case Repository.delete_module(repo_pid, module_name) do
      :ok ->
        Logger.info("Synchronizer: Module #{inspect(module_name)} (from #{file_path}) deleted from repository.")
        # TODO: Trigger re-analysis of modules that depended on the deleted module.
        %{base_result | status: :deleted, module_name: module_name}
      {:error, delete_reason} ->
        Logger.error("Synchronizer: Failed to delete module #{inspect(module_name)} for file #{file_path}: #{inspect(delete_reason)}")
        %{base_result | status: :error, module_name: module_name, reason: {:delete_failed, delete_reason}}
    end
  end

  # --- Advanced Synchronization Aspects (Placeholders) ---

  defp update_cross_module_dependencies(changed_module_name, old_dependencies, new_dependencies, repo_pid) do
    # This is a complex but crucial step.
    # 1. Find modules that depended on `changed_module_name` based on `old_dependencies`.
    # 2. Find modules that will now depend on `changed_module_name` based on `new_dependencies`.
    # 3. Trigger re-analysis or update linkage for affected modules.
    # This might involve re-building parts of their CPGs or updating call graph indexes.
    Logger.debug("Synchronizer: Updating cross-module dependencies for #{inspect(changed_module_name)} (not fully implemented).")
    :ok
  end

  defp invalidate_caches_for_module(module_name, repo_pid) do
    # Notify QueryEngine or other caching layers that data for `module_name` is stale.
    # QueryEngine.Cache.invalidate_for_module(module_name)
    Logger.debug("Synchronizer: Invalidating caches for #{inspect(module_name)} (not fully implemented).")
    :ok
  end

end
