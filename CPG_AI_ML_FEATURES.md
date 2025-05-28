# CPG AI/ML Features Enablement

**`CPG_AI_ML_FEATURES.MD`**

## 1. Overview

The CPG Algorithmic Enhancement Layer significantly enriches the data available for ElixirScope's AI and Machine Learning (ML) components. By providing structured graph-theoretic metrics and semantic relationships, this layer enables more sophisticated, accurate, and insightful AI-driven features. This document outlines how these new CPG-derived features can be leveraged by modules like `ElixirScope.AI.Analysis.IntelligentCodeAnalyzer`, `ElixirScope.AI.Predictive.ExecutionPredictor`, and future LLM-based functionalities.

## 2. Feature Categories from CPG Algorithms

The algorithms implemented in `CPGMath` and `CPGSemantics` produce a rich set of features that can be associated with CPG nodes (modules, functions, variables, AST constructs) or the graph as a whole.

### 2.1. Node-Level Features:

These features describe individual components within the CPG.

*   **Centrality Scores (from `CPGMath`):**
    *   `degree_centrality_in`, `degree_centrality_out`, `degree_centrality_total`: Raw counts or normalized scores indicating local connectivity (e.g., a function's direct usage, a variable's def/use count within its CPG representation).
    *   `betweenness_centrality_score`: Measures how often a node lies on shortest paths between other nodes (identifies brokers/bottlenecks in control or data flow).
    *   `closeness_centrality_score`: Measures how quickly a node can reach others (identifies well-connected utilities or central data points).
    *   `pagerank_score` / `eigenvector_centrality_score`: Measures influence within the graph (identifies impactful components).
    *   **AI Use:** These scores can be direct inputs to ML models for predicting defect proneness, change impact, or identifying architecturally significant components. For LLMs, they provide quantitative measures of a node's role.
