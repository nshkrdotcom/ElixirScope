# ElixirScope AST Repository - API Reference

This document provides a reference for the public APIs of the core components within the ElixirScope AST Repository. For detailed data structures, refer to `AST_REPOSITORY_DATA_SCHEMAS_AND_SPECIFICATIONS.md`.

## Table of Contents

1.  [ElixirScope.ASTRepository.Repository](#module-elixirscopeastrepositoryrepository)
2.  [ElixirScope.ASTRepository.ProjectPopulator](#module-elixirscopeastrepositoryprojectpopulator)
3.  [ElixirScope.ASTRepository.FileWatcher](#module-elixirscopeastrepositoryfilewatcher)
4.  [ElixirScope.ASTRepository.Synchronizer](#module-elixirscopeastrepositorysynchronizer)
5.  [ElixirScope.ASTRepository.ASTAnalyzer](#module-elixirscopeastrepositoryastanalyzer)
6.  [ElixirScope.ASTRepository.NodeIdentifier](#module-elixirscopeastrepositorynodeidentifier)
7.  [ElixirScope.ASTRepository.CFGGenerator](#module-elixirscopeastrepositorycfggenerator)
8.  [ElixirScope.ASTRepository.DFGGenerator](#module-elixirscopeastrepositorydfggenerator)
9.  [ElixirScope.ASTRepository.CPGBuilder](#module-elixirscopeastrepositorycpgbuilder)
10. [ElixirScope.ASTRepository.QueryBuilder](#module-elixirscopeastrepositoryquerybuilder)
11. [ElixirScope.ASTRepository.QueryExecutor](#module-elixirscopeastrepositoryqueryexecutor)
12. [ElixirScope.ASTRepository.Config](#module-elixirscopeastrepositoryconfig)
13. [Integration Bridges](#module-integration-bridges)
    *   [ElixirScope.Capture.TemporalBridge.ASTIntegration](#module-elixirscopecapturetemporalbridgeastintegration)
    *   [ElixirScope.AI.Bridge](#module-elixirscopeaibridge)
    *   [ElixirScope.ASTRepository.RuntimeBridge](#module-elixirscopeastrepositoryruntimebridge)

---

## 1. Module: `ElixirScope.ASTRepository.Repository`

The central GenServer for storing and managing AST-related data.

**Starting the Repository:**
*   `start_link(opts :: keyword()) :: GenServer.on_start()`
    *   Starts the Repository GenServer.
    *   `opts`: `[:name, :memory_limit_mb, :ets_table_options]`

**Core Operations:**
*   `clear_all(server \\ __MODULE__) :: :ok`
    *   Clears all data from the repository.
*   `store_module(server \\ __MODULE__, module_data :: EnhancedModuleData.t()) :: :ok | {:error, term()}`
*   `get_module(server \\ __MODULE__, module_name :: atom()) :: {:ok, EnhancedModuleData.t()} | {:error, :not_found}`
*   `list_modules(server \\ __MODULE__, filter_opts :: keyword()) :: {:ok, [EnhancedModuleData.t()]}`
*   `delete_module(server \\ __MODULE__, module_name :: atom()) :: :ok | {:error, term()}`
*   `store_function(server \\ __MODULE__, function_data :: EnhancedFunctionData.t()) :: :ok | {:error, term()}`
*   `get_function(server \\ __MODULE__, module_name :: atom(), function_name :: atom(), arity :: non_neg_integer()) :: {:ok, EnhancedFunctionData.t()} | {:error, :not_found}`
*   `get_functions_for_module(server \\ __MODULE__, module_name :: atom()) :: {:ok, [EnhancedFunctionData.t()]}`
*   `query_functions(server \\ __MODULE__, query_spec :: map()) :: {:ok, [EnhancedFunctionData.t()]} | {:error, term()}`
    *   `query_spec` structure detailed in `11-ast_repository.ex`.
*   `store_ast_node(server \\ __MODULE__, ast_node_id :: String.t(), ast_quoted :: Macro.t(), metadata :: map()) :: :ok | {:error, term()}`
*   `get_ast_node(server \\ __MODULE__, ast_node_id :: String.t()) :: {:ok, {Macro.t(), map()}} | {:error, :not_found}`
*   `store_cpg(server \\ __MODULE__, cpg_data :: CPGData.t()) :: :ok | {:error, term()}`
*   `get_cpg(server \\ __MODULE__, module_name :: atom(), function_name :: atom(), arity :: non_neg_integer()) :: {:ok, CPGData.t()} | {:error, :not_found}`

**Index/Relationship Queries:**
*   `get_module_by_filepath(server \\ __MODULE__, file_path :: String.t()) :: {:ok, EnhancedModuleData.t() | atom()} | {:error, :not_found}`
*   `find_callers_of_mfa(server \\ __MODULE__, target_mfa :: {atom, atom, non_neg_integer()}) :: {:ok, list()} | {:error, term()}`

---

## 2. Module: `ElixirScope.ASTRepository.ProjectPopulator`

Populates the AST Repository from project source files.

*   `populate_project(project_path :: String.t(), opts :: population_options()) :: {:ok, population_result()} | {:error, term()}`
    *   `population_options`: `[:include_deps, :include_test_files, :file_patterns, :ignore_patterns, :parallel_workers, :progress_callback, :error_handler, :file_processing_timeout_ms]`
    *   `population_result`: `%{status, total_files_discovered, files_processed, modules_added, functions_analyzed, errors, duration_ms, memory_impact_mb}`
*   `discover_elixir_files(project_path :: String.t(), file_patterns :: [String.t()], ignore_patterns :: [String.t()]) :: {:ok, [String.t()]} | {:error, term()}`
    *   Utility for finding relevant source files.

---

## 3. Module: `ElixirScope.ASTRepository.FileWatcher`

Monitors project directories for file changes.

**Starting the Watcher:**
*   `start_link(opts :: keyword()) :: GenServer.on_start()`
    *   `opts`: `[:project_path, :name, :debounce_ms, :ignore_patterns, :file_patterns, :callback]`

**Control Operations:**
*   `watch_directory(server \\ __MODULE__, directory_path :: String.t()) :: :ok | {:error, term()}` (Conceptual)
*   `unwatch_directory(server \\ __MODULE__, directory_path :: String.t()) :: :ok | {:error, term()}` (Conceptual)
*   `pause(server \\ __MODULE__) :: :ok`
*   `resume(server \\ __MODULE__) :: :ok`
*   `status(server \\ __MODULE__) :: {:ok, map()}`
    *   Returns `%{project_path, paused, pending_changes_count, debouncing}`

---

## 4. Module: `ElixirScope.ASTRepository.Synchronizer`

Applies incremental updates to the AST Repository based on file changes.

*   `sync_changes_batch(changes :: [FileChangeEvent.t()], opts :: sync_options()) :: {:ok, batch_sync_result()} | {:error, term()}`
    *   `sync_options`: `[:repo_pid, :analysis_opts]`
    *   `batch_sync_result`: `%{total_changes_processed, successful_syncs, failed_syncs, results, duration_ms}`
*   `sync_single_change_event(change :: FileChangeEvent.t(), repo_pid :: pid() | atom(), analysis_opts :: keyword()) :: individual_sync_result()`
    *   `individual_sync_result`: `%{file_path, status, module_name, reason}`

---

## 5. Module: `ElixirScope.ASTRepository.ASTAnalyzer`

Performs analysis of module and function ASTs.

*   `analyze_module_ast(module_ast :: Macro.t(), module_name :: atom(), file_path :: String.t(), opts :: keyword()) :: {:ok, EnhancedModuleData.t()} | {:error, term()}`
*   `analyze_function_ast(fun_ast :: Macro.t(), module_name :: atom(), fun_name :: atom(), arity :: non_neg_integer(), file_path :: String.t(), ast_node_id_prefix :: String.t(), opts :: keyword()) :: {:ok, EnhancedFunctionData.t()} | {:error, term()}`

*(Internal helper functions for extraction are not part of the public API unless exposed for extensibility).*

---

## 6. Module: `ElixirScope.ASTRepository.NodeIdentifier`

Manages generation and parsing of AST Node IDs.

*   `assign_ids_to_ast(ast :: Macro.t(), initial_context :: id_gen_context()) :: Macro.t()`
    *   Injects `:ast_node_id` into AST metadata.
    *   `id_gen_context`: `%{module_name, function_name, arity, clause_index, current_path}`
*   `assign_ids_custom_traverse(ast_node :: Macro.t(), context :: id_gen_context()) :: Macro.t()`
    *   Alternative traversal for ID assignment with precise path context.
*   `generate_id_for_current_node(node :: Macro.t(), context :: id_gen_context()) :: ast_node_id()`
*   `get_id_from_ast_meta(meta :: keyword() | nil) :: ast_node_id() | nil`
*   `parse_id(ast_node_id :: ast_node_id()) :: {:ok, map()} | {:error, :invalid_format}`
    *   Returns map with `%{module, function, arity, clause_index, path_info, node_hash}`.

---

## 7. Module: `ElixirScope.ASTRepository.CFGGenerator`

Generates Control Flow Graphs.

*   `generate_cfg(function_ast :: Macro.t(), opts :: keyword()) :: {:ok, CFGData.t()} | {:error, term()}`

---

## 8. Module: `ElixirScope.ASTRepository.DFGGenerator`

Generates Data Flow Graphs using SSA form.

*   `generate_dfg(function_ast :: Macro.t(), function_key :: {atom(), atom(), non_neg_integer()}, opts :: keyword()) :: {:ok, DFGData.t()} | {:error, term()}`

---

## 9. Module: `ElixirScope.ASTRepository.CPGBuilder`

Builds Code Property Graphs.

*   `build_cpg(function_data :: EnhancedFunctionData.t(), opts :: keyword()) :: {:ok, CPGData.t()} | {:error, term()}`
    *   Requires `function_data` to have `control_flow_graph` and `data_flow_graph` populated.

---

## 10. Module: `ElixirScope.ASTRepository.QueryBuilder`

Constructs query specifications for the AST Repository.

*   `find_functions() :: ast_repo_query_spec()`
*   `find_modules() :: ast_repo_query_spec()`
*   `find_cpg_nodes() :: ast_repo_query_spec()`
*   `where(query, field, op, value) :: ast_repo_query_spec()`
*   `select(query, fields) :: ast_repo_query_spec()`
*   `order_by(query, field, direction \\ :asc) :: ast_repo_query_spec()`
*   `limit(query, count) :: ast_repo_query_spec()`
*   `offset(query, count) :: ast_repo_query_spec()`
*   `by_complexity(query, metric, op, value) :: ast_repo_query_spec()`
*   `calls_mfa(query, target_mfa) :: ast_repo_query_spec()`
*   `callers_of_mfa(query, target_mfa) :: ast_repo_query_spec()`
*   `match_cpg_pattern(query, pattern_dsl) :: ast_repo_query_spec()`
*   `build_correlated_query(static_query_spec, runtime_query_template, join_on) :: map()` (for main Query Engine)

---

## 11. Module: `ElixirScope.ASTRepository.QueryExecutor`

Executes queries built by `QueryBuilder` against the AST Repository.

*   `execute_query(query_spec :: ast_repo_query_spec(), repo_pid :: pid() | atom()) :: {:ok, results :: list()} | {:error, term()}`

---

## 12. Module: `ElixirScope.ASTRepository.Config`

Centralized configuration access for AST Repository components.

*   `get(key_path :: list() | atom(), default_value :: any()) :: any()`
*   `repository_genserver_name() :: atom()`
*   `repository_max_memory_mb() :: non_neg_integer()`
*   `populator_include_deps?() :: boolean()`
*   *(... and other specific config getters for various components)*
*   `all_configs() :: map()`

---

## 13. Module: Integration Bridges

### `ElixirScope.Capture.TemporalBridge.ASTIntegration`

Enhances `TemporalBridge` with AST/CPG context.

*   `get_event_with_ast_context(event_id :: term(), repo_pid :: pid() | atom()) :: {:ok, map()} | {:error, term()}`
*   `reconstruct_state_with_ast_context(process_identifier, timestamp, repo_pid) :: {:ok, map()} | {:error, term()}`
*   `get_correlated_trace_with_ast_context(correlation_id, repo_pid) :: {:ok, [map()]} | {:error, term()}`
*   `get_runtime_execution_paths_for_function(function_key, time_range, repo_pid) :: {:ok, [[String.t()]]} | {:error, term()}`
*   `prepare_cpg_visualization_for_path(function_key, runtime_ast_node_id_path, repo_pid) :: {:ok, map()} | {:error, term()}`

### `ElixirScope.AI.Bridge`

Facilitates AI component interaction with the AST Repository and Query Engine.

*   `get_function_cpg_for_ai(function_key, repo_pid) :: {:ok, CPGData.t()} | {:error, term()}`
*   `find_cpg_nodes_for_ai_pattern(cpg_pattern_dsl, function_key_or_nil, repo_pid) :: {:ok, [CPGNode.t()]} | {:error, term()}`
*   `get_correlated_features_for_ai(target_type, ids, runtime_filters, static_features, dynamic_features) :: {:ok, list(map())} | {:error, term()}`
*   `analyze_for_instrumentation_plan(module_ast, module_name, file_path) :: {:ok, EnhancedModuleData.t(), map()} | {:error, term()}`
*   `generate_and_store_embeddings_for_module(module_name, repo_pid) :: :ok | {:error, term()}`
*   `predict_with_analyzer(analyzer_module, function_key, context) :: {:ok, map()} | {:error, term()}`
*   `query_llm_with_cpg_context(function_key, prompt_template, llm_opts) :: {:ok, String.t()} | {:error, term()}`

### `ElixirScope.ASTRepository.RuntimeBridge`

Bridge for `InstrumentationRuntime` (mostly compile-time helpers and minimal runtime interaction).

*   `ast_node_id_exists?(ast_node_id, repo_pid) :: boolean()` (Primarily for debug/validation)
*   `get_minimal_ast_context(ast_node_id, repo_pid) :: {:ok, map()} | {:error, term()}` (For async post-processing)
*   `notify_ast_node_executed(ast_node_id, function_key, correlation_id, repo_pid) :: :ok` (Async notification)
*   `ElixirScope.ASTRepository.RuntimeBridge.CompileTimeHelpers`:
    *   `ensure_and_get_ast_node_id(ast_node, id_gen_context) :: {Macro.t(), String.t() | nil}`
    *   `prepare_runtime_call_args(original_ast_node_with_id, runtime_function, additional_static_args) :: Macro.t()`

---

This API reference provides a high-level overview. Each function would have more detailed documentation regarding its specific parameters, behavior, and return values in its respective module.