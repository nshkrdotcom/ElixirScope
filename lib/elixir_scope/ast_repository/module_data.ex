# ==============================================================================
# Core Module Data Structure
# ==============================================================================

defmodule ElixirScope.ASTRepository.ModuleData do
  @moduledoc """
  Core module representation with static AST and runtime correlation data.

  This is the main data structure that coordinates with specialized analyzers
  and processors for comprehensive module analysis.
  """

  alias ElixirScope.Utils
  alias ElixirScope.ASTRepository.ModuleData.{
    ASTAnalyzer,
    ComplexityCalculator,
    DependencyExtractor,
    PatternDetector,
    AttributeExtractor
  }

  @type module_name :: atom()
  @type ast_node_id :: binary()
  @type correlation_id :: binary()
  @type function_key :: {module_name(), atom(), non_neg_integer()}

  defstruct [
    # Core AST Information
    :module_name,
    :ast,
    :source_file,
    :compilation_hash,
    :compilation_timestamp,

    # Instrumentation Metadata
    :instrumentation_points,
    :ast_node_mapping,
    :correlation_metadata,

    # Static Analysis Results
    :module_type,
    :complexity_metrics,
    :dependencies,
    :exports,
    :callbacks,
    :patterns,
    :attributes,

    # Runtime Correlation Data
    :runtime_insights,
    :execution_frequency,
    :performance_data,
    :error_patterns,
    :message_flows,

    # Metadata
    :created_at,
    :updated_at,
    :version
  ]

  @type t :: %__MODULE__{}

  @doc """
  Creates a new ModuleData structure from parsed AST.
  """
  @spec new(module_name(), term(), keyword()) :: t()
  def new(module_name, ast, opts \\ []) do
    timestamp = Utils.monotonic_timestamp()
    source_file = Keyword.get(opts, :source_file)

    %__MODULE__{
      module_name: module_name,
      ast: ast,
      source_file: source_file,
      compilation_hash: generate_compilation_hash(ast, source_file),
      compilation_timestamp: timestamp,
      instrumentation_points: Keyword.get(opts, :instrumentation_points, []),
      ast_node_mapping: Keyword.get(opts, :ast_node_mapping, %{}),
      correlation_metadata: Keyword.get(opts, :correlation_metadata, %{}),
      module_type: ASTAnalyzer.detect_module_type(ast),
      complexity_metrics: ComplexityCalculator.calculate_metrics(ast),
      dependencies: DependencyExtractor.extract_dependencies(ast),
      exports: ASTAnalyzer.extract_exports(ast),
      callbacks: ASTAnalyzer.extract_callbacks(ast),
      patterns: PatternDetector.detect_patterns(ast),
      attributes: AttributeExtractor.extract_attributes(ast),
      runtime_insights: nil,
      execution_frequency: %{},
      performance_data: %{},
      error_patterns: [],
      message_flows: [],
      created_at: timestamp,
      updated_at: timestamp,
      version: "1.0.0"
    }
  end

  @doc """
  Updates the runtime insights for this module.
  """
  @spec update_runtime_insights(t(), map()) :: t()
  def update_runtime_insights(%__MODULE__{} = module_data, insights) do
    %{module_data |
      runtime_insights: insights,
      updated_at: Utils.monotonic_timestamp()
    }
  end

  @doc """
  Updates execution frequency data for a specific function.
  """
  @spec update_execution_frequency(t(), function_key(), non_neg_integer()) :: t()
  def update_execution_frequency(%__MODULE__{} = module_data, function_key, frequency) do
    updated_frequency = Map.put(module_data.execution_frequency, function_key, frequency)

    %{module_data |
      execution_frequency: updated_frequency,
      updated_at: Utils.monotonic_timestamp()
    }
  end

  @doc """
  Updates performance data for a specific function.
  """
  @spec update_performance_data(t(), function_key(), map()) :: t()
  def update_performance_data(%__MODULE__{} = module_data, function_key, performance_metrics) do
    updated_performance = Map.put(module_data.performance_data, function_key, performance_metrics)

    %{module_data |
      performance_data: updated_performance,
      updated_at: Utils.monotonic_timestamp()
    }
  end

  @doc """
  Adds an error pattern to the module's runtime data.
  """
  @spec add_error_pattern(t(), map()) :: t()
  def add_error_pattern(%__MODULE__{} = module_data, error_pattern) do
    updated_patterns = [error_pattern | module_data.error_patterns]

    %{module_data |
      error_patterns: updated_patterns,
      updated_at: Utils.monotonic_timestamp()
    }
  end

  @doc """
  Gets all function keys for this module.
  """
  @spec get_function_keys(t()) :: [function_key()]
  def get_function_keys(%__MODULE__{} = module_data) do
    module_data.exports
    |> Enum.map(fn {name, arity} -> {module_data.module_name, name, arity} end)
  end

  @doc """
  Checks if the module has runtime correlation data.
  """
  @spec has_runtime_data?(t()) :: boolean()
  def has_runtime_data?(%__MODULE__{} = module_data) do
    not is_nil(module_data.runtime_insights) or
    map_size(module_data.execution_frequency) > 0 or
    map_size(module_data.performance_data) > 0 or
    length(module_data.error_patterns) > 0
  end

  @doc """
  Gets the correlation IDs associated with this module.
  """
  @spec get_correlation_ids(t()) :: [correlation_id()]
  def get_correlation_ids(%__MODULE__{} = module_data) do
    Map.keys(module_data.correlation_metadata)
  end

  @doc """
  Gets the AST node IDs for this module.
  """
  @spec get_ast_node_ids(t()) :: [ast_node_id()]
  def get_ast_node_ids(%__MODULE__{} = module_data) do
    Map.keys(module_data.ast_node_mapping)
  end

  # Private helper
  defp generate_compilation_hash(ast, source_file) do
    content = "#{inspect(ast)}#{source_file}"
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end
end
