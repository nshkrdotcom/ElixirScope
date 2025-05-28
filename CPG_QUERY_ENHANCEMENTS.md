# CPG Query Enhancements Documentation

**`CPG_QUERY_ENHANCEMENTS.MD`**

## 1. Overview

This document details the enhancements to ElixirScope's query capabilities, specifically how `ElixirScope.ASTRepository.QueryBuilder` and the query execution mechanisms (e.g., `ElixirScope.ASTRepository.QueryExecutor` or direct `EnhancedRepository` methods) are extended to leverage the new CPG Algorithmic Enhancement Layer.

These enhancements allow for more sophisticated queries that go beyond simple AST property lookups, incorporating results from graph algorithms and semantic analysis.

## 2. Enhanced Query Specification (`QueryBuilder`)

The `ElixirScope.ASTRepository.QueryBuilder.query_t()` structure and the `query_spec` map used by `QueryBuilder.build_query/1` and `QueryBuilder.execute_query/2` will be extended to support new clauses and filters.

### 2.1. New `FROM` Targets

While `FROM :functions` and `FROM :modules` remain, new conceptual targets might emerge based on CPG entities or analysis results:
*   `FROM :cpg_nodes`: Allows querying individual CPG nodes directly.
*   `FROM :cpg_edges`: Allows querying CPG edges.
*   `FROM :communities`: Allows querying detected code communities.
*   `FROM :critical_paths`: Allows querying identified critical paths.

**Example:**
```elixir
query_spec = %{
  select: [:node_id, :type, :centrality_score],
  from: :cpg_nodes, # Querying CPG nodes
  where: [{:centrality_score, :gt, 0.5, :betweenness}]
}
```

### 2.2. New `WHERE` Condition Operators and Fields

New fields derived from CPG algorithms can be used in `WHERE` clauses.

*   **Centrality Scores:**
    *   `{:centrality_degree, :gt, 10}`
    *   `{:centrality_betweenness, :gte, 0.2}`
    *   `{:centrality_closeness, :lt, 0.5}`
    *   `{:centrality_pagerank, :gt, 0.01}`
*   **Community Membership:**
    *   `{:community_id, :eq, 5}`
    *   `{:in_community_with, "other_node_id"}`
*   **Path Properties (when querying paths):**
    *   `{:path_length, :gt, 10}`
    *   `{:path_semantic_cost, :lt, 50.0}`
    *   `{:path_contains_node_type, :io_call}`
*   **Dependency/Impact Metrics:**
    *   `{:downstream_impact_count, :gt, 20}` (Number of nodes affected if this node changes)
    *   `{:coupling_strength_with, "another_node_id", :gt, 0.7}`
*   **Architectural Smells:**
    *   `{:has_smell, :god_object}`
    *   `{:has_smell, :cyclic_dependency, with_node: "Module.A"}`

**New Operators:**
*   `:has_smell`: Checks for a specific architectural smell.
*   `:in_community_with`: Checks if a node is in the same community as another.
*   `:path_contains_node_type`: For path queries, checks if path contains a node of a certain type.

**Example:**
```elixir
# Find functions with high betweenness centrality that are part of community 3
query_spec = %{
  select: [:module_name, :function_name, :arity, :centrality_betweenness],
  from: :functions, # Or :cpg_nodes if centrality is stored per CPG node
  where: [
    {:centrality_betweenness, :gt, 0.6},
    {:community_id, :eq, 3}
  ],
  order_by: {:desc, :centrality_betweenness}
}
```

### 2.3. New `SELECT` Fields

The `SELECT` clause can retrieve new metrics derived from CPG algorithms.
*   `:centrality_degree`, `:centrality_betweenness`, `:centrality_closeness`, `:centrality_pagerank`
*   `:community_id`
*   `:semantic_path_cost` (when querying paths)
*   `:impact_score` (when querying nodes for impact)
*   `:cohesion_score` (when querying modules)
*   `:coupling_scores` (a map of couplings when querying nodes/modules)

**Example:**
```elixir
query_spec = %{
  select: [
    :module_name, :function_name, :arity, 
    :centrality_betweenness, :community_id
  ],
  from: :functions,
  limit: 10
}
```

### 2.4. New Top-Level Query Types (for `QueryEngine.ASTExtensions.execute_ast_query/2`)

These represent direct invocations of specific CPG semantic algorithms.

*   **`:impact_analysis`**:
    ```elixir
    query = %{
      type: :impact_analysis,
      params: %{
        target_node_id: "MyModule.my_function/2:def",
        depth: 3,
        dependency_types: [:call, :data]
      }
    }
    # Returns: {:ok, impact_report_map} (see CPGSemantics API)
    ```
