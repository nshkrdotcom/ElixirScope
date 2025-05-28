Looking at the comprehensive documentation, I can see that the existing ElixirScope codebase already has a solid foundation with the Enhanced AST Repository, and the CPG_*.md documents represent the next evolutionary step - adding sophisticated graph algorithms and semantic analysis on top of the existing CPG infrastructure.

## Complete Implementation Guide for CPG Algorithmic Enhancement Layer

### Overview of Current State vs Target State

**Current State (v0.0.2 foundations):**
- ✅ Enhanced AST Repository with CPG generation
- ✅ Basic CFG, DFG, CPG data structures
- ✅ Node ID assignment and correlation
- ✅ Query infrastructure
- ✅ Pattern matching framework

**Target State (CPG Enhancements):**
- 🎯 Mathematical graph algorithms (CPGMath)
- 🎯 Semantic code-aware analysis (CPGSemantics)
- 🎯 Advanced pattern detection using graph properties
- 🎯 Query enhancements for algorithmic metrics
- 🎯 Performance optimizations for CPG operations
- 🎯 AI/ML feature extraction from graph analysis

### Implementation Strategy

#### Phase 1: Preliminary Context Setup

Before starting with the CPG_IMPLEMENTATION_PROMPTS.md, establish proper context:

**Initial Context Prompt:**
```
I'm working on enhancing ElixirScope's CPG (Code Property Graph) capabilities. The project already has:
1. Enhanced AST Repository with CPG generation (CPGData.t(), CPGNode.t(), CPGEdge.t() structures)
2. Query infrastructure (QueryBuilder, QueryExecutor)
3. Pattern matching framework
4. AI integration points

I need to implement the CPG Algorithmic Enhancement Layer following TDD. The enhancement includes:
- CPGMath: Graph algorithms (centrality, paths, SCCs, communities)
- CPGSemantics: Code-aware semantic analysis
- Query enhancements for graph metrics
- Advanced pattern detection

I have detailed design docs (CPG_*.md files) and will proceed with test-driven development. Please help me implement these features starting with the foundational tests.
```

#### Phase 2: TDD Test Structure

### Foundation Test Files to Create First

Let me write the foundational test files that should be created before implementation:

