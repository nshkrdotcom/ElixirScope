# Advanced CPG Pattern Detection

**`CPG_PATTERN_DETECTION_ADVANCED.MD`**

## 1. Overview

This document outlines enhancements to `ElixirScope.ASTRepository.PatternMatcher` to leverage the CPG Algorithmic Enhancement Layer. By incorporating graph-theoretic properties and semantic analysis results, the pattern matcher can detect more complex and nuanced code patterns, anti-patterns, and architectural concerns.

## 2. Leveraging CPG Algorithmic Insights

The `PatternMatcher` will be extended to use information derived from `CPGMath` and `CPGSemantics` as part of its rule-based detection logic.

### Key Algorithmic Data for Pattern Matching:

*   **Centrality Scores (`CPGMath`):**
    *   High degree/betweenness/PageRank can indicate "God Objects" or overly critical components.
    *   Low centrality might indicate dead or underutilized code.
*   **Community Detection Results (`CPGMath`, `CPGSemantics`):**
    *   Nodes within the same community with few external links can indicate good cohesion.
    *   Nodes that bridge multiple communities might be important integrators or potential bottlenecks.
    *   Small, isolated communities could represent dead features or poorly connected logic.
*   **Strongly Connected Components (SCCs) (`CPGMath`):**
    *   Directly identify circular dependencies between modules or functions.
    *   Large SCCs can indicate overly tangled code.
*   **Path Analysis (`CPGMath`, `CPGSemantics`):**
    *   `semantic_critical_path`: Identify critical execution paths that might be performance bottlenecks or high-risk areas.
    *   `trace_data_flow_semantic`: Analyze data flow paths for security vulnerabilities (e.g., taint analysis along CPG paths).
*   **Dependency Impact Scores (`CPGSemantics`):**
    *   High impact scores for a node can indicate a "Shotgun Surgery" candidate if changes to it affect many disparate parts of the codebase.
*   **Coupling Metrics (`CPGSemantics`):**
    *   High coupling scores between modules/functions, especially when combined with low cohesion within them, can indicate architectural problems.

## 3. Enhanced Pattern Definition

Pattern definitions within the `PatternMatcher`'s library (managed via `:ets.insert(@pattern_library, ...)` in `PatternMatcher`) will be extended to include rules based on CPG algorithmic results.

Pattern definitions stored in the `PatternMatcher`'s library (ETS table `@pattern_library`) will be extended. The `rules` list within a pattern definition can now include CPG-specific rule types.

A `pattern_def` map (value in the `@pattern_library` ETS table, keyed by `{:behavioral | :anti_pattern | :ast, pattern_name :: atom()}`) might now include:

```elixir
# Example of an enhanced pattern definition
pattern_def = %{
  description: "Identifies God Modules using CPG centrality and size.",
  severity: :warning,
  suggestions: ["Consider splitting module responsibilities.", "Delegate tasks to collaborators."],
  metadata: %{category: :architectural_smell, cwe_id: "CWE-XYZ"}, # Conceptual
  rules: [
    # Existing AST/DFG rules (functions taking function_data or module_data)
    # Example: &has_many_public_functions/1, 

    # New CPG-based rules:
    # Rule structure: {type, property_path, operator, value, options}
    #   - type: :cpg_node_metric, :cpg_graph_metric, :cpg_path_check, :custom_cpg_function
    #   - property_path: list of atoms to access metric (e.g., [:centrality, :betweenness_score])
    #   - operator: :gt, :lt, :eq, :in_percentile, :exists, :contains_node_type
    #   - value: The value to compare against.
    #   - options: Keyword list for additional rule parameters.

    {:cpg_node_metric, [:centrality, :degree_total], :gt_percentile, 90, applies_to: :module_root_node},
    {:cpg_node_metric, [:centrality, :betweenness_score], :gt_percentile, 90, applies_to: :module_root_node},
    {:cpg_node_metric, [:size_metrics, :lines_of_code], :gt, 1000, applies_to: :module_root_node}, # Assuming LoC is part of CPG node data
    {:cpg_node_metric, [:cohesion_metrics, :lcom4_variant], :gt, 0.8, applies_to: :module_root_node}, # Assuming cohesion is calculated

    # Custom function rule that can access CPG data
    # Takes: (entity_cpg_node_data, full_cpg_data, context_opts) -> boolean
    {:custom_cpg_function, &check_disparate_functionality_in_module/3} 
  ]
}

# Conceptual rule evaluation context:
# - entity_cpg_node_data: The CPGNode.t() for the module/function being evaluated.
# - full_cpg_data: The CPGData.t() of the containing entity (e.g., module's CPG if function is analyzed).
# - context_opts: Options passed to the pattern match call.
```

