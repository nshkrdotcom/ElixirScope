# CPGMath API Documentation

**`CPG_MATH_API.MD`**

## 1. Overview

The `ElixirScope.ASTRepository.Enhanced.CPGMath` module (conceptual name) provides a suite of standard graph algorithms adapted to operate on ElixirScope's Code Property Graphs (CPGs). These algorithms form the mathematical foundation for higher-level semantic analyses. They work directly with the `CPGData.t()` and related CPG node/edge structures defined in `elixir_scope/ast_repository/enhanced/cpg_data.ex`.

This API is primarily intended for internal use by other ElixirScope components like `CPGSemantics`, `QueryEngine`, and `PatternMatcher`.

## 2. Core Data Types Used

*   **`CPGData.t()`**: The complete Code Property Graph for a function or module.
*   **`CPGNode.t()`**: A node within the CPG.
*   **`CPGEdge.t()`**: An edge connecting two nodes in the CPG.
*   **`node_id :: String.t()`**: A unique identifier for a CPG node.

## 3. Pathfinding Algorithms

### `shortest_path(cpg, start_node_id, end_node_id, opts \\ [])`

Calculates the shortest path between two nodes in the CPG.
*   **`cpg`**: `CPGData.t()` - The Code Property Graph.
*   **`start_node_id`**: `node_id()` - The ID of the starting node.
*   **`end_node_id`**: `node_id()` - The ID of the target node.
*   **`opts`**: Keyword list of options:
    *   `:weight_function`: `(CPGEdge.t() -> non_neg_integer())` - A function to calculate edge weights. Defaults to `fn _edge -> 1 end` (number of hops).
    *   `:max_depth`: `pos_integer()` - Maximum path depth to explore.
*   **Returns:** `{:ok, path :: [node_id()]}` or `{:error, :no_path_found | :invalid_nodes}`.
*   **Algorithm:** Typically Dijkstra's or A* if heuristics are provided.
*   **Example:**
    ```elixir
    {:ok, path} = CPGMath.shortest_path(cpg, "node_A", "node_Z")
    # path might be ["node_A", "node_B", "node_C", "node_Z"]
    ```

### `all_paths(cpg, start_node_id, end_node_id, opts \\ [])`

Finds all simple paths (no repeated nodes, except possibly start/end for cycles if allowed) between two nodes.
*   **`cpg`**: `CPGData.t()`
*   **`start_node_id`**: `node_id()`
*   **`end_node_id`**: `node_id()`
*   **`opts`**: Keyword list of options:
    *   `:max_paths`: `pos_integer()` - Maximum number of paths to return (default: 100).
    *   `:max_depth`: `pos_integer()` - Maximum path length (default: 20).
*   **Returns:** `{:ok, paths :: [[node_id()]]}` or `{:error, :invalid_nodes}`.
*   **Algorithm:** Modified Depth-First Search (DFS).
*   **Example:**
    ```elixir
    {:ok, all_paths_found} = CPGMath.all_paths(cpg, "node_A", "node_Z", max_paths: 10)
    ```

## 4. Connectivity Algorithms

### `strongly_connected_components(cpg)`

Finds all Strongly Connected Components (SCCs) in the CPG. Useful for detecting cycles (e.g., circular dependencies, recursion).
*   **`cpg`**: `CPGData.t()`
*   **Returns:** `{:ok, sccs :: [[node_id()]]}` where each inner list is an SCC.
*   **Algorithm:** Tarjan's algorithm or Kosaraju's algorithm.
*   **Example:**
    ```elixir
    {:ok, components} = CPGMath.strongly_connected_components(cpg)
    # components might be [["node_R1", "node_R2"], ["node_M1", "node_M2", "node_M3"]]
    # (indicating recursion/mutual recursion or tight coupling)
    ```

### `topological_sort(cpg)`

Performs a topological sort of the CPG nodes, if the graph is a Directed Acyclic Graph (DAG).
*   **`cpg`**: `CPGData.t()`
*   **Returns:** `{:ok, sorted_nodes :: [node_id()]}` or `{:error, :graph_has_cycle}`.
*   **Algorithm:** Kahn's algorithm or DFS-based.
*   **Example:**
    ```elixir
    case CPGMath.topological_sort(cpg) do
      {:ok, order} -> # process order
      {:error, :graph_has_cycle} -> IO.puts("Cannot topologically sort a cyclic graph.")
    end
    ```

## 5. Centrality Measures

These functions calculate various centrality scores for each node in the CPG.

### `degree_centrality(cpg, opts \\ [])`

