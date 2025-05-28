defmodule ElixirScope.ASTRepository.Enhanced.CPGData do
  @moduledoc """
  Code Property Graph (CPG) that unifies AST, CFG, and DFG representations.

  A CPG provides a unified view of code structure by combining:
  - Syntax (AST): What the code looks like
  - Control Flow (CFG): How execution flows
  - Data Flow (DFG): How data moves through the code

  This enables powerful queries that span multiple dimensions of code analysis.
  """
  
  alias ElixirScope.ASTRepository.Enhanced.{CFGData, DFGData, OptimizationHint}
  
  defstruct [
    :function_key,          # {module, function, arity}
    :nodes,                 # %{node_id => CPGNode.t()}
    :edges,                 # [CPGEdge.t()]
    :node_mappings,         # Cross-references between AST/CFG/DFG nodes
    :query_indexes,         # Optimized indexes for common queries
    :source_graphs,         # %{:cfg => CFGData.t(), :dfg => DFGData.t()}
    :unified_analysis,      # UnifiedAnalysis.t() - Cross-cutting analysis
    :metadata,              # Additional metadata
    # Test compatibility fields
    :control_flow_graph,    # Direct reference to CFG
    :data_flow_graph,       # Direct reference to DFG
    :unified_nodes,         # Unified nodes map
    :unified_edges,         # Unified edges list
    :complexity_metrics,    # Complexity analysis
    :path_sensitive_analysis, # Path analysis
    :security_analysis,     # Security analysis
    :alias_analysis,        # Alias analysis
    :performance_analysis,  # Performance analysis
    :information_flow_analysis, # Information flow analysis
    :code_quality_analysis  # Code quality analysis
  ]
  
  @type t :: %__MODULE__{
    function_key: {module(), atom(), non_neg_integer()},
    nodes: %{String.t() => CPGNode.t()},
    edges: [CPGEdge.t()],
    node_mappings: NodeMappings.t(),
    query_indexes: QueryIndexes.t(),
    source_graphs: %{atom() => term()},
    unified_analysis: UnifiedAnalysis.t(),
    metadata: map(),
    # Test compatibility fields
    control_flow_graph: term(),
    data_flow_graph: term(),
    unified_nodes: term(),
    unified_edges: term(),
    complexity_metrics: term(),
    path_sensitive_analysis: term(),
    security_analysis: term(),
    alias_analysis: term(),
    performance_analysis: term(),
    information_flow_analysis: term(),
    code_quality_analysis: term()
  }
end

defmodule ElixirScope.ASTRepository.Enhanced.CPGNode do
  @moduledoc """
  Unified node in the Code Property Graph.
  
  Combines information from AST, CFG, and DFG representations.
  """

  defstruct [
    :id,                    # Unique node identifier
    :type,                  # Node type (:unified, :cfg_only, :dfg_only)
    :ast_node_id,           # Reference to AST node
    :cfg_node_id,           # Reference to CFG node
    :dfg_node_id,           # Reference to DFG node
    :line,                  # Source line number
    :scope_id,              # Scope identifier
    :expression,            # AST expression
    :control_flow_info,     # Control flow specific data
    :data_flow_info,        # Data flow specific data
    :unified_properties,    # Properties derived from unification
    :metadata               # Additional metadata
  ]

  @type t :: %__MODULE__{
    id: String.t(),
    type: atom(),
    ast_node_id: String.t() | nil,
    cfg_node_id: String.t() | nil,
    dfg_node_id: String.t() | nil,
    line: non_neg_integer(),
    scope_id: String.t(),
    expression: term(),
    control_flow_info: map(),
    data_flow_info: map(),
    unified_properties: map(),
    metadata: map()
  }
end

defmodule ElixirScope.ASTRepository.Enhanced.CPGEdge do
  @moduledoc """
  Unified edge in the Code Property Graph.
  
  Represents relationships between nodes across different graph dimensions.
  """

  defstruct [
    :id,                    # Unique edge identifier
    :from_node_id,          # Source node
    :to_node_id,            # Target node
    :type,                  # Edge type (:control_flow, :data_flow, :unified)
    :subtype,               # Edge subtype (specific to graph type)
    :condition,             # Optional condition
    :probability,           # Edge probability
    :source_graph,          # Which graph this edge comes from
    :unified_properties,    # Properties derived from unification
    :metadata               # Additional metadata
  ]

  @type t :: %__MODULE__{
    id: String.t(),
    from_node_id: String.t(),
    to_node_id: String.t(),
    type: atom(),
    subtype: atom(),
    condition: term() | nil,
    probability: float(),
    source_graph: atom(),
    unified_properties: map(),
    metadata: map()
  }
end

defmodule ElixirScope.ASTRepository.Enhanced.NodeMappings do
  @moduledoc """
  Cross-references between AST, CFG, and DFG nodes.
  """

  defstruct [
    :ast_to_cfg,            # %{ast_node_id => [cfg_node_id]}
    :ast_to_dfg,            # %{ast_node_id => [dfg_node_id]}
    :cfg_to_dfg,            # %{cfg_node_id => [dfg_node_id]}
    :dfg_to_cfg,            # %{dfg_node_id => [cfg_node_id]}
    :unified_mappings,      # %{unified_node_id => %{ast: id, cfg: id, dfg: id}}
    :reverse_mappings       # Reverse lookup tables
  ]

  @type t :: %__MODULE__{
    ast_to_cfg: %{String.t() => [String.t()]},
    ast_to_dfg: %{String.t() => [String.t()]},
    cfg_to_dfg: %{String.t() => [String.t()]},
    dfg_to_cfg: %{String.t() => [String.t()]},
    unified_mappings: %{String.t() => map()},
    reverse_mappings: map()
  }
