defmodule ElixirScope.ASTRepository.FunctionData do
  @moduledoc """
  Function-level data structure with static analysis and runtime correlation.
  
  This structure stores comprehensive information about individual functions including:
  - Function AST and metadata
  - Static analysis results
  - Runtime execution data
  - Performance metrics
  - Error patterns
  """
  
  alias ElixirScope.Utils
  
  @type module_name :: atom()
  @type function_name :: atom()
  @type function_key :: {module_name(), function_name(), arity()}
  @type ast_node_id :: binary()
  @type correlation_id :: binary()
  
  defstruct [
    # Core Function Information
    :function_key,         # {module, function, arity}
    :module_name,          # atom() - Parent module
    :function_name,        # atom() - Function name
    :arity,                # non_neg_integer() - Function arity
    :ast,                  # AST - Function AST
    :source_location,      # {file, line} - Source location
    
    # Function Metadata
    :visibility,           # :public | :private
    :type,                 # :function | :macro | :callback
    :guards,               # [guard()] - Function guards
    :documentation,        # String.t() | nil - Function documentation
    :attributes,           # [attribute()] - Function attributes
    :annotations,          # [annotation()] - Custom annotations
    
    # Static Analysis Results
    :complexity_metrics,   # ComplexityMetrics.t()
    :dependencies,         # [function_key()] - Function dependencies
    :side_effects,         # [side_effect()] - Detected side effects
    :purity_analysis,      # PurityAnalysis.t() - Function purity
    :type_signature,       # TypeSignature.t() - Inferred types
    
    # Instrumentation Data
    :instrumentation_points, # [InstrumentationPoint.t()]
    :ast_node_mapping,     # %{ast_node_id => AST_node}
    :correlation_metadata, # %{correlation_id => ast_node_id}
    
    # Runtime Execution Data
    :execution_statistics, # ExecutionStatistics.t()
    :performance_profile,  # PerformanceProfile.t()
    :error_history,        # [ErrorEvent.t()]
    :call_patterns,        # [CallPattern.t()]
    :return_patterns,      # [ReturnPattern.t()]
    
    # Temporal Data
    :first_execution,      # integer() | nil - First execution timestamp
    :last_execution,       # integer() | nil - Last execution timestamp
    :execution_count,      # non_neg_integer() - Total executions
    :hot_path_indicator,   # boolean() - Is this a hot path?
    
    # Metadata
    :created_at,           # integer() - Creation timestamp
    :updated_at,           # integer() - Last update timestamp
    :version               # String.t() - Data structure version
  ]
  
  @type t :: %__MODULE__{}
  
  @doc """
  Creates a new FunctionData structure from function AST.
  
  ## Parameters
  - `function_key` - The {module, function, arity} tuple
  - `ast` - The function AST
  - `opts` - Optional parameters including source_location, visibility, etc.
  """
  @spec new(function_key(), term(), keyword()) :: t()
  def new({module_name, function_name, arity} = function_key, ast, opts \\ []) do
    timestamp = Utils.monotonic_timestamp()
    
    %__MODULE__{
      function_key: function_key,
      module_name: module_name,
      function_name: function_name,
      arity: arity,
      ast: ast,
      source_location: Keyword.get(opts, :source_location),
      visibility: Keyword.get(opts, :visibility, :public),
      type: detect_function_type(ast),
      guards: extract_guards(ast),
      documentation: Keyword.get(opts, :documentation),
      attributes: Keyword.get(opts, :attributes, []),
      annotations: Keyword.get(opts, :annotations, []),
      complexity_metrics: calculate_complexity_metrics(ast),
      dependencies: extract_dependencies(ast),
      side_effects: analyze_side_effects(ast),
      purity_analysis: analyze_purity(ast),
      type_signature: infer_type_signature(ast),
      instrumentation_points: Keyword.get(opts, :instrumentation_points, []),
      ast_node_mapping: Keyword.get(opts, :ast_node_mapping, %{}),
      correlation_metadata: Keyword.get(opts, :correlation_metadata, %{}),
      execution_statistics: nil,
      performance_profile: nil,
      error_history: [],
      call_patterns: [],
      return_patterns: [],
      first_execution: nil,
      last_execution: nil,
      execution_count: 0,
      hot_path_indicator: false,
      created_at: timestamp,
      updated_at: timestamp,
      version: "1.0.0"
    }
  end
  
  @doc """
  Records a function execution event.
  """
  @spec record_execution(t(), map()) :: t()
  def record_execution(%__MODULE__{} = function_data, execution_event) do
    timestamp = Utils.monotonic_timestamp()
    
    %{function_data |
      execution_count: function_data.execution_count + 1,
      first_execution: function_data.first_execution || timestamp,
      last_execution: timestamp,
      updated_at: timestamp
    }
    |> update_execution_statistics(execution_event)
    |> update_performance_profile(execution_event)
    |> maybe_update_hot_path_indicator()
  end
  
  @doc """
  Records an error event for this function.
  """
  @spec record_error(t(), map()) :: t()
  def record_error(%__MODULE__{} = function_data, error_event) do
    updated_history = [error_event | function_data.error_history]
    
    %{function_data |
      error_history: updated_history,
      updated_at: Utils.monotonic_timestamp()
    }
  end
  
  @doc """
  Updates the performance profile with new execution data.
  """
  @spec update_performance_profile(t(), map()) :: t()
  def update_performance_profile(%__MODULE__{} = function_data, execution_data) do
    current_profile = function_data.performance_profile || %{
      average_duration: 0.0,
      min_duration: nil,
      max_duration: nil,
      p95_duration: nil,
      p99_duration: nil,
      memory_usage: %{},
      cpu_usage: %{}
    }
    
    updated_profile = merge_performance_data(current_profile, execution_data)
    
    %{function_data |
      performance_profile: updated_profile,
      updated_at: Utils.monotonic_timestamp()
    }
  end
  
  @doc """
  Adds a call pattern observation.
  """
  @spec add_call_pattern(t(), map()) :: t()
  def add_call_pattern(%__MODULE__{} = function_data, call_pattern) do
    updated_patterns = [call_pattern | function_data.call_patterns]
    
    %{function_data |
      call_patterns: updated_patterns,
      updated_at: Utils.monotonic_timestamp()
    }
  end
  
  @doc """
  Adds a return pattern observation.
  """
  @spec add_return_pattern(t(), map()) :: t()
  def add_return_pattern(%__MODULE__{} = function_data, return_pattern) do
    updated_patterns = [return_pattern | function_data.return_patterns]
    
    %{function_data |
      return_patterns: updated_patterns,
      updated_at: Utils.monotonic_timestamp()
    }
  end
  
  @doc """
  Checks if this function has runtime execution data.
  """
  @spec has_runtime_data?(t()) :: boolean()
  def has_runtime_data?(%__MODULE__{} = function_data) do
    function_data.execution_count > 0 or
    not is_nil(function_data.execution_statistics) or
    not is_nil(function_data.performance_profile) or
    length(function_data.error_history) > 0
  end
  
  @doc """
  Gets the correlation IDs associated with this function.
  """
  @spec get_correlation_ids(t()) :: [correlation_id()]
  def get_correlation_ids(%__MODULE__{} = function_data) do
    Map.keys(function_data.correlation_metadata)
  end
  
  @doc """
  Gets the AST node IDs for this function.
  """
  @spec get_ast_node_ids(t()) :: [ast_node_id()]
  def get_ast_node_ids(%__MODULE__{} = function_data) do
    Map.keys(function_data.ast_node_mapping)
  end
  
  @doc """
  Calculates the error rate for this function.
  """
  @spec error_rate(t()) :: float()
  def error_rate(%__MODULE__{} = function_data) do
    if function_data.execution_count > 0 do
      length(function_data.error_history) / function_data.execution_count
    else
      0.0
    end
  end
  
  @doc """
  Checks if this function is considered a performance bottleneck.
  """
  @spec is_bottleneck?(t()) :: boolean()
  def is_bottleneck?(%__MODULE__{} = function_data) do
    case function_data.performance_profile do
      nil -> false
      profile ->
        # Consider it a bottleneck if average duration > 100ms or it's a hot path with high duration
        profile.average_duration > 100.0 or
        (function_data.hot_path_indicator and profile.average_duration > 50.0)
    end
  end
  
  #############################################################################
  # Private Helper Functions
  #############################################################################
  
  defp detect_function_type(ast) do
    case ast do
      {:def, _, _} -> :function
      {:defp, _, _} -> :function
      {:defmacro, _, _} -> :macro
      {:defmacrop, _, _} -> :macro
      _ -> :function
    end
  end
  
  defp extract_guards(ast) do
    # Extract guard clauses from function definition
    case ast do
      {_def_type, _, [head | _]} when is_tuple(head) ->
        case head do
          {:when, _, [_function_head, guards]} -> [guards]
          _ -> []
        end
      _ -> []
    end
  end
  
  defp calculate_complexity_metrics(ast) do
    %{
      cyclomatic_complexity: count_decision_points(ast),
      cognitive_complexity: count_cognitive_complexity(ast),
      nesting_depth: calculate_nesting_depth(ast),
      parameter_count: count_parameters(ast),
      return_points: count_return_points(ast)
    }
  end
  
  defp extract_dependencies(_ast) do
    # Extract function calls within this function
    []  # TODO: Implement dependency extraction
  end
  
  defp analyze_side_effects(_ast) do
    # Analyze potential side effects
    []  # TODO: Implement side effect analysis
  end
  
  defp analyze_purity(_ast) do
    # Analyze function purity
    %{
      is_pure: false,  # TODO: Implement purity analysis
      side_effect_types: [],
      external_dependencies: []
    }
  end
  
  defp infer_type_signature(_ast) do
    # Infer type signature from AST
    %{
      parameters: [],  # TODO: Implement parameter type inference
      return_type: :any,  # TODO: Implement return type inference
      constraints: []
    }
  end
  
  defp update_execution_statistics(function_data, execution_event) do
    current_stats = function_data.execution_statistics || %{
      total_executions: 0,
      successful_executions: 0,
      failed_executions: 0,
      average_duration: 0.0,
      total_duration: 0.0
    }
    
    duration = Map.get(execution_event, :duration, 0.0)
    success = Map.get(execution_event, :success, true)
    
    updated_stats = %{
      total_executions: current_stats.total_executions + 1,
      successful_executions: current_stats.successful_executions + (if success, do: 1, else: 0),
      failed_executions: current_stats.failed_executions + (if success, do: 0, else: 1),
      total_duration: current_stats.total_duration + duration,
      average_duration: (current_stats.total_duration + duration) / (current_stats.total_executions + 1)
    }
    
    %{function_data | execution_statistics: updated_stats}
  end
  
  defp merge_performance_data(current_profile, execution_data) do
    duration = Map.get(execution_data, :duration, 0.0)
    
    %{current_profile |
      min_duration: min_duration(current_profile.min_duration, duration),
      max_duration: max_duration(current_profile.max_duration, duration)
    }
  end
  
  defp maybe_update_hot_path_indicator(function_data) do
    # Consider it a hot path if executed more than 1000 times
    hot_path = function_data.execution_count > 1000
    
    %{function_data | hot_path_indicator: hot_path}
  end
  
  defp min_duration(nil, duration), do: duration
  defp min_duration(current, duration), do: min(current, duration)
  
  defp max_duration(nil, duration), do: duration
  defp max_duration(current, duration), do: max(current, duration)
  
  # Complexity calculation helpers
  defp count_decision_points(_ast), do: 1  # TODO: Implement
  defp count_cognitive_complexity(_ast), do: 1  # TODO: Implement
  defp calculate_nesting_depth(_ast), do: 1  # TODO: Implement
  defp count_parameters(_ast), do: 0  # TODO: Implement
  defp count_return_points(_ast), do: 1  # TODO: Implement
end 