*   **`:architectural_smells_detection`**:
    ```elixir
    query = %{
      type: :architectural_smells_detection,
      params: %{
        smells_to_detect: [:god_object, :cyclic_dependencies],
        # Optional thresholds
        centrality_thresholds: %{degree: 50, betweenness: 0.7},
        scc_min_size: 3 
      }
    }
    # Returns: {:ok, smells_report_map} (see CPGSemantics API)
    ```
*   **`:critical_path_finding`**:
    ```elixir
    query = %{
      type: :critical_path_finding,
      params: %{
        start_node_id: "ModuleA.entry_point/0:def",
        end_node_id: "ModuleZ.exit_point/0:def",
        path_type: :execution,
        cost_factors: %{complexity: 1.0, performance_penalty: 2.0}
      }
    }
    # Returns: {:ok, path_list_with_details} (see CPGSemantics API)
    ```
*   **`:community_detection`**:
    ```elixir
    query = %{
      type: :community_detection,
      params: %{
        algorithm: :louvain,
        resolution: 1.0
      }
    }
    # Returns: {:ok, communities_report_list} (see CPGSemantics API)
    ```

## 3. Query Execution Enhancements (`QueryExecutor` / `EnhancedRepository`)

*   **Index Utilization**: The query execution mechanism will be enhanced to utilize new indexes built on algorithmic results (e.g., an index on centrality scores, or community IDs).
*   **Lazy Computation**: For expensive algorithmic queries (e.g., full impact analysis for a highly connected node), the system might:
    1.  First, check a cache for pre-computed results (managed by `MemoryManager` or within `CPGData`).
    2.  If not cached, compute it on-demand.
    3.  Optionally, provide a way for queries to specify if they allow stale data or require fresh computation.
*   **CPG Optimizer Integration**: The `QueryExecutor` will consult the `CPGOptimizer` (conceptual) to determine the most efficient way to satisfy a query, especially for those involving graph traversals or multiple algorithmic metrics.

## 4. Caching of Algorithmic Results

*   Results from computationally intensive graph algorithms (e.g., PageRank, full community detection on a large CPG) will be cached.
*   Caching can occur at two levels:
    1.  Within the `CPGData.t()` struct itself (e.g., `cpg.metadata.cached_centrality_scores`).
    2.  Managed by `ElixirScope.ASTRepository.MemoryManager` for broader query result caching.
*   **Invalidation**: Cache invalidation for algorithmic results will be triggered by:
    *   Changes to the underlying CPG structure (e.g., file changes leading to CPG updates).
    *   Explicit cache clearing commands.
    *   TTL policies.

## 5. Examples of Enhanced Queries

### Example 1: Find "God Functions"

```elixir
# Using new WHERE clause fields
god_function_query = %{
  select: [:module_name, :function_name, :arity, :centrality_betweenness, :centrality_degree],
  from: :functions, # Assuming centrality is aggregated to function level
  where: [
    {:and, [
      {:centrality_betweenness, :gt, 0.75}, # Example threshold
      {:centrality_degree, :gt, 50},      # Example threshold
      {:lines_of_code, :gt, 200}         # Example threshold
    ]}
  ],
  order_by: {:desc, :centrality_betweenness},
  limit: 10
}
{:ok, results} = ElixirScope.ASTRepository.QueryBuilder.execute_query(repo, god_function_query)
```
Or, using a dedicated architectural smell query type:
```elixir
# Using new top-level query type
god_function_query_alt = %{
  type: :architectural_smells_detection,
  params: %{
    smells_to_detect: [:god_object],
    centrality_thresholds: %{betweenness: 0.75, degree: 50},
    min_loc: 200
  }
}
{:ok, report} = ElixirScope.QueryEngine.ASTExtensions.execute_ast_query(god_function_query_alt)
# report would be %{god_object: [%{node_id: "...", evidence: %{...}}]}
```

### Example 2: Find Modules with High Outgoing Coupling

```elixir
# This requires coupling metrics to be computed and queryable
high_coupling_query = %{
  select: [:module_name, :outgoing_coupling_score],
  from: :modules,
  where: [
    {:outgoing_coupling_score, :gt, 0.8} # Example threshold
  ],
  order_by: {:desc, :outgoing_coupling_score}
}
# Execution would involve calculating or retrieving coupling for each module
```

### Example 3: Analyze Impact of Changing a Core Function

```elixir
impact_query = %{
  type: :impact_analysis,
  params: %{
    target_node_id: "Core.Utils.critical_helper/1:def", # CPG node ID for the function
    depth: 5,
    dependency_types: [:call, :data]
  }
}
{:ok, impact_report} = ElixirScope.QueryEngine.ASTExtensions.execute_ast_query(impact_query)
IO.puts("Downstream affected nodes: #{length(impact_report.downstream_nodes)}")
```

---