```elixir
# test/elixir_scope/ast_repository/enhanced/cpg_math_test.exs
defmodule ElixirScope.ASTRepository.Enhanced.CPGMathTest do
  use ExUnit.Case, async: true
  
  alias ElixirScope.ASTRepository.Enhanced.{CPGMath, CPGData, CPGNode, CPGEdge}
  alias ElixirScope.ASTRepository.TestDataGenerator
  
  describe "helper functions" do
    setup do
      # Create a simple test CPG
      nodes = %{
        "node_a" => %CPGNode{
          id: "node_a",
          ast_type: :function_def,
          ast_node_id: "ModuleA.func_a/1:def",
          metadata: %{line: 10}
        },
        "node_b" => %CPGNode{
          id: "node_b",
          ast_type: :function_def,
          ast_node_id: "ModuleA.func_b/2:def",
          metadata: %{line: 20}
        },
        "node_c" => %CPGNode{
          id: "node_c",
          ast_type: :function_def,
          ast_node_id: "ModuleA.func_c/0:def",
          metadata: %{line: 30}
        }
      }
      
      edges = [
        %CPGEdge{
          id: "edge_1",
          from_node_id: "node_a",
          to_node_id: "node_b",
          type: :call_graph,
          subtype: :direct_call,
          metadata: %{}
        },
        %CPGEdge{
          id: "edge_2",
          from_node_id: "node_b",
          to_node_id: "node_c",
          type: :call_graph,
          subtype: :direct_call,
          metadata: %{}
        },
        %CPGEdge{
          id: "edge_3",
          from_node_id: "node_c",
          to_node_id: "node_a",
          type: :data_flow,
          subtype: :return_value,
          metadata: %{}
        }
      ]
      
      cpg = %CPGData{
        version: 1,
        nodes: nodes,
        edges: edges,
        metadata: %{}
      }
      
      {:ok, cpg: cpg}
    end
    
    test "get_neighbors/3 returns outgoing neighbors", %{cpg: cpg} do
      assert {:ok, neighbors} = CPGMath.get_neighbors(cpg, "node_a", :out)
      assert neighbors == ["node_b"]
      
      assert {:ok, neighbors} = CPGMath.get_neighbors(cpg, "node_b", :out)
      assert neighbors == ["node_c"]
    end
    
    test "get_neighbors/3 returns incoming neighbors", %{cpg: cpg} do
      assert {:ok, neighbors} = CPGMath.get_neighbors(cpg, "node_b", :in)
      assert neighbors == ["node_a"]
      
      assert {:ok, neighbors} = CPGMath.get_neighbors(cpg, "node_a", :in)
      assert neighbors == ["node_c"]
    end
    
    test "get_neighbors/3 returns both directions", %{cpg: cpg} do
      assert {:ok, neighbors} = CPGMath.get_neighbors(cpg, "node_b", :both)
      assert Enum.sort(neighbors) == ["node_a", "node_c"]
    end
    
    test "get_neighbors/3 returns error for non-existent node", %{cpg: cpg} do
      assert {:error, :node_not_found} = CPGMath.get_neighbors(cpg, "node_x", :out)
    end
    
    test "get_edges/3 returns edge structures", %{cpg: cpg} do
      assert {:ok, edges} = CPGMath.get_edges(cpg, "node_a", :out)
      assert length(edges) == 1
      assert [%CPGEdge{from_node_id: "node_a", to_node_id: "node_b"}] = edges
    end
  end
  
  describe "strongly_connected_components/1" do
    test "identifies single-node SCCs in DAG" do
      # Create a DAG (no cycles)
      cpg = build_dag_cpg()
      
      assert {:ok, sccs} = CPGMath.strongly_connected_components(cpg)
      # Each node should be its own SCC in a DAG
      assert length(sccs) == map_size(cpg.nodes)
      assert Enum.all?(sccs, &(length(&1) == 1))
    end
    
    test "identifies multi-node SCC in cyclic graph", %{cpg: cpg} do
      # The setup CPG has a cycle: node_a -> node_b -> node_c -> node_a
      assert {:ok, sccs} = CPGMath.strongly_connected_components(cpg)
      assert length(sccs) == 1
      assert [scc] = sccs
      assert Enum.sort(scc) == ["node_a", "node_b", "node_c"]
    end
    
    test "handles disconnected components" do
      cpg = build_disconnected_cpg()
      
      assert {:ok, sccs} = CPGMath.strongly_connected_components(cpg)
      # Should have multiple SCCs for disconnected graph
      assert length(sccs) > 1
    end
  end
  
  describe "degree_centrality/2" do
    test "calculates total degree centrality", %{cpg: cpg} do
      assert {:ok, centrality_map} = CPGMath.degree_centrality(cpg)
      
      # Each node has degree 2 (1 in + 1 out) in our cycle
      assert centrality_map["node_a"] == centrality_map["node_b"]
      assert centrality_map["node_b"] == centrality_map["node_c"]
    end
    
    test "calculates in-degree centrality", %{cpg: cpg} do
      assert {:ok, centrality_map} = CPGMath.degree_centrality(cpg, direction: :in)
      
      # Each node has exactly 1 incoming edge
      assert centrality_map["node_a"] > 0
      assert centrality_map["node_b"] > 0
      assert centrality_map["node_c"] > 0
    end
    
    test "normalizes centrality scores", %{cpg: cpg} do
      assert {:ok, centrality_map} = CPGMath.degree_centrality(cpg, normalize: true)
      
      # Normalized scores should be between 0 and 1
      Enum.each(centrality_map, fn {_node_id, score} ->
        assert score >= 0.0 and score <= 1.0
      end)
    end
    
    test "handles nodes with no edges" do
      cpg = add_isolated_node(%{cpg: build_dag_cpg()})
      
      assert {:ok, centrality_map} = CPGMath.degree_centrality(cpg)
      assert centrality_map["isolated_node"] == 0.0
    end
  end
  
  describe "shortest_path/4" do
    test "finds shortest path in simple graph", %{cpg: cpg} do
      assert {:ok, path} = CPGMath.shortest_path(cpg, "node_a", "node_c")
      assert path == ["node_a", "node_b", "node_c"]
    end
    
    test "returns error when no path exists" do
      cpg = build_disconnected_cpg()
      
      assert {:error, :no_path_found} = CPGMath.shortest_path(cpg, "component1_node", "component2_node")
    end
    
    test "handles custom weight function", %{cpg: cpg} do
      # Weight function that makes direct paths expensive
      weight_fn = fn edge ->
        if edge.subtype == :direct_call, do: 10, else: 1
      end
      
      assert {:ok, path} = CPGMath.shortest_path(cpg, "node_a", "node_c", weight_function: weight_fn)
      # Might take a different path based on weights
      assert is_list(path)
      assert List.first(path) == "node_a"
      assert List.last(path) == "node_c"
    end
    
    test "respects max_depth option" do
      cpg = build_long_chain_cpg(10)
      
      assert {:ok, _path} = CPGMath.shortest_path(cpg, "node_0", "node_5", max_depth: 10)
      assert {:error, :max_depth_reached} = CPGMath.shortest_path(cpg, "node_0", "node_9", max_depth: 5)
    end
  end
  
  # Helper functions for building test CPGs
  defp build_dag_cpg do
    # Builds a simple DAG: A -> B -> C, A -> C
    nodes = %{
      "node_a" => %CPGNode{id: "node_a", ast_type: :function_def},
      "node_b" => %CPGNode{id: "node_b", ast_type: :function_def},
      "node_c" => %CPGNode{id: "node_c", ast_type: :function_def}
    }
    
    edges = [
      %CPGEdge{id: "e1", from_node_id: "node_a", to_node_id: "node_b", type: :call_graph},
      %CPGEdge{id: "e2", from_node_id: "node_b", to_node_id: "node_c", type: :call_graph},
      %CPGEdge{id: "e3", from_node_id: "node_a", to_node_id: "node_c", type: :call_graph}
    ]
    
    %CPGData{version: 1, nodes: nodes, edges: edges, metadata: %{}}
  end
  
  defp build_disconnected_cpg do
    # Builds a graph with two disconnected components
    nodes = %{
      "comp1_a" => %CPGNode{id: "comp1_a", ast_type: :function_def},
      "comp1_b" => %CPGNode{id: "comp1_b", ast_type: :function_def},
      "comp2_a" => %CPGNode{id: "comp2_a", ast_type: :function_def},
      "comp2_b" => %CPGNode{id: "comp2_b", ast_type: :function_def}
    }
    
    edges = [
      %CPGEdge{id: "e1", from_node_id: "comp1_a", to_node_id: "comp1_b", type: :call_graph},
      %CPGEdge{id: "e2", from_node_id: "comp2_a", to_node_id: "comp2_b", type: :call_graph}
    ]
    
    %CPGData{version: 1, nodes: nodes, edges: edges, metadata: %{}}
  end
  
  defp build_long_chain_cpg(length) do
    # Builds a linear chain: node_0 -> node_1 -> ... -> node_n
    nodes = Enum.reduce(0..(length-1), %{}, fn i, acc ->
      Map.put(acc, "node_#{i}", %CPGNode{id: "node_#{i}", ast_type: :function_def})
    end)
    
    edges = Enum.map(0..(length-2), fn i ->
      %CPGEdge{
        id: "edge_#{i}",
        from_node_id: "node_#{i}",
        to_node_id: "node_#{i+1}",
        type: :call_graph
      }
    end)
    
    %CPGData{version: 1, nodes: nodes, edges: edges, metadata: %{}}
  end
  
  defp add_isolated_node(%{cpg: cpg}) do
    new_node = %CPGNode{id: "isolated_node", ast_type: :function_def}
    %{cpg | nodes: Map.put(cpg.nodes, "isolated_node", new_node)}
  end
end
```