The `PatternMatcher`'s core `match_*_internal` functions will:
1.  Retrieve or ensure generation of the `CPGData.t()` for the module/function. This CPG might have pre-computed algorithmic results in its `metadata` or `unified_analysis` fields.
2.  For each rule in a pattern definition:
    *   If it's an old AST/DFG rule, evaluate it as before.
    *   If it's a `:cpg_node_metric` rule:
        *   Identify the target CPG node (e.g., module's root CPG node, function's entry CPG node).
        *   Retrieve or compute the required metric (e.g., centrality score) for that node using `CPGMath` or `CPGSemantics` on the `CPGData.t()`.
        *   Evaluate the operator and value. Handle percentiles by comparing against the distribution of that metric across all similar nodes in the CPG.
    *   If it's a `:cpg_graph_metric` rule: Evaluate a global property of the CPG (e.g., density, number of SCCs).
    *   If it's a `:cpg_path_check` rule: Invoke pathfinding algorithms from `CPGMath` or `CPGSemantics` and check path properties.
    *   If it's a `:custom_cpg_function`: Execute the custom function, passing it the relevant CPG node and the full CPG context.
3.  Combine results from all rules (e.g., all must pass, or a weighted score) to determine confidence.




A `pattern_def` map might now include:
```elixir
%{
  description: "Pattern description",
  severity: :warning | :error | :info,
  suggestions: ["Suggestion 1", "Suggestion 2"],
  metadata: %{category: :architecture | :performance | :security},
  rules: [
    # Existing AST-based rules (functions taking function_data or module_data)
    &ast_rule_function/1, 
    
    # New CPG-based rules (functions taking cpg_node_data and full cpg_context)
    # cpg_node_data might be the CPG node corresponding to the function/module
    # cpg_context would provide access to global CPG algorithmic results (centrality maps, communities)
    %Rule{
      type: :cpg_node_property, 
      property: :centrality_betweenness, 
      operator: :gt, 
      value: 0.7,
      applies_to: :function # or :module, :variable_node, etc.
    },
    %Rule{
      type: :cpg_community_property,
      property: :size, # or :density, :external_links
      operator: :lt,
      value: 3,
      condition: &small_isolated_community_check/2 # (community_info, cpg_context) -> boolean
    },
    %Rule{
      type: :cpg_scc_membership,
      min_scc_size: 3 # Belongs to an SCC of at least this size
    },
    # Custom function rule that can access CPG data
    &custom_cpg_rule_function/2 # (cpg_node_data, cpg_context) -> boolean
  ]
}

# Conceptual Rule struct
defmodule Rule do
  defstruct type: nil, property: nil, operator: nil, value: nil, applies_to: nil, condition: nil
end
```

The `PatternMatcher`'s core logic will need to:
1.  Retrieve the CPG for the module/function being analyzed.
2.  Fetch relevant pre-computed algorithmic results (centrality, communities) for the CPG or compute them if necessary (and cache them).
3.  Evaluate rules that depend on these CPG properties.

## 4. Examples of Advanced Pattern Detection

### 4.1. God Object / God Module

*   **PRD Link:** FR4.1
*   **Detection Logic:**
    1.  Identify CPG nodes representing modules or functions.
    2.  Calculate (or retrieve cached) centrality scores (e.g., degree, betweenness, PageRank) for these nodes within the CPG.
    3.  Flag nodes that have disproportionately high centrality scores compared to other nodes of the same type, potentially combined with:
        *   High Lines of Code (LoC) or function count (for modules).
        *   Low cohesion (if module cohesion metrics are available from `CPGSemantics`).
        *   Spanning multiple "concerns" or "features" if community detection has been run and nodes are associated with functional areas.
*   **CPG-Enhanced Detection Logic:**
    1.  Target: Module-level CPG representation (a subgraph or a representative node).
    2.  Rule 1 (`:cpg_node_metric`): High **Degree Centrality** (many incoming/outgoing calls/data flows to/from its functions).
    3.  Rule 2 (`:cpg_node_metric`): High **Betweenness Centrality** (its functions act as critical bridges between other parts of the system).
    4.  Rule 3 (AST/Static): High number of public functions / Lines of Code (from `EnhancedModuleData`).
    5.  Rule 4 (`:cpg_node_metric` or `CPGSemantics`): Low **Cohesion Score** (e.g., `analyze_module_cohesion` indicates internal parts are not well-related, or internal functions belong to many different detected code communities).
*   **Confidence:** Higher if multiple rules trigger.
*   **Rule Example (Conceptual):**
    ```elixir
    %Rule{
      type: :cpg_node_property, 
      property: :centrality_betweenness, 
      operator: :gt, 
      value_percentile: 0.95 # e.g., in the top 5% of betweenness for its type
    },
    %Rule{
      type: :cpg_node_property,
      property: :lines_of_code, # Assuming this is available on the node
      operator: :gt,
      value: 500 
    }
    ```

