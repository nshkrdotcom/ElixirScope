defmodule ElixirScope.ASTRepository.Enhanced.VariableData do
  @moduledoc """
  Variable data structure for enhanced AST analysis.
  """
  
  defstruct [
    :name,
    :type,
    :scope,
    :definition_line,
    :usage_lines,
    :mutations,
    :lifetime,
    :metadata
  ]
  
  @type t :: %__MODULE__{
    name: String.t(),
    type: atom(),
    scope: String.t(),
    definition_line: non_neg_integer(),
    usage_lines: list(non_neg_integer()),
    mutations: list(map()),
    lifetime: map(),
    metadata: map()
  }
end 