Calculates degree centrality (in-degree, out-degree, total degree) for each node.
*   **`cpg`**: `CPGData.t()`
*   **`opts`**: Keyword list of options:
    *   `:direction`: `:in | :out | :total` (default: `:total`).
    *   `:normalize`: `boolean()` - Whether to normalize scores (default: `true`).
*   **Returns:** `{:ok, centrality_map :: %{node_id() => float()}}`.
*   **Example:**
    ```elixir
    {:ok, degrees} = CPGMath.degree_centrality(cpg, direction: :out)
    # degrees might be %{"func_A" => 0.8, "func_B" => 0.5}
    ```

### `betweenness_centrality(cpg, opts \\ [])`

Calculates betweenness centrality for each node.
*   **`cpg`**: `CPGData.t()`
*   **`opts`**: Keyword list of options:
    *   `:normalize`: `boolean()` (default: `true`).
    *   `:weighted`: `boolean()` - Consider edge weights (default: `false`).
*   **Returns:** `{:ok, centrality_map :: %{node_id() => float()}}`.
*   **Algorithm:** Brandes' algorithm.

### `closeness_centrality(cpg, opts \\ [])`

Calculates closeness centrality for each node.
*   **`cpg`**: `CPGData.t()`
*   **`opts`**: Keyword list of options:
    *   `:weighted`: `boolean()` (default: `false`).
*   **Returns:** `{:ok, centrality_map :: %{node_id() => float()}}`.

### `eigenvector_centrality(cpg, opts \\ [])`

Calculates eigenvector centrality for each node.
*   **`cpg`**: `CPGData.t()`
*   **`opts`**: Keyword list of options:
    *   `:max_iter`: `pos_integer()` (default: 100).
    *   `:tolerance`: `float()` (default: 1.0e-6).
*   **Returns:** `{:ok, centrality_map :: %{node_id() => float()}}`.

### `pagerank_centrality(cpg, opts \\ [])`

Calculates PageRank centrality for each node.
*   **`cpg`**: `CPGData.t()`
*   **`opts`**: Keyword list of options:
    *   `:alpha`: `float()` - Damping factor (default: 0.85).
    *   `:max_iter`: `pos_integer()` (default: 100).
    *   `:tolerance`: `float()` (default: 1.0e-6).
*   **Returns:** `{:ok, centrality_map :: %{node_id() => float()}}`.

## 6. Community Detection Algorithms

### `community_louvain(cpg, opts \\ [])`

Detects communities in the CPG using the Louvain algorithm (modularity-based).
*   **`cpg`**: `CPGData.t()`
*   **`opts`**: Keyword list of options:
    *   `:weight_function`: `(CPGEdge.t() -> non_neg_integer())` - Edge weights.
    *   `:resolution`: `float()` - Resolution parameter for modularity (default: 1.0).
*   **Returns:** `{:ok, communities_map :: %{node_id() => community_id :: integer()}}`.
*   **Example:**
    ```elixir
    {:ok, node_communities} = CPGMath.community_louvain(cpg)
    # node_communities might be %{"node_A" => 0, "node_B" => 0, "node_C" => 1}
    ```

### `community_label_propagation(cpg, opts \\ [])`

Detects communities using the Label Propagation algorithm.
*   **`cpg`**: `CPGData.t()`
*   **`opts`**: Keyword list of options:
    *   `:max_iter`: `pos_integer()` (default: 100).
*   **Returns:** `{:ok, communities_map :: %{node_id() => community_id :: integer()}}`.

## 7. Graph Metrics

### `density(cpg)`

Calculates the density of the CPG.
*   **`cpg`**: `CPGData.t()`
*   **Returns:** `{:ok, density :: float()}` (between 0 and 1).

### `diameter(cpg, opts \\ [])`

Calculates the diameter of the CPG (longest shortest path).
*   **`cpg`**: `CPGData.t()`
*   **`opts`**: Keyword list of options:
    *   `:weight_function`: Edge weights.
*   **Returns:** `{:ok, diameter :: non_neg_integer()}` or `{:error, :disconnected_graph}`.

## 8. Helper Functions

These functions might be exposed if generally useful, or kept internal.

### `get_neighbors(cpg, node_id, direction \\ :out)`

Retrieves neighbors of a node.
*   **`direction`: `:in | :out | :both`**.
*   **Returns:** `{:ok, [node_id()]}`.

### `get_edges(cpg, node_id, direction \\ :out)`

Retrieves edges connected to a node.
*   **Returns:** `{:ok, [CPGEdge.t()]}`.

---
