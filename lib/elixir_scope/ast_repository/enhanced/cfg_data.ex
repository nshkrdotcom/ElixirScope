defmodule ElixirScope.ASTRepository.Enhanced.CFGData do
  @moduledoc """
  Enhanced Control Flow Graph representation for Elixir code.

  Handles Elixir-specific constructs:
  - Pattern matching with multiple clauses
  - Guard clauses and compound conditions
  - Pipe operations and data flow
  - OTP behavior patterns
  """

  defstruct [
    :function_key,          # {module, function, arity}
    :entry_node,           # Entry node ID
    :exit_nodes,           # List of exit node IDs (multiple returns)
    :nodes,                # %{node_id => CFGNode.t()}
    :edges,                # [CFGEdge.t()]
    :scopes,               # %{scope_id => ScopeInfo.t()}
    :complexity_metrics,   # ComplexityMetrics.t()
    :path_analysis,        # PathAnalysis.t()
    :metadata              # Additional metadata
  ]

  @type t :: %__MODULE__{
    function_key: {module(), atom(), non_neg_integer()},
    entry_node: String.t(),
    exit_nodes: [String.t()],
    nodes: %{String.t() => CFGNode.t()},
    edges: [CFGEdge.t()],
    scopes: %{String.t() => ScopeInfo.t()},
    complexity_metrics: ComplexityMetrics.t(),
    path_analysis: PathAnalysis.t(),
    metadata: map()
  }
end

defmodule ElixirScope.ASTRepository.Enhanced.CFGNode do
  @moduledoc """
  Individual node in the Control Flow Graph.
  """

  defstruct [
    :id,                   # Unique node identifier
    :type,                 # Node type (see @node_types)
    :ast_node_id,          # Corresponding AST node ID
    :line,                 # Source line number
    :scope_id,             # Scope identifier
    :expression,           # AST expression for this node
    :predecessors,         # [node_id] - incoming edges
    :successors,           # [node_id] - outgoing edges
    :metadata              # Node-specific metadata
  ]

  @type t :: %__MODULE__{
    id: String.t(),
    type: atom(),
    ast_node_id: String.t() | nil,
    line: non_neg_integer(),
    scope_id: String.t(),
    expression: term(),
    predecessors: [String.t()],
    successors: [String.t()],
    metadata: map()
  }

  # Elixir-specific node types
  @node_types [
    # Basic control flow
    :entry, :exit, :statement, :expression,

    # Pattern matching
    :pattern_match, :case_entry, :case_clause, :guard_check,

    # Function calls and operations
    :function_call, :pipe_operation, :anonymous_function,

    # Control structures
    :if_condition, :if_then, :if_else,
    :cond_entry, :cond_clause,
    :try_entry, :catch_clause, :rescue_clause, :after_clause,

    # Comprehensions
    :comprehension_entry, :comprehension_filter, :comprehension_generator,

    # Process operations
    :send_message, :receive_message, :spawn_process
  ]

  def node_types, do: @node_types
end

defmodule ElixirScope.ASTRepository.Enhanced.CFGEdge do
  @moduledoc """
  Edge in the Control Flow Graph representing control flow transitions.
  """

  defstruct [
    :from_node_id,         # Source node
    :to_node_id,           # Target node
    :type,                 # Edge type (see @edge_types)
    :condition,            # Optional condition (for conditional edges)
    :probability,          # Execution probability (0.0-1.0)
    :metadata              # Edge-specific metadata
  ]

  @type t :: %__MODULE__{
    from_node_id: String.t(),
    to_node_id: String.t(),
    type: atom(),
    condition: term() | nil,
    probability: float(),
    metadata: map()
  }

  @edge_types [
    :sequential,           # Normal sequential execution
    :conditional,          # If/case branch
    :pattern_match,        # Pattern match success
    :pattern_no_match,     # Pattern match failure (fall through)
    :guard_success,        # Guard clause success
    :guard_failure,        # Guard clause failure
    :exception,            # Exception flow
    :catch,                # Exception caught
    :loop_back,            # Loop iteration
    :loop_exit             # Loop termination
  ]

  def edge_types, do: @edge_types
