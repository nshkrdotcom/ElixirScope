defmodule ElixirScope.ASTRepository.Repository do
  @moduledoc """
  The central GenServer responsible for storing, managing, and providing access
  to all AST-related data, including Enhanced Module/Function Data, CFG, DFG, and CPGs.

  It utilizes ETS tables for efficient in-memory storage and indexing,
  with potential for future backend extensions (e.g., graph databases).

  This implementation aligns with the API specified in
  `AST_REPOSITORY_IMPLEMENTATION_GUIDE.md` and supports the data structures
  from `AST_REPOSITORY_DATA_SCHEMAS_AND_SPECIFICATIONS.md`.
  """
  use GenServer

  alias ElixirScope.ASTRepository.{
    EnhancedModuleData,
    EnhancedFunctionData,
    VariableData,
    CFGData,
    DFGData,
    CPGData,
    # Schemas for storage, potentially simpler than the full analysis results for some tables
    # For instance, AST nodes might be stored more compactly.
    # We'll use the main schemas for now for simplicity in direct storage.
  }

  # ETS Table Names (as per specifications)
  @ast_modules_table :ast_modules_enhanced        # Key: module_name (atom), Value: EnhancedModuleData.t()
  @ast_functions_table :ast_functions_enhanced    # Key: {module, fun, arity}, Value: EnhancedFunctionData.t()
  @ast_nodes_table :ast_nodes_detailed          # Key: ast_node_id (String.t()), Value: %{ast: Macro.t(), metadata: map()}
  @ast_variables_table :ast_variables_detailed    # Key: {module, fun, arity, var_name_ssa}, Value: VariableData.t() (bag for versions)
  @ast_cpg_table :ast_cpgs                      # Key: {module, fun, arity}, Value: CPGData.t()

  # Index Tables
  @module_by_file_index :idx_module_by_file      # Key: file_path (String.t()), Value: module_name (atom)
  @function_by_ast_node_index :idx_func_by_ast_node # Key: ast_node_id (String.t()) of def, Value: {m,f,a}
  @calls_by_target_index :idx_calls_by_target    # Key: {target_m,f,a}, Value: [{caller_m,f,a, call_site_id}] (bag)
  @complexity_index :idx_complexity_functions   # Key: complexity_score_bucket, Value: [{m,f,a}] (bag)

  # --- Client API ---

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "Clears all data from the repository. For testing or reset purposes."
  def clear_all(server \\ __MODULE__) do
    GenServer.call(server, :clear_all)
  end

  # --- Module Data ---
  def store_module(server \\ __MODULE__, %EnhancedModuleData{} = module_data) do
    GenServer.call(server, {:store_module, module_data})
  end

  def get_module(server \\ __MODULE__, module_name) when is_atom(module_name) do
    GenServer.call(server, {:get_module, module_name})
  end

  def list_modules(server \\ __MODULE__, filter_opts \\ []) do
    GenServer.call(server, {:list_modules, filter_opts})
  end

  def delete_module(server \\ __MODULE__, module_name) when is_atom(module_name) do
    GenServer.call(server, {:delete_module, module_name})
  end

  # --- Function Data ---
  def store_function(server \\ __MODULE__, %EnhancedFunctionData{} = function_data) do
    GenServer.call(server, {:store_function, function_data})
  end

  def get_function(server \\ __MODULE__, module_name, function_name, arity)
      when is_atom(module_name) and is_atom(function_name) and is_integer(arity) do
    GenServer.call(server, {:get_function, {module_name, function_name, arity}})
  end

  def get_functions_for_module(server \\ __MODULE__, module_name) when is_atom(module_name) do
    GenServer.call(server, {:get_functions_for_module, module_name})
  end

  # Query type defined in AST_REPOSITORY_IMPLEMENTATION_GUIDE.md
  @type function_query :: %{
    optional(:module) => atom() | [atom()],
    optional(:complexity) => {:gt | :lt | :eq, number()},
    optional(:visibility) => :public | :private,
    optional(:pattern) => String.t(), # e.g. function name regex
    optional(:calls_mfa) => {atom(), atom(), non_neg_integer()}, # Functions that call this MFA
    optional(:is_callback_for) => atom(), # Behaviour module
    optional(:limit) => pos_integer(),
    optional(:sort_by) => {:asc | :desc, atom()} # e.g. :complexity_score
  }
  def query_functions(server \\ __MODULE__, query_spec) do
    GenServer.call(server, {:query_functions, query_spec})
  end

  # --- AST Node Data ---
  def store_ast_node(server \\ __MODULE__, ast_node_id, ast_quoted, metadata \\ %{}) do
    GenServer.call(server, {:store_ast_node, ast_node_id, ast_quoted, metadata})
  end

  def get_ast_node(server \\ __MODULE__, ast_node_id) when is_binary(ast_node_id) do
    GenServer.call(server, {:get_ast_node, ast_node_id})
  end

  # --- CPG Data ---
  def store_cpg(server \\ __MODULE__, %CPGData{} = cpg_data) do
    GenServer.call(server, {:store_cpg, cpg_data})
  end

  def get_cpg(server \\ __MODULE__, module_name, function_name, arity) do
    GenServer.call(server, {:get_cpg, {module_name, function_name, arity}})
  end

  # --- Variable Data (Example - DFG results are often part of EnhancedFunctionData.dfg) ---
  # If variables were to be stored/queried globally or more directly:
  # def store_variable_data(server \\ __MODULE__, %VariableData{} = var_data) do ... end
  # def get_variable_data(server \\ __MODULE__, ssa_name, scope_id) do ... end


  # --- Index and Relationship Queries ---
  def get_module_by_filepath(server \\ __MODULE__, file_path) when is_binary(file_path) do
    GenServer.call(server, {:get_module_by_filepath, file_path})
  end

  def find_callers_of_mfa(server \\ __MODULE__, target_mfa :: {atom, atom, non_neg_integer()}) do
    GenServer.call(server, {:find_callers_of_mfa, target_mfa})
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(opts) do
    # Default table options
    default_table_opts = [:set, :public, :named_table, {:read_concurrency, true}, {:write_concurrency, true}]
    bag_table_opts = [:bag, :public, :named_table, {:read_concurrency, true}, {:write_concurrency, true}]

    # Create main storage tables
    :ets.new(@ast_modules_table, default_table_opts)
    :ets.new(@ast_functions_table, default_table_opts)
    :ets.new(@ast_nodes_table, default_table_opts)
    :ets.new(@ast_variables_table, bag_table_opts) # Bag for multiple versions/scopes
    :ets.new(@ast_cpg_table, default_table_opts)

    # Create index tables
    :ets.new(@module_by_file_index, default_table_opts)
    :ets.new(@function_by_ast_node_index, default_table_opts) # Assuming ast_node_id of def is unique
    :ets.new(@calls_by_target_index, bag_table_opts)
    :ets.new(@complexity_index, bag_table_opts)

    # Memory limit and other configurations
    memory_limit_mb = Keyword.get(opts, :memory_limit_mb, Application.get_env(:elixir_scope, [:ast_repository, :max_memory_mb], 500))
    # Could start a :timer for periodic memory checks if needed

    {:ok, %{memory_limit_mb: memory_limit_mb, stats: %{modules: 0, functions: 0}}}
  end

  @impl true
  def handle_call(:clear_all, _from, state) do
    :ets.delete_all_objects(@ast_modules_table)
    :ets.delete_all_objects(@ast_functions_table)
    :ets.delete_all_objects(@ast_nodes_table)
    :ets.delete_all_objects(@ast_variables_table)
    :ets.delete_all_objects(@ast_cpg_table)
    :ets.delete_all_objects(@module_by_file_index)
    :ets.delete_all_objects(@function_by_ast_node_index)
    :ets.delete_all_objects(@calls_by_target_index)
    :ets.delete_all_objects(@complexity_index)
    {:reply, :ok, %{state | stats: %{modules: 0, functions: 0}}}
  end

  @impl true
  def handle_call({:store_module, %EnhancedModuleData{} = module_data}, _from, state) do
    # TODO: Check memory limit before inserting
    :ets.insert(@ast_modules_table, {module_data.module_name, module_data})
    :ets.insert(@module_by_file_index, {module_data.file_path, module_data.module_name})
    # TODO: Update other relevant indexes (e.g., if module complexity is indexed)
    # TODO: Store functions from module_data.functions individually
    Enum.each(module_data.functions, fn func_data ->
      # This could be a cast to self to avoid blocking, or direct call to internal helper
      internal_store_function(func_data, state) # Pass state for potential index updates
    end)
    new_stats = Map.update(state.stats, :modules, 1, &(&1 + 1))
    {:reply, :ok, %{state | stats: new_stats}}
  end

  @impl true
  def handle_call({:get_module, module_name}, _from, state) do
    case :ets.lookup(@ast_modules_table, module_name) do
      [{^module_name, module_data}] -> {:reply, {:ok, module_data}, state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:list_modules, _filter_opts}, _from, state) do
    # TODO: Implement filtering based on filter_opts
    # This is a naive full scan; for large repos, use an index or selective iteration.
    all_modules = :ets.foldl(fn {{_name, data}, acc} -> [data | acc] end, [], @ast_modules_table)
    {:reply, {:ok, all_modules}, state}
  end

  @impl true
  def handle_call({:delete_module, module_name}, _from, state) do
    # TODO: Complex deletion: remove associated functions, CPGs, update indexes
    # For now, just basic deletion from main table
    :ets.delete(@ast_modules_table, module_name)
    # Also remove from file_path index if module_data was fetched first
    new_stats = Map.update(state.stats, :modules, 0, &(&1 - 1))
    {:reply, :ok, %{state | stats: new_stats}}
  end


  @impl true
  def handle_call({:store_function, %EnhancedFunctionData{} = function_data}, _from, state) do
    internal_store_function(function_data, state)
    new_stats = Map.update(state.stats, :functions, 1, &(&1 + 1))
    {:reply, :ok, %{state | stats: new_stats}}
  end

  @impl true
  def handle_call({:get_function, mfa_key}, _from, state) do
    case :ets.lookup(@ast_functions_table, mfa_key) do
      [{^mfa_key, function_data}] -> {:reply, {:ok, function_data}, state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:get_functions_for_module, module_name}, _from, state) do
    # This requires iterating or a secondary index (e.g., if functions table key was {module, fun, arity})
    # If key is {m,f,a}, we can use :ets.select or :ets.match
    pattern = {{module_name, :"$1", :"$2"}, :"$3"} # Match {M,F,A} => Value
    results = :ets.match_object(@ast_functions_table, pattern)
    functions = Enum.map(results, fn {_key, func_data} -> func_data end)
    {:reply, {:ok, functions}, state}
  end

  @impl true
  def handle_call({:query_functions, query_spec}, _from, state) do
    # This is a complex operation. Needs careful implementation.
    # 1. Start with a full list or use a primary index if possible (e.g., module filter)
    # 2. Apply filters sequentially or build an :ets.select call.
    # 3. Sort results.
    # 4. Apply limit.

    # Placeholder implementation:
    all_functions_raw = :ets.tab2list(@ast_functions_table) # Inefficient for large tables
    all_functions = Enum.map(all_functions_raw, fn {_key, data} -> data end)

    filtered_functions = all_functions
    |> filter_by_module(query_spec[:module])
    |> filter_by_complexity(query_spec[:complexity])
    |> filter_by_visibility(query_spec[:visibility])
    |> filter_by_calls_mfa(query_spec[:calls_mfa], state) # Needs calls_by_target_index
    # ... other filters ...
    |> sort_results(query_spec[:sort_by])
    |> limit_results(query_spec[:limit])

    {:reply, {:ok, filtered_functions}, state}
  end

  @impl true
  def handle_call({:store_ast_node, ast_node_id, ast_quoted, metadata}, _from, state) do
    :ets.insert(@ast_nodes_table, {ast_node_id, %{ast: ast_quoted, metadata: metadata}})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:get_ast_node, ast_node_id}, _from, state) do
    case :ets.lookup(@ast_nodes_table, ast_node_id) do
      [{^ast_node_id, data}] -> {:reply, {:ok, {data.ast, data.metadata}}, state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:store_cpg, %CPGData{} = cpg_data}, _from, state) do
    key = cpg_data.function_key
    :ets.insert(@ast_cpg_table, {key, cpg_data})
    # TODO: Update CPG-related indexes if any
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:get_cpg, mfa_key}, _from, state) do
     case :ets.lookup(@ast_cpg_table, mfa_key) do
      [{^mfa_key, cpg_data}] -> {:reply, {:ok, cpg_data}, state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:get_module_by_filepath, file_path}, _from, state) do
    case :ets.lookup(@module_by_file_index, file_path) do
      [{^file_path, module_name}] ->
        # Optionally, fetch the full module data
        handle_call({:get_module, module_name}, _from, state)
      [] -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:find_callers_of_mfa, target_mfa}, _from, state) do
    callers = :ets.lookup_element(@calls_by_target_index, target_mfa, 2) # Get list of callers
    # The value in @calls_by_target_index should be structured to be useful,
    # e.g., list of {caller_m,f,a, call_site_ast_node_id}
    {:reply, {:ok, callers}, state}
  end

  # --- Internal Helpers ---

  # Internal function to store function data and update indexes
  defp internal_store_function(%EnhancedFunctionData{} = function_data, _state) do
    mfa_key = {function_data.module_name, function_data.function_name, function_data.arity}
    :ets.insert(@ast_functions_table, {mfa_key, function_data})

    # Update function_by_ast_node_index (for the def node)
    if ast_node_id = function_data.ast_node_id, do: :ets.insert(@function_by_ast_node_index, {ast_node_id, mfa_key})

    # Update calls_by_target_index for all functions called by this one
    Enum.each(function_data.called_functions || [], fn called_func_info ->
      # called_func_info should be like %{module: M, function: F, arity: A, call_site_ast_id: ID}
      target_mfa = {called_func_info.module, called_func_info.function, called_func_info.arity}
      caller_info = {function_data.module_name, function_data.function_name, function_data.arity, called_func_info.call_site_ast_id}
      :ets.insert(@calls_by_target_index, {target_mfa, caller_info})
    end)

    # Update complexity_index
    if score = function_data.complexity_score do
      bucket = floor(score / 5) * 5 # Group by buckets of 5 for complexity score
      :ets.insert(@complexity_index, {bucket, mfa_key})
    end
    :ok
  end

  # --- Query Filtering Helpers (for query_functions) ---
  defp filter_by_module(functions, nil), do: functions
  defp filter_by_module(functions, module_name_or_list) do
    allowed_modules = List.wrap(module_name_or_list) |> MapSet.new()
    Enum.filter(functions, &MapSet.member?(allowed_modules, &1.module_name))
  end

  defp filter_by_complexity(functions, nil), do: functions
  defp filter_by_complexity(functions, {op, value}) do
    Enum.filter(functions, fn func_data ->
      score = func_data.complexity_score # Assuming this field exists and is numeric
      case op do
        :gt -> score > value
        :lt -> score < value
        :eq -> score == value
        _ -> true
      end
    end)
  end

  defp filter_by_visibility(functions, nil), do: functions
  defp filter_by_visibility(functions, visibility_atom) do
    Enum.filter(functions, &(&1.visibility == visibility_atom))
  end

  defp filter_by_calls_mfa(functions, nil, _state), do: functions
  defp filter_by_calls_mfa(functions, target_mfa, _state) do
    # This is inefficient if done by iterating all functions.
    # Better: Query @calls_by_target_index for target_mfa to get all caller MFAs,
    # then filter `functions` list to only include those MFAs.
    caller_mfas = :ets.lookup_element(@calls_by_target_index, target_mfa, 2) # list of {m,f,a, call_site_id}
                  |> Enum.map(fn {m,f,a,_site} -> {m,f,a} end)
                  |> MapSet.new()

    Enum.filter(functions, fn func_data ->
      mfa_key = {func_data.module_name, func_data.function_name, func_data.arity}
      MapSet.member?(caller_mfas, mfa_key)
    end)
  end


  defp sort_results(functions, nil), do: functions
  defp sort_results(functions, {direction, field_atom}) do
    Enum.sort_by(functions, &Map.get(&1, field_atom), if(direction == :desc, do: :desc, else: :asc))
  end

  defp limit_results(functions, nil), do: functions
  defp limit_results(functions, limit_val) when is_integer(limit_val) and limit_val > 0 do
    Enum.take(functions, limit_val)
  end
  defp limit_results(functions, _), do: functions # Invalid limit

end
