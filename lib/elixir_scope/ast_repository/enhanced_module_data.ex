defmodule ElixirScope.ASTRepository.EnhancedModuleData do
  @moduledoc """
  Comprehensive module representation with full AST and analysis metadata.

  This structure extends the basic ModuleData to support advanced AST analysis,
  comprehensive dependency tracking, and integration with CFG/DFG/CPG analysis.

  ## Features
  - Complete AST storage with size and depth metrics
  - Enhanced dependency tracking (imports, aliases, requires, uses)
  - OTP pattern detection and callback analysis
  - Comprehensive complexity metrics and code quality analysis
  - Security risk assessment
  - Efficient serialization for ETS storage

  ## Usage

      iex> module_data = EnhancedModuleData.new(MyModule, ast, source_file: "lib/my_module.ex")
      iex> EnhancedModuleData.validate(module_data)
      :ok
  """

  alias ElixirScope.ASTRepository.Enhanced.{
    EnhancedFunctionData,
    ComplexityMetrics
  }
  alias ElixirScope.ASTRepository.Enhanced.SupportingStructures.{
    MacroData,
    TypespecData,
    ModuleDependency,
    BehaviourUsage,
    CallbackData,
    ChildSpecData,
    CodeSmell,
    SecurityRisk
  }

  @type t :: %__MODULE__{
    # Identity
    module_name: atom(),
    file_path: String.t(),
    file_hash: String.t(),  # SHA256 for change detection

    # AST Data
    ast: Macro.t(),  # Complete module AST
    ast_size: non_neg_integer(),  # Number of AST nodes
    ast_depth: non_neg_integer(),  # Maximum AST depth

    # Module Components
    functions: [EnhancedFunctionData.t()],
    macros: [MacroData.t()],
    module_attributes: %{atom() => term()},
    typespecs: [TypespecData.t()],

    # Dependencies & Relationships
    imports: [ModuleDependency.t()],
    aliases: [ModuleDependency.t()],
    requires: [ModuleDependency.t()],
    uses: [BehaviourUsage.t()],

    # OTP Patterns
    behaviours: [atom()],
    callbacks_implemented: [CallbackData.t()],
    child_specs: [ChildSpecData.t()],

    # Analysis Metadata
    complexity_metrics: ComplexityMetrics.t(),
    code_smells: [CodeSmell.t()],
    security_risks: [SecurityRisk.t()],

    # Timestamps
    last_modified: DateTime.t(),
    last_analyzed: DateTime.t(),

    # Extensible Metadata
    metadata: map()
  }

  defstruct [
    # Identity
    :module_name,
    :file_path,
    :file_hash,

    # AST Data
    :ast,
    :ast_size,
    :ast_depth,

    # Module Components
    :functions,
    :macros,
    :module_attributes,
    :typespecs,

    # Dependencies & Relationships
    :imports,
    :aliases,
    :requires,
    :uses,

    # OTP Patterns
    :behaviours,
    :callbacks_implemented,
    :child_specs,

    # Analysis Metadata
    :complexity_metrics,
    :code_smells,
    :security_risks,

    # Timestamps
    :last_modified,
    :last_analyzed,

    # Extensible Metadata
    :metadata
  ]

  @doc """
  Creates a new EnhancedModuleData structure from parsed AST.

  ## Parameters
  - `module_name` - The module name (atom)
  - `ast` - The parsed AST
  - `opts` - Optional parameters including file_path, functions, etc.

  ## Examples

      iex> ast = quote do: defmodule MyModule, do: def hello, do: :world
      iex> data = EnhancedModuleData.new(MyModule, ast, file_path: "lib/my_module.ex")
      iex> data.module_name
      MyModule
  """
  @spec new(atom(), Macro.t(), keyword()) :: t()
  def new(module_name, ast, opts \\ []) do
    now = DateTime.utc_now()
    file_path = Keyword.get(opts, :file_path, "")

    %__MODULE__{
      # Identity
      module_name: module_name,
      file_path: file_path,
      file_hash: generate_file_hash(ast, file_path),

      # AST Data
      ast: ast,
      ast_size: calculate_ast_size(ast),
      ast_depth: calculate_ast_depth(ast),

      # Module Components
      functions: Keyword.get(opts, :functions, []),
      macros: extract_macros(ast),
      module_attributes: extract_module_attributes(ast),
      typespecs: extract_typespecs(ast),

      # Dependencies & Relationships
      imports: extract_imports(ast),
      aliases: extract_aliases(ast),
      requires: extract_requires(ast),
      uses: extract_uses(ast),

      # OTP Patterns
      behaviours: extract_behaviours(ast),
      callbacks_implemented: extract_callbacks_implemented(ast),
      child_specs: extract_child_specs(ast),

      # Analysis Metadata
      complexity_metrics: calculate_complexity_metrics(ast),
      code_smells: detect_code_smells(ast),
      security_risks: assess_security_risks(ast),

      # Timestamps
      last_modified: now,
      last_analyzed: now,

      # Extensible Metadata
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Validates the structure and data integrity of an EnhancedModuleData.

  ## Returns
  - `:ok` if valid
  - `{:error, reason}` if invalid
  """
  @spec validate(t()) :: :ok | {:error, term()}
  def validate(%__MODULE__{} = data) do
    with :ok <- validate_required_fields(data),
         :ok <- validate_ast_consistency(data),
         :ok <- validate_dependencies(data),
         :ok <- validate_timestamps(data) do
      :ok
    end
  end

  @doc """
  Converts the structure to a format suitable for ETS storage.

  This function optimizes the data for storage by:
  - Compressing large AST structures
  - Converting datetime to timestamps
  - Optimizing nested structures
  """
  @spec to_ets_format(t()) :: {atom(), binary()}
  def to_ets_format(%__MODULE__{} = data) do
    compressed_data = %{
      module_name: data.module_name,
      file_path: data.file_path,
      file_hash: data.file_hash,
      ast_compressed: compress_ast(data.ast),
      ast_size: data.ast_size,
      ast_depth: data.ast_depth,
      functions_count: length(data.functions),
      macros_count: length(data.macros),
      complexity_score: get_complexity_score(data.complexity_metrics),
      last_modified_ts: DateTime.to_unix(data.last_modified),
      last_analyzed_ts: DateTime.to_unix(data.last_analyzed),
      metadata: data.metadata
    }

    {data.module_name, :erlang.term_to_binary(compressed_data, [:compressed])}
  end

  @doc """
  Converts from ETS storage format back to full structure.
  """
  @spec from_ets_format({atom(), binary()}) :: t()
  def from_ets_format({module_name, binary_data}) do
    compressed_data = :erlang.binary_to_term(binary_data)

    %__MODULE__{
      module_name: module_name,
      file_path: compressed_data.file_path,
      file_hash: compressed_data.file_hash,
      ast: decompress_ast(compressed_data.ast_compressed),
      ast_size: compressed_data.ast_size,
      ast_depth: compressed_data.ast_depth,
      functions: [],  # Loaded separately for performance
      macros: [],
      module_attributes: %{},
      typespecs: [],
      imports: [],
      aliases: [],
      requires: [],
      uses: [],
      behaviours: [],
      callbacks_implemented: [],
      child_specs: [],
      complexity_metrics: %ComplexityMetrics{score: compressed_data.complexity_score},
      code_smells: [],
      security_risks: [],
      last_modified: DateTime.from_unix!(compressed_data.last_modified_ts),
      last_analyzed: DateTime.from_unix!(compressed_data.last_analyzed_ts),
      metadata: compressed_data.metadata
    }
  end

  @doc """
  Updates the module with new function data.
  """
  @spec add_function(t(), EnhancedFunctionData.t()) :: t()
  def add_function(%__MODULE__{} = data, function_data) do
    %{data |
      functions: [function_data | data.functions],
      last_analyzed: DateTime.utc_now()
    }
  end

  @doc """
  Gets all function names and arities for this module.
  """
  @spec get_function_signatures(t()) :: [{atom(), non_neg_integer()}]
  def get_function_signatures(%__MODULE__{} = data) do
    Enum.map(data.functions, fn func -> {func.function_name, func.arity} end)
  end

  @doc """
  Checks if the module has been modified since last analysis.
  """
  @spec needs_reanalysis?(t(), String.t()) :: boolean()
  def needs_reanalysis?(%__MODULE__{} = data, current_file_hash) do
    data.file_hash != current_file_hash
  end

  @doc """
  Gets the total complexity score for the module.
  """
  @spec get_total_complexity(t()) :: float()
  def get_total_complexity(%__MODULE__{} = data) do
    module_complexity = get_complexity_score(data.complexity_metrics)
    function_complexity =
      data.functions
      |> Enum.map(& &1.complexity_score)
      |> Enum.sum()

    module_complexity + function_complexity
  end

  @doc """
  Migrates from basic ModuleData to EnhancedModuleData.
  """
  @spec from_module_data(ElixirScope.ASTRepository.ModuleData.t()) :: t()
  def from_module_data(module_data) do
    now = DateTime.utc_now()

    %__MODULE__{
      module_name: module_data.module_name,
      file_path: module_data.source_file || "",
      file_hash: module_data.compilation_hash || "",
      ast: module_data.ast,
      ast_size: calculate_ast_size(module_data.ast),
      ast_depth: calculate_ast_depth(module_data.ast),
      functions: [],  # Will be populated separately
      macros: [],
      module_attributes: %{},
      typespecs: [],
      imports: [],
      aliases: [],
      requires: [],
      uses: [],
      behaviours: [],
      callbacks_implemented: [],
      child_specs: [],
      complexity_metrics: migrate_complexity_metrics(module_data.complexity_metrics),
      code_smells: [],
      security_risks: [],
      last_modified: DateTime.from_unix!(module_data.updated_at, :microsecond),
      last_analyzed: now,
      metadata: %{
        migrated_from: "ModuleData",
        migration_timestamp: DateTime.to_iso8601(now),
        original_version: module_data.version
      }
    }
  end

  # Private helper functions

  defp generate_file_hash(ast, file_path) do
    content = "#{inspect(ast)}#{file_path}"
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end

  defp calculate_ast_size(ast) do
    ast
    |> Macro.prewalk(0, fn node, acc -> {node, acc + 1} end)
    |> elem(1)
  end

  defp calculate_ast_depth(ast) do
    ast
    |> Macro.prewalk(0, fn
      {_, _, children}, depth when is_list(children) ->
        max_child_depth = children
        |> Enum.map(fn child -> calculate_ast_depth(child) end)
        |> Enum.max(fn -> 0 end)
        {{}, depth + 1 + max_child_depth}
      _, depth ->
        {{}, depth}
    end)
    |> elem(1)
  end

  defp extract_macros(_ast), do: []  # TODO: Implement macro extraction
  defp extract_module_attributes(_ast), do: %{}  # TODO: Implement attribute extraction
  defp extract_typespecs(_ast), do: []  # TODO: Implement typespec extraction
  defp extract_imports(_ast), do: []  # TODO: Implement import extraction
  defp extract_aliases(_ast), do: []  # TODO: Implement alias extraction
  defp extract_requires(_ast), do: []  # TODO: Implement require extraction
  defp extract_uses(_ast), do: []  # TODO: Implement use extraction
  defp extract_behaviours(_ast), do: []  # TODO: Implement behaviour extraction
  defp extract_callbacks_implemented(_ast), do: []  # TODO: Implement callback extraction
  defp extract_child_specs(_ast), do: []  # TODO: Implement child spec extraction

  defp calculate_complexity_metrics(_ast) do
    %ComplexityMetrics{
      score: 1.0,
      cyclomatic: 1,
      cognitive: 1,
      halstead: %{},
      maintainability_index: 100.0
    }
  end

  defp detect_code_smells(_ast), do: []  # TODO: Implement code smell detection
  defp assess_security_risks(_ast), do: []  # TODO: Implement security risk assessment

  defp validate_required_fields(%__MODULE__{module_name: nil}), do: {:error, :missing_module_name}
  defp validate_required_fields(%__MODULE__{ast: nil}), do: {:error, :missing_ast}
  defp validate_required_fields(_), do: :ok

  defp validate_ast_consistency(%__MODULE__{ast_size: size}) when size <= 0, do: {:error, :invalid_ast_size}
  defp validate_ast_consistency(%__MODULE__{ast_depth: depth}) when depth <= 0, do: {:error, :invalid_ast_depth}
  defp validate_ast_consistency(_), do: :ok

  defp validate_dependencies(_), do: :ok  # TODO: Implement dependency validation

  defp validate_timestamps(%__MODULE__{last_modified: nil}), do: {:error, :missing_last_modified}
  defp validate_timestamps(%__MODULE__{last_analyzed: nil}), do: {:error, :missing_last_analyzed}
  defp validate_timestamps(_), do: :ok

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

  defp get_complexity_score(%ComplexityMetrics{score: score}), do: score
  defp get_complexity_score(_), do: 1.0

  defp migrate_complexity_metrics(nil) do
    %ComplexityMetrics{score: 1.0, cyclomatic: 1, cognitive: 1, halstead: %{}, maintainability_index: 100.0}
  end
  defp migrate_complexity_metrics(old_metrics) do
    %ComplexityMetrics{
      score: Map.get(old_metrics, :score, 1.0),
      cyclomatic: Map.get(old_metrics, :cyclomatic, 1),
      cognitive: Map.get(old_metrics, :cognitive, 1),
      halstead: Map.get(old_metrics, :halstead, %{}),
      maintainability_index: Map.get(old_metrics, :maintainability_index, 100.0)
    }
  end
end