```elixir
# test/elixir_scope/ast_repository/enhanced/cpg_semantics_test.exs
defmodule ElixirScope.ASTRepository.Enhanced.CPGSemanticsTest do
  use ExUnit.Case, async: true
  
  alias ElixirScope.ASTRepository.Enhanced.{CPGSemantics, CPGData, CPGNode, CPGEdge, CPGMath}
  
  describe "semantic edge weight calculation" do
    setup do
      cpg = build_semantic_test_cpg()
      {:ok, cpg: cpg}
    end
    
    test "calculates weight based on node types", %{cpg: cpg} do
      edge = %CPGEdge{
        from_node_id: "io_func",
        to_node_id: "db_func",
        type: :call_graph,
        subtype: :direct_call
      }
      
      context_opts = %{
        goal: :performance_impact,
        weights: %{
          node_type_penalties: %{io_operation: 5.0, db_operation: 10.0},
          edge_type_costs: %{direct_call: 1.0}
        }
      }
      
      # This would be a private function, but we test the concept
      # weight = CPGSemantics.calculate_semantic_edge_weight(edge, cpg, context_opts)
      # assert weight > 1.0  # Should be penalized for I/O and DB operations
    end
  end
  
  describe "semantic_critical_path/4" do
    test "finds path with highest semantic cost", %{cpg: cpg} do
      cost_factors = %{
        complexity: 1.0,
        io_penalty: 5.0,
        db_penalty: 10.0
      }
      
      assert {:ok, path, details} = CPGSemantics.semantic_critical_path(
        cpg, 
        "entry_func", 
        "exit_func",
        cost_factors: cost_factors
      )
      
      assert is_list(path)
      assert List.first(path) == "entry_func"
      assert List.last(path) == "exit_func"
      assert details.total_cost > 0
      assert is_map(details.contributing_factors)
    end
    
    test "respects path_type option" do
      cpg = build_multi_edge_type_cpg()
      
      # Should only follow execution paths
      assert {:ok, exec_path, _} = CPGSemantics.semantic_critical_path(
        cpg,
        "func_a",
        "func_c",
        path_type: :execution
      )
      
      # Should only follow data dependency paths  
      assert {:ok, data_path, _} = CPGSemantics.semantic_critical_path(
        cpg,
        "func_a", 
        "func_c",
        path_type: :data_dependency
      )
      
      # Paths might be different
      assert exec_path != data_path or length(exec_path) != length(data_path)
    end
  end
  
  describe "dependency_impact_analysis/3" do
    test "identifies downstream impact", %{cpg: cpg} do
      assert {:ok, impact_report} = CPGSemantics.dependency_impact_analysis(
        cpg,
        "core_func",
        depth: 3
      )
      
      assert is_list(impact_report.downstream_nodes)
      assert length(impact_report.downstream_nodes) > 0
      assert impact_report.direct_impact_score > 0
      assert impact_report.transitive_impact_score >= impact_report.direct_impact_score
    end
    
    test "respects dependency type filters" do
      cpg = build_multi_edge_type_cpg()
      
      assert {:ok, call_impact} = CPGSemantics.dependency_impact_analysis(
        cpg,
        "func_a",
        dependency_types: [:call]
      )
      
      assert {:ok, data_impact} = CPGSemantics.dependency_impact_analysis(
        cpg,
        "func_a", 
        dependency_types: [:data]
      )
      
      # Different dependency types should yield different impacts
      assert call_impact.downstream_nodes != data_impact.downstream_nodes
    end
  end
  
  describe "detect_architectural_smells/2" do
    test "detects god objects based on centrality" do
      cpg = build_god_object_cpg()
      
      assert {:ok, smells_report} = CPGSemantics.detect_architectural_smells(
        cpg,
        smells_to_detect: [:god_object]
      )
      
      assert Map.has_key?(smells_report, :god_object)
      assert length(smells_report.god_object) > 0
      
      god_object = hd(smells_report.god_object)
      assert god_object.node_id == "central_hub_func"
      assert god_object.evidence.centrality_scores.degree > 0.8
      assert god_object.severity in [:high, :medium]
    end
    
    test "detects cyclic dependencies" do
      cpg = build_cyclic_dependency_cpg()
      
      assert {:ok, smells_report} = CPGSemantics.detect_architectural_smells(
        cpg,
        smells_to_detect: [:cyclic_dependencies]
      )
      
      assert Map.has_key?(smells_report, :cyclic_dependencies)
      cycles = smells_report.cyclic_dependencies
      assert length(cycles) > 0
      
      # Should identify the cycle
      cycle = hd(cycles)
      assert length(cycle.nodes_in_cycle) >= 2
    end
  end
  
  describe "identify_code_communities/2" do
    test "enriches community detection with semantic info" do
      cpg = build_modular_cpg()
      
      assert {:ok, communities_report} = CPGSemantics.identify_code_communities(cpg)
      
      assert is_list(communities_report)
      assert length(communities_report) > 1
      
      community = hd(communities_report)
      assert Map.has_key?(community, :community_id)
      assert Map.has_key?(community, :member_nodes)
      assert Map.has_key?(community, :dominant_node_types)
      assert Map.has_key?(community, :description_summary)
      assert is_binary(community.description_summary)
    end
    
    test "uses specified algorithm" do
      cpg = build_modular_cpg()
      
      assert {:ok, louvain_communities} = CPGSemantics.identify_code_communities(
        cpg,
        algorithm: :louvain
      )
      
      assert {:ok, label_prop_communities} = CPGSemantics.identify_code_communities(
        cpg,
        algorithm: :label_propagation  
      )
      
      # Different algorithms might produce different communities
      assert length(louvain_communities) > 0
      assert length(label_prop_communities) > 0
    end
  end
  
  # Helper functions for building semantic test CPGs
  defp build_semantic_test_cpg do
    nodes = %{
      "entry_func" => %CPGNode{
        id: "entry_func",
        ast_type: :function_def,
        metadata: %{complexity_score: 2}
      },
      "io_func" => %CPGNode{
        id: "io_func", 
        ast_type: :function_def,
        metadata: %{node_type: :io_operation, complexity_score: 5}
      },
      "db_func" => %CPGNode{
        id: "db_func",
        ast_type: :function_def,
        metadata: %{node_type: :db_operation, complexity_score: 8}
      },
      "core_func" => %CPGNode{
        id: "core_func",
        ast_type: :function_def,
        metadata: %{complexity_score: 10}
      },
      "exit_func" => %CPGNode{
        id: "exit_func",
        ast_type: :function_def,
        metadata: %{complexity_score: 1}
      }
    }
    
    edges = [
      %CPGEdge{
        id: "e1",
        from_node_id: "entry_func",
        to_node_id: "io_func",
        type: :call_graph
      },
      %CPGEdge{
        id: "e2", 
        from_node_id: "io_func",
        to_node_id: "db_func",
        type: :call_graph
      },
      %CPGEdge{
        id: "e3",
        from_node_id: "db_func",
        to_node_id: "core_func",
        type: :call_graph
      },
      %CPGEdge{
        id: "e4",
        from_node_id: "core_func",
        to_node_id: "exit_func",
        type: :call_graph
      }
    ]
    
    %CPGData{
      version: 1,
      nodes: nodes,
      edges: edges,
      metadata: %{}
    }
  end
  
  defp build_multi_edge_type_cpg do
    # CPG with different edge types (call vs data flow)
    nodes = %{
      "func_a" => %CPGNode{id: "func_a", ast_type: :function_def},
      "func_b" => %CPGNode{id: "func_b", ast_type: :function_def},
      "func_c" => %CPGNode{id: "func_c", ast_type: :function_def}
    }
    
    edges = [
      %CPGEdge{
        id: "call_1",
        from_node_id: "func_a",
        to_node_id: "func_b",
        type: :call_graph
      },
      %CPGEdge{
        id: "data_1",
        from_node_id: "func_a",
        to_node_id: "func_c",
        type: :data_flow
      },
      %CPGEdge{
        id: "call_2",
        from_node_id: "func_b",
        to_node_id: "func_c",
        type: :call_graph
      }
    ]
    
    %CPGData{version: 1, nodes: nodes, edges: edges, metadata: %{}}
  end
  
  defp build_god_object_cpg do
    # One central hub connected to many other nodes
    hub = %CPGNode{id: "central_hub_func", ast_type: :function_def}
    
    peripherals = Enum.reduce(1..10, %{}, fn i, acc ->
      Map.put(acc, "peripheral_#{i}", %CPGNode{
        id: "peripheral_#{i}",
        ast_type: :function_def
      })
    end)
    
    nodes = Map.put(peripherals, "central_hub_func", hub)
    
    # Hub is connected to all peripherals
    edges = Enum.flat_map(1..10, fn i ->
      [
        %CPGEdge{
          id: "to_hub_#{i}",
          from_node_id: "peripheral_#{i}",
          to_node_id: "central_hub_func",
          type: :call_graph
        },
        %CPGEdge{
          id: "from_hub_#{i}",
          from_node_id: "central_hub_func", 
          to_node_id: "peripheral_#{i}",
          type: :call_graph
        }
      ]
    end)
    
    %CPGData{version: 1, nodes: nodes, edges: edges, metadata: %{}}
  end
  
  defp build_cyclic_dependency_cpg do
    # A -> B -> C -> A cycle
    nodes = %{
      "module_a" => %CPGNode{id: "module_a", ast_type: :module_def},
      "module_b" => %CPGNode{id: "module_b", ast_type: :module_def},
      "module_c" => %CPGNode{id: "module_c", ast_type: :module_def}
    }
    
    edges = [
      %CPGEdge{
        id: "a_to_b",
        from_node_id: "module_a",
        to_node_id: "module_b",
        type: :module_dependency
      },
      %CPGEdge{
        id: "b_to_c",
        from_node_id: "module_b",
        to_node_id: "module_c",
        type: :module_dependency
      },
      %CPGEdge{
        id: "c_to_a",
        from_node_id: "module_c",
        to_node_id: "module_a",
        type: :module_dependency
      }
    ]
    
    %CPGData{version: 1, nodes: nodes, edges: edges, metadata: %{}}
  end
  
  defp build_modular_cpg do
    # Two distinct communities with minimal cross-connections
    community1_nodes = %{
      "c1_func1" => %CPGNode{id: "c1_func1", ast_type: :function_def},
      "c1_func2" => %CPGNode{id: "c1_func2", ast_type: :function_def},
      "c1_func3" => %CPGNode{id: "c1_func3", ast_type: :function_def}
    }
    
    community2_nodes = %{
      "c2_func1" => %CPGNode{id: "c2_func1", ast_type: :function_def},
      "c2_func2" => %CPGNode{id: "c2_func2", ast_type: :function_def},
      "c2_func3" => %CPGNode{id: "c2_func3", ast_type: :function_def}
    }
    
    nodes = Map.merge(community1_nodes, community2_nodes)
    
    # Dense connections within communities
    community1_edges = [
      %CPGEdge{id: "c1_e1", from_node_id: "c1_func1", to_node_id: "c1_func2", type: :call_graph},
      %CPGEdge{id: "c1_e2", from_node_id: "c1_func2", to_node_id: "c1_func3", type: :call_graph},
      %CPGEdge{id: "c1_e3", from_node_id: "c1_func3", to_node_id: "c1_func1", type: :call_graph}
    ]
    
    community2_edges = [
      %CPGEdge{id: "c2_e1", from_node_id: "c2_func1", to_node_id: "c2_func2", type: :call_graph},
      %CPGEdge{id: "c2_e2", from_node_id: "c2_func2", to_node_id: "c2_func3", type: :call_graph},
      %CPGEdge{id: "c2_e3", from_node_id: "c2_func3", to_node_id: "c2_func1", type: :call_graph}
    ]
    
    # One cross-community edge
    bridge_edge = %CPGEdge{
      id: "bridge",
      from_node_id: "c1_func1",
      to_node_id: "c2_func1",
      type: :call_graph
    }
    
    edges = community1_edges ++ community2_edges ++ [bridge_edge]
    
    %CPGData{version: 1, nodes: nodes, edges: edges, metadata: %{}}
  end
end
```