*   **Community Membership (from `CPGMath`, refined by `CPGSemantics`):**
    *   `community_id`: Categorical feature indicating which functional or structural group a CPG node belongs to.
    *   `intra_community_degree_ratio`: Ratio of connections within its community vs. outside (measures encapsulation/cohesion of the node's local context).
    *   `node_role_in_community`: (e.g., `:core`, `:bridge`, `:peripheral`) Derived by `CPGSemantics` based on connectivity within and outside its community.
    *   **AI Use:** Helps in understanding module cohesion, feature entanglement, and can be used for recommending refactoring to improve modularity. LLMs can use this to understand the context of a piece of code.
*   **Local Graph Properties (from `CPGMath`):**
    *   `local_clustering_coefficient`: How interconnected a node's immediate neighbors are.
    *   **AI Use:** Can indicate local complexity or specific micro-patterns.
*   **Semantic Node Type (from CPG Node itself, refined by `PatternRecognizer`):**
    *   E.g., `:function_definition`, `:variable_declaration`, `:ecto_query_call`, `:genserver_handle_call_entry`.
    *   **AI Use:** Critical for type-specific analysis and model training.

### 2.2. Path-Level Features:

These features describe sequences of nodes and edges within the CPG.

*   **Semantic Path Properties (from `CPGSemantics.semantic_critical_path`):**
    *   `semantic_path_cost`: Composite cost of a path considering complexity, risk, performance penalties, etc.
    *   `path_length` (semantic or hop-based).
    *   `path_bottleneck_nodes_count`: Number of nodes along a path with specific critical properties (e.g., high complexity, known performance issues).
    *   `path_risk_score`: Aggregated risk score along a path.
    *   **AI Use:** `ExecutionPredictor` can use typical semantic path costs as features. Path properties can be used to rank potential root causes in error diagnosis for LLMs.
*   **Data Flow Path Properties (from `CPGSemantics.trace_data_flow_semantic`):**
    *   `taint_propagation_score`: Likelihood or confidence of tainted data reaching a sink through a specific path.
    *   `transformations_on_path`: Sequence of operations (e.g., function calls, operators) applied to data along a path.
    *   `control_flow_conditions_for_path`: Conjunction of CFG conditions that enable this data flow.
    *   **AI Use:** Security vulnerability prediction (SQLi, XSS), data leakage analysis, understanding data lineage for LLMs.

### 2.3. Graph-Level (or Subgraph-Level) Features:

These describe properties of the entire CPG or significant subgraphs (e.g., a module's CPG).

*   **Overall Graph Metrics (from `CPGMath` applied to a CPG):**
    *   `density`: Overall interconnectedness.
    *   `diameter`: Longest shortest path (indicates information propagation delay).
    *   `average_clustering_coefficient`.
    *   `scc_summary`: `%{count: integer, max_size: integer, avg_size: float}` - Indicates presence and scale of cyclic dependencies.
    *   **AI Use:** Characterize overall project/module health, complexity, and maintainability. Can be used as global context for AI models.
*   **Community Structure Properties (from `CPGSemantics.identify_code_communities`):**
    *   `number_of_communities`.
    *   `modularity_score`.
    *   `average_community_size`.
    *   `inter_community_edge_density` (measures coupling between communities).
    *   **AI Use:** Assess architectural quality, identify overly fragmented or monolithic designs. LLMs can use this to understand the macroscopic structure.

## 3. Enhancing Existing AI Components

### 3.1. `ElixirScope.AI.Analysis.IntelligentCodeAnalyzer`

*   **Semantic Analysis & Quality Assessment:**
    *   **Complexity Refinement:** `complexity_score` for a function can be augmented by its CPG centrality (e.g., `pagerank_score` from the function call graph part of the CPG). A function with high AST complexity but low CPG centrality (rarely used, not a bridge) might be less critical than one with moderate AST complexity but high CPG centrality.
    *   **Cohesion/Coupling Metrics:** Use `CPGSemantics.analyze_module_cohesion/3` for a module's CPG representation and `CPGSemantics.identify_coupling/4` between module CPGs to provide more accurate maintainability scores.
    *   **Pattern Context:** When identifying design patterns, the community structure a pattern participates in can provide context (e.g., a Factory pattern primarily used within a "DataImport" community).
    *   Use SCC results to directly identify circular dependencies, a strong indicator of poor maintainability.
*   **Refactoring Suggestions:**
    *   **Extract Component:** If `CPGSemantics.identify_code_communities/2` identifies a set of highly interconnected CPG nodes within a larger function/module CPG that forms a distinct sub-community, suggest extracting it.
    *   **Relocate Component:** If `CPGSemantics.identify_coupling/4` shows a function's CPG node is more strongly coupled to CPG nodes of an external module than its own, suggest moving it.
    *   **Prioritization:** Prioritize refactoring suggestions for CPG nodes with high `CPGSemantics.dependency_impact_analysis/3` scores.
*   **Pattern/Anti-Pattern Recognition (via enhanced `PatternMatcher`):**
    *   Use `PatternMatcher` (enhanced with CPG rules as per `CPG_PATTERN_DETECTION_ADVANCED.MD`) for more robust detection.
    *   **God Object/Module:** Use `PatternMatcher` rules checking for high CPG centrality and large CPG subgraph size.
    *   **Shotgun Surgery:** Low centrality but high impact score.
    *   **Cyclic Dependencies:** Directly consume SCC results from `CPGMath.strongly_connected_components/1` applied to module/function call dependency graphs derived from the CPG.

### 3.2. `ElixirScope.AI.Predictive.ExecutionPredictor`

*   **Predicting Execution Paths:**
    *   Use `CPGSemantics.semantic_critical_path/4` (with weights biased towards execution likelihood based on CFG edge probabilities if available, or default weights) as a primary feature for predicting likely paths.
    *   The sequence of CPG node types along a path can be a feature.
    *   Incorporate control flow probabilities if derived from CFG analysis (e.g., based on guard clause complexity or typical branch outcomes).
*   **Predicting Resource Usage:**
    *   The sum or average of `complexity_score` (from `EnhancedFunctionData`, linked via CPG nodes) of function CPG nodes along a predicted execution path.
    *   The number and type of "heavy" CPG nodes (e.g., representing I/O, DB calls, complex computations) on the path.
    *   The complexity of the CPG subgraph traversed by a predicted execution path can be a feature.
    *   Centrality of nodes along the path (especially if they represent shared resources or complex operations) can influence resource predictions.
*   **Analyzing Concurrency Impacts:**
    *   CPG nodes representing shared resources (identified via DFG analysis within CPG) that also have high `betweenness_centrality` in the context of concurrent execution paths are strong candidates for contention points.
    *   Trace dependencies between CPG nodes representing tasks/processes. SCCs in this CPG-derived process interaction graph can indicate deadlock risks.
    *   Use CPG to model dependencies between concurrently executing functions; SCCs in this graph can indicate deadlock risks.

### 3.3. LLM Interactions (`ElixirScope.AI.LLM.Client` & `AI.Bridge`)

*   **Richer Context for LLMs (`AI.Bridge.get_correlated_features_for_ai`):**
    *   When requesting LLM analysis for a piece of code (represented by a CPG node or subgraph):
        *   Provide its key CPG node-level features: centrality scores, community ID, semantic node type.
        *   Summarize its local CPG neighborhood: e.g., types of directly connected nodes, strength of key incoming/outgoing CPG edges (call, data flow).
        *   A summary of its direct CPG dependencies (callers, callees, data sources/sinks).
        *   Identified architectural smells related to the component.
        *   If analyzing an error, provide the `CPGSemantics.semantic_critical_path` leading to the CPG node representing the error location, highlighting critical CPG nodes.
        *   If suggesting refactoring, provide `CPGSemantics.dependency_impact_analysis` summary to help the LLM understand constraints and potential side effects of changes.
*   **CPG-Informed Prompt Engineering:**
    *   Structure prompts to guide LLMs to reason based on CPG properties.
    *   Example: "The function `foo/1` (CPG node ID: `...`) has a PageRank of 0.05 in the call graph and is part of community 3, which primarily handles user authentication. It calls function `bar/2` (CPG node ID: `...`) which performs a database write. Explain potential security risks."
    *   Example: "Module `Baz` (CPG node ID: `...`) has a low cohesion score of 0.3 based on its internal CPG structure. Its functions `f1`, `f2` are in community A, while `f3`, `f4` are in community B. Suggest how to refactor `Baz`."
    *   Example: "Given that function `X` has a high betweenness centrality (score: 0.8) and connects communities A (data access) and B (business logic), and its semantic critical path cost is Y, how would you refactor it to reduce its bottleneck potential?"

## 4. New AI/ML Opportunities Enabled by CPG Algorithms

*   **Semantic Code Search (`QueryEngine.ASTExtensions` + AI):**
    *   Represent CPG nodes/subgraphs as embeddings (e.g., using Graph Neural Networks - GNNs - or other graph embedding techniques).
    *   Allow users to search for code semantically: "find functions similar to this one in terms of data flow patterns and call structure," not just text.
*   **Semantic Code Clone Detection:**
    *   Compare CPG subgraphs using graph isomorphism or graph similarity algorithms (from `CPGMath` or specialized tools).
    *   Train ML models on pairs of CPG subgraphs to detect semantic clones even if syntactically different.
*   **Advanced Defect Prediction (ML Model):**
    *   Use a richer feature set for ML models: CPG node centralities, community properties, path complexities from CPG, semantic coupling/cohesion scores, historical churn rates for CPG nodes, and historical bug data.
*   **Automated Architectural Refactoring Engine (AI + `CPGSemantics`):**
    *   AI agents that use `CPGSemantics.detect_architectural_smells` to identify issues.
    *   Then, use impact analysis and community data to propose concrete CPG transformations (e.g., "Move CPG nodes X,Y,Z from community A to form a new component B because...").
    *   Based on community analysis, AI could suggest concrete refactorings like splitting modules, moving functions, or introducing new abstractions to improve modularity and reduce coupling.
    *   Translate CPG transformations back to source code changes (highly complex future goal).
*   **Fine-Grained Test Case Generation (AI + CPG Paths):**
    *   Use `CPGSemantics.semantic_critical_path` and `CPGSemantics.trace_data_flow_semantic` to identify distinct, semantically relevant execution and data flow paths through the CPG.
    *   Use `CPGMath.all_paths` combined with semantic path analysis to identify distinct execution paths.
    *   AI generates test inputs to cover these specific CPG paths and their boundary conditions.
*   **Predictive Security Vulnerability Analysis (ML Model):**
    *   Train ML models (e.g., GNNs) on CPGs labeled with known vulnerabilities. Features would include data flow path properties (source/sink types, transformations from `CPGSemantics`), call graph patterns, and specific AST node types present in vulnerable CPG subgraphs.
    *   Train models on CPG patterns associated with known vulnerabilities (e.g., specific data flow paths from user input to sensitive sinks, certain API usage patterns identified in the CPG).
*   **Intelligent Code Summarization/Documentation Generation:**
    *   Use CPG community information, key CPG bridge nodes (high betweenness), and critical paths to generate summaries of a module's or function's role and key interactions.

## 5. Accessing CPG Algorithmic Features for AI

AI components will primarily access these new features through:
1.  **`ElixirScope.ASTRepository.EnhancedRepository`**: To get `CPGData.t()` for modules/functions. The `CPGData.t().metadata` or `CPGData.t().unified_analysis` fields should be populated with (or provide functions to compute) results from `CPGMath` and `CPGSemantics`. This internally calls the CPG generators and stores/retrieves `CPGData`.
2.  **`ElixirScope.QueryEngine.ASTExtensions` (via `QueryBuilder`):** For executing queries that filter or sort based on new CPG-derived metrics (e.g., `SELECT ... WHERE centrality_betweenness > 0.5`). For querying data based on the new metrics.
3.  **`ElixirScope.AI.Bridge`**: This module will act as a specialized facade, offering functions like `get_function_cpg_with_algorithms_for_ai(function_key, [:centrality, :community])` or `get_node_features_for_ml(cpg_node_id, [:pagerank, :community_size, :ast_type])`. It would orchestrate calls to `EnhancedRepository`, `CPGMath`, and `CPGSemantics`. This facilitates direct calls to `CPGMath` and `CPGSemantics` for specific, on-demand algorithmic analysis if not covered by standard queries or pre-computed metrics.

By leveraging the CPG Algorithmic Enhancement Layer, ElixirScope's AI capabilities can move beyond surface-level AST analysis to a deeper, more structural and semantic understanding of the codebase, leading to more powerful and accurate developer assistance. This layer transforms the CPG from a rich data structure into an active analytical tool, providing the deep semantic and structural context that AI/ML models need to deliver truly intelligent insights about Elixir code.