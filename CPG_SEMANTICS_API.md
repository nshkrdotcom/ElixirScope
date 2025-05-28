# CPGSemantics API Documentation

**`CPG_SEMANTICS_API.MD`**

## 1. Overview

The `ElixirScope.ASTRepository.Enhanced.CPGSemantics` module (conceptual name) builds upon the foundational graph algorithms provided by `CPGMath`. It introduces code-specific semantics, context, and heuristics to interpret graph properties in a way that is meaningful for understanding Elixir codebases.

This module provides higher-level analytical functions that combine raw graph metrics with knowledge of Elixir syntax, OTP patterns, and common software engineering principles. The results are used to power advanced querying, pattern detection, and AI-driven insights.

## 2. Core Concepts

*   **Semantic Weighting**: Assigning meaningful weights to CPG nodes and edges based on their code representation (e.g., a function call edge to an Ecto function might have a higher "cost" or "risk" weight than a call to a simple math utility).
*   **Contextual Analysis**: Considering the type of CPG nodes (function, module, variable, AST construct) and their properties (complexity, visibility, annotations) when interpreting graph algorithm results.
*   **Elixir-Specific Heuristics**: Incorporating knowledge of Elixir idioms, OTP behaviors, and common library usage patterns to refine analysis.

## 3. Semantic Pathfinding and Analysis

### `semantic_critical_path(cpg, start_node_id, end_node_id, opts \\ [])`

Identifies critical execution or dependency paths considering semantic factors.
*   **`cpg`**: `CPGData.t()`
*   **`start_node_id`**: `node_id()`
*   **`end_node_id`**: `node_id()`
*   **`opts`**: Keyword list of options:
    *   `:path_type`: `:execution | :data_dependency | :call_chain` (default: `:execution`).
    *   `:cost_factors`: `map()` - Factors to consider for path cost, e.g., `%{complexity: 0.5, io_penalty: 2.0, security_risk: 3.0}`.
    *   `:risk_threshold`: `float()` - Minimum risk score for a path to be considered critical.
*   **Returns:** `{:ok, path :: [node_id()], details :: map()}` or `{:error, :no_critical_path_found}`.
    *   `details` includes path cost, risk score, primary contributing factors.
*   **Details:** Extends standard shortest/longest path algorithms by using a composite weight function derived from `cost_factors` and CPG node/edge properties.
*   **Example:**
    ```elixir
    # Find critical execution path with high I/O and complexity cost
    cost_factors = %{complexity: 1.5, node_type_penalties: %{io_call: 5.0}}
    {:ok, path, details} = CPGSemantics.semantic_critical_path(cpg, entry_node, exit_node, cost_factors: cost_factors)
    IO.puts("Critical path risk: #{details.risk_score}")
    ```

### `trace_data_flow_semantic(cpg, start_variable_node_id, end_variable_node_id, opts \\ [])`

Traces data flow between two variables, considering transformations and control flow context.
*   **`cpg`**: `CPGData.t()`
*   **`start_variable_node_id`**: `node_id()` - CPG node representing the source variable's definition/use.
*   **`end_variable_node_id`**: `node_id()` - CPG node representing the target variable's definition/use.
*   **`opts`**: Keyword list of options:
    *   `:max_depth`: `pos_integer()` - Maximum depth of data flow trace.
*   **Returns:** `{:ok, flow_paths :: [map()]}` or `{:error, :no_flow_found}`.
    *   Each `flow_path` map includes: `path_nodes :: [node_id()]`, `transformations :: [String.t()]`, `control_flow_conditions :: [String.t()]`.
*   **Example:**
    ```elixir
    {:ok, flows} = CPGSemantics.trace_data_flow_semantic(cpg, "var_user_input_def", "var_query_param_use")
    # Analyze flows for potential taint propagation
    ```

## 4. Dependency and Impact Analysis

### `dependency_impact_analysis(cpg, target_node_id, opts \\ [])`

Analyzes the potential impact of changing a given CPG node.
*   **`cpg`**: `CPGData.t()`
*   **`target_node_id`**: `node_id()` - The CPG node whose change impact is to be assessed.
*   **`opts`**: Keyword list of options:
    *   `:depth`: `pos_integer()` - How many levels of dependencies to trace (default: 3).
    *   `:dependency_types`: `[:call, :data, :control]` - Types of dependencies to consider (default: `[:call, :data]`).
    *   `:exclude_node_types`: `[atom()]` - CPG node types to exclude from impact analysis (e.g., primitive type nodes).
*   **Returns:** `{:ok, impact_report :: map()}`.
    *   `impact_report` includes: `%{upstream_nodes: [node_id()], downstream_nodes: [node_id()], direct_impact_score: float(), transitive_impact_score: float(), affected_communities: [community_id()]}`.