```elixir
# test/elixir_scope/ast_repository/enhanced/cpg_query_integration_test.exs
defmodule ElixirScope.ASTRepository.Enhanced.CPGQueryIntegrationTest do
  use ExUnit.Case, async: false
  
  alias ElixirScope.ASTRepository.{QueryBuilder, EnhancedRepository}
  alias ElixirScope.ASTRepository.Enhanced.{CPGMath, CPGSemantics}
  
  setup do
    # Start the enhanced repository
    {:ok, repo} = EnhancedRepository.start_link()
    
    # Populate with test data that includes CPG
    populate_test_repository(repo)
    
    on_exit(fn ->
      if Process.alive?(repo), do: GenServer.stop(repo)
    end)
    
    {:ok, repo: repo}
  end
  
  describe "querying with CPG metrics" do
    test "filters functions by centrality scores", %{repo: repo} do
      query_spec = %{
        select: [:module_name, :function_name, :arity, :centrality_betweenness],
        from: :functions,
        where: [
          {:centrality_betweenness, :gt, 0.5}
        ],
        order_by: {:desc, :centrality_betweenness}
      }
      
      assert {:ok, results} = QueryBuilder.execute_query(repo, query_spec)
      assert is_list(results.data)
      
      # All results should have high centrality
      Enum.each(results.data, fn func ->
        assert func.centrality_betweenness > 0.5
      end)
      
      # Should be ordered by centrality descending
      centralities = Enum.map(results.data, & &1.centrality_betweenness)
      assert centralities == Enum.sort(centralities, :desc)
    end
    
    test "filters by community membership", %{repo: repo} do
      query_spec = %{
        select: [:module_name, :function_name, :community_id],
        from: :functions,
        where: [
          {:community_id, :eq, 1}
        ]
      }
      
      assert {:ok, results} = QueryBuilder.execute_query(repo, query_spec)
      assert Enum.all?(results.data, &(&1.community_id == 1))
    end
    
    test "complex query with multiple CPG conditions", %{repo: repo} do
      query_spec = %{
        select: [:module_name, :function_name, :centrality_degree, :community_id],
        from: :functions,
        where: [
          {:and, [
            {:centrality_degree, :gt, 5},
            {:community_id, :in, [1, 2, 3]},
            {:lines_of_code, :gt, 20}
          ]}
        ]
      }
      
      assert {:ok, results} = QueryBuilder.execute_query(repo, query_spec)
      
      Enum.each(results.data, fn func ->
        assert func.centrality_degree > 5
        assert func.community_id in [1, 2, 3]
        assert func.lines_of_code > 20
      end)
    end
  end
  
  describe "new query types for CPG analysis" do
    test "impact analysis query", %{repo: repo} do
      query = %{
        type: :impact_analysis,
        params: %{
          target_node_id: "MyModule.critical_function/2:def",
          depth: 3,
          dependency_types: [:call, :data]
        }
      }
      
      assert {:ok, impact_report} = EnhancedRepository.query_analysis(:impact_analysis, query.params)
      
      assert Map.has_key?(impact_report, :downstream_nodes)
      assert Map.has_key?(impact_report, :upstream_nodes)
      assert Map.has_key?(impact_report, :direct_impact_score)
      assert Map.has_key?(impact_report, :transitive_impact_score)
      assert is_list(impact_report.affected_communities)
    end
    
    test "architectural smells detection query", %{repo: repo} do
      query = %{
        type: :architectural_smells_detection,
        params: %{
          smells_to_detect: [:god_object, :shotgun_surgery],
          centrality_thresholds: %{
            degree: 50,
            betweenness: 0.7
          }
        }
      }
      
      assert {:ok, smells_report} = EnhancedRepository.query_analysis(:architectural_smells, query.params)
      
      assert is_map(smells_report)
      # Should have results for requested smell types
      assert Map.has_key?(smells_report, :god_object) or Map.has_key?(smells_report, :shotgun_surgery)
    end
    
    test "critical path finding query", %{repo: repo} do
      query = %{
        type: :critical_path_finding,
        params: %{
          start_node_id: "MyModule.entry_point/0:def",
          end_node_id: "MyModule.exit_point/1:def",
          path_type: :execution,
          cost_factors: %{
            complexity: 1.0,
            io_penalty: 5.0
          }
        }
      }
      
      assert {:ok, path_result} = EnhancedRepository.query_analysis(:critical_path, query.params)
      
      assert Map.has_key?(path_result, :path)
      assert Map.has_key?(path_result, :total_cost)
      assert Map.has_key?(path_result, :bottleneck_nodes)
      assert is_list(path_result.path)
    end
  end
  
  describe "on-demand CPG metric computation" do
    test "computes centrality on first access", %{repo: repo} do
      # Query for a function that hasn't had centrality computed yet
      query_spec = %{
        select: [:module_name, :function_name, :centrality_pagerank],
        from: :functions,
        where: [
          {:module_name, :eq, TestModule}
        ],
        limit: 1
      }
      
      # First query should trigger computation
      {time1, {:ok, result1}} = :timer.tc(fn ->
        QueryBuilder.execute_query(repo, query_spec)
      end)
      
      assert length(result1.data) == 1
      func = hd(result1.data)
      assert is_float(func.centrality_pagerank)
      
      # Second query should use cached result and be faster
      {time2, {:ok, result2}} = :timer.tc(fn ->
        QueryBuilder.execute_query(repo, query_spec)
      end)
      
      assert result2.data == result1.data
      assert time2 < time1 * 0.5  # Should be at least 2x faster
    end
  end
  
  # Helper to populate test repository with CPG data
  defp populate_test_repository(repo) do
    # Create test modules with various complexity patterns
    
    # Module with a "god function"
    god_module_ast = quote do
      defmodule GodModule do
        # This function calls many others - high centrality
        def god_function(data) do
          data
          |> process_step1()
          |> process_step2()
          |> process_step3()
          |> validate_data()
          |> transform_data()
          |> persist_data()
          |> notify_systems()
          |> log_results()
        end
        
        def process_step1(data), do: data
        def process_step2(data), do: data
        def process_step3(data), do: data
        def validate_data(data), do: data
        def transform_data(data), do: data
        def persist_data(data), do: data
        def notify_systems(data), do: data
        def log_results(data), do: data
      end
    end
    
    # Module with cyclic dependencies
    cyclic_module_ast = quote do
      defmodule CyclicModule do
        def func_a(x) do
          if x > 0, do: func_b(x - 1), else: 0
        end
        
        def func_b(x) do
          if x > 0, do: func_c(x - 1), else: 0
        end
        
        def func_c(x) do
          if x > 0, do: func_a(x - 1), else: 0
        end
      end
    end
    
    # Well-structured modular code
    modular_ast = quote do
      defmodule ModularCode do
        # Community 1: Data processing
        def parse_input(raw), do: {:ok, raw}
        def validate_input({:ok, data}), do: {:ok, data}
        def sanitize_input({:ok, data}), do: {:ok, data}
        
        # Community 2: Business logic
        def calculate_result(data), do: data * 2
        def apply_rules(data), do: data
        def generate_output(data), do: data
      end
    end
    
    # Store modules with CPG generation
    EnhancedRepository.store_enhanced_module(GodModule, god_module_ast)
    EnhancedRepository.store_enhanced_module(CyclicModule, cyclic_module_ast)
    EnhancedRepository.store_enhanced_module(ModularCode, modular_ast)
    
    # Ensure CPGs are generated
    EnhancedRepository.get_cpg(GodModule, :god_function, 1)
    EnhancedRepository.get_cpg(CyclicModule, :func_a, 1)
    EnhancedRepository.get_cpg(ModularCode, :parse_input, 1)
  end
end
```

