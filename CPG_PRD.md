# Product Requirements Document: ElixirScope CPG Algorithmic Enhancement Layer

**Version:** 1.0
**Date:** May 28, 2025
**Status:** Proposed
**Owner:** ElixirScope Product Team

## 1. Introduction

ElixirScope currently possesses a functional Code Property Graph (CPG) that unifies AST, CFG, and DFG representations, providing a rich semantic understanding of Elixir code. This project aims to build a new "Algorithmic Enhancement Layer" on top of this existing CPG foundation. The goal is to significantly elevate ElixirScope's analytical power by integrating advanced graph algorithms, making them "code-aware," and exposing these new insights through enhanced querying and pattern detection capabilities. This layer will also introduce sophisticated performance and memory optimizations specific to CPG management, paving the way for future AI/ML integrations and truly revolutionary debugging and code intelligence features.

## 2. Goals

*   **Goal 1: Enhance Analytical Depth:** Introduce mathematical rigor and new analytical dimensions to the existing CPG by applying formal graph algorithms.
*   **Goal 2: Improve Code Understanding:** Enable deeper insights into code structure, dependencies, architectural health, and potential issues through code-aware algorithmic analysis.
*   **Goal 3: Expand Querying Power:** Allow users and AI components to perform more sophisticated queries that leverage complex graph relationships and derived algorithmic metrics.
*   **Goal 4: Boost Pattern Detection:** Implement advanced pattern and anti-pattern detection techniques that utilize graph-theoretic properties.
*   **Goal 5: Optimize CPG Performance & Scalability:** Introduce CPG-specific optimizations for performance, memory usage, and incremental updates to handle large-scale projects efficiently.
*   **Goal 6: Strengthen AI/ML Foundation:** Provide a richer, more structured data foundation for current and future AI/ML-driven features, such as predictive debugging and semantic code search.

## 3. Target Users & Use Cases

*   **Developers (All Levels):**
    *   **Use Case:** Understand complex codebases faster by visualizing critical paths, identifying architectural bottlenecks (e.g., god objects via centrality), and exploring code communities.
    *   **Use Case:** Receive more precise and actionable refactoring suggestions based on deep dependency and impact analysis.
    *   **Use Case:** Debug complex issues by tracing semantic paths and understanding data flow implications identified by graph algorithms.
*   **Architects & Tech Leads:**
    *   **Use Case:** Analyze architectural health, detect violations of design principles (e.g., dependency inversion), and identify high-impact areas for refactoring.
    *   **Use Case:** Assess the potential impact of changes across the codebase using graph-based dependency analysis.
    *   **Use Case:** Monitor architectural debt and identify "shotgun surgery" candidates.
*   **ElixirScope AI Components (Internal Users):**
    *   **Use Case:** `PredictiveAnalyzer` uses centrality metrics, path complexities, and community data as features for more accurate predictions.
    *   **Use Case:** `PatternRecognizer` leverages graph-theoretic properties (e.g., centrality, connectivity) for more robust detection of complex patterns and anti-patterns.
    *   **Use Case:** `ASTEmbeddings` (future) can use graph-structural features identified by algorithms to create richer embeddings.
*   **ElixirScope UI/IDE Integration (Future):**
    *   **Use Case:** Visually represent code communities, critical paths, and centrality hotspots directly in the IDE or ElixirScope UI.
    *   **Use Case:** Provide interactive exploration of dependency chains and impact analysis.

## 4. Requirements & Features

This enhancement focuses on the following key areas:

### 4.1. Formalized Graph Algorithm Layer (`CPGMath`, `CPGSemantics`)

*   **FR1.1 (Mathematical Graph Algorithms - `CPGMath`):**
    Implement or integrate capabilities to perform standard graph algorithms on the CPG data:
    *   Strongly Connected Components (for cycle detection).
    *   Topological Sort.
    *   Shortest/Longest Path calculations (as a basis for semantic paths).
    *   Centrality Measures: Degree, Betweenness, Closeness, Eigenvector, PageRank.
    *   Community Detection: Modularity-based (e.g., Louvain), Label Propagation.
*   **FR1.2 (Code-Aware Semantic Algorithms - `CPGSemantics`):**
    Develop algorithms that adapt mathematical graph computations with code-specific semantics:
    *   **Semantic Shortest/Critical Path:** Paths weighted by factors like control flow probability, data dependency strength, node complexity, security risk propagation.
    *   **Dependency Impact Analysis:** Identify upstream and downstream nodes affected by a change to a specific CPG node, considering different relationship types (call, data, control).
    *   **Architectural Debt Analysis:** Utilize centrality and community detection results to identify potential architectural issues (e.g., god objects, poor cohesion, high coupling).

### 4.2. Code-Aware Algorithm Adaptations

*   **FR2.1 (Semantic Edge Weights):**
    Implement a system for calculating dynamic, semantic weights for CPG edges based on edge type (AST, CFG, DFG, call), node properties (complexity, security risk, performance profile of connected nodes), and query context.
