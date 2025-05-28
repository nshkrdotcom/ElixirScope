defmodule ElixirScope.ASTRepository.Enhanced.EnhancedFunctionData do
  @moduledoc """
  Enhanced function data structure for advanced AST analysis.
  
  Contains comprehensive function information including:
  - Basic function metadata
  - Control Flow Graph (CFG) data
  - Data Flow Graph (DFG) data
  - Code Property Graph (CPG) data
  - Complexity and performance metrics
  - Security analysis results
  - Optimization hints
  """
  
  alias ElixirScope.ASTRepository.Enhanced.{CFGData, DFGData}
  
  defstruct [
    # Basic function information
    :module_name,
    :function_name,
    :arity,
    :ast_node_id,
    :file_path,
    :line_start,
    :line_end,
    :column_start,
    :column_end,
    
    # AST information
    :ast,
    :head_ast,
    :body_ast,
    
    # Function properties
    :visibility,
    :is_macro,
    :is_guard,
    :is_callback,
    :is_delegate,
    
    # Function structure
    :clauses,
    :guard_clauses,
    :pattern_matches,
    :parameters,
    :local_variables,
    :captures,
    
    # Analysis results
    :control_flow_graph,
    :cyclomatic_complexity,
    :nesting_depth,
    :data_flow_graph,
    :variable_mutations,
    :return_points,
    
    # Call information
    :called_functions,
    :calling_functions,
    :external_calls,
    
    # Quality metrics
    :complexity_score,
    :maintainability_index,
    :test_coverage,
    :performance_profile,
    
    # Documentation
    :doc_string,
    :spec,
    :examples,
    :tags,
    :annotations,
    :metadata,
    
    # Additional data
    :cfg_data,
    :dfg_data,
    :cpg_data,
    :complexity_metrics,
    :performance_analysis,
    :security_analysis,
    :optimization_hints,
    :created_at,
    :updated_at
  ]
  
  @type t :: %__MODULE__{
    module_name: atom(),
    function_name: atom(),
    arity: non_neg_integer(),
    ast_node_id: String.t(),
    file_path: String.t(),
    line_start: non_neg_integer(),
    line_end: non_neg_integer(),
    column_start: non_neg_integer(),
    column_end: non_neg_integer(),
    ast: term(),
    head_ast: term(),
    body_ast: term(),
    visibility: :public | :private,
    is_macro: boolean(),
    is_guard: boolean(),
    is_callback: boolean(),
    is_delegate: boolean(),
    clauses: list(),
    guard_clauses: list(),
    pattern_matches: list(),
    parameters: list(),
    local_variables: list(),
    captures: list(),
    control_flow_graph: CFGData.t(),
    cyclomatic_complexity: non_neg_integer(),
    nesting_depth: non_neg_integer(),
    data_flow_graph: DFGData.t(),
    variable_mutations: list(),
    return_points: list(),
    called_functions: list(),
    calling_functions: list(),
    external_calls: list(),
    complexity_score: float(),
    maintainability_index: float(),
    test_coverage: float() | nil,
    performance_profile: map() | nil,
    doc_string: String.t() | nil,
    spec: term() | nil,
    examples: list(),
    tags: list(String.t()),
    annotations: map(),
    metadata: map(),
    cfg_data: map() | nil,
    dfg_data: map() | nil,
    cpg_data: map() | nil,
    complexity_metrics: map(),
    performance_analysis: map(),
    security_analysis: map(),
    optimization_hints: list(),
    created_at: DateTime.t(),
    updated_at: DateTime.t()
  }
end 