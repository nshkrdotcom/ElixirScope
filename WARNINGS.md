home@Desktop:~/p/g/n/ElixirScope$ mix compile
    warning: module attribute @function_analysis_timeout was set but never used
    │
 65 │   @function_analysis_timeout 10
    │   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/elixir_scope/ast_repository/pattern_matcher.ex:65: ElixirScope.ASTRepository.PatternMatcher (module)

    warning: module attribute @high_confidence_threshold was set but never used
    │
 61 │   @high_confidence_threshold 0.9
    │   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/elixir_scope/ast_repository/pattern_matcher.ex:61: ElixirScope.ASTRepository.PatternMatcher (module)

    warning: unused alias CFGData
    │
 49 │   alias ElixirScope.ASTRepository.Enhanced.{
    │   ~
    │
    └─ lib/elixir_scope/ast_repository/pattern_matcher.ex:49:3

    warning: unused alias DFGData
    │
 49 │   alias ElixirScope.ASTRepository.Enhanced.{
    │   ~
    │
    └─ lib/elixir_scope/ast_repository/pattern_matcher.ex:49:3

    warning: unused alias EnhancedFunctionData
    │
 49 │   alias ElixirScope.ASTRepository.Enhanced.{
    │   ~
    │
    └─ lib/elixir_scope/ast_repository/pattern_matcher.ex:49:3

    warning: unused alias EnhancedModuleData
    │
 49 │   alias ElixirScope.ASTRepository.Enhanced.{
    │   ~
    │
    └─ lib/elixir_scope/ast_repository/pattern_matcher.ex:49:3

    warning: unused alias EnhancedRepository
    │
 48 │   alias ElixirScope.ASTRepository.EnhancedRepository
    │   ~
    │
    └─ lib/elixir_scope/ast_repository/pattern_matcher.ex:48:3

     warning: variable "repo" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 719 │   defp get_module_data(repo, module) when not is_nil(module) do
     │                        ~~~~
     │
     └─ lib/elixir_scope/ast_repository/runtime_correlator.ex:719:24: ElixirScope.ASTRepository.RuntimeCorrelator.get_module_data/2

     warning: variable "repo" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 800 │   defp get_cfg_context(repo, ast_context) do
     │                        ~~~~
     │
     └─ lib/elixir_scope/ast_repository/runtime_correlator.ex:800:24: ElixirScope.ASTRepository.RuntimeCorrelator.get_cfg_context/2

     warning: variable "repo" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 816 │   defp get_dfg_context(repo, ast_context) do
     │                        ~~~~
     │
     └─ lib/elixir_scope/ast_repository/runtime_correlator.ex:816:24: ElixirScope.ASTRepository.RuntimeCorrelator.get_dfg_context/2

      warning: variable "duration" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 1063 │   defp update_correlation_stats(stats, operation, duration) do
      │                                                   ~~~~~~~~
      │
      └─ lib/elixir_scope/ast_repository/runtime_correlator.ex:1063:51: ElixirScope.ASTRepository.RuntimeCorrelator.update_correlation_stats/3

    warning: unused alias CFGData
    │
 46 │   alias ElixirScope.ASTRepository.Enhanced.{
    │   ~
    │
    └─ lib/elixir_scope/ast_repository/runtime_correlator.ex:46:3

    warning: unused alias DFGData
    │
 46 │   alias ElixirScope.ASTRepository.Enhanced.{
    │   ~
    │
    └─ lib/elixir_scope/ast_repository/runtime_correlator.ex:46:3

    warning: unused alias EnhancedFunctionData
    │
 46 │   alias ElixirScope.ASTRepository.Enhanced.{
    │   ~
    │
    └─ lib/elixir_scope/ast_repository/runtime_correlator.ex:46:3

    warning: unused alias EnhancedModuleData
    │
 46 │   alias ElixirScope.ASTRepository.Enhanced.{
    │   ~
    │
    └─ lib/elixir_scope/ast_repository/runtime_correlator.ex:46:3

    warning: unused alias EventStore
    │
 52 │   alias ElixirScope.Storage.EventStore
    │   ~
    │
    └─ lib/elixir_scope/ast_repository/runtime_correlator.ex:52:3

    warning: unused alias Events
    │
 53 │   alias ElixirScope.Events
    │   ~
    │
    └─ lib/elixir_scope/ast_repository/runtime_correlator.ex:53:3

     warning: variable "count" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 921 │       %{dry_run: true, modules_to_clean: count} ->
     │                                          ~
     │
     └─ lib/elixir_scope/ast_repository/memory_manager.ex:921:42: ElixirScope.ASTRepository.MemoryManager.update_cleanup_stats/3

    warning: unused alias EnhancedRepository
    │
 48 │   alias ElixirScope.ASTRepository.EnhancedRepository
    │   ~
    │
    └─ lib/elixir_scope/ast_repository/memory_manager.ex:48:3

     warning: the following clause will never match:

         {:error, _}

     because it attempts to match on the result of:

         compress_module_data(module, compression_level)

     which has type:

         dynamic({:ok, integer()})

     typing violation found at:
     │
 844 │         {:error, _} ->
     │         ~~~~~~~~~~~~~~
     │
     └─ lib/elixir_scope/ast_repository/memory_manager.ex:844: ElixirScope.ASTRepository.MemoryManager.compress_candidates/2

    warning: unused alias CFGData
    │
 13 │   alias ElixirScope.ASTRepository.Enhanced.{CFGData, DFGData, OptimizationHint}
    │   ~
    │
    └─ lib/elixir_scope/ast_repository/enhanced/cpg_data.ex:13:3

    warning: unused alias DFGData
    │
 13 │   alias ElixirScope.ASTRepository.Enhanced.{CFGData, DFGData, OptimizationHint}
    │   ~
    │
    └─ lib/elixir_scope/ast_repository/enhanced/cpg_data.ex:13:3

    warning: unused alias OptimizationHint
    │
 13 │   alias ElixirScope.ASTRepository.Enhanced.{CFGData, DFGData, OptimizationHint}
    │   ~
    │
    └─ lib/elixir_scope/ast_repository/enhanced/cpg_data.ex:13:3

      warning: function create_fake_ast_from_nodes/1 is unused
      │
 1372 │   defp create_fake_ast_from_nodes(nodes) do
      │        ~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cfg_generator.ex:1372:8: ElixirScope.ASTRepository.Enhanced.CFGGenerator (module)

      warning: function create_empty_path_analysis/0 is unused
      │
 1422 │   defp create_empty_path_analysis do
      │        ~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cfg_generator.ex:1422:8: ElixirScope.ASTRepository.Enhanced.CFGGenerator (module)

     warning: clauses with the same name and arity (number of arguments) should be grouped together, "defp normalize_query/1" was previously defined (lib/elixir_scope/ast_repository/query_builder.ex:296)
     │
 322 │   defp normalize_query(%__MODULE__{} = query), do: {:ok, query}
     │        ~
     │
     └─ lib/elixir_scope/ast_repository/query_builder.ex:322:8

    warning: unused alias EnhancedFunctionData
    │
 56 │   alias ElixirScope.ASTRepository.Enhanced.{
    │   ~
    │
    └─ lib/elixir_scope/ast_repository/query_builder.ex:56:3

    warning: unused alias EnhancedModuleData
    │
 56 │   alias ElixirScope.ASTRepository.Enhanced.{
    │   ~
    │
    └─ lib/elixir_scope/ast_repository/query_builder.ex:56:3

    warning: unused alias EnhancedRepository
    │
 55 │   alias ElixirScope.ASTRepository.EnhancedRepository
    │   ~
    │
    └─ lib/elixir_scope/ast_repository/query_builder.ex:55:3

     warning: variable "ast_repo" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 558 │   defp build_execution_path(events, ast_repo) do
     │                                     ~~~~~~~~
     │
     └─ lib/elixir_scope/capture/temporal_bridge_enhancement.ex:558:37: ElixirScope.Capture.TemporalBridgeEnhancement.build_execution_path/2

     warning: variable "time_range" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 721 │   defp find_flow_events_between_nodes(from_events, to_events, time_range) do
     │                                                               ~~~~~~~~~~
     │
     └─ lib/elixir_scope/capture/temporal_bridge_enhancement.ex:721:63: ElixirScope.Capture.TemporalBridgeEnhancement.find_flow_events_between_nodes/3

    warning: module attribute @context_lookup_timeout was set but never used
    │
 57 │   @context_lookup_timeout 10   # milliseconds
    │   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/elixir_scope/capture/temporal_bridge_enhancement.ex:57: ElixirScope.Capture.TemporalBridgeEnhancement (module)

    warning: unused alias EnhancedRepository
    │
 48 │   alias ElixirScope.ASTRepository.EnhancedRepository
    │   ~
    │
    └─ lib/elixir_scope/capture/temporal_bridge_enhancement.ex:48:3

      warning: function scope_depth/1 is unused
      │
 1223 │   defp scope_depth(scope) do
      │        ~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/dfg_generator.ex:1223:8: ElixirScope.ASTRepository.Enhanced.DFGGenerator (module)

      warning: function generate_pattern_nodes/1 is unused
      │
 1686 │   defp generate_pattern_nodes(state) do
      │        ~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/dfg_generator.ex:1686:8: ElixirScope.ASTRepository.Enhanced.DFGGenerator (module)

      warning: function generate_comprehension_nodes/1 is unused
      │
 1700 │   defp generate_comprehension_nodes(state) do
      │        ~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/dfg_generator.ex:1700:8: ElixirScope.ASTRepository.Enhanced.DFGGenerator (module)

      warning: function find_unused_variables/1 is unused
      │
 1077 │   defp find_unused_variables(variables) do
      │        ~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/dfg_generator.ex:1077:8: ElixirScope.ASTRepository.Enhanced.DFGGenerator (module)

      warning: function find_shadowed_variables/1 is unused
      │
 1085 │   defp find_shadowed_variables(variables) do
      │        ~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/dfg_generator.ex:1085:8: ElixirScope.ASTRepository.Enhanced.DFGGenerator (module)

      warning: function find_dependencies_recursive/4 is unused
      │
 1331 │   defp find_dependencies_recursive(edges, nodes, node_id, visited) do
      │        ~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/dfg_generator.ex:1331:8: ElixirScope.ASTRepository.Enhanced.DFGGenerator (module)

      warning: function extract_variables_from_metadata/1 is unused
      │
 1239 │   defp extract_variables_from_metadata(metadata) do
      │        ~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/dfg_generator.ex:1239:8: ElixirScope.ASTRepository.Enhanced.DFGGenerator (module)

      warning: function extract_variable_names/1 is unused
      │
 1035 │   defp extract_variable_names(variables) do
      │        ~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/dfg_generator.ex:1035:8: ElixirScope.ASTRepository.Enhanced.DFGGenerator (module)

      warning: function extract_usage_type/1 is unused
      │
 1409 │   defp extract_usage_type(metadata) do
      │        ~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/dfg_generator.ex:1409:8: ElixirScope.ASTRepository.Enhanced.DFGGenerator (module)

      warning: function extract_definition_type/1 is unused
      │
 1402 │   defp extract_definition_type(metadata) do
      │        ~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/dfg_generator.ex:1402:8: ElixirScope.ASTRepository.Enhanced.DFGGenerator (module)

      warning: function extract_captured_variable_names/1 is unused
      │
 1428 │   defp extract_captured_variable_names(captures) do
      │        ~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/dfg_generator.ex:1428:8: ElixirScope.ASTRepository.Enhanced.DFGGenerator (module)

      warning: function create_minimal_analysis_results/0 is unused
      │
 1361 │   defp create_minimal_analysis_results do
      │        ~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/dfg_generator.ex:1361:8: ElixirScope.ASTRepository.Enhanced.DFGGenerator (module)

      warning: function calculate_data_flow_complexity_metric/1 is unused
      │
 1140 │   defp calculate_data_flow_complexity_metric(state) do
      │        ~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/dfg_generator.ex:1140:8: ElixirScope.ASTRepository.Enhanced.DFGGenerator (module)

     warning: unused alias ShadowInfo
     │
 969 │         alias ElixirScope.ASTRepository.Enhanced.{Mutation, ShadowInfo, VariableVersion}
     │         ~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/dfg_generator.ex:969:9

     warning: do not use "length(rest) > 0" to check if a list is not empty since length always traverses the whole list. Prefer to pattern match on a non-empty list, such as [_ | _], or use "rest != []" as a guard
     │
 917 │         ["entry" | rest] when length(rest) > 0 ->
     │                                            ~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:917:44

      warning: function propagate_taint_from_source/3 is unused
      │
 1285 │   defp propagate_taint_from_source(_source, _edges, _visited), do: []
      │        ~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:1285:8: ElixirScope.ASTRepository.Enhanced.CPGBuilder (module)

      warning: function find_xss_risks/2 is unused
      │
 1287 │   defp find_xss_risks(_dfg, _nodes), do: []
      │        ~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:1287:8: ElixirScope.ASTRepository.Enhanced.CPGBuilder (module)

      warning: function find_unsafe_deserialization/2 is unused
      │
 1289 │   defp find_unsafe_deserialization(_dfg, _nodes), do: []
      │        ~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:1289:8: ElixirScope.ASTRepository.Enhanced.CPGBuilder (module)

      warning: function find_taint_sources/1 is unused
      │
 1284 │   defp find_taint_sources(_dfg), do: []
      │        ~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:1284:8: ElixirScope.ASTRepository.Enhanced.CPGBuilder (module)

      warning: function find_sql_injection_risks/2 is unused
      │
 1286 │   defp find_sql_injection_risks(_dfg, _nodes), do: []
      │        ~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:1286:8: ElixirScope.ASTRepository.Enhanced.CPGBuilder (module)

      warning: function find_paths_between_nodes/4 is unused
      │
 1243 │   defp find_paths_between_nodes(edges, start_node, end_node, visited) do
      │        ~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:1243:8: ElixirScope.ASTRepository.Enhanced.CPGBuilder (module)

      warning: function find_path_traversal_risks/2 is unused
      │
 1288 │   defp find_path_traversal_risks(_dfg, _nodes), do: []
      │        ~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:1288:8: ElixirScope.ASTRepository.Enhanced.CPGBuilder (module)

     warning: function calculate_cognitive_complexity/2 is unused
     │
 765 │   defp calculate_cognitive_complexity(cfg, dfg) do
     │        ~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:765:8: ElixirScope.ASTRepository.Enhanced.CPGBuilder (module)

    warning: unused alias CFGData
    │
 20 │   alias ElixirScope.ASTRepository.Enhanced.{
    │   ~
    │
    └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:20:3

    warning: unused alias DFGData
    │
 20 │   alias ElixirScope.ASTRepository.Enhanced.{
    │   ~
    │
    └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:20:3

      warning: ElixirScope.ASTRepository.Enhanced.CFGGenerator.find_paths/3 is undefined or private
      │
 1185 │     CFGGenerator.find_paths(cpg.control_flow_graph, from_node, [to_node])
      │                  ~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:1185:18: ElixirScope.ASTRepository.Enhanced.CPGBuilder.trace_control_flow/3

      warning: ElixirScope.ASTRepository.Enhanced.CFGGenerator.detect_unreachable_code/1 is undefined or private
      │
 1208 │     CFGGenerator.detect_unreachable_code(cpg.control_flow_graph)
      │                  ~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:1208:18: ElixirScope.ASTRepository.Enhanced.CPGBuilder.find_dead_code/1

    warning: unused alias FunctionData
    │
 24 │   alias ElixirScope.ASTRepository.{ModuleData, FunctionData}
    │   ~
    │
    └─ lib/elixir_scope/ast_repository/enhanced_repository.ex:24:3

    warning: unused alias ModuleData
    │
 24 │   alias ElixirScope.ASTRepository.{ModuleData, FunctionData}
    │   ~
    │
    └─ lib/elixir_scope/ast_repository/enhanced_repository.ex:24:3

    warning: unused alias QueryEngine
    │
 34 │   alias ElixirScope.QueryEngine
    │   ~
    │
    └─ lib/elixir_scope/ast_repository/enhanced_repository.ex:34:3

    warning: unused alias ComplexityMetrics
    │
 60 │ alias ElixirScope.ASTRepository.Enhanced.ComplexityMetrics
    │ ~
    │
    └─ lib/elixir_scope/ast_repository/enhanced/shared_data_structures.ex:60:1

    warning: ScopeInfo.scope_types/0 is undefined (module ScopeInfo is not available or is yet to be defined). Did you mean:

          * ElixirScope.ASTRepository.Enhanced.ScopeInfo.scope_types/0

    │
  9 │   defdelegate scope_types(), to: ScopeInfo
    │   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/elixir_scope/ast_repository/enhanced/shared_data_structures.ex:9: ElixirScope.ASTRepository.Enhanced.SharedDataStructures.scope_types/0

    warning: ComplexityMetrics.complexity_metrics_fields/0 is undefined (module ComplexityMetrics is not available or is yet to be defined). Make sure the module name is correct and has been specified in full (or that an alias has been defined)
    │
 10 │   defdelegate complexity_metrics_fields(), to: ComplexityMetrics
    │   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/elixir_scope/ast_repository/enhanced/shared_data_structures.ex:10: ElixirScope.ASTRepository.Enhanced.SharedDataStructures.complexity_metrics_fields/0

    warning: module attribute @analysis_cache_prefix was set but never used
    │
 40 │   @analysis_cache_prefix "analysis:"
    │   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    │
    └─ lib/elixir_scope/ast_repository/performance_optimizer.ex:40: ElixirScope.ASTRepository.PerformanceOptimizer (module)

     warning: function get_memory_usage/0 is unused
     │
 800 │   defp get_memory_usage() do
     │        ~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/file_watcher.ex:800:8: ElixirScope.ASTRepository.Enhanced.FileWatcher (module)

     warning: function calculate_uptime/0 is unused
     │
 795 │   defp calculate_uptime() do
     │        ~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/file_watcher.ex:795:8: ElixirScope.ASTRepository.Enhanced.FileWatcher (module)

     warning: function calculate_memory_usage/1 is unused
     │
 810 │   defp calculate_memory_usage(_state) do
     │        ~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/file_watcher.ex:810:8: ElixirScope.ASTRepository.Enhanced.FileWatcher (module)

     warning: FileSystem.stop/1 is undefined or private
     │
 365 │         FileSystem.stop(state.watcher_pid)
     │                    ~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/file_watcher.ex:365:20: ElixirScope.ASTRepository.Enhanced.FileWatcher.stop_current_watcher/1

     warning: ElixirScope.ASTRepository.Enhanced.EnhancedRepository.clear_repository/0 is undefined (module ElixirScope.ASTRepository.Enhanced.EnhancedRepository is not available or is yet to be defined)
     │
 723 │     EnhancedRepository.clear_repository()
     │                        ~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/file_watcher.ex:723:24: ElixirScope.ASTRepository.Enhanced.FileWatcher.perform_full_rescan/2

     warning: variable "ast" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 695 │   defp count_ast_lines(ast) do
     │                        ~~~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/project_populator.ex:695:24: ElixirScope.ASTRepository.Enhanced.ProjectPopulator.count_ast_lines/1

     warning: variable "ast" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 745 │   defp detect_recursion_in_ast(ast) do
     │                                ~~~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/project_populator.ex:745:32: ElixirScope.ASTRepository.Enhanced.ProjectPopulator.detect_recursion_in_ast/1

     warning: redefining module ElixirScope.ASTRepository.Enhanced.PerformanceAnalysis (current version loaded from _build/dev/lib/elixir_scope/ebin/Elixir.ElixirScope.ASTRepository.Enhanced.PerformanceAnalysis.beam)
     │
 419 │ defmodule ElixirScope.ASTRepository.Enhanced.PerformanceAnalysis do
     │ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/dfg_data.ex:419: ElixirScope.ASTRepository.Enhanced.PerformanceAnalysis (module)

     warning: unused alias ScopeInfo
     │
 249 │ alias ElixirScope.ASTRepository.Enhanced.ScopeInfo
     │ ~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/dfg_data.ex:249:1

    warning: ElixirScope.ASTRepository.RuntimeCorrelator.get_events_for_ast_node/1 is undefined or private
    │
 81 │     case RuntimeCorrelator.get_events_for_ast_node(ast_node_id) do
    │                            ~
    │
    └─ lib/elixir_scope/core/event_manager.ex:81:28: ElixirScope.Core.EventManager.get_events_for_ast_node/1

    warning: ElixirScope.ASTRepository.RuntimeCorrelator.get_statistics/0 is undefined or private
    │
 92 │     case RuntimeCorrelator.get_statistics() do
    │                            ~
    │
    └─ lib/elixir_scope/core/event_manager.ex:92:28: ElixirScope.Core.EventManager.get_correlation_statistics/0

     warning: ElixirScope.ASTRepository.RuntimeCorrelator.health_check/0 is undefined or private
     │
 212 │           case RuntimeCorrelator.health_check() do
     │                                  ~
     │
     └─ lib/elixir_scope/core/event_manager.ex:212:34: ElixirScope.Core.EventManager.fallback_to_runtime_correlator/1

     warning: ElixirScope.ASTRepository.RuntimeCorrelator.query_temporal_events/2 is undefined or private
     │
 216 │               case RuntimeCorrelator.query_temporal_events(start_time, end_time) do
     │                                      ~
     │
     └─ lib/elixir_scope/core/event_manager.ex:216:38: ElixirScope.Core.EventManager.fallback_to_runtime_correlator/1
