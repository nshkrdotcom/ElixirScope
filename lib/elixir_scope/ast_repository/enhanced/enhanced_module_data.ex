defmodule ElixirScope.ASTRepository.Enhanced.EnhancedModuleData do
  @moduledoc """
  Enhanced module data structure for advanced AST analysis.
  
  Contains comprehensive module information including:
  - Basic module metadata
  - Function definitions and analysis
  - Dependency relationships
  - Quality and complexity metrics
  - Security analysis results
  - Performance optimization hints
  """
  
  defstruct [
    :module_name,
    :file_path,
    :ast,
    :functions,
    :dependencies,
    :exports,
    :attributes,
    :complexity_metrics,
    :quality_metrics,
    :security_analysis,
    :performance_hints,
    :file_size,
    :line_count,
    :created_at,
    :updated_at
  ]
  
  @type t :: %__MODULE__{
    module_name: atom(),
    file_path: String.t() | nil,
    ast: term(),
    functions: map(),
    dependencies: list(),
    exports: list(),
    attributes: map(),
    complexity_metrics: map(),
    quality_metrics: map(),
    security_analysis: map(),
    performance_hints: list(),
    file_size: non_neg_integer() | nil,
    line_count: non_neg_integer() | nil,
    created_at: DateTime.t(),
    updated_at: DateTime.t()
  }
end 