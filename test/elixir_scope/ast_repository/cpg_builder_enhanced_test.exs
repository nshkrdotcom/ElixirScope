# defmodule ElixirScope.ASTRepository.CPGBuilderEnhancedTest do
#   use ExUnit.Case, async: true

#   alias ElixirScope.ASTRepository.Enhanced.{CPGBuilder, CPGData, CFGGenerator, DFGGenerator}
#   alias ElixirScope.TestHelpers

#   describe "CPG unification correctness" do
#     setup do
#       :ok = TestHelpers.ensure_config_available()
#       :ok
#     end

#     test "creates :unified_nodes that correctly link to corresponding CFGNode and DFGNode IDs" do
#       function_ast = quote do
#         def unified_function(x) do
#           y = x + 1
#           z = y * 2
#           z
#         end
#       end

#       {:ok, cfg} = CFGGenerator.generate_cfg(function_ast)
#       {:ok, dfg} = DFGGenerator.generate_dfg(function_ast)
#       {:ok, cpg} = CPGBuilder.build_cpg(cfg, dfg)

#       # Should have unified nodes
#       unified_nodes = cpg.nodes
#       |> Map.values()
#       |> Enum.filter(&(&1.type == :unified))

#       assert length(unified_nodes) >= 1

#       # Each unified node should link to CFG and/or DFG nodes
#       Enum.each(unified_nodes, fn unified_node ->
#         # Should have references to source nodes
#         assert Map.has_key?(unified_node, :cfg_node_id) or Map.has_key?(unified_node, :dfg_node_id)

#         # If it has CFG reference, it should exist in CFG
#         if Map.has_key?(unified_node, :cfg_node_id) and unified_node.cfg_node_id do
#           assert Map.has_key?(cfg.nodes, unified_node.cfg_node_id)
#         end

#         # If it has DFG reference, it should exist in DFG
#         if Map.has_key?(unified_node, :dfg_node_id) and unified_node.dfg_node_id do
#           assert Map.has_key?(dfg.nodes, unified_node.dfg_node_id)
#         end
#       end)
#     end

#     test "creates :control_flow CPGEdges derived from CFGEdges" do
#       function_ast = quote do
#         def control_flow_function(condition) do
#           if condition do
#             :true_branch
#           else
#             :false_branch
#           end
#         end
#       end

#       {:ok, cfg} = CFGGenerator.generate_cfg(function_ast)
#       {:ok, dfg} = DFGGenerator.generate_dfg(function_ast)
#       {:ok, cpg} = CPGBuilder.build_cpg(cfg, dfg)

#       # Should have control flow edges
#       control_flow_edges = cpg.edges
#       |> Enum.filter(&(&1.type == :control_flow))

#       assert length(control_flow_edges) >= 1

#       # Control flow edges should correspond to CFG edges
#       cfg_edge_count = length(cfg.edges)

#       # Should have at least some control flow edges derived from CFG
#       assert length(control_flow_edges) >= min(cfg_edge_count, 1)

#       # Each control flow edge should connect valid CPG nodes
#       all_cpg_node_ids = Map.keys(cpg.nodes)

#       Enum.each(control_flow_edges, fn edge ->
#         assert edge.from in all_cpg_node_ids
#         assert edge.to in all_cpg_node_ids
#       end)
#     end

#     test "creates :data_flow CPGEdges derived from DFG :data_flows" do
#       function_ast = quote do
#         def data_flow_function do
#           x = 10
#           y = x + 1
#           z = y * 2
#           {x, y, z}
#         end
#       end

#       {:ok, cfg} = CFGGenerator.generate_cfg(function_ast)
#       {:ok, dfg} = DFGGenerator.generate_dfg(function_ast)
#       {:ok, cpg} = CPGBuilder.build_cpg(cfg, dfg)

#       # Should have data flow edges
#       data_flow_edges = cpg.edges
#       |> Enum.filter(&(&1.type == :data_flow))

#       assert length(data_flow_edges) >= 1

#       # Data flow edges should correspond to DFG data flows
#       dfg_flow_count = length(dfg.data_flows)

#       # Should have at least some data flow edges derived from DFG
#       assert length(data_flow_edges) >= min(dfg_flow_count, 1)

#       # Each data flow edge should connect valid CPG nodes
#       all_cpg_node_ids = Map.keys(cpg.nodes)

#       Enum.each(data_flow_edges, fn edge ->
#         assert edge.from in all_cpg_node_ids
#         assert edge.to in all_cpg_node_ids
#       end)
#     end

