defmodule ElixirScope.ASTRepository.Enhanced.DFGData do
  @moduledoc """
  Enhanced Data Flow Graph representation for Elixir code.

  Uses Static Single Assignment (SSA) form to handle Elixir's
  immutable variable semantics and pattern matching.
  """

  defstruct [
    :function_key,          # {module, function, arity}
    :variables,             # %{variable_name => [VariableVersion.t()]}
    :definitions,           # [Definition.t()] - Variable definitions
    :uses,                  # [Use.t()] - Variable uses
    :data_flows,            # [DataFlow.t()] - Data flow edges
    :phi_nodes,             # [PhiNode.t()] - SSA merge points
    :scopes,                # %{scope_id => ScopeInfo.t()}
    :analysis_results,      # Analysis results
    :metadata,              # Additional metadata
    
    # Additional fields expected by tests (for backward compatibility)
    :nodes,                 # [DFGNode.t()] - Graph nodes as list
    :edges,                 # [DFGEdge.t()] - Graph edges
    :nodes_map,             # %{node_id => DFGNode.t()} - Graph nodes as map for map_size
    :mutations,             # [Mutation.t()] - Variable mutations/rebindings
    :complexity_score,      # float() - Overall complexity score
    :variable_lifetimes,    # %{variable => lifetime_info} - Variable lifetimes
    :unused_variables,      # [VariableVersion.t()] - Unused variables
    :shadowed_variables,    # [ShadowInfo.t()] - Variable shadowing
    :captured_variables,    # [VariableVersion.t()] - Closure captures
    :optimization_hints,    # [OptimizationHint.t()] - Optimization opportunities
    :fan_in,                # integer() - Variables with multiple inputs
    :fan_out,               # integer() - Variables with multiple outputs
    :depth,                 # integer() - Dependency chain depth
    :width,                 # integer() - Parallel data flows
    :data_flow_complexity,  # integer() - Overall data flow complexity
    :variable_complexity    # integer() - Variable interaction complexity
  ]

  @type t :: %__MODULE__{
    function_key: {module(), atom(), non_neg_integer()},
    variables: %{String.t() => [VariableVersion.t()]},
    definitions: [Definition.t()],
    uses: [Use.t()],
    data_flows: [DataFlow.t()],
    phi_nodes: [PhiNode.t()],
    scopes: %{String.t() => ScopeInfo.t()},
    analysis_results: AnalysisResults.t(),
    metadata: map(),
    
    # Additional fields for test compatibility
    nodes: [DFGNode.t()],
    edges: [DFGEdge.t()],
    nodes_map: %{String.t() => DFGNode.t()},
    mutations: [Mutation.t()],
    complexity_score: float(),
    variable_lifetimes: %{String.t() => LifetimeInfo.t()},
    unused_variables: [VariableVersion.t()],
    shadowed_variables: [ShadowInfo.t()],
    captured_variables: [VariableVersion.t()],
    optimization_hints: [OptimizationHint.t()],
    fan_in: non_neg_integer(),
    fan_out: non_neg_integer(),
    depth: non_neg_integer(),
    width: non_neg_integer(),
    data_flow_complexity: non_neg_integer(),
    variable_complexity: non_neg_integer()
  }
end

defmodule ElixirScope.ASTRepository.Enhanced.VariableVersion do
  @moduledoc """
  Versioned variable in SSA form.

  Each variable assignment creates a new version.
  Example: x, x_1, x_2, etc.
  """

  defstruct [
    :name,                  # Original variable name
    :version,               # Version number (0, 1, 2, ...)
    :ssa_name,              # SSA name (e.g., "x_1")
    :scope_id,              # Scope where defined
    :definition_node,       # AST node where defined
    :type_info,             # Inferred type information
    :is_parameter,          # Is this a function parameter?
    :is_captured,           # Is this variable captured in closure?
    :metadata               # Additional metadata
  ]

  @type t :: %__MODULE__{
    name: String.t(),
    version: non_neg_integer(),
    ssa_name: String.t(),
    scope_id: String.t(),
    definition_node: String.t(),
    type_info: TypeInfo.t() | nil,
    is_parameter: boolean(),
    is_captured: boolean(),
    metadata: map()
  }