*   **Example:**
    ```elixir
    {:ok, report} = CPGSemantics.dependency_impact_analysis(cpg, "MyModule.critical_function_node", depth: 5)
    IO.puts("Changing this function might affect #{length(report.downstream_nodes)} downstream components.")
    ```

### `identify_coupling(cpg, node_id1, node_id2, opts \\ [])`

Measures the coupling strength and type between two CPG nodes (e.g., functions or modules).
*   **`cpg`**: `CPGData.t()`
*   **`node_id1`**: `node_id()`
*   **`node_id2`**: `node_id()`
*   **`opts`**: Keyword list.
*   **Returns:** `{:ok, coupling_info :: map()}`.
    *   `coupling_info` includes: `%{strength: float(), types: [:call | :data_access | :shared_state], direction: :a_to_b | :b_to_a | :bidirectional}`.
*   **Example:**
    ```elixir
    {:ok, coupling} = CPGSemantics.identify_coupling(cpg, "ModuleA_node", "ModuleB_node")
    # coupling.strength might be 0.75, coupling.types might be [:call, :data_access]
    ```

## 5. Architectural Analysis

### `detect_architectural_smells(cpg, opts \\ [])`

Identifies potential architectural smells using CPG properties and semantic interpretation.
*   **`cpg`**: `CPGData.t()`
*   **`opts`**: Keyword list of options:
    *   `:smells_to_detect`: `[:god_object | :feature_envy | :shotgun_surgery | :cyclic_dependencies]` (default: all).
    *   `:centrality_thresholds`: `map()` - Thresholds for centrality-based smells.
    *   `:coupling_thresholds`: `map()` - Thresholds for coupling-based smells.
*   **Returns:** `{:ok, smells_report :: %{atom() => [smell_details :: map()]}}`.
    *   `smell_details` includes node IDs, evidence, severity.
*   **Details:** Leverages `CPGMath` (centrality, SCCs, community detection) and interprets results in code context. For example, a node with very high degree and betweenness centrality within its community might be a "God Object."
*   **Example:**
    ```elixir
    {:ok, report} = CPGSemantics.detect_architectural_smells(cpg, smells_to_detect: [:god_object, :cyclic_dependencies])
    god_objects = report[:god_object] || []
    ```

### `analyze_module_cohesion(cpg, module_node_id, opts \\ [])`

Assesses the cohesion of a module based on the interconnectedness of its internal CPG nodes (functions, data structures).
*   **`cpg`**: `CPGData.t()`
*   **`module_node_id`**: `node_id()` - CPG node representing the module.
*   **`opts`**: Keyword list.
*   **Returns:** `{:ok, cohesion_score :: float(), details :: map()}`.
    *   `details` might include internal vs. external edge ratios, LCOM (Lack of Cohesion in Methods) variants adapted for CPG.
*   **Details:** Uses community detection results or direct analysis of subgraph density for the module's components.

### `identify_code_communities(cpg, opts \\ [])`

Applies community detection and provides semantically enriched information about the detected communities.
*   **`cpg`**: `CPGData.t()`
*   **`opts`**: Keyword list of options for the underlying `CPGMath.community_louvain/2` or `CPGMath.community_label_propagation/2`.
    *   `:algorithm`: `:louvain | :label_propagation` (default: `:louvain`).
*   **Returns:** `{:ok, communities_report :: [map()]}`.
    *   Each community `map` includes: `community_id`, `member_nodes :: [node_id()]`, `dominant_node_types :: [atom()]`, `inter_community_links :: integer()`, `description_summary :: String.t()`.
*   **Details:** Post-processes raw community detection results by analyzing the types of nodes within each community to infer its purpose (e.g., "Data Access Layer," "User Authentication Feature").

## 6. Semantic Weighting and Heuristics

While not direct API calls, these are crucial internal aspects of `CPGSemantics`:

### Semantic Edge Weight Calculation
*   `CPGSemantics` will contain internal functions to calculate weights for `CPGEdge.t()` instances based on their type and the properties of connected nodes.
*   **Factors influencing weights:**
    *   **Control Flow**: Probability (if known), complexity of conditions.
    *   **Data Flow**: Type of data, direct vs. indirect flow, variable lifetime.
    *   **Call Flow**: Criticality of called function, frequency (if runtime data available).
    *   **AST Edges**: Syntactic relationship (e.g., parent-child, sibling).
    *   **Node Properties**: Security risk of source/target, performance cost, complexity.

### Elixir-Specific Heuristics
*   **OTP Awareness**: Give special consideration to OTP-related CPG nodes (GenServers, Supervisors). E.g., calls to `GenServer.call` might have different semantic impact than normal function calls.
*   **Macro Expansion**: Where CPG nodes represent expanded macro code, heuristics might be applied to trace back to the original macro invocation for analysis.
*   **Library Usage**: Recognize calls to common libraries (Ecto, Phoenix) and adjust semantic interpretations accordingly (e.g., `Ecto.Repo.all/2` implies a database interaction).

---
