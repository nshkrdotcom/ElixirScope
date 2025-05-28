defmodule ElixirScope.ASTRepository.DFGData do
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
    :metadata               # Additional metadata
  ]

  @type t :: %__MODULE__{}
end

defmodule ElixirScope.ASTRepository.VariableVersion do
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

  @type t :: %__MODULE__{}
end

defmodule ElixirScope.ASTRepository.Definition do
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

  @type t :: %__MODULE__{}

  @definition_types [
    :assignment,            # x = value
    :parameter,             # Function parameter
    :pattern_match,         # Pattern match in case/function head
    :comprehension,         # Variable in comprehension
    :catch_variable,        # Exception variable in catch/rescue
    :receive_variable       # Variable bound in receive
  ]
end

defmodule ElixirScope.ASTRepository.Use do
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

  @type t :: %__MODULE__{}

  @use_types [
    :read,                  # Variable value read
    :pattern_match,         # Variable used in pattern
    :guard,                 # Variable used in guard
    :function_call,         # Variable passed to function
    :pipe_operation,        # Variable in pipe chain
    :message_send,          # Variable sent as message
    :closure_capture        # Variable captured in closure
  ]
end

defmodule ElixirScope.ASTRepository.DataFlow do
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

  @type t :: %__MODULE__{}

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
end

defmodule ElixirScope.ASTRepository.PhiNode do
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

  @type t :: %__MODULE__{}
end

defmodule ElixirScope.ASTRepository.ScopeInfo do
  @moduledoc """
  Information about variable scopes in Elixir.
  """

  defstruct [
    :id,                    # Unique scope identifier
    :type,                  # Scope type (see @scope_types)
    :parent_scope,          # Parent scope ID
    :child_scopes,          # [scope_id] - Child scopes
    :variables,             # [VariableVersion.t()] - Variables in scope
    :ast_node_id,           # AST node that creates this scope
    :entry_points,          # [ast_node_id] - Ways to enter scope
    :exit_points,           # [ast_node_id] - Ways to exit scope
    :metadata               # Additional metadata
  ]

  @type t :: %__MODULE__{}

  @scope_types [
    :function,              # Function scope
    :case_clause,           # Case clause scope
    :if_branch,             # If/else branch scope
    :try_block,             # Try block scope
    :catch_clause,          # Catch/rescue clause scope
    :comprehension,         # Comprehension scope
    :receive_clause,        # Receive clause scope
    :anonymous_function,    # Anonymous function scope
    :module                 # Module scope
  ]
end
