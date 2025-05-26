defmodule ElixirScope.ASTRepository.ModuleData do
  @moduledoc """
  Complete module representation with static AST and runtime correlation data.
  
  This structure stores all information about a module including:
  - Original AST with instrumentation metadata
  - Static analysis results
  - Runtime correlation data
  - Performance metrics
  """
  
  alias ElixirScope.Utils
  
  @type module_name :: atom()
  @type ast_node_id :: binary()
  @type correlation_id :: binary()
  @type function_key :: {module_name(), atom(), non_neg_integer()}
  
  defstruct [
    # Core AST Information
    :module_name,          # atom() - Module name
    :ast,                  # AST - Original parsed AST
    :source_file,          # String.t() - Source file path
    :compilation_hash,     # String.t() - Hash for change detection
    :compilation_timestamp, # integer() - When module was compiled
    
    # Instrumentation Metadata
    :instrumentation_points, # [InstrumentationPoint.t()] - Points for tracing
    :ast_node_mapping,     # %{ast_node_id => AST_node} - Node ID to AST mapping
    :correlation_metadata, # %{correlation_id => ast_node_id} - Correlation mapping
    
    # Static Analysis Results
    :module_type,          # :genserver | :supervisor | :phoenix_controller | etc.
    :complexity_metrics,   # ComplexityMetrics.t()
    :dependencies,         # [module_name()] - Module dependencies
    :exports,              # [{function_name, arity}] - Public functions
    :callbacks,            # [callback_name()] - OTP callbacks
    :patterns,             # [pattern_name()] - Architectural patterns
    :attributes,           # [attribute()] - Module attributes
    
    # Runtime Correlation Data
    :runtime_insights,     # RuntimeInsights.t() - Aggregated runtime data
    :execution_frequency,  # %{function_key => frequency} - How often functions run
    :performance_data,     # %{function_key => PerformanceMetrics.t()}
    :error_patterns,       # [ErrorPattern.t()] - Runtime error patterns
    :message_flows,        # [MessageFlow.t()] - Inter-process communications
    
    # Metadata
    :created_at,           # integer() - Creation timestamp
    :updated_at,           # integer() - Last update timestamp
    :version               # String.t() - Data structure version
  ]
  
  @type t :: %__MODULE__{}
  
  @doc """
  Creates a new ModuleData structure from parsed AST.
  
  ## Parameters
  - `module_name` - The module name (atom)
  - `ast` - The parsed AST
  - `opts` - Optional parameters including source_file, instrumentation_points, etc.
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
      module_type: detect_module_type(ast),
      complexity_metrics: calculate_complexity_metrics(ast),
      dependencies: extract_dependencies(ast),
      exports: extract_exports(ast),
      callbacks: extract_callbacks(ast),
      patterns: detect_patterns(ast),
      attributes: extract_attributes(ast),
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
  
  #############################################################################
  # Private Helper Functions
  #############################################################################
  
  defp generate_compilation_hash(ast, source_file) do
    content = "#{inspect(ast)}#{source_file}"
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end
  
  defp detect_module_type(ast) do
    # Simple pattern matching to detect common module types
    cond do
      has_use_directive?(ast, GenServer) -> :genserver
      has_use_directive?(ast, Supervisor) -> :supervisor
      has_use_directive?(ast, Agent) -> :agent
      has_use_directive?(ast, Task) -> :task
      has_phoenix_controller_pattern?(ast) -> :phoenix_controller
      has_phoenix_live_view_pattern?(ast) -> :phoenix_live_view
      has_ecto_schema_pattern?(ast) -> :ecto_schema
      true -> :module
    end
  end
  
  defp calculate_complexity_metrics(ast) do
    # Basic complexity calculation - can be enhanced
    %{
      cyclomatic_complexity: count_decision_points(ast),
      cognitive_complexity: count_cognitive_complexity(ast),
      lines_of_code: count_lines_of_code(ast),
      function_count: count_functions(ast),
      nesting_depth: calculate_max_nesting_depth(ast)
    }
  end
  
  defp extract_dependencies(ast) do
    # Extract module dependencies from import, alias, use, require statements
    dependencies = []
    
    # Walk the AST to find dependency declarations
    dependencies
    |> extract_imports(ast)
    |> extract_aliases(ast)
    |> extract_uses(ast)
    |> extract_requires(ast)
    |> Enum.uniq()
  end
  
  defp extract_exports(ast) do
    # Extract public function definitions
    case ast do
      {:defmodule, _, [_module_name, [do: body]]} ->
        extract_function_definitions(body, :public)
      _ ->
        []
    end
  end
  
  defp extract_callbacks(ast) do
    # Extract OTP callback implementations
    case ast do
      {:defmodule, _, [_name, [do: body]]} ->
        extract_callback_functions(body)
      _ ->
        []
    end
  end
  
  defp extract_callback_functions({:__block__, _, statements}) do
    statements
    |> Enum.filter(&is_callback_function?/1)
    |> Enum.map(&extract_callback_info/1)
    |> Enum.reject(&is_nil/1)
  end
  
  defp extract_callback_functions(statement) do
    if is_callback_function?(statement) do
      case extract_callback_info(statement) do
        nil -> []
        callback -> [callback]
      end
    else
      []
    end
  end
  
  defp is_callback_function?({:def, _, [{name, _, args} | _]}) do
    arity = if is_list(args), do: length(args), else: 0
    
    # Common OTP callbacks
    case {name, arity} do
      {:init, 1} -> true
      {:handle_call, 3} -> true
      {:handle_cast, 2} -> true
      {:handle_info, 2} -> true
      {:terminate, 2} -> true
      {:code_change, 3} -> true
      {:handle_continue, 2} -> true
      # Phoenix LiveView callbacks
      {:mount, 3} -> true
      {:handle_event, 3} -> true
      {:handle_params, 3} -> true
      {:render, 1} -> true
      # Phoenix Controller callbacks
      {:action, 2} -> true
      # Task callbacks
      {:run, 1} -> true
      _ -> false
    end
  end
  
  defp is_callback_function?(_), do: false
  
  defp extract_callback_info({:def, _, [{name, _, args} | _]}) do
    arity = if is_list(args), do: length(args), else: 0
    
    %{
      name: name,
      arity: arity,
      type: determine_callback_type(name, arity)
    }
  end
  
  defp extract_callback_info(_), do: nil
  
  defp determine_callback_type(name, arity) do
    case {name, arity} do
      {:init, 1} -> :genserver
      {:handle_call, 3} -> :genserver
      {:handle_cast, 2} -> :genserver
      {:handle_info, 2} -> :genserver
      {:terminate, 2} -> :genserver
      {:code_change, 3} -> :genserver
      {:handle_continue, 2} -> :genserver
      {:mount, 3} -> :live_view
      {:handle_event, 3} -> :live_view
      {:handle_params, 3} -> :live_view
      {:render, 1} -> :live_view
      {:action, 2} -> :controller
      {:run, 1} -> :task
      _ -> :unknown
    end
  end
  
  defp detect_patterns(ast) do
    # Detect architectural patterns
    patterns = []
    
    patterns
    |> maybe_add_pattern(:singleton, has_singleton_pattern?(ast))
    |> maybe_add_pattern(:factory, has_factory_pattern?(ast))
    |> maybe_add_pattern(:observer, has_observer_pattern?(ast))
    |> maybe_add_pattern(:state_machine, has_state_machine_pattern?(ast))
  end
  
  defp extract_attributes(ast) do
    # Extract module attributes
    case ast do
      {:defmodule, _, [_name, [do: body]]} ->
        extract_attribute_statements(body)
      _ ->
        []
    end
  end
  
  defp extract_attribute_statements({:__block__, _, statements}) do
    statements
    |> Enum.filter(&is_attribute_statement?/1)
    |> Enum.map(&extract_attribute_info/1)
    |> Enum.reject(&is_nil/1)
  end
  
  defp extract_attribute_statements(statement) do
    if is_attribute_statement?(statement) do
      case extract_attribute_info(statement) do
        nil -> []
        attribute -> [attribute]
      end
    else
      []
    end
  end
  
  defp is_attribute_statement?({:@, _, [{name, _, _}]}) when is_atom(name) do
    true
  end
  
  defp is_attribute_statement?(_), do: false
  
  defp extract_attribute_info({:@, _, [{name, _, [value]}]}) do
    %{
      name: name,
      value: value,
      type: determine_attribute_type(name)
    }
  end
  
  defp extract_attribute_info({:@, _, [{name, _, _}]}) do
    %{
      name: name,
      value: nil,
      type: determine_attribute_type(name)
    }
  end
  
  defp extract_attribute_info(_), do: nil
  
  defp determine_attribute_type(name) do
    case name do
      :moduledoc -> :documentation
      :doc -> :documentation
      :behaviour -> :behaviour
      :behavior -> :behaviour  # American spelling
      :impl -> :implementation
      :spec -> :typespec
      :type -> :typespec
      :typep -> :typespec
      :opaque -> :typespec
      :callback -> :callback
      :macrocallback -> :callback
      :optional_callbacks -> :callback
      :derive -> :protocol
      :protocol -> :protocol
      :fallback_to_any -> :protocol
      _ -> :custom
    end
  end
  
  # Helper functions for AST analysis
  defp has_use_directive?(ast, target_module) do
    # Check if AST contains a use directive for the given module
    case ast do
      {:defmodule, _, [_name, [do: body]]} ->
        find_use_directive(body, target_module)
      _ ->
        false
    end
  end
  
  defp find_use_directive({:__block__, _, statements}, target_module) do
    Enum.any?(statements, &check_use_statement(&1, target_module))
  end
  
  defp find_use_directive(statement, target_module) do
    check_use_statement(statement, target_module)
  end
  
  defp check_use_statement({:use, _, [{:__aliases__, _, modules}]}, target_module) do
    # In AST, modules appear as atoms like :GenServer
    # But target_module is the full module name like Elixir.GenServer
    # We need to compare the last part of the module name
    ast_module = List.last(modules)
    target_atom = case target_module do
      atom when is_atom(atom) ->
        # Convert Elixir.GenServer to :GenServer for comparison
        atom |> Module.split() |> List.last() |> String.to_atom()
      _ -> target_module
    end
    ast_module == target_atom
  end
  
  defp check_use_statement({:use, _, [module]}, target_module) when is_atom(module) do
    module == target_module
  end
  
  defp check_use_statement(_, _), do: false
  
  defp has_phoenix_controller_pattern?(ast) do
    # Check for Phoenix controller patterns
    case ast do
      {:defmodule, _, [_name, [do: body]]} ->
        has_controller_use_directive?(body) or has_controller_functions?(body)
      _ ->
        false
    end
  end
  
  defp has_controller_use_directive?({:__block__, _, statements}) do
    Enum.any?(statements, &is_controller_use_statement?/1)
  end
  
  defp has_controller_use_directive?(statement) do
    is_controller_use_statement?(statement)
  end
  
  defp is_controller_use_statement?({:use, _, [{:__aliases__, _, modules}]}) do
    # Check for patterns like "use MyApp.Web, :controller" or "use Phoenix.Controller"
    case modules do
      [_, "Web"] -> true  # MyApp.Web pattern
      ["Phoenix", "Controller"] -> true
      _ -> false
    end
  end
  
  defp is_controller_use_statement?({:use, _, [module, :controller]}) when is_atom(module) do
    true
  end
  
  defp is_controller_use_statement?(_), do: false
  
  defp has_controller_functions?({:__block__, _, statements}) do
    Enum.any?(statements, &is_controller_function?/1)
  end
  
  defp has_controller_functions?(statement) do
    is_controller_function?(statement)
  end
  
  defp is_controller_function?({:def, _, [{name, _, _} | _]}) when name in [:index, :show, :new, :create, :edit, :update, :delete] do
    true
  end
  
  defp is_controller_function?(_), do: false
  
  defp has_phoenix_live_view_pattern?(ast) do
    # Check for Phoenix LiveView patterns
    case ast do
      {:defmodule, _, [_name, [do: body]]} ->
        has_live_view_use_directive?(body) or has_live_view_functions?(body)
      _ ->
        false
    end
  end
  
  defp has_live_view_use_directive?({:__block__, _, statements}) do
    Enum.any?(statements, &is_live_view_use_statement?/1)
  end
  
  defp has_live_view_use_directive?(statement) do
    is_live_view_use_statement?(statement)
  end
  
  defp is_live_view_use_statement?({:use, _, [{:__aliases__, _, modules}]}) do
    case modules do
      ["Phoenix", "LiveView"] -> true
      [_, "Web", "LiveView"] -> true  # MyApp.Web.LiveView pattern
      _ -> false
    end
  end
  
  defp is_live_view_use_statement?(_), do: false
  
  defp has_live_view_functions?({:__block__, _, statements}) do
    Enum.any?(statements, &is_live_view_function?/1)
  end
  
  defp has_live_view_functions?(statement) do
    is_live_view_function?(statement)
  end
  
  defp is_live_view_function?({:def, _, [{name, _, _} | _]}) when name in [:mount, :handle_event, :handle_info, :handle_params, :render] do
    true
  end
  
  defp is_live_view_function?(_), do: false
  
  defp has_ecto_schema_pattern?(ast) do
    # Check for Ecto schema patterns
    case ast do
      {:defmodule, _, [_name, [do: body]]} ->
        has_ecto_use_directive?(body) or has_schema_definition?(body)
      _ ->
        false
    end
  end
  
  defp has_ecto_use_directive?({:__block__, _, statements}) do
    Enum.any?(statements, &is_ecto_use_statement?/1)
  end
  
  defp has_ecto_use_directive?(statement) do
    is_ecto_use_statement?(statement)
  end
  
  defp is_ecto_use_statement?({:use, _, [{:__aliases__, _, modules}]}) do
    case modules do
      ["Ecto", "Schema"] -> true
      [_, "Schema"] -> true  # MyApp.Schema pattern
      _ -> false
    end
  end
  
  defp is_ecto_use_statement?(_), do: false
  
  defp has_schema_definition?({:__block__, _, statements}) do
    Enum.any?(statements, &is_schema_statement?/1)
  end
  
  defp has_schema_definition?(statement) do
    is_schema_statement?(statement)
  end
  
  defp is_schema_statement?({:schema, _, _}), do: true
  defp is_schema_statement?({:embedded_schema, _, _}), do: true
  defp is_schema_statement?(_), do: false
  
  defp count_decision_points(_ast) do
    # Count if/case/cond/try statements for cyclomatic complexity
    1  # TODO: Implement decision point counting
  end
  
  defp count_cognitive_complexity(_ast) do
    # Calculate cognitive complexity
    1  # TODO: Implement cognitive complexity calculation
  end
  
  defp count_lines_of_code(_ast) do
    # Count lines of code
    1  # TODO: Implement LOC counting
  end
  
  defp count_functions(_ast) do
    # Count function definitions
    0  # TODO: Implement function counting
  end
  
  defp calculate_max_nesting_depth(_ast) do
    # Calculate maximum nesting depth
    1  # TODO: Implement nesting depth calculation
  end
  
  defp extract_imports(dependencies, _ast) do
    # Extract import statements
    dependencies  # TODO: Implement import extraction
  end
  
  defp extract_aliases(dependencies, _ast) do
    # Extract alias statements
    dependencies  # TODO: Implement alias extraction
  end
  
  defp extract_uses(dependencies, _ast) do
    # Extract use statements
    dependencies  # TODO: Implement use extraction
  end
  
  defp extract_requires(dependencies, _ast) do
    # Extract require statements
    dependencies  # TODO: Implement require extraction
  end
  
  defp extract_function_definitions(_body, _visibility) do
    # Extract function definitions
    []  # TODO: Implement function definition extraction
  end
  
  defp maybe_add_pattern(patterns, pattern, true), do: [pattern | patterns]
  defp maybe_add_pattern(patterns, _pattern, false), do: patterns
  
  defp has_singleton_pattern?(ast) do
    # Basic singleton pattern detection - look for single instance creation
    case ast do
      {:defmodule, _, [_name, [do: body]]} ->
        has_singleton_indicators?(body)
      _ ->
        false
    end
  end
  
  defp has_factory_pattern?(ast) do
    # Basic factory pattern detection - look for create/build functions
    case ast do
      {:defmodule, _, [_name, [do: body]]} ->
        has_factory_indicators?(body)
      _ ->
        false
    end
  end
  
  defp has_observer_pattern?(ast) do
    # Basic observer pattern detection - look for notify/subscribe functions
    case ast do
      {:defmodule, _, [_name, [do: body]]} ->
        has_observer_indicators?(body)
      _ ->
        false
    end
  end
  
  defp has_state_machine_pattern?(ast) do
    # Basic state machine pattern detection - look for state transitions
    case ast do
      {:defmodule, _, [_name, [do: body]]} ->
        has_state_machine_indicators?(body)
      _ ->
        false
    end
  end
  
  # Helper functions for pattern detection
  defp has_singleton_indicators?({:__block__, _, statements}) do
    Enum.any?(statements, &is_singleton_function?/1)
  end
  
  defp has_singleton_indicators?(statement) do
    is_singleton_function?(statement)
  end
  
  defp is_singleton_function?({:def, _, [{name, _, _} | _]}) when name in [:instance, :get_instance, :singleton] do
    true
  end
  
  defp is_singleton_function?(_), do: false
  
  defp has_factory_indicators?({:__block__, _, statements}) do
    Enum.any?(statements, &is_factory_function?/1)
  end
  
  defp has_factory_indicators?(statement) do
    is_factory_function?(statement)
  end
  
  defp is_factory_function?({:def, _, [{name, _, _} | _]}) when name in [:create, :build, :make, :new] do
    true
  end
  
  defp is_factory_function?(_), do: false
  
  defp has_observer_indicators?({:__block__, _, statements}) do
    Enum.any?(statements, &is_observer_function?/1)
  end
  
  defp has_observer_indicators?(statement) do
    is_observer_function?(statement)
  end
  
  defp is_observer_function?({:def, _, [{name, _, _} | _]}) when name in [:notify, :subscribe, :unsubscribe, :add_observer, :remove_observer] do
    true
  end
  
  defp is_observer_function?(_), do: false
  
  defp has_state_machine_indicators?({:__block__, _, statements}) do
    Enum.any?(statements, &is_state_machine_function?/1)
  end
  
  defp has_state_machine_indicators?(statement) do
    is_state_machine_function?(statement)
  end
  
  defp is_state_machine_function?({:def, _, [{name, _, _} | _]}) when name in [:transition, :change_state, :next_state, :current_state] do
    true
  end
  
  defp is_state_machine_function?(_), do: false
end 