```elixir
# test/elixir_scope/ast_repository/enhanced/cpg_pattern_matcher_integration_test.exs
defmodule ElixirScope.ASTRepository.Enhanced.CPGPatternMatcherIntegrationTest do
  use ExUnit.Case, async: false
  
  alias ElixirScope.ASTRepository.{PatternMatcher, EnhancedRepository}
  alias ElixirScope.ASTRepository.Enhanced.{CPGMath, CPGSemantics}
  
  setup do
    {:ok, repo} = EnhancedRepository.start_link()
    {:ok, matcher} = PatternMatcher.start_link()
    
    # Populate with code that exhibits various patterns
    populate_patterns_test_data(repo)
    
    on_exit(fn ->
      if Process.alive?(repo), do: GenServer.stop(repo)
      if Process.alive?(matcher), do: GenServer.stop(matcher)
    end)
    
    {:ok, repo: repo, matcher: matcher}
  end
  
  describe "god object detection with CPG" do
    test "detects god functions using centrality metrics", %{repo: repo} do
      # Register enhanced god function pattern
      pattern_spec = %{
        pattern_type: :anti_pattern,
        pattern_name: :god_function_cpg,
        confidence_threshold: 0.7
      }
      
      assert {:ok, matches} = PatternMatcher.match_anti_pattern(repo, pattern_spec)
      
      # Should detect the god function
      assert length(matches) > 0
      
      god_match = Enum.find(matches, &(&1.pattern_name == :god_function_cpg))
      assert god_match != nil
      assert god_match.confidence >= 0.7
      assert god_match.entity_type == :function
      
      # Check that evidence includes CPG metrics
      evidence = god_match.evidence
      assert Map.has_key?(evidence, :centrality_scores)
      assert evidence.centrality_scores.betweenness > 0.7
      assert evidence.centrality_scores.degree > 0.8
    end
    
    test "combines AST and CPG rules for higher confidence", %{repo: repo} do
      # Pattern with both AST rules (high LoC) and CPG rules (high centrality)
      pattern_spec = %{
        pattern_type: :anti_pattern,
        pattern_name: :god_function_combined,
        confidence_threshold: 0.8
      }
      
      assert {:ok, matches} = PatternMatcher.match_anti_pattern(repo, pattern_spec)
      
      # Functions matching both criteria should have higher confidence
      high_confidence_matches = Enum.filter(matches, &(&1.confidence >= 0.9))
      assert length(high_confidence_matches) > 0
    end
  end
  
  describe "shotgun surgery detection" do
    test "identifies functions with high downstream impact", %{repo: repo} do
      pattern_spec = %{
        pattern_type: :anti_pattern,
        pattern_name: :shotgun_surgery,
        confidence_threshold: 0.6
      }
      
      assert {:ok, matches} = PatternMatcher.match_anti_pattern(repo, pattern_spec)
      
      shotgun_matches = Enum.filter(matches, &(&1.pattern_name == :shotgun_surgery))
      assert length(shotgun_matches) > 0
      
      # Check evidence includes impact analysis
      match = hd(shotgun_matches)
      assert Map.has_key?(match.evidence, :impact_analysis)
      assert match.evidence.impact_analysis.affected_communities > 2
      assert length(match.evidence.impact_analysis.downstream_nodes) > 5
    end
  end
  
  describe "architectural pattern detection" do
    test "identifies well-encapsulated modules using community detection", %{repo: repo} do
      pattern_spec = %{
        pattern_type: :behavioral_pattern,
        pattern_name: :well_encapsulated_module,
        confidence_threshold: 0.7
      }
      
      assert {:ok, matches} = PatternMatcher.match_behavioral_pattern(repo, pattern_spec)
      
      # Should find modules with high cohesion
      encapsulated = Enum.filter(matches, &(&1.pattern_name == :well_encapsulated_module))
      assert length(encapsulated) > 0
      
      match = hd(encapsulated)
      assert match.evidence.cohesion_score > 0.7
      assert match.evidence.inter_community_edges < 3
    end
    
    test "detects circular dependencies using SCCs", %{repo: repo} do
      pattern_spec = %{
        pattern_type: :anti_pattern,
        pattern_name: :circular_dependency,
        confidence_threshold: 0.9
      }
      
      assert {:ok, matches} = PatternMatcher.match_anti_pattern(repo, pattern_spec)
      
      circular_matches = Enum.filter(matches, &(&1.pattern_name == :circular_dependency))
      assert length(circular_matches) > 0
      
      match = hd(circular_matches)
      assert match.confidence >= 0.9  # High confidence for structural property
      assert length(match.evidence.scc_nodes) >= 2
    end
  end
  
  # Helper to create test code with various patterns
  defp populate_patterns_test_data(repo) do
    # God function example
    god_function_ast = quote do
      defmodule ControllerHub do
        # High centrality - orchestrates everything
        def process_request(conn, params) do
          user = authenticate_user(conn)
          data = validate_params(params)
          
          result = 
            data
            |> fetch_related_data()
            |> apply_business_rules()
            |> calculate_metrics()
            |> generate_report()
            |> send_notifications()
            |> log_activity()
            |> cache_results()
          
          render_response(conn, result)
        end
        
        # All these functions are called by process_request
        def authenticate_user(conn), do: %{}
        def validate_params(params), do: params
        def fetch_related_data(data), do: data
        def apply_business_rules(data), do: data
        def calculate_metrics(data), do: data
        def generate_report(data), do: data
        def send_notifications(data), do: data
        def log_activity(data), do: data
        def cache_results(data), do: data
        def render_response(conn, data), do: conn
      end
    end
    
    # Shotgun surgery - changes here affect many places
    shotgun_ast = quote do
      defmodule DataSchema do
        def validate_field(field, value) do
          # This is called by many modules across communities
          case field do
            :email -> validate_email(value)
            :phone -> validate_phone(value)
            :age -> validate_age(value)
            _ -> {:error, :unknown_field}
          end
        end
        
        defp validate_email(email), do: {:ok, email}
        defp validate_phone(phone), do: {:ok, phone}
        defp validate_age(age), do: {:ok, age}
      end
    end
    
    # Circular dependency
    circular_ast = quote do
      defmodule CircularA do
        def process(x) do
          CircularB.transform(x)
        end
        
        def helper(x), do: x * 2
      end
      
      defmodule CircularB do
        def transform(x) do
          CircularC.compute(x)
        end
        
        def utility(x), do: x + 1
      end
      
      defmodule CircularC do
        def compute(x) do
          CircularA.helper(x)  # Creates cycle
        end
      end
    end
    
    # Well encapsulated module
    encapsulated_ast = quote do
      defmodule WellEncapsulated do
        # High internal cohesion, low external coupling
        def public_api(input) do
          input
          |> internal_step1()
          |> internal_step2()
          |> internal_step3()
        end
        
        defp internal_step1(data) do
          internal_helper(data, :step1)
        end
        
        defp internal_step2(data) do
          internal_helper(data, :step2)
        end
        
        defp internal_step3(data) do
          internal_helper(data, :step3)
        end
        
        defp internal_helper(data, step) do
          # All internal, no external dependencies
          Map.put(data, step, true)
        end
      end
    end
    
    # Store all test modules
    EnhancedRepository.store_enhanced_module(ControllerHub, god_function_ast)
    EnhancedRepository.store_enhanced_module(DataSchema, shotgun_ast)
    EnhancedRepository.store_enhanced_module(CircularA, circular_ast)
    EnhancedRepository.store_enhanced_module(CircularB, circular_ast)
    EnhancedRepository.store_enhanced_module(CircularC, circular_ast)
    EnhancedRepository.store_enhanced_module(WellEncapsulated, encapsulated_ast)
  end
end
```