end

defmodule ElixirScope.ASTRepository.Enhanced.Definition do
  @moduledoc """
  Variable definition point in the data flow graph.
  """

  defstruct [
    :variable,              # VariableVersion.t()
    :ast_node_id,           # AST node where defined
    :definition_type,       # Type of definition (see @definition_types)
    :source_expression,     # AST of the defining expression
    :line,                  # Source line number
    :scope_id,              # Scope identifier
    :reaching_definitions,  # [Definition.t()] - Definitions that reach here
    :metadata               # Additional metadata
  ]

  @type t :: %__MODULE__{
    variable: VariableVersion.t(),
    ast_node_id: String.t(),
    definition_type: atom(),
    source_expression: term(),
    line: non_neg_integer(),
    scope_id: String.t(),
    reaching_definitions: [t()],
    metadata: map()
  }

  @definition_types [
    :assignment,            # x = value
    :parameter,             # Function parameter
    :pattern_match,         # Pattern match in case/function head
    :comprehension,         # Variable in comprehension
    :catch_variable,        # Exception variable in catch/rescue
    :receive_variable       # Variable bound in receive
  ]

  def definition_types, do: @definition_types
end

defmodule ElixirScope.ASTRepository.Enhanced.Use do
  @moduledoc """
  Variable use point in the data flow graph.
  """

  defstruct [
    :variable,              # VariableVersion.t()
    :ast_node_id,           # AST node where used
    :use_type,              # Type of use (see @use_types)
    :context,               # Usage context
    :line,                  # Source line number
    :scope_id,              # Scope identifier
    :reaching_definition,   # Definition.t() that reaches this use
    :metadata               # Additional metadata
  ]

  @type t :: %__MODULE__{
    variable: VariableVersion.t(),
    ast_node_id: String.t(),
    use_type: atom(),
    context: term(),
    line: non_neg_integer(),
    scope_id: String.t(),
    reaching_definition: Definition.t(),
    metadata: map()
  }

  @use_types [
    :read,                  # Variable value read
    :pattern_match,         # Variable used in pattern
    :guard,                 # Variable used in guard
    :function_call,         # Variable passed to function
    :pipe_operation,        # Variable in pipe chain
    :message_send,          # Variable sent as message
    :closure_capture        # Variable captured in closure
  ]

  def use_types, do: @use_types
end

defmodule ElixirScope.ASTRepository.Enhanced.DataFlow do
  @moduledoc """
  Data flow edge connecting definition to use.
  """

  defstruct [
    :from_definition,       # Definition.t()
    :to_use,                # Use.t()
    :flow_type,             # Type of data flow (see @flow_types)
    :path_condition,        # Condition for this flow to occur
    :probability,           # Flow probability (0.0-1.0)
    :transformation,        # Any transformation applied to data
    :metadata               # Additional metadata
  ]

  @type t :: %__MODULE__{
    from_definition: Definition.t(),
    to_use: Use.t(),
    flow_type: atom(),
    path_condition: term() | nil,
    probability: float(),
    transformation: term() | nil,
    metadata: map()
  }

  @flow_types [
    :direct,                # Direct assignment flow
    :conditional,           # Flow through conditional
    :pattern_match,         # Flow through pattern match
    :pipe_transform,        # Flow through pipe operation
    :function_return,       # Flow from function return
    :closure_capture,       # Flow into closure
    :message_pass,          # Flow through message passing
    :destructuring          # Flow through destructuring assignment
  ]

  def flow_types, do: @flow_types
end

defmodule ElixirScope.ASTRepository.Enhanced.PhiNode do
  @moduledoc """
  SSA Phi node for merging variable versions at control flow merge points.

  Example: After if-else, variables may have different versions
  that need to be merged.
  """

  defstruct [
    :target_variable,       # VariableVersion.t() - Result of phi
    :source_variables,      # [VariableVersion.t()] - Input versions
    :merge_point,           # AST node ID where merge occurs
    :conditions,            # [condition] - Conditions for each source
    :scope_id,              # Scope where merge occurs
    :metadata               # Additional metadata
  ]

  @type t :: %__MODULE__{
    target_variable: VariableVersion.t(),
    source_variables: [VariableVersion.t()],
    merge_point: String.t(),
    conditions: [term()],
    scope_id: String.t(),
    metadata: map()
  }