*   **FR2.2 (Contextual Heuristics):**
    Allow graph algorithms to incorporate heuristics based on Elixir-specific code constructs (e.g., OTP patterns, macro expansions) when evaluating paths or node importance.

### 4.3. Expanded Query Capabilities

*   **FR3.1 (Algorithmic Query Types):**
    Extend the `QueryBuilder` and `QueryExecutor` (or `ASTExtensions`) to support new query types that invoke the CPG algorithms:
    *   `{:impact_analysis, node_id, opts}`
    *   `{:architectural_smells, opts}`
    *   `{:critical_path, from_node, to_node, opts}`
    *   `{:community_analysis, opts}`
    *   `{:centrality_analysis, metric_type, opts}`
*   **FR3.2 (Querying Derived Metrics):**
    Enable querying on metrics derived from graph algorithms (e.g., "find all functions with betweenness centrality > X").

### 4.4. Advanced Graph-Theoretic Pattern Detection

*   **FR4.1 (Centrality-Based Pattern Detection):**
    Implement detection for patterns like "God Objects" by identifying CPG nodes with disproportionately high centrality scores (e.g., betweenness, degree).
*   **FR4.2 (Connectivity-Based Pattern Detection):**
    *   Implement detection for patterns like "Shotgun Surgery" by analyzing the impact scope (number of affected nodes) if a CPG node were changed.
    *   Detect "Feature Envy" by analyzing data flow edges between module/function CPG nodes to identify functions that interact more with external data/logic than their own.
*   **FR4.3 (Cycle-Based Pattern Detection):**
    Utilize Strongly Connected Components to robustly detect circular dependencies at various levels (module, function call).

### 4.5. CPG Performance & Memory Optimization Strategies

*   **FR5.1 (Incremental CPG Updates):**
    Design and implement mechanisms within `CPGBuilder` and `Repository` (potentially via `Synchronizer`) to update the CPG incrementally when source code changes, rather than full CPG rebuilds. This includes updating only affected nodes, edges, and derived algorithmic results.
*   **FR5.2 (CPG Query Optimizer):**
    Develop a `CPGOptimizer` component that analyzes CPG query specifications and chooses an optimal execution strategy (e.g., index-guided search, specific graph traversal algorithms).
*   **FR5.3 (Memory-Efficient CPG Representations):**
    Investigate and implement strategies for compact CPG storage if needed for very large projects, such as:
    *   Interning common strings within CPG node/edge properties.
    *   Compressing less frequently accessed parts of node/edge data.
    *   (Future) Node paging or offloading parts of the CPG to disk.
*   **FR5.4 (Algorithmic Result Caching):**
    Implement caching for the results of computationally expensive graph algorithms (e.g., centrality, community detection) with appropriate invalidation strategies (e.g., invalidate on CPG structural changes). This can be part of the `CPGData` structure (`:path_cache`) or managed by `MemoryManager`.

### 4.6. Foundation for Future AI/ML & Advanced Tooling

*   **FR6.1 (Rich Feature Extraction):**
    Ensure that the CPG and the results from the new algorithmic layer provide a rich set of features suitable for consumption by AI/ML models (e.g., graph structural features, centrality scores, path complexities, community membership).
*   **FR6.2 (Stable Identifiers):**
    Reinforce the stability and utility of CPG node/edge identifiers for linking to external AI models or knowledge bases.

## 5. Non-Functional Requirements

*   **NFR1 (Performance):**
    *   Centrality calculations for a medium project CPG (<1000 modules): < 5 seconds.
    *   Semantic pathfinding between two functions in a large module: < 500ms.
    *   Incremental CPG update for a single file change: < 1 second added to current sync time.
*   **NFR2 (Scalability):**
    *   The system should handle CPGs for projects up to 1 million LOC with the described algorithms.
    *   Memory usage for the stored algorithmic results should be manageable (e.g., < 20% increase over base CPG storage for typical analyses).
*   **NFR3 (Accuracy):**
    *   Graph algorithms (shortest path, SCC) should be correctly implemented.
    *   Code-aware heuristics should demonstrably improve the relevance of results compared to generic graph algorithms.
*   **NFR4 (Extensibility):**
    *   The algorithmic layer should be designed to allow for the addition of new graph algorithms and semantic interpretations in the future.

## 6. Future Considerations (Out of Scope for this PRD, but informed by it)

*   Full implementation of GNN-based features.
*   Real-time IDE integration leveraging incremental CPG updates and semantic queries.
*   Plugin system for custom CPG analyses.
*   Distributed CPGs and cross-repository analysis.

## 7. Open Questions

*   Which specific graph library (if any) should be used as a reference or for primitive operations within `CPGMath` (e.g., for highly optimized SCC or PageRank implementations if building from scratch is too slow)? Current recommendation is to adapt ideas, not directly use existing Elixir graph libraries unless they meet performance and CPG integration needs.
*   What is the precise strategy for caching and invalidating results of expensive graph algorithms (e.g., full centrality recalculation vs. incremental updates on CPG changes)?
*   How will the "semantic weights" for code-aware algorithms be configured and tuned?

---