### Implementation Order and Strategy

#### Phase 3: Implementation Order

1. **Foundation (Week 1)**
   - Implement `CPGMath` helper functions (`get_neighbors`, `get_edges`)
   - Implement basic graph algorithms (SCCs, degree centrality)
   - All tests should pass for these basic functions

2. **Core Algorithms (Week 2)**
   - Complete `CPGMath` with pathfinding and remaining centrality measures
   - Start `CPGSemantics` with semantic weight calculation
   - Implement critical path analysis

3. **Integration (Week 3)**
   - Update `QueryBuilder` for new filter conditions
   - Enhance `EnhancedRepository` query handling
   - Implement on-demand computation and caching

4. **Advanced Features (Week 4)**
   - Complete `CPGSemantics` architectural analysis
   - Enhance `PatternMatcher` with CPG rules
   - Implement performance optimizations

### Enhanced Prompting Strategy

#### For Each Implementation Session:

1. **Context Setting Prompt:**
```
I'm implementing [specific module/function] for the CPG Algorithmic Enhancement Layer. 
Current status:
- [What's already implemented]
- [What test is failing/next to implement]
The failing test expects: [specific behavior]
Please help implement this following TDD - make the test pass with minimal correct implementation.
```

2. **Algorithm Implementation Prompt:**
```
I need to implement [algorithm name] for CPGMath. Here's the test that needs to pass:
[paste specific test]

The algorithm should:
- Work with CPGData.t() structure (nodes as map, edges as list)
- Follow the API defined in CPG_MATH_API.md
- Return the expected format

Please provide the implementation.
```