end

# ScopeInfo is defined in shared_data_structures.ex
alias ElixirScope.ASTRepository.Enhanced.ScopeInfo

defmodule ElixirScope.ASTRepository.Enhanced.AnalysisResults do
  @moduledoc """
  Results of data flow analysis.
  """

  defstruct [
    :variable_lifetimes,     # %{variable => lifetime_info}
    :unused_variables,       # [VariableVersion.t()] - Unused variables
    :shadowed_variables,     # [ShadowInfo.t()] - Variable shadowing
    :captured_variables,     # [VariableVersion.t()] - Closure captures
    :optimization_hints,     # [OptimizationHint.t()] - Optimization opportunities
    :complexity_metrics,     # DataFlowComplexity.t() - Complexity metrics
    :dependency_analysis,    # DependencyAnalysis.t() - Variable dependencies
    :mutation_analysis,      # MutationAnalysis.t() - Mutation tracking
    :performance_analysis    # PerformanceAnalysis.t() - Performance insights
  ]

  @type t :: %__MODULE__{
    variable_lifetimes: %{String.t() => LifetimeInfo.t()},
    unused_variables: [VariableVersion.t()],
    shadowed_variables: [ShadowInfo.t()],
    captured_variables: [VariableVersion.t()],
    optimization_hints: [OptimizationHint.t()],
    complexity_metrics: DataFlowComplexity.t(),
    dependency_analysis: DependencyAnalysis.t(),
    mutation_analysis: MutationAnalysis.t(),
    performance_analysis: PerformanceAnalysis.t()
  }
end

defmodule ElixirScope.ASTRepository.Enhanced.TypeInfo do
  @moduledoc """
  Type information for variables (inferred or annotated).
  """

  defstruct [
    :type,                   # Inferred or declared type
    :constraints,            # Type constraints
    :source,                 # How type was determined
    :confidence,             # Confidence level (0.0-1.0)
    :metadata                # Additional type metadata
  ]

  @type t :: %__MODULE__{
    type: term(),
    constraints: [term()],
    source: atom(),
    confidence: float(),
    metadata: map()
  }
end

defmodule ElixirScope.ASTRepository.Enhanced.ShadowInfo do
  @moduledoc """
  Information about variable shadowing.
  """

  defstruct [
    :shadowed_variable,      # VariableVersion.t() - Original variable
    :shadowing_variable,     # VariableVersion.t() - Shadowing variable
    :scope_context,          # Where shadowing occurs
    :potential_confusion,    # Risk of confusion
    :metadata                # Additional metadata
  ]

  @type t :: %__MODULE__{
    shadowed_variable: VariableVersion.t(),
    shadowing_variable: VariableVersion.t(),
    scope_context: String.t(),
    potential_confusion: atom(),
    metadata: map()
  }
end

defmodule ElixirScope.ASTRepository.Enhanced.OptimizationHint do
  @moduledoc """
  Optimization hints based on data flow analysis.
  """

  defstruct [
    :type,                   # Type of optimization
    :description,            # Human-readable description
    :variables_involved,     # [VariableVersion.t()] - Affected variables
    :potential_benefit,      # Estimated benefit
    :confidence,             # Confidence in hint (0.0-1.0)
    :metadata                # Additional metadata
  ]

  @type t :: %__MODULE__{
    type: atom(),
    description: String.t(),
    variables_involved: [VariableVersion.t()],
    potential_benefit: atom(),
    confidence: float(),
    metadata: map()
  }
end

defmodule ElixirScope.ASTRepository.Enhanced.DataFlowComplexity do
  @moduledoc """
  Data flow complexity metrics.
  """

  defstruct [
    :variable_count,         # Total number of variables
    :definition_count,       # Total number of definitions
    :use_count,              # Total number of uses
    :phi_node_count,         # Number of phi nodes
    :max_variable_versions,  # Maximum versions for any variable
    :scope_depth,            # Maximum scope nesting depth
    :data_flow_edges,        # Number of data flow edges
    :complexity_score        # Overall complexity score
  ]

  @type t :: %__MODULE__{
    variable_count: non_neg_integer(),
    definition_count: non_neg_integer(),
    use_count: non_neg_integer(),
    phi_node_count: non_neg_integer(),
    max_variable_versions: non_neg_integer(),
    scope_depth: non_neg_integer(),
    data_flow_edges: non_neg_integer(),
    complexity_score: float()
  }