end

defmodule ElixirScope.ASTRepository.Enhanced.QueryIndexes do
  @moduledoc """
  Optimized indexes for common CPG queries.
  """

  defstruct [
    :by_type,               # %{node_type => [node_id]}
    :by_line,               # %{line_number => [node_id]}
    :by_scope,              # %{scope_id => [node_id]}
    :by_variable,           # %{variable_name => [node_id]}
    :by_function_call,      # %{function_name => [node_id]}
    :control_flow_paths,    # Precomputed control flow paths
    :data_flow_chains,      # Precomputed data flow chains
    :pattern_indexes        # Indexes for common patterns
  ]

  @type t :: %__MODULE__{
    by_type: %{atom() => [String.t()]},
    by_line: %{non_neg_integer() => [String.t()]},
    by_scope: %{String.t() => [String.t()]},
    by_variable: %{String.t() => [String.t()]},
    by_function_call: %{String.t() => [String.t()]},
    control_flow_paths: map(),
    data_flow_chains: map(),
    pattern_indexes: map()
  }
end

defmodule ElixirScope.ASTRepository.Enhanced.UnifiedAnalysis do
  @moduledoc """
  Cross-cutting analysis results that span multiple graph dimensions.
  """

  defstruct [
    :security_analysis,     # SecurityAnalysis.t() - Security vulnerabilities
    :performance_analysis,  # PerformanceAnalysis.t() - Performance issues
    :quality_analysis,      # QualityAnalysis.t() - Code quality metrics
    :complexity_analysis,   # ComplexityAnalysis.t() - Unified complexity
    :pattern_analysis,      # PatternAnalysis.t() - Code patterns
    :dependency_analysis,   # DependencyAnalysis.t() - Dependencies
    :information_flow,      # InformationFlow.t() - Information flow tracking
    :alias_analysis,        # AliasAnalysis.t() - Alias analysis
    :optimization_hints     # [OptimizationHint.t()] - Optimization opportunities
  ]

  @type t :: %__MODULE__{
    security_analysis: SecurityAnalysis.t(),
    performance_analysis: PerformanceAnalysis.t(),
    quality_analysis: QualityAnalysis.t(),
    complexity_analysis: ComplexityAnalysis.t(),
    pattern_analysis: PatternAnalysis.t(),
    dependency_analysis: DependencyAnalysis.t(),
    information_flow: InformationFlow.t(),
    alias_analysis: AliasAnalysis.t(),
    optimization_hints: [OptimizationHint.t()]
  }
end

# Supporting analysis structures
defmodule ElixirScope.ASTRepository.Enhanced.SecurityAnalysis do
  defstruct [:vulnerabilities, :risk_level, :security_patterns, :recommendations]
  @type t :: %__MODULE__{vulnerabilities: [map()], risk_level: atom(), security_patterns: [map()], recommendations: [String.t()]}
end

defmodule ElixirScope.ASTRepository.Enhanced.PerformanceAnalysis do
  defstruct [:bottlenecks, :optimization_opportunities, :performance_risks, :metrics]
  @type t :: %__MODULE__{bottlenecks: [map()], optimization_opportunities: [map()], performance_risks: [map()], metrics: map()}
end

defmodule ElixirScope.ASTRepository.Enhanced.QualityAnalysis do
  defstruct [:code_smells, :maintainability_score, :readability_score, :quality_metrics]
  @type t :: %__MODULE__{code_smells: [map()], maintainability_score: float(), readability_score: float(), quality_metrics: map()}
end

defmodule ElixirScope.ASTRepository.Enhanced.ComplexityAnalysis do
  defstruct [:unified_complexity, :complexity_distribution, :hotspots, :trends]
  @type t :: %__MODULE__{unified_complexity: float(), complexity_distribution: map(), hotspots: [map()], trends: map()}
end

defmodule ElixirScope.ASTRepository.Enhanced.PatternAnalysis do
  defstruct [:detected_patterns, :anti_patterns, :design_patterns, :pattern_metrics]
  @type t :: %__MODULE__{detected_patterns: [map()], anti_patterns: [map()], design_patterns: [map()], pattern_metrics: map()}
end

defmodule ElixirScope.ASTRepository.Enhanced.InformationFlow do
  defstruct [:flow_paths, :sensitive_flows, :flow_violations, :flow_metrics]
  @type t :: %__MODULE__{flow_paths: [map()], sensitive_flows: [map()], flow_violations: [map()], flow_metrics: map()}
end

defmodule ElixirScope.ASTRepository.Enhanced.AliasAnalysis do
  defstruct [:aliases, :alias_chains, :alias_conflicts, :alias_metrics]
  @type t :: %__MODULE__{aliases: [map()], alias_chains: [map()], alias_conflicts: [map()], alias_metrics: map()}
end

 