3. **Integration Prompt:**
```
I'm integrating CPG metrics into [QueryBuilder/PatternMatcher/etc].
Current code: [paste relevant section]
Need to add: [specific feature from CPG_QUERY_ENHANCEMENTS.md]
Tests expecting: [paste failing integration test]

Please show the changes needed.
```

### Key Considerations for TDD Implementation:

1. **Start Small**: Each test should focus on one specific behavior
2. **Mock External Dependencies**: For integration tests, mock the algorithmic computations initially
3. **Incremental Complexity**: Start with simple graphs in tests, add complexity gradually
4. **Performance Tests**: Add performance benchmarks as separate test suite
5. **Property-Based Testing**: Consider adding property tests for graph algorithms

### Additional Test Helpers to Create:

```elixir
# test/support/cpg_test_helpers.ex
defmodule ElixirScope.CPGTestHelpers do
  alias ElixirScope.ASTRepository.Enhanced.{CPGData, CPGNode, CPGEdge}
  
  def simple_cpg(opts \\ []) do
    # Generates various simple CPG patterns for testing
  end
  
  def random_cpg(node_count, edge_probability \\ 0.3) do
    # Generates random CPGs for property testing
  end
  
  def assert_valid_centrality_scores(scores) do
    # Validates centrality score properties
  end
  
  def assert_valid_path(path, start_node, end_node) do
    # Validates path properties
  end
end
```

This approach ensures that:
1. Each feature is thoroughly tested before implementation
2. The implementation is driven by actual requirements
3. Integration points are clearly defined
4. Performance characteristics are measurable
5. The enhancement layer integrates smoothly with existing code

The CPG_IMPLEMENTATION_PROMPTS.md provides good starting points, but should be enhanced with:
- Specific test context
- Current implementation state
- Clear success criteria from the failing tests
- Integration context from existing modules