end

defmodule ElixirScope.ASTRepository.Enhanced.DependencyAnalysis do
  @moduledoc """
  Variable dependency analysis results.
  """

  defstruct [
    :dependency_graph,       # %{variable => [dependencies]}
    :circular_dependencies,  # [CircularDependency.t()]
    :dependency_chains,      # [DependencyChain.t()]
    :critical_variables,     # [VariableVersion.t()] - High-impact variables
    :isolated_variables      # [VariableVersion.t()] - No dependencies
  ]

  @type t :: %__MODULE__{
    dependency_graph: %{String.t() => [String.t()]},
    circular_dependencies: [CircularDependency.t()],
    dependency_chains: [DependencyChain.t()],
    critical_variables: [VariableVersion.t()],
    isolated_variables: [VariableVersion.t()]
  }
end

defmodule ElixirScope.ASTRepository.Enhanced.MutationAnalysis do
  @moduledoc """
  Analysis of variable mutations (rebinding in Elixir context).
  """

  defstruct [
    :rebinding_points,       # [RebindingPoint.t()] - Where variables are rebound
    :mutation_frequency,     # %{variable => frequency}
    :mutation_patterns,      # [MutationPattern.t()] - Common patterns
    :potential_issues        # [MutationIssue.t()] - Potential problems
  ]

  @type t :: %__MODULE__{
    rebinding_points: [RebindingPoint.t()],
    mutation_frequency: %{String.t() => non_neg_integer()},
    mutation_patterns: [MutationPattern.t()],
    potential_issues: [MutationIssue.t()]
  }
end

defmodule ElixirScope.ASTRepository.Enhanced.PerformanceAnalysis do
  @moduledoc """
  Performance analysis based on data flow patterns.
  """

  defstruct [
    :memory_usage_patterns,  # [MemoryPattern.t()] - Memory usage patterns
    :computation_chains,     # [ComputationChain.t()] - Expensive computations
    :optimization_opportunities, # [OptimizationOpportunity.t()]
    :performance_risks       # [PerformanceRisk.t()] - Performance risks
  ]

  @type t :: %__MODULE__{
    memory_usage_patterns: [MemoryPattern.t()],
    computation_chains: [ComputationChain.t()],
    optimization_opportunities: [OptimizationOpportunity.t()],
    performance_risks: [PerformanceRisk.t()]
  }
end

# Supporting structures for analysis results
defmodule ElixirScope.ASTRepository.Enhanced.LifetimeInfo do
  defstruct [:start_line, :end_line, :scope_duration, :usage_frequency]
  @type t :: %__MODULE__{start_line: non_neg_integer(), end_line: non_neg_integer(), scope_duration: non_neg_integer(), usage_frequency: non_neg_integer()}
end

defmodule ElixirScope.ASTRepository.Enhanced.CircularDependency do
  defstruct [:variables, :cycle_length, :severity]
  @type t :: %__MODULE__{variables: [String.t()], cycle_length: non_neg_integer(), severity: atom()}
end

defmodule ElixirScope.ASTRepository.Enhanced.DependencyChain do
  defstruct [:variables, :chain_length, :complexity]
  @type t :: %__MODULE__{variables: [String.t()], chain_length: non_neg_integer(), complexity: float()}
end

defmodule ElixirScope.ASTRepository.Enhanced.RebindingPoint do
  defstruct [:variable, :old_version, :new_version, :ast_node_id, :reason]
  @type t :: %__MODULE__{variable: String.t(), old_version: VariableVersion.t(), new_version: VariableVersion.t(), ast_node_id: String.t(), reason: atom()}
end