### 4.2. Shotgun Surgery

*   **PRD Link:** FR4.2
*   **Detection Logic:**
    1.  For a candidate CPG node (e.g., a function), use `CPGSemantics.dependency_impact_analysis/3` to determine its downstream impact radius.
    2.  Analyze the communities of the affected downstream nodes. If a small change to the candidate node affects many nodes spread across *different* unrelated communities, it's a sign of Shotgun Surgery.
*   **CPG-Enhanced Detection Logic:**
    1.  Target: Function-level CPG nodes.
    2.  Rule 1 (`:custom_cpg_function` using `CPGSemantics.dependency_impact_analysis`):
        *   Calculate downstream impact for a function node.
        *   If the number of affected *distinct code communities* is high (e.g., > 3-4) relative to the total number of directly affected nodes, it's a strong indicator. This signifies that a change to this function ripples across many unrelated parts of the system.
    3.  Rule 2 (Optional, from Version Control if integrated): High historical churn rate for this function and its impacted downstream nodes.
*   **Confidence:** Based on the ratio of affected communities to affected nodes and the spread of impact.    
*   **Rule Example (Conceptual):**
    ```elixir
    %Rule{
      type: :custom_cpg,
      condition: fn cpg_node_data, cpg_context ->
        impact_report = CPGSemantics.dependency_impact_analysis(cpg_context.full_cpg, cpg_node_data.id, depth: 2)
        affected_communities = CPGSemantics.get_communities_for_nodes(cpg_context.full_cpg, impact_report.downstream_nodes)
        
        # High number of distinct affected communities for a moderate number of affected nodes
        length(impact_report.downstream_nodes) > 5 && length(Enum.uniq(affected_communities)) > 3
      end
    }
    ```

### 4.3. Feature Envy (between modules/components)

*   **PRD Link:** FR4.2
*   **Detection Logic:**
    1.  Consider CPG nodes representing functions.
    2.  For a function `F` in module `M1`, analyze its DFG edges (data dependencies) and call graph edges.
    3.  Count interactions (data access, function calls) with nodes belonging to `M1` versus nodes belonging to another module `M2`.
    4.  If `F` interacts significantly more with `M2`'s components than `M1`'s, it might be feature envy.
*   **CPG-Enhanced Detection Logic:**
    1.  Target: Function-level CPG nodes.
    2.  For a function CPG node `F_node` within module `M1_cpg_subgraph`:
        *   Rule 1 (`:custom_cpg_function`): Analyze outgoing CPG edges (call graph, data flow) from `F_node`.
        *   Count interactions (number of edges or sum of semantic edge weights) with nodes *within* `M1_cpg_subgraph`.
        *   Count interactions with nodes within *another specific* module's CPG subgraph, say `M2_cpg_subgraph`.
        *   If interactions with `M2` are significantly higher (e.g., > 2x) than with `M1`, it's a candidate.
    3.  Rule 2 (`CPGSemantics.identify_coupling`): High coupling strength between `F_node` and nodes in `M2`.
*   **Confidence:** Higher if the ratio of external to internal interactions is large.
*   **Rule Example (Conceptual):**
    ```elixir
    %Rule{
      type: :custom_cpg,
      condition: fn function_cpg_node, cpg_context ->
        # Get owning module for function_cpg_node
        # Get DFG/call edges from function_cpg_node
        # Count internal vs. external interactions (e.g., to a specific other module)
        # Return true if external_interactions_M2 > internal_interactions_M1 * threshold
        false # Placeholder
      end
    }
    ```

### 4.4. Circular Dependencies (Module/Function Level)

*   **PRD Link:** FR4.3
*   **Detection Logic:**
    1.  Build a dependency graph from CPG call edges (function-level) or abstracted module-level dependencies.
    2.  Run `CPGMath.strongly_connected_components/1` on this dependency graph.
    3.  Any SCC with more than one node represents a circular dependency.
*   **CPG-Enhanced Detection Logic:**
    1.  Target: Module-level or Function-level dependency graph derived from CPG call edges.
    2.  Rule 1 (`:custom_cpg_function` using `CPGMath.strongly_connected_components`):
        *   Execute SCC algorithm on the relevant dependency graph.
        *   Any SCC with size > 1 indicates a cycle.
    3.  Severity can be based on the size of the SCC or the "criticality" (e.g., PageRank) of nodes involved in the cycle.
*   **Confidence:** 1.0 (High) if an SCC > 1 is found, as this is a direct structural property.
*   **Rule Example (Conceptual):**
    ```elixir
    %Rule{
      type: :cpg_scc_membership,
      scc_min_size: 2, # Part of a cycle of 2 or more nodes
      applies_to: :module_dependency_graph # Or :function_call_graph
    }
    ```

