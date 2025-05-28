home@Desktop:~/p/g/n/ElixirScope$ mix compile
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

    warning: variable "reason" is unused (if the variable is not meant to be used, prefix it with an underscore)
    │
 44 │             {:error, reason} ->
    │                      ~
    │
    └─ lib/elixir_scope/ast_repository/enhanced/cfg_generator.ex:44:22: ElixirScope.ASTRepository.Enhanced.CFGGenerator.generate_cfg/2

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

     warning: variable "other" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 780 │         other ->
     │         ~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/dfg_generator.ex:780:9: ElixirScope.ASTRepository.Enhanced.DFGGenerator.analyze_anonymous_function_data_flow/3

     warning: variable "node_id" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 847 │     {state, node_id} = create_dfg_node(state, :variable_definition, line, %{
     │             ~~~~~~~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/dfg_generator.ex:847:13: ElixirScope.ASTRepository.Enhanced.DFGGenerator.create_variable_definition/5

      warning: variable "state" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 1217 │   defp extract_used_variables_in_scope(state) do
      │                                        ~~~~~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/dfg_generator.ex:1217:40: ElixirScope.ASTRepository.Enhanced.DFGGenerator.extract_used_variables_in_scope/1

      warning: variable "state" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 1284 │   defp find_inlining_opportunities(state) do
      │                                    ~~~~~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/dfg_generator.ex:1284:36: ElixirScope.ASTRepository.Enhanced.DFGGenerator.find_inlining_opportunities/1

      warning: variable "edges" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 1323 │   defp trace_variable_path(edges, variable_nodes, path) do
      │                            ~~~~~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/dfg_generator.ex:1323:28: ElixirScope.ASTRepository.Enhanced.DFGGenerator.trace_variable_path/3

      warning: variable "path" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 1323 │   defp trace_variable_path(edges, variable_nodes, path) do
      │                                                   ~~~~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/dfg_generator.ex:1323:51: ElixirScope.ASTRepository.Enhanced.DFGGenerator.trace_variable_path/3

      warning: variable "scope" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 1460 │     Enum.reduce(variables_by_scope, %{}, fn {scope, scope_variables}, graph ->
      │                                              ~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/dfg_generator.ex:1460:46: ElixirScope.ASTRepository.Enhanced.DFGGenerator.build_dependency_graph_same_scope/1

      warning: variable "conditional_node" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 1652 │   defp find_variables_assigned_in_conditional_branches(state, conditional_node) do
      │                                                               ~~~~~~~~~~~~~~~~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/dfg_generator.ex:1652:63: ElixirScope.ASTRepository.Enhanced.DFGGenerator.find_variables_assigned_in_conditional_branches/2

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

     warning: variable "unified_nodes" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 858 │   defp find_execution_paths_impl(cfg, unified_nodes) do
     │                                       ~~~~~~~~~~~~~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:858:39: ElixirScope.ASTRepository.Enhanced.CPGBuilder.find_execution_paths_impl/2

     warning: do not use "length(rest) > 0" to check if a list is not empty since length always traverses the whole list. Prefer to pattern match on a non-empty list, such as [_ | _], or use "rest != []" as a guard
     │
 917 │         ["entry" | rest] when length(rest) > 0 ->
     │                                            ~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:917:44

      warning: variable "dfg" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 1032 │   defp analyze_taint_propagation(dfg, unified_edges) do
      │                                  ~~~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:1032:34: ElixirScope.ASTRepository.Enhanced.CPGBuilder.analyze_taint_propagation/2

      warning: variable "unified_edges" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 1032 │   defp analyze_taint_propagation(dfg, unified_edges) do
      │                                       ~~~~~~~~~~~~~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:1032:39: ElixirScope.ASTRepository.Enhanced.CPGBuilder.analyze_taint_propagation/2

      warning: variable "cfg" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 1041 │   defp detect_security_vulnerabilities(cfg, dfg, unified_nodes) do
      │                                        ~~~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:1041:40: ElixirScope.ASTRepository.Enhanced.CPGBuilder.detect_security_vulnerabilities/3

      warning: variable "dfg" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 1041 │   defp detect_security_vulnerabilities(cfg, dfg, unified_nodes) do
      │                                             ~~~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:1041:45: ElixirScope.ASTRepository.Enhanced.CPGBuilder.detect_security_vulnerabilities/3

      warning: variable "unified_nodes" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 1041 │   defp detect_security_vulnerabilities(cfg, dfg, unified_nodes) do
      │                                                  ~~~~~~~~~~~~~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:1041:50: ElixirScope.ASTRepository.Enhanced.CPGBuilder.detect_security_vulnerabilities/3

      warning: variable "to_var" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 1178 │   defp trace_data_flow(cpg, from_var, to_var) do
      │                                       ~~~~~~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:1178:39: ElixirScope.ASTRepository.Enhanced.CPGBuilder.trace_data_flow/3

      warning: variable "original_cpg" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 1277 │   defp merge_cpgs(original_cpg, new_cpg) do
      │                   ~~~~~~~~~~~~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:1277:19: ElixirScope.ASTRepository.Enhanced.CPGBuilder.merge_cpgs/2

      warning: variable "target" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 1422 │     chain_complexity = Enum.reduce(aliases, 0, fn {target, source}, acc ->
      │                                                    ~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:1422:52: ElixirScope.ASTRepository.Enhanced.CPGBuilder.calculate_alias_complexity/1

      warning: variable "metrics" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 1435 │   defp find_complexity_issues(metrics) do
      │                               ~~~~~~~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:1435:31: ElixirScope.ASTRepository.Enhanced.CPGBuilder.find_complexity_issues/1

      warning: variable "function_calls" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 1473 │     function_calls = []
      │     ~~~~~~~~~~~~~~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:1473:5: ElixirScope.ASTRepository.Enhanced.CPGBuilder.find_common_subexpressions/2

      warning: variable "dfg" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 1620 │   defp find_loop_invariants(cfg, dfg) do
      │                                  ~~~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:1620:34: ElixirScope.ASTRepository.Enhanced.CPGBuilder.find_loop_invariants/2

      warning: variable "cfg" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 1699 │   defp find_performance_hotspots(cfg, dfg) do
      │                                  ~~~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:1699:34: ElixirScope.ASTRepository.Enhanced.CPGBuilder.find_performance_hotspots/2

      warning: variable "dfg" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 1699 │   defp find_performance_hotspots(cfg, dfg) do
      │                                       ~~~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:1699:39: ElixirScope.ASTRepository.Enhanced.CPGBuilder.find_performance_hotspots/2

      warning: variable "cfg" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 1924 │   defp calculate_readability_score(cfg, dfg) do
      │                                    ~~~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:1924:36: ElixirScope.ASTRepository.Enhanced.CPGBuilder.calculate_readability_score/2

      warning: variable "dfg" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 1924 │   defp calculate_readability_score(cfg, dfg) do
      │                                         ~~~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:1924:41: ElixirScope.ASTRepository.Enhanced.CPGBuilder.calculate_readability_score/2

      warning: variable "cfg" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 1929 │   defp calculate_complexity_density(cfg) do
      │                                     ~~~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:1929:37: ElixirScope.ASTRepository.Enhanced.CPGBuilder.calculate_complexity_density/1

      warning: variable "cfg" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 1934 │   defp calculate_coupling_factor(cfg, dfg) do
      │                                  ~~~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:1934:34: ElixirScope.ASTRepository.Enhanced.CPGBuilder.calculate_coupling_factor/2

      warning: variable "cpg" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 2058 │   defp calculate_node_complexities(cpg) do
      │                                    ~~~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:2058:36: ElixirScope.ASTRepository.Enhanced.CPGBuilder.calculate_node_complexities/1

      warning: variable "cfg" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 2077 │   defp create_node_mappings(cfg, dfg) do
      │                             ~~~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:2077:29: ElixirScope.ASTRepository.Enhanced.CPGBuilder.create_node_mappings/2

      warning: variable "dfg" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 2077 │   defp create_node_mappings(cfg, dfg) do
      │                                  ~~~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:2077:34: ElixirScope.ASTRepository.Enhanced.CPGBuilder.create_node_mappings/2

      warning: variable "unified_edges" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 2088 │   defp create_query_indexes(unified_nodes, unified_edges) do
      │                                            ~~~~~~~~~~~~~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:2088:44: ElixirScope.ASTRepository.Enhanced.CPGBuilder.create_query_indexes/2

      warning: variable "unified_nodes" is unused (if the variable is not meant to be used, prefix it with an underscore)
      │
 2088 │   defp create_query_indexes(unified_nodes, unified_edges) do
      │                             ~~~~~~~~~~~~~
      │
      └─ lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex:2088:29: ElixirScope.ASTRepository.Enhanced.CPGBuilder.create_query_indexes/2

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

     warning: variable "opts" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 212 │   def handle_call({:store_enhanced_module, module_name, ast, opts}, _from, state) do
     │                                                              ~~~~
     │
     └─ lib/elixir_scope/ast_repository/enhanced_repository.ex:212:62: ElixirScope.ASTRepository.EnhancedRepository.handle_call/3

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

     warning: variable "opts" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 339 │   defp start_file_watcher(project_path, opts) do
     │                                         ~~~~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/file_watcher.ex:339:41: ElixirScope.ASTRepository.Enhanced.FileWatcher.start_file_watcher/2

     warning: variable "state" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 810 │   defp calculate_memory_usage(state) do
     │                               ~~~~~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/file_watcher.ex:810:31: ElixirScope.ASTRepository.Enhanced.FileWatcher.calculate_memory_usage/1

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
 810 │   defp calculate_memory_usage(state) do
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

     warning: variable "module_name" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 111 │            {:ok, {module_name, module_data}} <- analyze_single_module(parsed_file, true, true, false, 30_000) do
     │                   ~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/project_populator.ex:111:19: ElixirScope.ASTRepository.Enhanced.ProjectPopulator.parse_and_analyze_file/1

     warning: variable "timeout" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 343 │   defp analyze_single_module(parsed_file, generate_cfg, generate_dfg, generate_cpg, timeout) do
     │                                                                                     ~~~~~~~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/project_populator.ex:343:85: ElixirScope.ASTRepository.Enhanced.ProjectPopulator.analyze_single_module/5

     warning: variable "ast" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 508 │   defp extract_module_dependencies(ast) do
     │                                    ~~~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/project_populator.ex:508:36: ElixirScope.ASTRepository.Enhanced.ProjectPopulator.extract_module_dependencies/1

     warning: variable "ast" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 517 │   defp extract_module_exports(ast) do
     │                               ~~~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/project_populator.ex:517:31: ElixirScope.ASTRepository.Enhanced.ProjectPopulator.extract_module_exports/1

     warning: variable "ast" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 526 │   defp extract_module_attributes(ast) do
     │                                  ~~~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/project_populator.ex:526:34: ElixirScope.ASTRepository.Enhanced.ProjectPopulator.extract_module_attributes/1

     warning: variable "ast" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 560 │   defp perform_module_security_analysis(ast, functions) do
     │                                         ~~~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/project_populator.ex:560:41: ElixirScope.ASTRepository.Enhanced.ProjectPopulator.perform_module_security_analysis/2

     warning: variable "ast" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 572 │   defp generate_module_performance_hints(ast, functions) do
     │                                          ~~~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/project_populator.ex:572:42: ElixirScope.ASTRepository.Enhanced.ProjectPopulator.generate_module_performance_hints/2

     warning: variable "dfg_data" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 607 │   defp analyze_function_performance_characteristics(func_ast, cfg_data, dfg_data) do
     │                                                                         ~~~~~~~~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/project_populator.ex:607:73: ElixirScope.ASTRepository.Enhanced.ProjectPopulator.analyze_function_performance_characteristics/3

     warning: variable "cpg_data" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 621 │   defp analyze_function_security_characteristics(func_ast, cpg_data) do
     │                                                            ~~~~~~~~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/project_populator.ex:621:60: ElixirScope.ASTRepository.Enhanced.ProjectPopulator.analyze_function_security_characteristics/2

     warning: variable "func_ast" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 621 │   defp analyze_function_security_characteristics(func_ast, cpg_data) do
     │                                                  ~~~~~~~~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/project_populator.ex:621:50: ElixirScope.ASTRepository.Enhanced.ProjectPopulator.analyze_function_security_characteristics/2

     warning: variable "dfg_data" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 630 │   defp generate_function_optimization_hints(func_ast, cfg_data, dfg_data) do
     │                                                                 ~~~~~~~~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/project_populator.ex:630:65: ElixirScope.ASTRepository.Enhanced.ProjectPopulator.generate_function_optimization_hints/3

     warning: variable "analyzed_modules" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 663 │   defp detect_dependency_cycles(analyzed_modules) do
     │                                 ~~~~~~~~~~~~~~~~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/project_populator.ex:663:33: ElixirScope.ASTRepository.Enhanced.ProjectPopulator.detect_dependency_cycles/1

     warning: variable "ast" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 695 │   defp count_ast_lines(ast) do
     │                        ~~~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/project_populator.ex:695:24: ElixirScope.ASTRepository.Enhanced.ProjectPopulator.count_ast_lines/1

     warning: variable "ast" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 701 │   defp calculate_documentation_coverage(ast, functions) do
     │                                         ~~~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/project_populator.ex:701:41: ElixirScope.ASTRepository.Enhanced.ProjectPopulator.calculate_documentation_coverage/2

     warning: variable "functions" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 701 │   defp calculate_documentation_coverage(ast, functions) do
     │                                              ~~~~~~~~~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/project_populator.ex:701:46: ElixirScope.ASTRepository.Enhanced.ProjectPopulator.calculate_documentation_coverage/2

     warning: variable "ast" is unused (if the variable is not meant to be used, prefix it with an underscore)
     │
 706 │   defp calculate_cognitive_complexity(ast) do
     │                                       ~~~
     │
     └─ lib/elixir_scope/ast_repository/enhanced/project_populator.ex:706:39: ElixirScope.ASTRepository.Enhanced.ProjectPopulator.calculate_cognitive_complexity/1

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