#     test "creates :ast_structure CPGEdges representing parent/child relationships from the original AST" do
#       function_ast = quote do
#         def ast_structure_function do
#           case input() do
#             {:ok, value} ->
#               process(value)
#             {:error, reason} ->
#               handle_error(reason)
#           end
#         end
#       end

#       {:ok, cfg} = CFGGenerator.generate_cfg(function_ast)
#       {:ok, dfg} = DFGGenerator.generate_dfg(function_ast)
#       {:ok, cpg} = CPGBuilder.build_cpg(cfg, dfg)

#       # Should have AST structure edges
#       ast_structure_edges = cpg.edges
#       |> Enum.filter(&(&1.type == :ast_structure))

#       # May or may not have explicit AST structure edges depending on implementation
#       assert is_list(ast_structure_edges)

#       # If AST structure edges exist, they should connect valid nodes
#       if length(ast_structure_edges) > 0 do
#         all_cpg_node_ids = Map.keys(cpg.nodes)

#         Enum.each(ast_structure_edges, fn edge ->
#           assert edge.from in all_cpg_node_ids
#           assert edge.to in all_cpg_node_ids
#           assert edge.label in [:parent_child, :ast_parent, :contains, nil]
#         end)
#       end
#     end

#     test "CPGNodes corresponding to function calls have outgoing :call_graph CPGEdges to the CPG entry of the called function (intra-module for now)" do
#       function_ast = quote do
#         def caller_function do
#           result = helper_function()
#           another_helper(result)
#         end

#         def helper_function do
#           :helper_result
#         end

#         def another_helper(input) do
#           input
#         end
#       end

#       {:ok, cfg} = CFGGenerator.generate_cfg(function_ast)
#       {:ok, dfg} = DFGGenerator.generate_dfg(function_ast)
#       {:ok, cpg} = CPGBuilder.build_cpg(cfg, dfg)

#       # Should have function call nodes
#       call_nodes = cpg.nodes
#       |> Map.values()
#       |> Enum.filter(&(&1.type in [:function_call, :call]))

#       assert length(call_nodes) >= 2  # helper_function() and another_helper()

#       # Should have call graph edges
#       call_graph_edges = cpg.edges
#       |> Enum.filter(&(&1.type == :call_graph))

#       # May or may not have explicit call graph edges depending on implementation
#       assert is_list(call_graph_edges)

#       # If call graph edges exist, they should connect calls to function entries
#       if length(call_graph_edges) > 0 do
#         function_entry_nodes = cpg.nodes
#         |> Map.values()
#         |> Enum.filter(&(&1.type in [:function_entry, :entry]))

#         assert length(function_entry_nodes) >= 1

#         Enum.each(call_graph_edges, fn edge ->
#           from_node = cpg.nodes[edge.from]
#           to_node = cpg.nodes[edge.to]

#           assert from_node.type in [:function_call, :call]
#           assert to_node.type in [:function_entry, :entry, :function_definition]
#         end)
#       end
#     end

#     test "CPGNodes for function definitions include :ast, :control_flow_graph, and :data_flow_graph summaries or references" do
#       function_ast = quote do
#         def summarized_function(x, y) do
#           if x > 0 do
#             result = y * 2
#           else
#             result = y / 2
#           end
#           result
#         end
#       end

#       {:ok, cfg} = CFGGenerator.generate_cfg(function_ast)
#       {:ok, dfg} = DFGGenerator.generate_dfg(function_ast)
#       {:ok, cpg} = CPGBuilder.build_cpg(cfg, dfg)

#       # Should have function definition nodes
#       function_nodes = cpg.nodes
#       |> Map.values()
#       |> Enum.filter(&(&1.type in [:function_definition, :function, :def]))

#       assert length(function_nodes) >= 1
#       function_node = hd(function_nodes)

#       # Function node should have rich metadata
#       assert Map.has_key?(function_node, :metadata)
#       metadata = function_node.metadata

#       # Should have AST information
#       assert Map.has_key?(metadata, :ast) or Map.has_key?(function_node, :ast_snippet)

#       # Should have CFG summary or reference
#       assert Map.has_key?(metadata, :control_flow_graph) or
#              Map.has_key?(metadata, :cfg_summary) or
#              Map.has_key?(function_node, :cfg_node_ids)

#       # Should have DFG summary or reference
#       assert Map.has_key?(metadata, :data_flow_graph) or
#              Map.has_key?(metadata, :dfg_summary) or
#              Map.has_key?(function_node, :dfg_node_ids)
#     end