### 4.5. Unstable Abstraction / High-Traffic Bridge

*   **Detection Logic:**
    1.  Identify nodes with high Betweenness Centrality (they act as bridges).
    2.  If such a "bridge" node also has a high churn rate (from version control, if available) or low test coverage (if available), it's an unstable abstraction.
    3.  If a bridge node is part of many critical semantic paths, it's a high-traffic bridge.
*   **Rule Example (Conceptual - for high-traffic bridge):**
    ```elixir
    %Rule{
      type: :cpg_node_property,
      property: :centrality_betweenness,
      operator: :gt_percentile,
      value: 0.90
    },
    %Rule{
      type: :custom_cpg,
      condition: fn cpg_node_data, cpg_context ->
        # Query how many semantic_critical_paths pass through cpg_node_data.id
        # path_count > threshold
        false # Placeholder
      end
    }
    ```
### 4.6. Data Sink without Sanitization (Taint Analysis based)

*   **Detection Logic:**
    1.  Target: Data Flow paths within CPG.
    2.  Rule 1 (`:cpg_path_check` using `CPGSemantics.trace_data_flow_semantic`):
        *   Identify "source" CPG nodes (e.g., user input, external API response).
        *   Identify "sink" CPG nodes (e.g., database query execution, `System.cmd` call, render to HTML).
        *   Trace data flow paths from sources to sinks.
    3.  Rule 2 (`:custom_cpg_function`): For each path found, check if it passes through a "sanitization" CPG node (e.g., call to an input validation function, HTML escaping function).
    4.  If a path from source to sink exists *without* passing through a sanitizer, flag as a potential vulnerability.
*   **Confidence:** High if direct path without sanitization is found. Medium if sanitization is present but deemed weak by other rules.

## 5. Implementation within `PatternMatcher`

*   **Pattern Definition Storage (`@pattern_library`):** Store the enhanced pattern definitions, including CPG-specific rule types.
*   **Main Matching Logic (`match_*_internal` functions):**
    1.  For each module/function, retrieve its `CPGData.t()` from `EnhancedRepository`. This should ideally include pre-computed metrics like centrality and community info if available (or compute them on-demand via `CPGMath`/`CPGSemantics` and cache them).
    2.  Iterate through registered patterns.
    3.  For each pattern, evaluate its list of `rules`:
        *   Dispatch to existing AST/DFG rule evaluators.
        *   For CPG rules:
            *   Access properties directly from the CPG node data (if available).
            *   Call `CPGMath` or `CPGSemantics` functions with the `CPGData.t()` and relevant CPG node IDs or parameters.
            *   Evaluate custom CPG functions.
    4.  Combine rule outcomes to calculate a confidence score for the pattern match.
    5.  If confidence meets the threshold, create a `pattern_match` result struct.
*   **Caching (`@table_name` - analysis_cache):** Cache the results of pattern matching for a given module/function and CPG version to avoid re-computation if the CPG hasn't changed. The cache key should include a CPG checksum or version.

## 6. Implementation Considerations


*   **Performance**: Computing graph algorithms can be expensive. Results should be cached effectively (`MemoryManager`, `CPGData`'s metadata). Lazy computation or incremental updates for algorithmic results will be crucial.
*   **Threshold Tuning**: Many graph-based pattern detections will rely on thresholds (e.g., "high centrality"). These thresholds may need to be configurable or adapt dynamically to project size/characteristics.
*   **Contextual Interpretation**: Raw graph metrics need semantic interpretation. For example, a highly central node isn't always bad; it could be a well-designed core utility. `CPGSemantics` plays a key role here.
*   **Combining Evidence**: Pattern confidence will increase if multiple rules (AST-based, DFG-based, CPG-algorithmic) corroborate a finding. The `PatternMatcher` should support weighting and combining evidence from different sources.

---

## 7. Performance Considerations

*   **Lazy Computation**: Algorithmic CPG properties (centrality, communities) should ideally be computed lazily by `CPGMath`/`CPGSemantics` and cached (either in `CPGData.metadata` or `MemoryManager`). `PatternMatcher` requests them as needed.
*   **Batch Analysis**: When analyzing a whole project, `PatternMatcher` could process modules/functions in batches, loading their CPGs and computing necessary global metrics (like percentile thresholds for centrality) once per batch.
*   **Rule Ordering**: Within a pattern definition, computationally cheaper rules (e.g., AST checks) should be evaluated before expensive CPG algorithmic rules to allow for early exit.

By integrating CPG algorithmic insights, `PatternMatcher` will evolve from a syntax-aware tool to a deeply semantic and structural code analysis engine.

---