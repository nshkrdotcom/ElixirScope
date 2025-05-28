defmodule ElixirScope.ASTRepository.CFGData do
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

  @type t :: %__MODULE__{}
end

defmodule ElixirScope.ASTRepository.CFGNode do
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

  @type t :: %__MODULE__{}

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
end

defmodule ElixirScope.ASTRepository.CFGEdge do
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

  @type t :: %__MODULE__{}

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
end

defmodule ElixirScope.ASTRepository.ComplexityMetrics do
  @moduledoc """
  Comprehensive complexity metrics for Elixir functions.
  """

  defstruct [
    # Traditional metrics
    :cyclomatic_complexity,      # McCabe's cyclomatic complexity
    :essential_complexity,       # Essential complexity (structured programming)
    :cognitive_complexity,       # Cognitive complexity (readability)

    # Elixir-specific metrics
    :pattern_complexity,         # Number of pattern match clauses
    :guard_complexity,           # Complexity from guard clauses
    :pipe_chain_length,          # Longest pipe chain
    :nesting_depth,              # Maximum nesting depth

    # Path analysis
    :total_paths,                # Total possible execution paths
    :unreachable_paths,          # Number of unreachable paths
    :critical_path_length,       # Longest execution path

    # Risk indicators
    :error_prone_patterns,       # Count of error-prone patterns
    :performance_risks,          # Performance risk indicators
    :maintainability_score       # Overall maintainability (0-100)
  ]

  @type t :: %__MODULE__{}
end
