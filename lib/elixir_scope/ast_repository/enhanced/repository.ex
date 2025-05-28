defmodule ElixirScope.ASTRepository.Enhanced.Repository do
  @moduledoc """
  Enhanced AST Repository with comprehensive project storage and analysis capabilities.
  
  Provides high-performance storage and querying for:
  - Enhanced module and function data with full AST analysis
  - Complex function queries by criteria (complexity, patterns, etc.)
  - AST node correlation and reference tracking
  - Performance monitoring and memory management
  
  Performance targets:
  - Module storage: <50ms for modules with <1000 functions
  - Function queries: <100ms for complex filters
  - Memory usage: <500MB for typical projects
  """
  
  use GenServer
  require Logger
  
  alias ElixirScope.ASTRepository.Enhanced.EnhancedModuleData
  
  # Client API
  
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  def stop(pid) do
    GenServer.stop(pid)
  end
  
  def store_module(pid, module_data) do
    GenServer.call(pid, {:store_module, module_data})
  end
  
  def get_module(pid, module_name) do
    GenServer.call(pid, {:get_module, module_name})
  end
  
  def store_function(pid, function_data) do
    GenServer.call(pid, {:store_function, function_data})
  end
  
  def get_function(pid, module_name, function_name, arity) do
    GenServer.call(pid, {:get_function, module_name, function_name, arity})
  end
  
  def query_modules_by_file(pid, file_path) do
    GenServer.call(pid, {:query_modules_by_file, file_path})
  end
  
  def query_functions(pid, criteria) do
    GenServer.call(pid, {:query_functions, criteria})
  end
  
  def get_all_modules(pid) do
    GenServer.call(pid, :get_all_modules)
  end
  
  def delete_module(pid, module_name) do
    GenServer.call(pid, {:delete_module, module_name})
  end
  
  def clear_all(pid) do
    GenServer.call(pid, :clear_all)
  end
  
  def health_check(pid) do
    GenServer.call(pid, :health_check)
  end
  
  def get_statistics(pid) do
    GenServer.call(pid, :get_statistics)
  end
  
  def get_ast_node(pid, ast_node_id) do
    GenServer.call(pid, {:get_ast_node, ast_node_id})
  end
  
  def find_references(pid, module_name, function_name, arity) do
    GenServer.call(pid, {:find_references, module_name, function_name, arity})
  end
  
  def correlate_event_to_ast(pid, event) do
    GenServer.call(pid, {:correlate_event_to_ast, event})
  end
  
  # Server callbacks
  
  def init(opts) do
    memory_limit = Keyword.get(opts, :memory_limit, 1000)
    
    # Create ETS tables
    create_ets_tables()
    
    state = %{
      memory_limit: memory_limit,
      started_at: DateTime.utc_now(),
      stats: %{
        modules_stored: 0,
        functions_stored: 0,
        queries_executed: 0,
        total_memory_mb: 0
      }
    }
    
    {:ok, state}
  end
  
  def handle_call({:store_module, module_data}, _from, state) do
    Logger.debug("Repository: Attempting to store module: #{inspect(module_data.module_name)}")
    Logger.debug("Repository: Module data structure keys: #{inspect(Map.keys(module_data))}")
    Logger.debug("Repository: Module file path: #{module_data.file_path}")
    Logger.debug("Repository: Module function count: #{map_size(module_data.functions)}")
    
    case validate_module_data(module_data) do
      :ok ->
        Logger.debug("Repository: Module validation successful")
        
        # Store in ETS
        try do
          Logger.debug("Repository: Inserting into :ast_modules_enhanced table")
          :ets.insert(:ast_modules_enhanced, {module_data.module_name, module_data})
          
          Logger.debug("Repository: Inserting into :ast_module_by_file table")
          :ets.insert(:ast_module_by_file, {module_data.file_path, module_data.module_name})
          
          # Verify storage immediately
          case :ets.lookup(:ast_modules_enhanced, module_data.module_name) do
            [{module_name, stored_data}] when module_name == module_data.module_name ->
              Logger.debug("Repository: Storage verification successful - module found in table")
              Logger.debug("Repository: Stored module name: #{inspect(stored_data.module_name)}")
            [] ->
              Logger.error("Repository: Storage verification failed - module not found after insert!")
          end
          
          # Store AST nodes for correlation
          Logger.debug("Repository: Storing AST nodes for correlation")
          store_module_ast_nodes(module_data)
          
          # Update statistics
          new_stats = %{state.stats | modules_stored: state.stats.modules_stored + 1}
          Logger.debug("Repository: Module storage completed successfully. Total modules: #{new_stats.modules_stored}")
          
          {:reply, :ok, %{state | stats: new_stats}}
        rescue
          e ->
            Logger.error("Repository: Exception during module storage: #{Exception.message(e)}")
            Logger.error("Repository: Exception stacktrace: #{Exception.format_stacktrace(__STACKTRACE__)}")
            {:reply, {:error, {:storage_exception, Exception.message(e)}}, state}
        end
      
      {:error, reason} ->
        Logger.error("Repository: Module validation failed: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end
  
  def handle_call({:get_module, module_name}, _from, state) do
    Logger.debug("Repository: Attempting to retrieve module: #{inspect(module_name)}")
    
    # Check table info first
    table_size = :ets.info(:ast_modules_enhanced, :size)
    Logger.debug("Repository: :ast_modules_enhanced table size: #{table_size}")
    
    case :ets.lookup(:ast_modules_enhanced, module_name) do
      [{found_name, module_data}] when found_name == module_name -> 
        Logger.debug("Repository: Module retrieval successful")
        Logger.debug("Repository: Retrieved module name: #{inspect(module_data.module_name)}")
        Logger.debug("Repository: Retrieved module file path: #{module_data.file_path}")
        {:reply, {:ok, module_data}, state}
      [] -> 
        Logger.warning("Repository: Module not found: #{inspect(module_name)}")
        
        # Debug: List all modules in table
        all_modules = :ets.tab2list(:ast_modules_enhanced)
        |> Enum.map(fn {name, _data} -> name end)
        Logger.debug("Repository: All modules in table: #{inspect(all_modules)}")
        
        {:reply, {:error, :not_found}, state}
    end
  end
  
  def handle_call({:store_function, function_data}, _from, state) do
    key = {function_data.module_name, function_data.function_name, function_data.arity}
    
    # Store in main table
    :ets.insert(:ast_functions_enhanced, {key, function_data})
    
    # Store in indexes for efficient querying
    store_function_indexes(function_data)
    
    # Store AST nodes for correlation
    store_function_ast_nodes(function_data)
    
    # Update statistics
    new_stats = %{state.stats | functions_stored: state.stats.functions_stored + 1}
    {:reply, :ok, %{state | stats: new_stats}}
  end
  
  def handle_call({:get_function, module_name, function_name, arity}, _from, state) do
    key = {module_name, function_name, arity}
    case :ets.lookup(:ast_functions_enhanced, key) do
      [{^key, function_data}] -> {:reply, {:ok, function_data}, state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end
  
  def handle_call({:query_modules_by_file, file_path}, _from, state) do
    modules = :ets.lookup(:ast_module_by_file, file_path)
    |> Enum.map(fn {_file, module_name} ->
      [{^module_name, module_data}] = :ets.lookup(:ast_modules_enhanced, module_name)
      module_data
    end)
    {:reply, {:ok, modules}, state}
  end
  
  def handle_call({:query_functions, criteria}, _from, state) do
    start_time = System.monotonic_time(:microsecond)
    
    # Execute the query
    functions = execute_function_query(criteria)
    
    # Update query statistics
    end_time = System.monotonic_time(:microsecond)
    query_time_us = end_time - start_time
    
    new_stats = %{state.stats | queries_executed: state.stats.queries_executed + 1}
    
    Logger.debug("Function query completed in #{query_time_us}µs, returned #{length(functions)} results")
    
    {:reply, {:ok, functions}, %{state | stats: new_stats}}
  end
  
  def handle_call(:get_all_modules, _from, state) do
    modules = :ets.tab2list(:ast_modules_enhanced)
    |> Enum.map(fn {_name, module_data} -> module_data end)
    {:reply, {:ok, modules}, state}
  end
  
  def handle_call({:delete_module, module_name}, _from, state) do
    Logger.debug("Repository: Attempting to delete module: #{inspect(module_name)}")
    
    # Delete from main modules table
    :ets.delete(:ast_modules_enhanced, module_name)
    
    # Delete from file index (need to find the file path first)
    case :ets.lookup(:ast_modules_enhanced, module_name) do
      [] ->
        # Module was deleted, now clean up file index
        # Find and remove file index entries for this module
        file_entries = :ets.match(:ast_module_by_file, {~c"$1", module_name})
        Enum.each(file_entries, fn [file_path] ->
          :ets.delete_object(:ast_module_by_file, {file_path, module_name})
        end)
        
        # Clean up AST metadata for this module
        module_ast_id = "#{module_name}:module"
        :ets.delete(:ast_metadata, module_ast_id)
        
        # Update statistics
        new_stats = %{state.stats | modules_stored: max(0, state.stats.modules_stored - 1)}
        Logger.debug("Repository: Module #{inspect(module_name)} deleted successfully")
        {:reply, :ok, %{state | stats: new_stats}}
      
      [{^module_name, _module_data}] ->
        # Module still exists, deletion failed
        Logger.error("Repository: Failed to delete module #{inspect(module_name)}")
        {:reply, {:error, :deletion_failed}, state}
    end
  end
  
  def handle_call(:clear_all, _from, state) do
    clear_all_tables()
    
    # Reset statistics
    new_stats = %{
      modules_stored: 0,
      functions_stored: 0,
      queries_executed: state.stats.queries_executed,
      total_memory_mb: 0
    }
    
    {:reply, :ok, %{state | stats: new_stats}}
  end
  
  def handle_call(:health_check, _from, state) do
    memory_usage = calculate_memory_usage()
    
    health = %{
      status: (if memory_usage.total_mb < state.memory_limit, do: :healthy, else: :warning),
      table_sizes: %{
        modules: :ets.info(:ast_modules_enhanced, :size),
        functions: :ets.info(:ast_functions_enhanced, :size),
        ast_nodes: :ets.info(:ast_metadata, :size)
      },
      memory_usage: memory_usage,
      index_stats: %{
        file_index: :ets.info(:ast_module_by_file, :size),
        function_name_index: :ets.info(:ast_function_by_name, :size),
        complexity_index: :ets.info(:ast_function_by_complexity, :size)
      },
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at),
      performance: state.stats
    }
    {:reply, {:ok, health}, state}
  end
  
  def handle_call(:get_statistics, _from, state) do
    memory_usage = calculate_memory_usage()
    
    stats = %{
      memory_usage_mb: memory_usage.total_mb,
      modules_count: :ets.info(:ast_modules_enhanced, :size),
      functions_count: :ets.info(:ast_functions_enhanced, :size),
      ast_nodes_count: :ets.info(:ast_metadata, :size),
      queries_executed: state.stats.queries_executed,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }
    {:reply, {:ok, stats}, state}
  end
  
  def handle_call({:get_ast_node, ast_node_id}, _from, state) do
    case :ets.lookup(:ast_metadata, ast_node_id) do
      [{^ast_node_id, ast_data}] -> {:reply, {:ok, ast_data}, state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end
  
  def handle_call({:find_references, module_name, function_name, arity}, _from, state) do
    target_key = {module_name, function_name, arity}
    
    # Find all functions that call this target
    references = :ets.lookup(:ast_calls_by_target, target_key)
    |> Enum.map(fn {_target, caller_key} -> caller_key end)
    |> Enum.uniq()
    
    {:reply, {:ok, references}, state}
  end
  
  def handle_call({:correlate_event_to_ast, event}, _from, state) do
    # Try to find AST node by event correlation
    case Map.get(event, :ast_node_id) do
      nil -> 
        {:reply, {:error, :no_ast_correlation}, state}
      ast_node_id ->
        case :ets.lookup(:ast_metadata, ast_node_id) do
          [{^ast_node_id, _ast_data}] -> 
            {:reply, {:ok, ast_node_id}, state}
          [] -> 
            {:reply, {:error, :ast_node_not_found}, state}
        end
    end
  end
  
  # Private functions
  
  defp create_ets_tables do
    # Avoid table name conflicts by checking if they exist
    tables_to_create = [
      {:ast_modules_enhanced, [:named_table, :public, :set]},
      {:ast_functions_enhanced, [:named_table, :public, :set]},
      {:ast_variables, [:named_table, :public, :set]},
      {:ast_calls, [:named_table, :public, :set]},
      {:ast_metadata, [:named_table, :public, :set]},
      # Indexes
      {:ast_module_by_file, [:named_table, :public, :bag]},
      {:ast_function_by_name, [:named_table, :public, :bag]},
      {:ast_function_by_complexity, [:named_table, :public, :bag]},
      {:ast_calls_by_target, [:named_table, :public, :bag]}
    ]
    
    Enum.each(tables_to_create, fn {table_name, opts} ->
      case :ets.whereis(table_name) do
        :undefined -> :ets.new(table_name, opts)
        _tid -> :ok  # Table already exists
      end
    end)
  end
  
  defp clear_all_tables do
    tables = [
      :ast_modules_enhanced, :ast_functions_enhanced, :ast_variables, 
      :ast_calls, :ast_metadata, :ast_module_by_file, :ast_function_by_name,
      :ast_function_by_complexity, :ast_calls_by_target
    ]
    
    Enum.each(tables, fn table ->
      case :ets.whereis(table) do
        :undefined -> :ok
        _tid -> :ets.delete_all_objects(table)
      end
    end)
  end
  
  defp store_function_indexes(function_data) do
    key = {function_data.module_name, function_data.function_name, function_data.arity}
    
    # Index by function name for pattern queries
    :ets.insert(:ast_function_by_name, {function_data.function_name, key})
    
    # Index by complexity for performance queries
    complexity_score = get_in(function_data.complexity_metrics, [:combined_complexity]) || 1.0
    complexity_bucket = complexity_to_bucket(complexity_score)
    :ets.insert(:ast_function_by_complexity, {complexity_bucket, key})
    
    # Index function calls for reference tracking (skip if no call data available)
    # TODO: Implement call tracking when we have proper AST analysis
  end
  
  defp store_module_ast_nodes(module_data) do
    # Store module-level AST metadata
    module_ast_id = "#{module_data.module_name}:module"
    :ets.insert(:ast_metadata, {module_ast_id, %{
      type: :module,
      module: module_data.module_name,
      ast: module_data.ast,
      file_path: module_data.file_path
    }})
  end
  
  defp store_function_ast_nodes(function_data) do
    # Generate AST node ID if not present
    ast_node_id = "#{function_data.module_name}:#{function_data.function_name}:#{function_data.arity}:def"
    
    # Store function-level AST metadata
    :ets.insert(:ast_metadata, {ast_node_id, %{
      type: :function,
      module: function_data.module_name,
      function: function_data.function_name,
      arity: function_data.arity,
      ast: function_data.ast,
      complexity: get_in(function_data.complexity_metrics, [:combined_complexity]) || 1.0
    }})
  end
  
  defp execute_function_query(criteria) do
    # Start with all functions
    all_functions = :ets.tab2list(:ast_functions_enhanced)
    |> Enum.map(fn {_key, function_data} -> function_data end)
    
    # Apply filters
    filtered_functions = apply_function_filters(all_functions, criteria)
    
    # Apply sorting if specified
    sorted_functions = apply_function_sorting(filtered_functions, criteria)
    
    # Apply limit if specified
    apply_function_limit(sorted_functions, criteria)
  end
  
  defp apply_function_filters(functions, criteria) do
    Enum.filter(functions, fn function ->
      Enum.all?(criteria, fn {filter_key, filter_value} ->
        apply_single_filter(function, filter_key, filter_value)
      end)
    end)
  end
  
  defp apply_single_filter(function, :complexity, {:gt, threshold}) do
    complexity = get_in(function.complexity_metrics, [:combined_complexity]) || 1.0
    complexity > threshold
  end
  
  defp apply_single_filter(function, :complexity, {:lt, threshold}) do
    complexity = get_in(function.complexity_metrics, [:combined_complexity]) || 1.0
    complexity < threshold
  end
  
  defp apply_single_filter(function, :complexity, {:eq, threshold}) do
    complexity = get_in(function.complexity_metrics, [:combined_complexity]) || 1.0
    complexity == threshold
  end
  
  defp apply_single_filter(function, :module, value) do
    function.module_name == value
  end
  
  defp apply_single_filter(function, :function_name, value) do
    function.function_name == value
  end
  
  defp apply_single_filter(_function, :limit, _value) do
    true  # Limit is handled separately
  end
  
  defp apply_single_filter(_function, :sort, _value) do
    true  # Sort is handled separately
  end
  
  defp apply_single_filter(_function, _unknown_filter, _value) do
    true  # Unknown filters are ignored
  end
  
  defp apply_function_sorting(functions, criteria) do
    case Map.get(criteria, :sort) do
      {:desc, :complexity} ->
        Enum.sort_by(functions, fn f -> get_in(f.complexity_metrics, [:combined_complexity]) || 1.0 end, :desc)
      {:asc, :complexity} ->
        Enum.sort_by(functions, fn f -> get_in(f.complexity_metrics, [:combined_complexity]) || 1.0 end, :asc)
      {:desc, :name} ->
        Enum.sort_by(functions, & &1.function_name, :desc)
      {:asc, :name} ->
        Enum.sort_by(functions, & &1.function_name, :asc)
      _ ->
        functions  # No sorting
    end
  end
  
  defp apply_function_limit(functions, criteria) do
    case Map.get(criteria, :limit) do
      nil -> functions
      limit when is_integer(limit) -> Enum.take(functions, limit)
      _ -> functions
    end
  end
  
  defp complexity_to_bucket(score) when score <= 1.0, do: :low
  defp complexity_to_bucket(score) when score <= 5.0, do: :medium
  defp complexity_to_bucket(score) when score <= 10.0, do: :high
  defp complexity_to_bucket(_score), do: :very_high
  
  defp calculate_memory_usage do
    tables = [:ast_modules_enhanced, :ast_functions_enhanced, :ast_variables, 
              :ast_calls, :ast_metadata, :ast_module_by_file, :ast_function_by_name,
              :ast_function_by_complexity, :ast_calls_by_target]
    
    total_words = Enum.reduce(tables, 0, fn table, acc ->
      case :ets.whereis(table) do
        :undefined -> acc
        _tid -> acc + (:ets.info(table, :memory) || 0)
      end
    end)
    
    # Convert words to MB (1 word = 8 bytes on 64-bit systems)
    total_mb = (total_words * 8) / (1024 * 1024)
    
    %{
      total_mb: Float.round(total_mb, 2),
      total_words: total_words
    }
  end
  
  defp validate_module_data(%EnhancedModuleData{module_name: nil}), do: {:error, :invalid_data}
  defp validate_module_data(%EnhancedModuleData{}), do: :ok
  defp validate_module_data(_), do: {:error, :invalid_data}
end 