end

# ComplexityMetrics is defined in shared_data_structures.ex
# alias ElixirScope.ASTRepository.Enhanced.ComplexityMetrics

defmodule ElixirScope.ASTRepository.Enhanced.PathAnalysis do
  @moduledoc """
  Path analysis results for control flow graph.
  """

  defstruct [
    :all_paths,                  # [Path.t()] - All execution paths
    :critical_paths,             # [Path.t()] - Longest/most complex paths
    :unreachable_nodes,          # [node_id] - Unreachable nodes
    :loop_analysis,              # LoopAnalysis.t() - Loop detection results
    :branch_coverage,            # BranchCoverage.t() - Branch coverage analysis
    :path_conditions             # %{path_id => condition} - Path conditions
  ]

  @type t :: %__MODULE__{
    all_paths: [Path.t()],
    critical_paths: [Path.t()],
    unreachable_nodes: [String.t()],
    loop_analysis: LoopAnalysis.t(),
    branch_coverage: BranchCoverage.t(),
    path_conditions: %{String.t() => term()}
  }
end

defmodule ElixirScope.ASTRepository.Enhanced.Path do
  @moduledoc """
  Represents an execution path through the CFG.
  """

  defstruct [
    :id,                         # Unique path identifier
    :nodes,                      # [node_id] - Nodes in path
    :edges,                      # [edge] - Edges in path
    :conditions,                 # [condition] - Conditions for this path
    :complexity,                 # Path complexity score
    :probability,                # Execution probability
    :metadata                    # Additional metadata
  ]

  @type t :: %__MODULE__{
    id: String.t(),
    nodes: [String.t()],
    edges: [CFGEdge.t()],
    conditions: [term()],
    complexity: non_neg_integer(),
    probability: float(),
    metadata: map()
  }
end

# ScopeInfo is defined in shared_data_structures.ex
# alias ElixirScope.ASTRepository.Enhanced.ScopeInfo

defmodule ElixirScope.ASTRepository.Enhanced.LoopAnalysis do
  @moduledoc """
  Loop detection and analysis results.
  """

  defstruct [
    :loops,                      # [Loop.t()] - Detected loops
    :loop_nesting_depth,         # Maximum loop nesting depth
    :infinite_loop_risk,         # Risk of infinite loops
    :loop_complexity             # Complexity added by loops
  ]

  @type t :: %__MODULE__{
    loops: [Loop.t()],
    loop_nesting_depth: non_neg_integer(),
    infinite_loop_risk: atom(),
    loop_complexity: non_neg_integer()
  }
end

defmodule ElixirScope.ASTRepository.Enhanced.Loop do
  @moduledoc """
  Represents a detected loop in the CFG.
  """

  defstruct [
    :id,                         # Unique loop identifier
    :header_node,                # Loop header node
    :back_edges,                 # [edge] - Back edges
    :body_nodes,                 # [node_id] - Nodes in loop body
    :exit_conditions,            # [condition] - Loop exit conditions
    :nesting_level,              # Nesting level
    :metadata                    # Additional metadata
  ]

  @type t :: %__MODULE__{
    id: String.t(),
    header_node: String.t(),
    back_edges: [CFGEdge.t()],
    body_nodes: [String.t()],
    exit_conditions: [term()],
    nesting_level: non_neg_integer(),
    metadata: map()
  }
end

defmodule ElixirScope.ASTRepository.Enhanced.BranchCoverage do
  @moduledoc """
  Branch coverage analysis for testing.
  """

  defstruct [
    :total_branches,             # Total number of branches
    :covered_branches,           # Number of covered branches
    :uncovered_branches,         # [branch] - Uncovered branches
    :coverage_percentage,        # Coverage percentage
    :critical_uncovered          # [branch] - Critical uncovered branches
  ]

  @type t :: %__MODULE__{
    total_branches: non_neg_integer(),
    covered_branches: non_neg_integer(),
    uncovered_branches: [term()],
    coverage_percentage: float(),
    critical_uncovered: [term()]
  }
end 