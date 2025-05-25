defmodule ElixirScope.AI.CodeAnalyzer do
  @moduledoc """
  AI-powered code analysis engine for ElixirScope.

  Analyzes Elixir codebases to understand structure, complexity, and patterns
  to generate intelligent instrumentation recommendations.

  Initially implemented with rule-based heuristics, designed to be enhanced
  with actual LLM integration.
  """

  alias ElixirScope.AI.{ComplexityAnalyzer, PatternRecognizer}

  defstruct [
    :module_type,
    :complexity_score,
    :callbacks,
    :actions,
    :events,
    :children,
    :strategy,
    :state_complexity,
    :performance_critical,
    :database_interactions,
    :recommended_instrumentation,
    :confidence_score,
    :has_mount
  ]

  @doc """
  Analyzes a single piece of Elixir code and returns analysis results.
  """
  def analyze_code(code_string) when is_binary(code_string) do
    with {:ok, ast} <- Code.string_to_quoted(code_string) do
      analyze_ast(ast)
    else
      {:error, _} -> {:error, :invalid_code}
    end
  end

  @doc """
  Analyzes a complete Elixir project directory.
  """
  def analyze_project(project_path) do
    elixir_files = find_elixir_files(project_path)

    module_analyses =
      elixir_files
      |> Enum.map(&analyze_file/1)
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, analysis} -> analysis end)

    project_structure = analyze_project_structure(module_analyses)
    supervision_tree = build_supervision_tree(module_analyses)
    message_flows = analyze_inter_module_communication(module_analyses)

    %{
      total_modules: length(module_analyses),
      genserver_modules: count_by_type(module_analyses, :genserver),
      phoenix_modules: count_by_type(module_analyses, :phoenix_controller) +
                      count_by_type(module_analyses, :phoenix_liveview),
      supervision_tree: supervision_tree,
      project_structure: project_structure,
      external_dependencies: extract_dependencies(module_analyses),
      internal_message_flows: message_flows,
      recommended_plan: generate_project_plan(module_analyses),
      estimated_overhead: calculate_estimated_overhead(module_analyses)
    }
  end

  @doc """
  Generates an instrumentation plan for a project.
  """
  def generate_instrumentation_plan(project_path) do
    project_analysis = analyze_project(project_path)

    priority_modules = prioritize_modules(project_analysis)
    instrumentation_strategies = generate_strategies(priority_modules)

    %{
      priority_modules: priority_modules,
      instrumentation_strategies: instrumentation_strategies,
      estimated_impact: calculate_impact(instrumentation_strategies),
      configuration: generate_configuration(instrumentation_strategies)
    }
  end

  @doc """
  Analyzes message flow patterns across modules.
  """
  def analyze_message_flows(code_samples) do
    call_patterns = extract_call_patterns(code_samples)
    pubsub_patterns = extract_pubsub_patterns(code_samples)

    %{
      call_patterns: call_patterns,
      pubsub_patterns: pubsub_patterns,
      correlation_opportunities: identify_correlation_opportunities(call_patterns, pubsub_patterns)
    }
  end

  @doc """
  Analyzes a single function for complexity and performance characteristics.
  """
  def analyze_function(function_code) do
    {:ok, ast} = Code.string_to_quoted(function_code)

    complexity = ComplexityAnalyzer.calculate_complexity(ast)
    performance_indicators = analyze_performance_patterns(ast)

    %{
      complexity_score: complexity.score,
      nesting_depth: complexity.nesting_depth,
      performance_critical: performance_indicators.is_critical,
      recommended_instrumentation: recommend_function_instrumentation(complexity, performance_indicators)
    }
  end

  # Private implementation functions

  defp analyze_ast(ast) do
    module_type = PatternRecognizer.identify_module_type(ast)
    complexity = ComplexityAnalyzer.analyze_module(ast)
    patterns = PatternRecognizer.extract_patterns(ast)

    %__MODULE__{
      module_type: module_type,
      complexity_score: complexity.score,
      callbacks: patterns.callbacks,
      actions: patterns.actions,
      events: patterns.events,
      children: patterns.children,
      strategy: patterns.strategy,
      state_complexity: complexity.state_complexity,
      performance_critical: complexity.performance_critical,
      database_interactions: patterns.database_interactions,
      recommended_instrumentation: recommend_instrumentation(module_type, complexity, patterns),
      confidence_score: calculate_confidence(module_type, patterns),
      has_mount: :mount in patterns.callbacks
    }
  end

  defp analyze_file(file_path) do
    try do
      code = File.read!(file_path)
      analysis = analyze_code(code)
      {:ok, Map.put(analysis, :file_path, file_path)}
    rescue
      error -> {:error, {file_path, error}}
    end
  end

  defp find_elixir_files(project_path) do
    Path.wildcard(Path.join([project_path, "**", "*.ex"]))
    |> Enum.reject(&String.contains?(&1, "/_build/"))
    |> Enum.reject(&String.contains?(&1, "/deps/"))
  end

  defp analyze_project_structure(module_analyses) do
    modules_by_type = Enum.group_by(module_analyses, & &1.module_type)

    %{
      genservers: Map.get(modules_by_type, :genserver, []),
      supervisors: Map.get(modules_by_type, :supervisor, []),
      phoenix_controllers: Map.get(modules_by_type, :phoenix_controller, []),
      phoenix_liveviews: Map.get(modules_by_type, :phoenix_liveview, []),
      regular_modules: Map.get(modules_by_type, :regular, [])
    }
  end

  defp build_supervision_tree(module_analyses) do
    supervisors = Enum.filter(module_analyses, &(&1.module_type == :supervisor))
    workers = Enum.filter(module_analyses, &(&1.module_type == :genserver))

    # Build tree structure based on children specifications
    Enum.map(supervisors, fn supervisor ->
      children = match_supervisor_children(supervisor, workers)
      %{
        supervisor: supervisor,
        children: children,
        strategy: supervisor.strategy
      }
    end)
  end

  defp analyze_inter_module_communication(module_analyses) do
    # Extract GenServer.call/cast patterns
    call_patterns = extract_genserver_calls(module_analyses)

    # Extract PubSub patterns
    pubsub_patterns = extract_pubsub_usage(module_analyses)

    %{
      genserver_calls: call_patterns,
      pubsub_usage: pubsub_patterns,
      process_links: analyze_process_links(module_analyses)
    }
  end

  defp recommend_instrumentation(module_type, complexity, patterns) do
    base_recommendation = case module_type do
      :genserver ->
        if complexity.state_complexity == :high do
          :full_state_tracking
        else
          :state_tracking
        end

      :supervisor ->
        :process_lifecycle

      :phoenix_controller ->
        if patterns.database_interactions do
          :request_lifecycle
        else
          :request_lifecycle
        end

      :phoenix_liveview ->
        :liveview_lifecycle

      _ ->
        if complexity.performance_critical do
          :performance_monitoring
        else
          :minimal
        end
    end

    # Adjust based on complexity
    if complexity.score > 10 do
      enhance_instrumentation(base_recommendation)
    else
      base_recommendation
    end
  end

  defp prioritize_modules(project_analysis) do
    all_modules = extract_all_modules(project_analysis)

    # Score modules based on multiple factors
    scored_modules = Enum.map(all_modules, fn module ->
      score = calculate_priority_score(module, project_analysis)
      priority = determine_priority_level(score)

      %{
        module: module,
        score: score,
        priority: priority,
        instrumentation_type: recommend_detailed_instrumentation(module, priority),
        reason: generate_priority_reason(module, score)
      }
    end)

    # Sort by score descending
    Enum.sort_by(scored_modules, & &1.score, :desc)
  end

  defp calculate_priority_score(module, project_analysis) do
    base_score = case module.module_type do
      :genserver -> 8
      :supervisor -> 6
      :phoenix_controller -> 7
      :phoenix_liveview -> 7
      _ -> 3
    end

    complexity_bonus = min(module.complexity_score, 5)
    critical_path_bonus = if in_critical_path?(module, project_analysis), do: 3, else: 0
    performance_bonus = if module.performance_critical, do: 4, else: 0

    base_score + complexity_bonus + critical_path_bonus + performance_bonus
  end

  defp determine_priority_level(score) do
    cond do
      score >= 15 -> :critical
      score >= 10 -> :high
      score >= 6 -> :medium
      true -> :low
    end
  end

  defp recommend_detailed_instrumentation(module, priority) do
    base_type = module.recommended_instrumentation

    case priority do
      :critical -> enhance_to_full_tracing(base_type)
      :high -> enhance_to_detailed_tracing(base_type)
      :medium -> base_type
      :low -> simplify_instrumentation(base_type)
    end
  end

  defp generate_strategies(priority_modules) do
    Enum.reduce(priority_modules, %{}, fn module_info, acc ->
      strategy = create_instrumentation_strategy(module_info)
      Map.put(acc, module_info.module.file_path, strategy)
    end)
  end

  defp create_instrumentation_strategy(module_info) do
    %{
      module_type: module_info.module.module_type,
      instrumentation_level: module_info.instrumentation_type,
      specific_functions: select_functions_to_instrument(module_info),
      capture_settings: generate_capture_settings(module_info),
      sampling_rate: calculate_sampling_rate(module_info.priority),
      performance_budget: calculate_performance_budget(module_info.priority)
    }
  end

  defp select_functions_to_instrument(module_info) do
    case module_info.module.module_type do
      :genserver ->
        base_callbacks = [:init, :handle_call, :handle_cast, :handle_info]
        if module_info.priority in [:critical, :high] do
          base_callbacks ++ [:terminate, :code_change]
        else
          base_callbacks
        end

      :phoenix_controller ->
        # Instrument all public actions
        module_info.module.actions || []

      :phoenix_liveview ->
        base_callbacks = [:mount, :handle_event]
        if module_info.priority == :critical do
          base_callbacks ++ [:handle_info, :handle_params]
        else
          base_callbacks
        end

      _ ->
        # For regular modules, instrument high-complexity functions
        []  # Would need to extract function list from AST
    end
  end

  defp generate_capture_settings(module_info) do
    %{
      capture_args: module_info.priority in [:critical, :high],
      capture_return: module_info.priority in [:critical, :high],
      capture_state: module_info.module.module_type in [:genserver, :phoenix_liveview],
      capture_exceptions: true,
      capture_performance: module_info.module.performance_critical
    }
  end

  defp extract_call_patterns(code_samples) do
    Enum.flat_map(code_samples, fn code ->
      {:ok, ast} = Code.string_to_quoted(code)

      Macro.prewalk(ast, [], fn
        # GenServer.call patterns
        {{:., _, [{:__aliases__, _, [:GenServer]}, :call]}, _, [target, message]} = node, acc ->
          pattern = %{
            type: :genserver_call,
            target_server: extract_target(target),
            message_type: :call,
            message_pattern: extract_message_pattern(message),
            recommended_correlation: true
          }
          {node, [pattern | acc]}

        # GenServer.cast patterns
        {{:., _, [{:__aliases__, _, [:GenServer]}, :cast]}, _, [target, message]} = node, acc ->
          pattern = %{
            type: :genserver_cast,
            target_server: extract_target(target),
            message_type: :cast,
            message_pattern: extract_message_pattern(message),
            recommended_correlation: true
          }
          {node, [pattern | acc]}

        node, acc -> {node, acc}
      end) |> elem(1)
    end)
  end

  defp extract_pubsub_patterns(code_samples) do
    Enum.flat_map(code_samples, fn code ->
      {:ok, ast} = Code.string_to_quoted(code)

      Macro.prewalk(ast, [], fn
        # Phoenix.PubSub.broadcast patterns
        {{:., _, [{:__aliases__, _, [:Phoenix, :PubSub]}, :broadcast]}, _, [pubsub, topic, message]} = node, acc ->
          pattern = %{
            type: :pubsub_broadcast,
            pubsub_server: extract_pubsub_server(pubsub),
            topic_pattern: extract_topic_pattern(topic),
            message_type: extract_message_type(message),
            recommended_tracing: :broadcast_correlation
          }
          {node, [pattern | acc]}

        node, acc -> {node, acc}
      end) |> elem(1)
    end)
  end

  # Utility functions

  defp count_by_type(analyses, type) do
    Enum.count(analyses, &(&1.module_type == type))
  end

  defp extract_dependencies(module_analyses) do
    Enum.flat_map(module_analyses, fn _analysis ->
      # TODO: Extract actual dependencies from analysis
      []
    end)
    |> Enum.uniq()
  end

  defp calculate_estimated_overhead(module_analyses) do
    total_complexity = Enum.sum(Enum.map(module_analyses, & &1.complexity_score))
    instrumented_modules = Enum.count(module_analyses, &(&1.recommended_instrumentation != :minimal))

    # Estimate based on complexity and number of instrumented modules
    base_overhead = instrumented_modules * 0.001  # 0.1% per module
    complexity_overhead = total_complexity * 0.0001  # Based on complexity

    min(base_overhead + complexity_overhead, 0.05)  # Cap at 5%
  end

  defp match_supervisor_children(supervisor, workers) do
    # Match supervisor children specifications with actual worker modules
    Enum.filter(workers, fn worker ->
      # This would need more sophisticated matching based on actual children specs
      worker.file_path =~ supervisor.file_path
    end)
  end

  defp extract_genserver_calls(_module_analyses) do
    # TODO: Implement GenServer call pattern extraction
    []
  end

  defp extract_pubsub_usage(_module_analyses) do
    # TODO: Implement PubSub usage pattern extraction
    []
  end

  defp analyze_process_links(_module_analyses) do
    # TODO: Implement process link analysis
    []
  end

  defp in_critical_path?(_module, _project_analysis) do
    # TODO: Implement critical path analysis
    false
  end

  defp enhance_to_full_tracing(base_type) do
    case base_type do
      :state_tracking -> :full_state_tracking
      :request_lifecycle -> :request_lifecycle_with_db
      :minimal -> :performance_monitoring
      other -> other
    end
  end

  defp enhance_to_detailed_tracing(base_type) do
    case base_type do
      :minimal -> :state_tracking
      other -> other
    end
  end

  defp simplify_instrumentation(base_type) do
    case base_type do
      :full_state_tracking -> :state_tracking
      :request_lifecycle_with_db -> :request_lifecycle
      :performance_monitoring -> :minimal
      other -> other
    end
  end

  defp calculate_sampling_rate(priority) do
    case priority do
      :critical -> 1.0
      :high -> 0.8
      :medium -> 0.5
      :low -> 0.2
    end
  end

  defp calculate_performance_budget(priority) do
    case priority do
      :critical -> 1000  # 1000 microseconds
      :high -> 500
      :medium -> 200
      :low -> 50
    end
  end

  defp extract_all_modules(project_analysis) do
    project_analysis.project_structure.genservers ++
    project_analysis.project_structure.supervisors ++
    project_analysis.project_structure.phoenix_controllers ++
    project_analysis.project_structure.phoenix_liveviews ++
    project_analysis.project_structure.regular_modules
  end

  defp calculate_confidence(module_type, patterns) do
    base_confidence = case module_type do
      :genserver -> 0.9
      :supervisor -> 0.8
      :phoenix_controller -> 0.85
      :phoenix_liveview -> 0.85
      _ -> 0.6
    end

    # Adjust based on pattern recognition certainty
    pattern_confidence = if length(patterns.callbacks || []) > 0, do: 0.1, else: 0.0

    min(base_confidence + pattern_confidence, 1.0)
  end

  defp analyze_performance_patterns(ast) do
    # Analyze AST for performance-critical patterns
    has_enum_operations = ast_contains_pattern?(ast, {:Enum, :map})
    has_database_operations = ast_contains_pattern?(ast, {:Repo, :all})
    has_expensive_computations = calculate_computational_complexity(ast) > 5

    %{
      is_critical: has_enum_operations or has_database_operations or has_expensive_computations,
      enum_operations: has_enum_operations,
      database_operations: has_database_operations,
      computational_complexity: calculate_computational_complexity(ast)
    }
  end

  defp recommend_function_instrumentation(complexity, performance_indicators) do
    cond do
      complexity.score > 8 -> :detailed_tracing  # Prioritize high complexity
      complexity.nesting_depth > 3 -> :detailed_tracing
      performance_indicators.is_critical -> :performance_monitoring
      true -> :minimal
    end
  end

  defp ast_contains_pattern?(ast, {module, function}) do
    Macro.prewalk(ast, false, fn
      {{:., _, [{:__aliases__, _, [^module]}, ^function]}, _, _}, _acc ->
        {true, true}
      node, acc -> {node, acc}
    end) |> elem(1)
  end

  defp calculate_computational_complexity(ast) do
    # Simple heuristic based on nested operations and function calls
    Macro.prewalk(ast, 0, fn
      {:case, _, _}, acc -> {true, acc + 2}
      {:if, _, _}, acc -> {true, acc + 1}
      {:cond, _, _}, acc -> {true, acc + 2}
      {{:., _, _}, _, _}, acc -> {true, acc + 1}  # Function call
      node, acc -> {node, acc}
    end) |> elem(1)
  end

  defp extract_target({:__aliases__, _, module_parts}) do
    Module.concat(module_parts)
  end
  defp extract_target(atom) when is_atom(atom), do: atom
  defp extract_target(_), do: :unknown

  defp extract_message_pattern({:{}, _, [atom | _]}) when is_atom(atom), do: atom
  defp extract_message_pattern(atom) when is_atom(atom), do: atom
  defp extract_message_pattern(_), do: :unknown

  defp extract_topic_pattern({:<<>>, _, parts}) do
    # Handle string interpolation like "user:#{user_id}"
    case parts do
      [topic] when is_binary(topic) -> 
        topic
      [prefix, {:"::", _, [{{:., _, [Kernel, :to_string]}, _, [_expr]}, {:binary, _, _}]}] when is_binary(prefix) ->
        # Handle interpolation like "user:#{user_id}" -> "user:*"
        prefix <> "*"
      [prefix | _rest] when is_binary(prefix) ->
        # Handle any other interpolation patterns
        prefix <> "*"
      _ -> 
        :unknown
    end
  end
  defp extract_topic_pattern(topic) when is_binary(topic) do
    topic
  end
  defp extract_topic_pattern(_), do: :unknown

  defp extract_message_type({:{}, _, [type | _]}) when is_atom(type), do: type
  defp extract_message_type({type, _}) when is_atom(type), do: type  # Handle 2-element tuples
  defp extract_message_type(atom) when is_atom(atom), do: atom
  defp extract_message_type(_), do: :unknown

  defp extract_pubsub_server({:__aliases__, _, module_parts}) do
    Module.concat(module_parts)
  end
  defp extract_pubsub_server(_), do: :unknown

  # Stub implementations for missing functions
  # TODO: Implement these functions properly in future phases

  defp calculate_impact(_instrumentation_strategies) do
    %{
      performance_overhead: 0.01,
      memory_usage: "minimal",
      coverage: 0.8
    }
  end

  defp generate_configuration(_instrumentation_strategies) do
    %{
      sampling_rate: 1.0,
      buffer_size: 1024,
      async_processing: true
    }
  end

  defp identify_correlation_opportunities(_call_patterns, _pubsub_patterns) do
    []
  end

  defp generate_project_plan(_module_analyses) do
    %{
      phases: [:foundation, :instrumentation, :analysis],
      estimated_duration: "2-3 weeks",
      priority_modules: []
    }
  end

  defp enhance_instrumentation(base_recommendation) do
    case base_recommendation do
      :minimal -> :state_tracking
      :state_tracking -> :full_state_tracking
      other -> other
    end
  end

  defp generate_priority_reason(_module, score) do
    cond do
      score >= 15 -> "Critical path component with high complexity"
      score >= 10 -> "Important component requiring monitoring"
      score >= 6 -> "Moderate priority for instrumentation"
      true -> "Low priority, minimal instrumentation needed"
    end
  end
end