defmodule ElixirScope.ASTRepository.Enhanced.MutationPattern do
  defstruct [:pattern_type, :frequency, :variables, :description]
  @type t :: %__MODULE__{pattern_type: atom(), frequency: non_neg_integer(), variables: [String.t()], description: String.t()}
end

defmodule ElixirScope.ASTRepository.Enhanced.MutationIssue do
  defstruct [:issue_type, :severity, :variables, :description, :suggestion]
  @type t :: %__MODULE__{issue_type: atom(), severity: atom(), variables: [String.t()], description: String.t(), suggestion: String.t()}
end

defmodule ElixirScope.ASTRepository.Enhanced.MemoryPattern do
  defstruct [:pattern_type, :variables, :estimated_impact, :description]
  @type t :: %__MODULE__{pattern_type: atom(), variables: [String.t()], estimated_impact: atom(), description: String.t()}
end

defmodule ElixirScope.ASTRepository.Enhanced.ComputationChain do
  defstruct [:variables, :operations, :estimated_cost, :optimization_potential]
  @type t :: %__MODULE__{variables: [String.t()], operations: [term()], estimated_cost: float(), optimization_potential: atom()}
end

defmodule ElixirScope.ASTRepository.Enhanced.OptimizationOpportunity do
  defstruct [:opportunity_type, :description, :variables, :estimated_benefit, :implementation_difficulty]
  @type t :: %__MODULE__{opportunity_type: atom(), description: String.t(), variables: [String.t()], estimated_benefit: atom(), implementation_difficulty: atom()}
end

defmodule ElixirScope.ASTRepository.Enhanced.PerformanceRisk do
  defstruct [:risk_type, :severity, :variables, :description, :mitigation]
  @type t :: %__MODULE__{risk_type: atom(), severity: atom(), variables: [String.t()], description: String.t(), mitigation: String.t()}
end

# Additional structs expected by tests
defmodule ElixirScope.ASTRepository.Enhanced.DFGNode do
  @moduledoc """
  Node in the data flow graph representation expected by tests.
  """
  
  defstruct [
    :id,                     # Unique node identifier
    :type,                   # Node type (:variable, :operation, :phi, :call, :pattern_match, :comprehension, etc.)
    :ast_node_id,            # Associated AST node ID
    :variable,               # Associated variable (if applicable)
    :operation,              # Operation type (if applicable)
    :line,                   # Source line number
    :metadata                # Additional metadata
  ]
  
  @type t :: %__MODULE__{
    id: String.t(),
    type: atom(),
    ast_node_id: String.t() | nil,
    variable: VariableVersion.t() | nil,
    operation: term() | nil,
    line: non_neg_integer() | nil,
    metadata: map()
  }
end

defmodule ElixirScope.ASTRepository.Enhanced.DFGEdge do
  @moduledoc """
  Edge in the data flow graph representation expected by tests.
  """
  
  defstruct [
    :id,                     # Unique edge identifier
    :type,                   # Edge type (:data_flow, :mutation, :conditional_flow, :call_flow, :pipe_flow, :capture, etc.)
    :from_node,              # Source node ID
    :to_node,                # Target node ID
    :label,                  # Edge label
    :condition,              # Condition for edge (if applicable)
    :metadata                # Additional metadata
  ]
  
  @type t :: %__MODULE__{
    id: String.t(),
    type: atom(),
    from_node: String.t(),
    to_node: String.t(),
    label: String.t() | nil,
    condition: term() | nil,
    metadata: map()
  }
end

defmodule ElixirScope.ASTRepository.Enhanced.Mutation do
  @moduledoc """
  Variable mutation/rebinding information expected by tests.
  """
  
  defstruct [
    :variable,               # Variable being mutated
    :old_value,              # Previous value/version
    :new_value,              # New value/version
    :ast_node_id,            # AST node where mutation occurs
    :mutation_type,          # Type of mutation (:rebinding, :pattern_match, :assignment, etc.)
    :line,                   # Source line number
    :metadata                # Additional metadata
  ]
  
  @type t :: %__MODULE__{
    variable: String.t(),
    old_value: term(),
    new_value: term(),
    ast_node_id: String.t(),
    mutation_type: atom(),
    line: non_neg_integer() | nil,
    metadata: map()
  }
end 