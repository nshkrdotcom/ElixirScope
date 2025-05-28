defmodule ElixirScope.ASTRepository.Enhanced.SupportingStructures do
  @moduledoc """
  Supporting data structures for the Enhanced AST Repository.
  
  This module defines all the supporting structs used by EnhancedModuleData
  and EnhancedFunctionData for comprehensive AST analysis.
  """
  
  # Module dependency structures
  
  defmodule MacroData do
    @moduledoc "Macro definition data"
    
    defstruct [
      :name,
      :arity,
      :ast,
      :visibility,
      :line,
      :documentation,
      :metadata
    ]
    
    @type t :: %__MODULE__{
      name: atom(),
      arity: non_neg_integer(),
      ast: Macro.t(),
      visibility: :public | :private,
      line: pos_integer(),
      documentation: String.t() | nil,
      metadata: map()
    }
  end
  
  defmodule TypespecData do
    @moduledoc "Type specification data"
    
    defstruct [
      :name,
      :arity,
      :type,
      :spec_ast,
      :line,
      :metadata
    ]
    
    @type t :: %__MODULE__{
      name: atom(),
      arity: non_neg_integer(),
      type: :spec | :type | :opaque | :callback,
      spec_ast: Macro.t(),
      line: pos_integer(),
      metadata: map()
    }
  end
  
  defmodule ModuleDependency do
    @moduledoc "Module dependency information"
    
    defstruct [
      :module,
      :type,
      :alias_name,
      :functions,
      :line,
      :metadata
    ]
    
    @type t :: %__MODULE__{
      module: atom(),
      type: :import | :alias | :require,
      alias_name: atom() | nil,
      functions: [atom()] | :all,
      line: pos_integer(),
      metadata: map()
    }
  end
  
  defmodule BehaviourUsage do
    @moduledoc "Behaviour usage information"
    
    defstruct [
      :behaviour,
      :callbacks_implemented,
      :line,
      :metadata
    ]
    
    @type t :: %__MODULE__{
      behaviour: atom(),
      callbacks_implemented: [atom()],
      line: pos_integer(),
      metadata: map()
    }
  end
  
  defmodule CallbackData do
    @moduledoc "Callback implementation data"
    
    defstruct [
      :name,
      :arity,
      :behaviour,
      :ast,
      :line,
      :metadata
    ]
    
    @type t :: %__MODULE__{
      name: atom(),
      arity: non_neg_integer(),
      behaviour: atom(),
      ast: Macro.t(),
      line: pos_integer(),
      metadata: map()
    }
  end
  
  defmodule ChildSpecData do
    @moduledoc "Child specification data for supervisors"
    
    defstruct [
      :id,
      :start,
      :restart,
      :shutdown,
      :type,
      :modules,
      :line,
      :metadata
    ]
    
    @type t :: %__MODULE__{
      id: term(),
      start: {module(), atom(), [term()]},
      restart: :permanent | :temporary | :transient,
      shutdown: non_neg_integer() | :infinity | :brutal_kill,
      type: :worker | :supervisor,
      modules: [module()] | :dynamic,
      line: pos_integer(),
      metadata: map()
    }
  end
  
  defmodule CodeSmell do
    @moduledoc "Code smell detection result"
    
    defstruct [
      :type,
      :severity,
      :description,
      :location,
      :suggestion,
      :metadata
    ]
    
    @type t :: %__MODULE__{
      type: atom(),
      severity: :low | :medium | :high | :critical,
      description: String.t(),
      location: ASTLocation.t(),
      suggestion: String.t() | nil,
      metadata: map()
    }
  end
  
  defmodule SecurityRisk do
    @moduledoc "Security risk assessment result"
    
    defstruct [
      :type,
      :severity,
      :description,
      :location,
      :cwe_id,
      :mitigation,
      :metadata
    ]
    
    @type t :: %__MODULE__{
      type: atom(),
      severity: :low | :medium | :high | :critical,
      description: String.t(),
      location: ASTLocation.t(),
      cwe_id: String.t() | nil,
      mitigation: String.t() | nil,
      metadata: map()
    }
  end
  
  # Function-level structures
  
  defmodule ClauseData do
    @moduledoc "Function clause data"
    
    defstruct [
      :index,
      :patterns,
      :guards,
      :body,
      :ast,
      :line,
      :metadata
    ]
    
    @type t :: %__MODULE__{
      index: non_neg_integer(),
      patterns: [PatternData.t()],
      guards: [Macro.t()],
      body: Macro.t(),
      ast: Macro.t(),
      line: pos_integer(),
      metadata: map()
    }
  end
  
  defmodule PatternData do
    @moduledoc "Pattern matching data"
    
    defstruct [
      :type,
      :pattern_ast,
      :variables_bound,
      :complexity,
      :line,
      :metadata
    ]
    
    @type t :: %__MODULE__{
      type: :literal | :variable | :tuple | :list | :map | :struct | :binary | :complex,
      pattern_ast: Macro.t(),
      variables_bound: [atom()],
      complexity: non_neg_integer(),
      line: pos_integer(),
      metadata: map()
    }
  end
  
  defmodule ParameterData do
    @moduledoc "Function parameter data"
    
    defstruct [
      :name,
      :position,
      :type,
      :default_value,
      :pattern,
      :metadata
    ]
    
    @type t :: %__MODULE__{
      name: atom(),
      position: non_neg_integer(),
      type: :required | :optional | :keyword | :rest,
      default_value: term() | nil,
      pattern: PatternData.t() | nil,
      metadata: map()
    }
  end
  
  defmodule CaptureData do
    @moduledoc "Variable capture data for closures"
    
    defstruct [
      :variable_name,
      :capture_type,
      :source_scope,
      :line,
      :metadata
    ]
    
    @type t :: %__MODULE__{
      variable_name: atom(),
      capture_type: :read | :write | :read_write,
      source_scope: String.t(),
      line: pos_integer(),
      metadata: map()
    }
  end
  
  defmodule VariableMutation do
    @moduledoc "Variable mutation tracking"
    
    defstruct [
      :variable_name,
      :mutation_type,
      :location,
      :old_value_ast,
      :new_value_ast,
      :metadata
    ]
    
    @type t :: %__MODULE__{
      variable_name: atom(),
      mutation_type: :assignment | :pattern_match | :update,
      location: ASTLocation.t(),
      old_value_ast: Macro.t() | nil,
      new_value_ast: Macro.t(),
      metadata: map()
    }
  end
  
  defmodule ReturnPoint do
    @moduledoc "Function return point data"
    
    defstruct [
      :type,
      :location,
      :return_ast,
      :is_explicit,
      :metadata
    ]
    
    @type t :: %__MODULE__{
      type: :normal | :early | :exception | :throw,
      location: ASTLocation.t(),
      return_ast: Macro.t(),
      is_explicit: boolean(),
      metadata: map()
    }
  end
  
  defmodule FunctionCall do
    @moduledoc "Function call data"
    
    defstruct [
      :target_module,
      :target_function,
      :target_arity,
      :call_type,
      :ast_node_id,
      :line,
      :arguments,
      :metadata
    ]
    
    @type t :: %__MODULE__{
      target_module: atom(),
      target_function: atom(),
      target_arity: non_neg_integer(),
      call_type: :local | :remote | :dynamic | :pipe,
      ast_node_id: String.t(),
      line: pos_integer(),
      arguments: [Macro.t()],
      metadata: map()
    }
  end
  
  defmodule FunctionReference do
    @moduledoc "Function reference for reverse indexing"
    
    defstruct [
      :caller_module,
      :caller_function,
      :caller_arity,
      :call_site_id,
      :call_frequency,
      :metadata
    ]
    
    @type t :: %__MODULE__{
      caller_module: atom(),
      caller_function: atom(),
      caller_arity: non_neg_integer(),
      call_site_id: String.t(),
      call_frequency: non_neg_integer(),
      metadata: map()
    }
  end
  
  defmodule ExternalCall do
    @moduledoc "External function call data"
    
    defstruct [
      :target_module,
      :target_function,
      :target_arity,
      :call_type,
      :is_safe,
      :side_effects,
      :line,
      :metadata
    ]
    
    @type t :: %__MODULE__{
      target_module: atom(),
      target_function: atom(),
      target_arity: non_neg_integer(),
      call_type: :erlang | :external | :nif | :port,
      is_safe: boolean(),
      side_effects: [atom()],
      line: pos_integer(),
      metadata: map()
    }
  end
  
  defmodule PerformanceProfile do
    @moduledoc "Performance profiling data"
    
    defstruct [
      :average_duration_ms,
      :min_duration_ms,
      :max_duration_ms,
      :p95_duration_ms,
      :p99_duration_ms,
      :memory_usage,
      :cpu_usage,
      :call_count,
      :error_count,
      :last_updated,
      :metadata
    ]
    
    @type t :: %__MODULE__{
      average_duration_ms: float(),
      min_duration_ms: float(),
      max_duration_ms: float(),
      p95_duration_ms: float(),
      p99_duration_ms: float(),
      memory_usage: map(),
      cpu_usage: map(),
      call_count: non_neg_integer(),
      error_count: non_neg_integer(),
      last_updated: DateTime.t(),
      metadata: map()
    }
  end
  
  defmodule Example do
    @moduledoc "Documentation example data"
    
    defstruct [
      :title,
      :code,
      :expected_output,
      :tags,
      :metadata
    ]
    
    @type t :: %__MODULE__{
      title: String.t() | nil,
      code: String.t(),
      expected_output: term() | nil,
      tags: [String.t()],
      metadata: map()
    }
  end
  
  defmodule ASTLocation do
    @moduledoc "AST location information"
    
    defstruct [
      :file,
      :line,
      :column,
      :ast_node_id,
      :metadata
    ]
    
    @type t :: %__MODULE__{
      file: String.t(),
      line: pos_integer(),
      column: pos_integer() | nil,
      ast_node_id: String.t() | nil,
      metadata: map()
    }
  end
  
  # Helper functions for creating common structures
  
  @doc """
  Creates a new ASTLocation from line information.
  """
  @spec new_location(String.t(), pos_integer(), pos_integer() | nil, String.t() | nil) :: ASTLocation.t()
  def new_location(file, line, column \\ nil, ast_node_id \\ nil) do
    %ASTLocation{
      file: file,
      line: line,
      column: column,
      ast_node_id: ast_node_id,
      metadata: %{}
    }
  end
  
  @doc """
  Creates a new FunctionCall from call information.
  """
  @spec new_function_call(atom(), atom(), non_neg_integer(), atom(), String.t(), pos_integer()) :: FunctionCall.t()
  def new_function_call(target_module, target_function, target_arity, call_type, ast_node_id, line) do
    %FunctionCall{
      target_module: target_module,
      target_function: target_function,
      target_arity: target_arity,
      call_type: call_type,
      ast_node_id: ast_node_id,
      line: line,
      arguments: [],
      metadata: %{}
    }
  end
  
  @doc """
  Creates a new CodeSmell from detection information.
  """
  @spec new_code_smell(atom(), atom(), String.t(), ASTLocation.t(), String.t() | nil) :: CodeSmell.t()
  def new_code_smell(type, severity, description, location, suggestion \\ nil) do
    %CodeSmell{
      type: type,
      severity: severity,
      description: description,
      location: location,
      suggestion: suggestion,
      metadata: %{}
    }
  end
  
  @doc """
  Creates a new SecurityRisk from assessment information.
  """
  @spec new_security_risk(atom(), atom(), String.t(), ASTLocation.t(), String.t() | nil, String.t() | nil) :: SecurityRisk.t()
  def new_security_risk(type, severity, description, location, cwe_id \\ nil, mitigation \\ nil) do
    %SecurityRisk{
      type: type,
      severity: severity,
      description: description,
      location: location,
      cwe_id: cwe_id,
      mitigation: mitigation,
      metadata: %{}
    }
  end
  
  @doc """
  Creates a new PerformanceProfile with default values.
  """
  @spec new_performance_profile() :: PerformanceProfile.t()
  def new_performance_profile do
    %PerformanceProfile{
      average_duration_ms: 0.0,
      min_duration_ms: 0.0,
      max_duration_ms: 0.0,
      p95_duration_ms: 0.0,
      p99_duration_ms: 0.0,
      memory_usage: %{},
      cpu_usage: %{},
      call_count: 0,
      error_count: 0,
      last_updated: DateTime.utc_now(),
      metadata: %{}
    }
  end
end 