defmodule ElixirScope.ASTRepository.EnhancedFunctionData do
  @moduledoc """
  Enhanced function data structure with comprehensive AST analysis information.
  
  This structure extends the basic FunctionData to support advanced analysis including:
  - Control Flow Graph (CFG) and Data Flow Graph (DFG) analysis
  - Comprehensive variable tracking and mutation analysis
  - Pattern matching and call graph data
  - Performance profiling hooks
  - Detailed complexity metrics
  
  ## Features
  - Complete function AST with head/body separation
  - Variable lifetime and mutation tracking
  - Control and data flow analysis
  - Call dependency tracking
  - Performance profiling integration
  - Pattern matching analysis
  - Comprehensive documentation support
  
  ## Usage
  
      iex> function_data = EnhancedFunctionData.new({MyModule, :my_func, 2}, ast)
      iex> EnhancedFunctionData.validate(function_data)
      :ok
  """
  
  alias ElixirScope.ASTRepository.Enhanced.{
    CFGData,
    DFGData,
    VariableData
  }
  alias ElixirScope.ASTRepository.Enhanced.SupportingStructures.{
    ClauseData,
    PatternData,
    ParameterData,
    CaptureData,
    VariableMutation,
    ReturnPoint,
    FunctionCall,
    FunctionReference,
    ExternalCall,
    PerformanceProfile,
    TypespecData,
    Example
  }
  # alias ElixirScope.Utils
  
  @type t :: %__MODULE__{
    # Identity
    module_name: atom(),
    function_name: atom(),
    arity: non_neg_integer(),
    ast_node_id: String.t(),  # e.g., "MyModule:my_func:2:def"
    
    # Location
    file_path: String.t(),
    line_start: pos_integer(),
    line_end: pos_integer(),
    column_start: pos_integer(),
    column_end: pos_integer(),
    
    # AST Data
    ast: Macro.t(),  # Complete function AST
    head_ast: Macro.t(),  # Function head/signature
    body_ast: Macro.t(),  # Function body
    
    # Function Characteristics
    visibility: :public | :private,
    is_macro: boolean(),
    is_guard: boolean(),
    is_callback: boolean(),
    is_delegate: boolean(),
    
    # Clauses & Patterns
    clauses: [ClauseData.t()],
    guard_clauses: [Macro.t()],
    pattern_matches: [PatternData.t()],
    
    # Variables & Data Flow
    parameters: [ParameterData.t()],
    local_variables: [VariableData.t()],
    captures: [CaptureData.t()],  # Captured variables in closures
    
    # Control Flow
    control_flow_graph: CFGData.t(),
    cyclomatic_complexity: non_neg_integer(),
    nesting_depth: non_neg_integer(),
    
    # Data Flow
    data_flow_graph: DFGData.t(),
    variable_mutations: [VariableMutation.t()],
    return_points: [ReturnPoint.t()],
    
    # Dependencies
    called_functions: [FunctionCall.t()],
    calling_functions: [FunctionReference.t()],  # Reverse index
    external_calls: [ExternalCall.t()],
    
    # Analysis Results
    complexity_score: float(),
    maintainability_index: float(),
    test_coverage: float() | nil,
    performance_profile: PerformanceProfile.t() | nil,
    
    # Documentation
    doc_string: String.t() | nil,
    spec: TypespecData.t() | nil,
    examples: [Example.t()],
    
    # Metadata
    tags: [String.t()],
    annotations: map(),
    metadata: map()
  }
  
  defstruct [
    # Identity
    :module_name,
    :function_name,
    :arity,
    :ast_node_id,
    
    # Location
    :file_path,
    :line_start,
    :line_end,
    :column_start,
    :column_end,
    
    # AST Data
    :ast,
    :head_ast,
    :body_ast,
    
    # Function Characteristics
    :visibility,
    :is_macro,
    :is_guard,
    :is_callback,
    :is_delegate,
    
    # Clauses & Patterns
    :clauses,
    :guard_clauses,
    :pattern_matches,
    
    # Variables & Data Flow
    :parameters,
    :local_variables,
    :captures,
    
    # Control Flow
    :control_flow_graph,
    :cyclomatic_complexity,
    :nesting_depth,
    
    # Data Flow
    :data_flow_graph,
    :variable_mutations,
    :return_points,
    
    # Dependencies
    :called_functions,
    :calling_functions,
    :external_calls,
    
    # Analysis Results
    :complexity_score,
    :maintainability_index,
    :test_coverage,
    :performance_profile,
    
    # Documentation
    :doc_string,
    :spec,
    :examples,
    
    # Metadata
    :tags,
    :annotations,
    :metadata
  ]
  
  @doc """
  Creates a new EnhancedFunctionData structure from function AST.
  
  ## Parameters
  - `function_key` - The {module, function, arity} tuple
  - `ast` - The function AST
  - `opts` - Optional parameters including file_path, visibility, etc.
  
  ## Examples
  
      iex> ast = quote do: def hello(name), do: "Hello, " <> name
      iex> data = EnhancedFunctionData.new({MyModule, :hello, 1}, ast)
      iex> data.function_name
      :hello
  """
  @spec new({atom(), atom(), non_neg_integer()}, Macro.t(), keyword()) :: t()
  def new({module_name, function_name, arity}, ast, opts \\ []) do
    ast_node_id = generate_ast_node_id(module_name, function_name, arity, ast)
    {head_ast, body_ast} = extract_head_and_body(ast)
    location = extract_location(ast, opts)
    
    %__MODULE__{
      # Identity
      module_name: module_name,
      function_name: function_name,
      arity: arity,
      ast_node_id: ast_node_id,
      
      # Location
      file_path: Keyword.get(opts, :file_path, ""),
      line_start: location.line_start,
      line_end: location.line_end,
      column_start: location.column_start,
      column_end: location.column_end,
      
      # AST Data
      ast: ast,
      head_ast: head_ast,
      body_ast: body_ast,
      
      # Function Characteristics
      visibility: detect_visibility(ast),
      is_macro: detect_is_macro(ast),
      is_guard: detect_is_guard(ast),
      is_callback: detect_is_callback(ast, opts),
      is_delegate: detect_is_delegate(ast),
      
      # Clauses & Patterns
      clauses: extract_clauses(ast),
      guard_clauses: extract_guard_clauses(ast),
      pattern_matches: extract_pattern_matches(ast),
      
      # Variables & Data Flow
      parameters: extract_parameters(head_ast),
      local_variables: extract_local_variables(body_ast),
      captures: extract_captures(body_ast),
      
      # Control Flow
      control_flow_graph: generate_cfg(ast),
      cyclomatic_complexity: calculate_cyclomatic_complexity(ast),
      nesting_depth: calculate_nesting_depth(ast),
      
      # Data Flow
      data_flow_graph: generate_dfg(ast),
      variable_mutations: extract_variable_mutations(ast),
      return_points: extract_return_points(ast),
      
      # Dependencies
      called_functions: extract_called_functions(ast),
      calling_functions: [],  # Populated by reverse indexing
      external_calls: extract_external_calls(ast),
      
      # Analysis Results
      complexity_score: calculate_complexity_score(ast),
      maintainability_index: calculate_maintainability_index(ast),
      test_coverage: nil,  # Populated by test analysis
      performance_profile: nil,  # Populated by runtime profiling
      
      # Documentation
      doc_string: extract_doc_string(ast, opts),
      spec: extract_spec(ast, opts),
      examples: extract_examples(ast, opts),
      
      # Metadata
      tags: Keyword.get(opts, :tags, []),
      annotations: Keyword.get(opts, :annotations, %{}),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end
  
  @doc """
  Validates the structure and data integrity of an EnhancedFunctionData.
  
  ## Returns
  - `:ok` if valid
  - `{:error, reason}` if invalid
  """
  @spec validate(t()) :: :ok | {:error, term()}
  def validate(%__MODULE__{} = data) do
    with :ok <- validate_required_fields(data),
         :ok <- validate_ast_consistency(data),
         :ok <- validate_location_data(data),
         :ok <- validate_complexity_metrics(data) do
      :ok
    end
  end
  
  @doc """
  Converts the structure to a format suitable for ETS storage.
  """
  @spec to_ets_format(t()) :: {{atom(), atom(), non_neg_integer()}, binary()}
  def to_ets_format(%__MODULE__{} = data) do
    function_key = {data.module_name, data.function_name, data.arity}
    
    compressed_data = %{
      ast_node_id: data.ast_node_id,
      file_path: data.file_path,
      location: %{
        line_start: data.line_start,
        line_end: data.line_end,
        column_start: data.column_start,
        column_end: data.column_end
      },
      ast_compressed: compress_ast(data.ast),
      characteristics: %{
        visibility: data.visibility,
        is_macro: data.is_macro,
        is_guard: data.is_guard,
        is_callback: data.is_callback,
        is_delegate: data.is_delegate
      },
      analysis: %{
        complexity_score: data.complexity_score,
        cyclomatic_complexity: data.cyclomatic_complexity,
        nesting_depth: data.nesting_depth,
        maintainability_index: data.maintainability_index
      },
      variables_count: length(data.local_variables),
      calls_count: length(data.called_functions),
      metadata: data.metadata
    }
    
    {function_key, :erlang.term_to_binary(compressed_data, [:compressed])}
  end
  
  @doc """
  Converts from ETS storage format back to full structure.
  """
  @spec from_ets_format({{atom(), atom(), non_neg_integer()}, binary()}) :: t()
  def from_ets_format({{module_name, function_name, arity}, binary_data}) do
    compressed_data = :erlang.binary_to_term(binary_data)
    location = compressed_data.location
    characteristics = compressed_data.characteristics
    analysis = compressed_data.analysis
    
    %__MODULE__{
      module_name: module_name,
      function_name: function_name,
      arity: arity,
      ast_node_id: compressed_data.ast_node_id,
      file_path: compressed_data.file_path,
      line_start: location.line_start,
      line_end: location.line_end,
      column_start: location.column_start,
      column_end: location.column_end,
      ast: decompress_ast(compressed_data.ast_compressed),
      head_ast: nil,  # Reconstructed on demand
      body_ast: nil,  # Reconstructed on demand
      visibility: characteristics.visibility,
      is_macro: characteristics.is_macro,
      is_guard: characteristics.is_guard,
      is_callback: characteristics.is_callback,
      is_delegate: characteristics.is_delegate,
      clauses: [],  # Loaded separately for performance
      guard_clauses: [],
      pattern_matches: [],
      parameters: [],
      local_variables: [],
      captures: [],
      control_flow_graph: nil,
      cyclomatic_complexity: analysis.cyclomatic_complexity,
      nesting_depth: analysis.nesting_depth,
      data_flow_graph: nil,
      variable_mutations: [],
      return_points: [],
      called_functions: [],
      calling_functions: [],
      external_calls: [],
      complexity_score: analysis.complexity_score,
      maintainability_index: analysis.maintainability_index,
      test_coverage: nil,
      performance_profile: nil,
      doc_string: nil,
      spec: nil,
      examples: [],
      tags: [],
      annotations: %{},
      metadata: compressed_data.metadata
    }
  end
  
  @doc """
  Updates the function with performance profile data.
  """
  @spec update_performance_profile(t(), PerformanceProfile.t()) :: t()
  def update_performance_profile(%__MODULE__{} = data, profile) do
    %{data | performance_profile: profile}
  end
  
  @doc """
  Adds a calling function reference for reverse indexing.
  """
  @spec add_calling_function(t(), FunctionReference.t()) :: t()
  def add_calling_function(%__MODULE__{} = data, function_ref) do
    %{data | calling_functions: [function_ref | data.calling_functions]}
  end
  
  @doc """
  Gets the function signature as a string.
  """
  @spec get_signature(t()) :: String.t()
  def get_signature(%__MODULE__{} = data) do
    "#{data.module_name}.#{data.function_name}/#{data.arity}"
  end
  
  @doc """
  Checks if the function is a hot path based on complexity and call frequency.
  """
  @spec is_hot_path?(t()) :: boolean()
  def is_hot_path?(%__MODULE__{} = data) do
    high_complexity = data.complexity_score > 10.0
    frequent_calls = length(data.calling_functions) > 5
    
    high_complexity or frequent_calls
  end
  
  @doc """
  Gets all variable names used in the function.
  """
  @spec get_variable_names(t()) :: [atom()]
  def get_variable_names(%__MODULE__{} = data) do
    parameter_names = Enum.map(data.parameters, & &1.name)
    local_names = Enum.map(data.local_variables, & &1.name)
    capture_names = Enum.map(data.captures, & &1.variable_name)
    
    (parameter_names ++ local_names ++ capture_names)
    |> Enum.uniq()
  end
  
  @doc """
  Migrates from basic FunctionData to EnhancedFunctionData.
  """
  @spec from_function_data(ElixirScope.ASTRepository.FunctionData.t()) :: t()
  def from_function_data(function_data) do
    {module_name, function_name, arity} = function_data.function_key
    
    %__MODULE__{
      module_name: module_name,
      function_name: function_name,
      arity: arity,
      ast_node_id: generate_ast_node_id(module_name, function_name, arity, function_data.ast),
      file_path: extract_file_path(function_data.source_location),
      line_start: extract_line_start(function_data.source_location),
      line_end: extract_line_end(function_data.source_location),
      column_start: 1,
      column_end: 1,
      ast: function_data.ast,
      head_ast: nil,
      body_ast: nil,
      visibility: function_data.visibility,
      is_macro: function_data.type == :macro,
      is_guard: false,
      is_callback: function_data.type == :callback,
      is_delegate: false,
      clauses: [],
      guard_clauses: function_data.guards || [],
      pattern_matches: [],
      parameters: [],
      local_variables: [],
      captures: [],
      control_flow_graph: nil,
      cyclomatic_complexity: get_cyclomatic_from_old_metrics(function_data.complexity_metrics),
      nesting_depth: 1,
      data_flow_graph: nil,
      variable_mutations: [],
      return_points: [],
      called_functions: migrate_dependencies_to_calls(function_data.dependencies),
      calling_functions: [],
      external_calls: [],
      complexity_score: get_complexity_score_from_old_metrics(function_data.complexity_metrics),
      maintainability_index: 100.0,
      test_coverage: nil,
      performance_profile: migrate_performance_profile(function_data.performance_profile),
      doc_string: function_data.documentation,
      spec: nil,
      examples: [],
      tags: [],
      annotations: %{},
      metadata: %{
        migrated_from: "FunctionData",
        migration_timestamp: DateTime.to_iso8601(DateTime.utc_now()),
        original_version: function_data.version
      }
    }
  end
  
  # Private helper functions
  
  defp generate_ast_node_id(module_name, function_name, arity, ast) do
    ast_hash = :crypto.hash(:md5, inspect(ast)) |> Base.encode16(case: :lower)
    "#{module_name}:#{function_name}:#{arity}:def:#{String.slice(ast_hash, 0, 8)}"
  end
  
  defp extract_head_and_body({:def, _, [head, body]}), do: {head, body}
  defp extract_head_and_body({:defp, _, [head, body]}), do: {head, body}
  defp extract_head_and_body({:defmacro, _, [head, body]}), do: {head, body}
  defp extract_head_and_body({:defmacrop, _, [head, body]}), do: {head, body}
  defp extract_head_and_body(ast), do: {ast, nil}
  
  defp extract_location(_ast, opts) do
    %{
      line_start: Keyword.get(opts, :line_start, 1),
      line_end: Keyword.get(opts, :line_end, 1),
      column_start: Keyword.get(opts, :column_start, 1),
      column_end: Keyword.get(opts, :column_end, 1)
    }
  end
  
  defp detect_visibility({:defp, _, _}), do: :private
  defp detect_visibility({:defmacrop, _, _}), do: :private
  defp detect_visibility(_), do: :public
  
  defp detect_is_macro({:defmacro, _, _}), do: true
  defp detect_is_macro({:defmacrop, _, _}), do: true
  defp detect_is_macro(_), do: false
  
  defp detect_is_guard(_ast), do: false  # TODO: Implement guard detection
  defp detect_is_callback(_ast, _opts), do: false  # TODO: Implement callback detection
  defp detect_is_delegate(_ast), do: false  # TODO: Implement delegate detection
  
  defp extract_clauses(_ast), do: []  # TODO: Implement clause extraction
  defp extract_guard_clauses(_ast), do: []  # TODO: Implement guard clause extraction
  defp extract_pattern_matches(_ast), do: []  # TODO: Implement pattern match extraction
  defp extract_parameters(_ast), do: []  # TODO: Implement parameter extraction
  defp extract_local_variables(_ast), do: []  # TODO: Implement variable extraction
  defp extract_captures(_ast), do: []  # TODO: Implement capture extraction
  
  defp generate_cfg(_ast), do: nil  # TODO: Implement CFG generation
  defp generate_dfg(_ast), do: nil  # TODO: Implement DFG generation
  
  defp calculate_cyclomatic_complexity(_ast), do: 1  # TODO: Implement complexity calculation
  defp calculate_nesting_depth(_ast), do: 1  # TODO: Implement nesting depth calculation
  defp calculate_complexity_score(_ast), do: 1.0  # TODO: Implement complexity scoring
  defp calculate_maintainability_index(_ast), do: 100.0  # TODO: Implement maintainability index
  
  defp extract_variable_mutations(_ast), do: []  # TODO: Implement mutation extraction
  defp extract_return_points(_ast), do: []  # TODO: Implement return point extraction
  defp extract_called_functions(_ast), do: []  # TODO: Implement function call extraction
  defp extract_external_calls(_ast), do: []  # TODO: Implement external call extraction
  
  defp extract_doc_string(_ast, _opts), do: nil  # TODO: Implement doc string extraction
  defp extract_spec(_ast, _opts), do: nil  # TODO: Implement spec extraction
  defp extract_examples(_ast, _opts), do: []  # TODO: Implement example extraction
  
  defp validate_required_fields(%__MODULE__{module_name: nil}), do: {:error, :missing_module_name}
  defp validate_required_fields(%__MODULE__{function_name: nil}), do: {:error, :missing_function_name}
  defp validate_required_fields(%__MODULE__{ast: nil}), do: {:error, :missing_ast}
  defp validate_required_fields(_), do: :ok
  
  defp validate_ast_consistency(%__MODULE__{arity: arity}) when arity < 0, do: {:error, :invalid_arity}
  defp validate_ast_consistency(_), do: :ok
  
  defp validate_location_data(%__MODULE__{line_start: start, line_end: end_line}) when start > end_line, do: {:error, :invalid_line_range}
  defp validate_location_data(_), do: :ok
  
  defp validate_complexity_metrics(%__MODULE__{complexity_score: score}) when score < 0, do: {:error, :invalid_complexity_score}
  defp validate_complexity_metrics(_), do: :ok
  
  defp compress_ast(ast) do
    ast
    |> :erlang.term_to_binary([:compressed])
    |> Base.encode64()
  end
  
  defp decompress_ast(compressed_string) do
    compressed_string
    |> Base.decode64!()
    |> :erlang.binary_to_term()
  end
  
  defp extract_file_path({file, _line}), do: file
  defp extract_file_path(_), do: ""
  
  defp extract_line_start({_file, line}), do: line
  defp extract_line_start(_), do: 1
  
  defp extract_line_end({_file, line}), do: line
  defp extract_line_end(_), do: 1
  
  defp get_cyclomatic_from_old_metrics(nil), do: 1
  defp get_cyclomatic_from_old_metrics(metrics), do: Map.get(metrics, :cyclomatic, 1)
  
  defp get_complexity_score_from_old_metrics(nil), do: 1.0
  defp get_complexity_score_from_old_metrics(metrics), do: Map.get(metrics, :score, 1.0)
  
  defp migrate_dependencies_to_calls(nil), do: []
  defp migrate_dependencies_to_calls(deps) when is_list(deps) do
    Enum.map(deps, fn
      {module, function, arity} ->
        %FunctionCall{
          target_module: module,
          target_function: function,
          target_arity: arity,
          call_type: :local,
          ast_node_id: "migrated_call",
          line: 1
        }
      _ -> 
        %FunctionCall{
          target_module: :unknown,
          target_function: :unknown,
          target_arity: 0,
          call_type: :unknown,
          ast_node_id: "migrated_call",
          line: 1
        }
    end)
  end
  defp migrate_dependencies_to_calls(_), do: []
  
  defp migrate_performance_profile(nil), do: nil
  defp migrate_performance_profile(old_profile) do
    %PerformanceProfile{
      average_duration_ms: Map.get(old_profile, :average_duration, 0.0),
      min_duration_ms: Map.get(old_profile, :min_duration, 0.0),
      max_duration_ms: Map.get(old_profile, :max_duration, 0.0),
      p95_duration_ms: Map.get(old_profile, :p95_duration, 0.0),
      p99_duration_ms: Map.get(old_profile, :p99_duration, 0.0),
      memory_usage: Map.get(old_profile, :memory_usage, %{}),
      cpu_usage: Map.get(old_profile, :cpu_usage, %{}),
      call_count: 0,
      error_count: 0
    }
  end
end 