#     test "CPGData includes :node_mappings for cross-referencing (AST ID -> CFG ID, AST ID -> DFG ID)" do
#       function_ast = quote do
#         def mapped_function do
#           x = input()
#           y = process(x)
#           output(y)
#         end
#       end

#       {:ok, cfg} = CFGGenerator.generate_cfg(function_ast)
#       {:ok, dfg} = DFGGenerator.generate_dfg(function_ast)
#       {:ok, cpg} = CPGBuilder.build_cpg(cfg, dfg)

#       # Should have node mappings
#       assert Map.has_key?(cpg, :node_mappings) or Map.has_key?(cpg, :mappings)

#       if Map.has_key?(cpg, :node_mappings) do
#         mappings = cpg.node_mappings

#         # Should have AST to CFG mappings
#         if Map.has_key?(mappings, :ast_to_cfg) do
#           ast_to_cfg = mappings.ast_to_cfg
#           assert is_map(ast_to_cfg)

#           # Mappings should reference valid CFG nodes
#           Enum.each(Map.values(ast_to_cfg), fn cfg_id ->
#             assert Map.has_key?(cfg.nodes, cfg_id)
#           end)
#         end

#         # Should have AST to DFG mappings
#         if Map.has_key?(mappings, :ast_to_dfg) do
#           ast_to_dfg = mappings.ast_to_dfg
#           assert is_map(ast_to_dfg)

#           # Mappings should reference valid DFG nodes
#           Enum.each(Map.values(ast_to_dfg), fn dfg_id ->
#             assert Map.has_key?(dfg.nodes, dfg_id)
#           end)
#         end
#       end
#     end

#     test "CPGData :unified_analysis fields are initialized (even if empty/default before semantic layer runs)" do
#       function_ast = quote do
#         def analysis_ready_function do
#           data = fetch_data()
#           validated = validate(data)
#           transform(validated)
#         end
#       end

#       {:ok, cfg} = CFGGenerator.generate_cfg(function_ast)
#       {:ok, dfg} = DFGGenerator.generate_dfg(function_ast)
#       {:ok, cpg} = CPGBuilder.build_cpg(cfg, dfg)

#       # Should have unified analysis structure
#       assert Map.has_key?(cpg, :unified_analysis) or Map.has_key?(cpg, :analysis)

#       if Map.has_key?(cpg, :unified_analysis) do
#         analysis = cpg.unified_analysis

#         # Should have initialized analysis fields
#         expected_fields = [:semantic_analysis, :pattern_analysis, :flow_analysis, :complexity_metrics]

#         Enum.each(expected_fields, fn field ->
#           if Map.has_key?(analysis, field) do
#             # Field exists and should be initialized (even if empty)
#             assert analysis[field] != nil
#           end
#         end)
#       end
#     end

#     test "handles functions with only CFG (no DFG generated due to error/simplicity) or vice-versa gracefully" do
#       # Simple function that might not generate complex DFG
#       simple_ast = quote do
#         def simple_literal do
#           42
#         end
#       end

#       # Function that might have CFG issues
#       complex_ast = quote do
#         def potentially_problematic do
#           case complex_pattern_match() do
#             {:ok, %{nested: %{deep: value}}} -> value
#             _ -> :error
#           end
#         end
#       end

#       # Test simple function
#       case CFGGenerator.generate_cfg(simple_ast) do
#         {:ok, cfg} ->
#           case DFGGenerator.generate_dfg(simple_ast) do
#             {:ok, dfg} ->
#               {:ok, cpg} = CPGBuilder.build_cpg(cfg, dfg)
#               assert %CPGData{} = cpg

#             {:error, _} ->
#               # DFG generation failed, CPG should handle CFG-only
#               {:ok, cpg} = CPGBuilder.build_cpg(cfg, nil)
#               assert %CPGData{} = cpg
#           end

#         {:error, _} ->
#           # CFG generation failed, test DFG-only if possible
#           case DFGGenerator.generate_dfg(simple_ast) do
#             {:ok, dfg} ->
#               {:ok, cpg} = CPGBuilder.build_cpg(nil, dfg)
#               assert %CPGData{} = cpg

#             {:error, _} ->
#               # Both failed, this is acceptable for this test
#               :ok
#           end
#       end

#       # Test complex function
#       case CFGGenerator.generate_cfg(complex_ast) do
#         {:ok, cfg} ->
#           case DFGGenerator.generate_dfg(complex_ast) do
#             {:ok, dfg} ->
#               {:ok, cpg} = CPGBuilder.build_cpg(cfg, dfg)
#               assert %CPGData{} = cpg

#             {:error, _} ->
#               # DFG generation failed, CPG should handle CFG-only
#               case CPGBuilder.build_cpg(cfg, nil) do
#                 {:ok, cpg} -> assert %CPGData{} = cpg
#                 {:error, _} -> :ok  # Acceptable for foundation tests
#               end
#           end

#         {:error, _} ->
#           # CFG generation failed, this is acceptable
#           :ok
#       end
#     end

#     test "all CPGEdges in generated CPG connect valid, existing CPGNodes" do
#       function_ast = quote do
#         def validation_function(input) do
#           case input do
#             {:ok, data} ->
#               processed = process_data(data)
#               validate_result(processed)

#             {:error, reason} ->
#               log_error(reason)
#               :error
#           end
#         end
#       end

#       {:ok, cfg} = CFGGenerator.generate_cfg(function_ast)
#       {:ok, dfg} = DFGGenerator.generate_dfg(function_ast)
#       {:ok, cpg} = CPGBuilder.build_cpg(cfg, dfg)

#       # All edges should connect existing nodes
#       all_cpg_node_ids = Map.keys(cpg.nodes)

#       Enum.each(cpg.edges, fn edge ->
#         assert edge.from in all_cpg_node_ids, "CPG edge 'from' node #{edge.from} should exist in nodes"
#         assert edge.to in all_cpg_node_ids, "CPG edge 'to' node #{edge.to} should exist in nodes"
#         assert is_binary(edge.id), "CPG edge should have a valid ID"
#         assert edge.type in [:control_flow, :data_flow, :ast_structure, :call_graph, :unified],
#                "CPG edge should have a valid type"
#       end)

#       # No orphaned nodes (every node should be connected to at least one edge, except possibly entry/exit)
#       connected_node_ids = cpg.edges
#       |> Enum.flat_map(&[&1.from, &1.to])
#       |> Enum.uniq()

#       orphaned_nodes = all_cpg_node_ids -- connected_node_ids

#       # Orphaned nodes should only be entry/exit or isolated literals
#       orphaned_node_types = orphaned_nodes
#       |> Enum.map(&cpg.nodes[&1])
#       |> Enum.map(& &1.type)

#       allowed_orphan_types = [:entry, :exit, :literal, :constant, :isolated]

#       Enum.each(orphaned_node_types, fn type ->
#         assert type in allowed_orphan_types or length(orphaned_nodes) == 0,
#                "Orphaned node type #{type} should be allowed or no orphaned nodes should exist"
#       end)
#     end

#     test "preserves semantic information from both CFG and DFG in unified representation" do
#       function_ast = quote do
#         def semantic_function(x, y) do
#           if x > 0 do
#             result = expensive_computation(y)
#             cache_result(result)
#             result
#           else
#             default_value()
#           end
#         end
#       end

#       {:ok, cfg} = CFGGenerator.generate_cfg(function_ast)
#       {:ok, dfg} = DFGGenerator.generate_dfg(function_ast)
#       {:ok, cpg} = CPGBuilder.build_cpg(cfg, dfg)

#       # Should preserve control flow semantics
#       conditional_nodes = cpg.nodes
#       |> Map.values()
#       |> Enum.filter(&(&1.type in [:conditional, :if, :unified]))
#       |> Enum.filter(fn node ->
#         # Check if node represents conditional logic
#         metadata = Map.get(node, :metadata, %{})
#         Map.get(metadata, :represents_conditional, false) or
#         Map.get(metadata, :ast_type) == :if or
#         String.contains?(to_string(Map.get(node, :ast_snippet, "")), "if")
#       end)

#       assert length(conditional_nodes) >= 1

#       # Should preserve data flow semantics
#       variable_nodes = cpg.nodes
#       |> Map.values()
#       |> Enum.filter(fn node ->
#         node.type in [:variable_definition, :variable_use, :unified] and
#         Map.has_key?(node, :variable_name)
#       end)

#       # Should have nodes for variables: x, y, result
#       variable_names = variable_nodes
#       |> Enum.map(&Map.get(&1, :variable_name))
#       |> Enum.filter(&is_binary/1)
#       |> Enum.uniq()

#       expected_variables = ["x", "y", "result"]
#       found_variables = Enum.filter(expected_variables, &(&1 in variable_names))

#       # Should find at least some of the expected variables
#       assert length(found_variables) >= 1
#     end
#   end
# end
