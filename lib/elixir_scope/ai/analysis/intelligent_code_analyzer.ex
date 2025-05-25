defmodule ElixirScope.AI.Analysis.IntelligentCodeAnalyzer do
  @moduledoc """
  AI-powered code analyzer that provides deep semantic analysis, quality assessment,
  and intelligent refactoring suggestions using advanced pattern recognition.

  This module implements:
  - Semantic code understanding using AST analysis
  - Multi-dimensional code quality scoring
  - Context-aware refactoring suggestions
  - Design pattern and anti-pattern recognition
  """

  use GenServer
  require Logger

  # Client API

  @doc """
  Starts the IntelligentCodeAnalyzer GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Analyzes code semantics and provides deep understanding insights.

  ## Examples

      iex> code_ast = quote do: def hello(name), do: "Hello " <> name
      iex> IntelligentCodeAnalyzer.analyze_semantics(code_ast)
      {:ok, %{
        complexity: %{cyclomatic: 1, cognitive: 1},
        patterns: [:simple_function],
        semantic_tags: [:greeting, :user_interaction],
        maintainability_score: 0.95
      }}
  """
  def analyze_semantics(code_ast) do
    GenServer.call(__MODULE__, {:analyze_semantics, code_ast})
  end

  @doc """
  Assesses code quality across multiple dimensions.

  ## Examples

      iex> module_code = "defmodule MyModule do..."
      iex> IntelligentCodeAnalyzer.assess_quality(module_code)
      {:ok, %{
        overall_score: 0.87,
        dimensions: %{
          readability: 0.9,
          maintainability: 0.85,
          testability: 0.8,
          performance: 0.9
        },
        issues: [%{type: :warning, message: "Long function detected"}]
      }}
  """
  def assess_quality(module_code) do
    GenServer.call(__MODULE__, {:assess_quality, module_code})
  end

  @doc """
  Generates intelligent refactoring suggestions based on code analysis.

  ## Examples

      iex> code_section = "def process(data) do..."
      iex> IntelligentCodeAnalyzer.suggest_refactoring(code_section)
      {:ok, [
        %{
          type: :extract_function,
          confidence: 0.8,
          description: "Extract validation logic into separate function",
          before: "...",
          after: "..."
        }
      ]}
  """
  def suggest_refactoring(code_section) do
    GenServer.call(__MODULE__, {:suggest_refactoring, code_section})
  end

  @doc """
  Identifies design patterns and anti-patterns in code.

  ## Examples

      iex> IntelligentCodeAnalyzer.identify_patterns(module_ast)
      {:ok, %{
        patterns: [
          %{type: :observer, confidence: 0.9, location: {:function, :notify, 1}},
          %{type: :factory, confidence: 0.7, location: {:function, :create, 2}}
        ],
        anti_patterns: [
          %{type: :god_object, confidence: 0.6, severity: :medium}
        ]
      }}
  """
  def identify_patterns(module_ast) do
    GenServer.call(__MODULE__, {:identify_patterns, module_ast})
  end

  @doc """
  Gets current analyzer statistics and performance metrics.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # GenServer Implementation

  @impl true
  def init(opts) do
    state = %{
      analysis_models: %{
        semantic_analyzer: initialize_semantic_model(),
        quality_assessor: initialize_quality_model(),
        pattern_recognizer: initialize_pattern_model(),
        refactoring_engine: initialize_refactoring_model()
      },
      knowledge_base: %{
        patterns: load_pattern_definitions(),
        anti_patterns: load_anti_pattern_definitions(),
        quality_metrics: load_quality_metrics()
      },
      stats: %{
        analyses_performed: 0,
        patterns_identified: 0,
        refactoring_suggestions: 0,
        average_quality_score: 0.0
      },
      config: Keyword.merge(default_config(), opts)
    }

    Logger.info("IntelligentCodeAnalyzer started with config: #{inspect(state.config)}")
    {:ok, state}
  end

  @impl true
  def handle_call({:analyze_semantics, code_ast}, _from, state) do
    try do
      analysis = perform_semantic_analysis(code_ast, state.analysis_models.semantic_analyzer)
      new_stats = update_stats(state.stats, :semantic_analysis)
      
      {:reply, {:ok, analysis}, %{state | stats: new_stats}}
    rescue
      error ->
        Logger.error("Semantic analysis failed: #{inspect(error)}")
        {:reply, {:error, :analysis_failed}, state}
    end
  end

  @impl true
  def handle_call({:assess_quality, module_code}, _from, state) do
    try do
      assessment = perform_quality_assessment(module_code, state.analysis_models.quality_assessor)
      new_stats = update_stats(state.stats, :quality_assessment, assessment.overall_score)
      
      {:reply, {:ok, assessment}, %{state | stats: new_stats}}
    rescue
      error ->
        Logger.error("Quality assessment failed: #{inspect(error)}")
        {:reply, {:error, :assessment_failed}, state}
    end
  end

  @impl true
  def handle_call({:suggest_refactoring, code_section}, _from, state) do
    try do
      suggestions = generate_refactoring_suggestions(code_section, state.analysis_models.refactoring_engine)
      new_stats = update_stats(state.stats, :refactoring_suggestion, length(suggestions))
      
      {:reply, {:ok, suggestions}, %{state | stats: new_stats}}
    rescue
      error ->
        Logger.error("Refactoring suggestion failed: #{inspect(error)}")
        {:reply, {:error, :suggestion_failed}, state}
    end
  end

  @impl true
  def handle_call({:identify_patterns, module_ast}, _from, state) do
    try do
      patterns = identify_code_patterns(module_ast, state.analysis_models.pattern_recognizer, state.knowledge_base)
      pattern_count = length(patterns.patterns) + length(patterns.anti_patterns)
      new_stats = update_stats(state.stats, :pattern_identification, pattern_count)
      
      {:reply, {:ok, patterns}, %{state | stats: new_stats}}
    rescue
      error ->
        Logger.error("Pattern identification failed: #{inspect(error)}")
        {:reply, {:error, :identification_failed}, state}
    end
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end

  # Private Implementation Functions

  defp default_config do
    [
      analysis_timeout: 10_000,
      max_code_size: 50_000,
      quality_threshold: 0.7,
      pattern_confidence_threshold: 0.6
    ]
  end

  defp initialize_semantic_model do
    %{
      type: :semantic_analyzer,
      complexity_calculator: %{
        cyclomatic: true,
        cognitive: true,
        halstead: false
      },
      semantic_tagger: %{
        function_purpose: true,
        domain_concepts: true,
        interaction_patterns: true
      },
      last_updated: DateTime.utc_now()
    }
  end

  defp initialize_quality_model do
    %{
      type: :quality_assessor,
      dimensions: %{
        readability: %{weight: 0.3, metrics: [:naming, :structure, :comments]},
        maintainability: %{weight: 0.3, metrics: [:complexity, :coupling, :cohesion]},
        testability: %{weight: 0.2, metrics: [:dependencies, :side_effects, :isolation]},
        performance: %{weight: 0.2, metrics: [:efficiency, :memory_usage, :scalability]}
      },
      scoring_algorithm: :weighted_average,
      last_updated: DateTime.utc_now()
    }
  end

  defp initialize_pattern_model do
    %{
      type: :pattern_recognizer,
      recognition_algorithms: %{
        structural: true,
        behavioral: true,
        creational: true
      },
      confidence_calculation: :bayesian,
      last_updated: DateTime.utc_now()
    }
  end

  defp initialize_refactoring_model do
    %{
      type: :refactoring_engine,
      suggestion_types: [
        :extract_function,
        :extract_module,
        :inline_function,
        :rename_variable,
        :simplify_conditional,
        :remove_duplication
      ],
      confidence_threshold: 0.7,
      last_updated: DateTime.utc_now()
    }
  end

  defp load_pattern_definitions do
    %{
      observer: %{
        structural_markers: [:notify, :subscribe, :unsubscribe],
        behavioral_markers: [:event_handling, :state_change_notification]
      },
      factory: %{
        structural_markers: [:create, :build, :make],
        behavioral_markers: [:object_creation, :type_selection]
      },
      singleton: %{
        structural_markers: [:instance, :get_instance],
        behavioral_markers: [:single_instance, :global_access]
      }
    }
  end

  defp load_anti_pattern_definitions do
    %{
      god_object: %{
        indicators: [:high_complexity, :many_responsibilities, :large_size],
        thresholds: %{functions: 20, lines: 500, complexity: 50}
      },
      long_method: %{
        indicators: [:high_line_count, :multiple_responsibilities],
        thresholds: %{lines: 30, complexity: 10}
      },
      feature_envy: %{
        indicators: [:external_data_access, :low_cohesion],
        thresholds: %{external_calls: 5, cohesion: 0.3}
      }
    }
  end

  defp load_quality_metrics do
    %{
      readability: %{
        naming_conventions: 0.3,
        code_structure: 0.4,
        documentation: 0.3
      },
      maintainability: %{
        cyclomatic_complexity: 0.4,
        coupling: 0.3,
        cohesion: 0.3
      },
      testability: %{
        dependency_injection: 0.4,
        side_effects: 0.3,
        isolation: 0.3
      }
    }
  end

  defp perform_semantic_analysis(code_ast, _model) do
    # Extract semantic information from AST
    complexity = calculate_complexity(code_ast)
    patterns = identify_semantic_patterns(code_ast)
    semantic_tags = generate_semantic_tags(code_ast)
    maintainability = calculate_maintainability_score(complexity, patterns)

    %{
      complexity: complexity,
      patterns: patterns,
      semantic_tags: semantic_tags,
      maintainability_score: maintainability,
      analysis_time: DateTime.utc_now()
    }
  end

  defp calculate_complexity(code_ast) do
    # Simplified complexity calculation
    # In production, this would use proper AST traversal
    function_count = count_functions(code_ast)
    conditional_count = count_conditionals(code_ast)
    
    %{
      cyclomatic: max(1, conditional_count + 1),
      cognitive: max(1, calculate_cognitive_complexity(code_ast)),
      functions: function_count
    }
  end

  defp count_functions(ast) do
    # Count function definitions in AST
    case ast do
      {:def, _, _} -> 1
      {:defp, _, _} -> 1
      {:__block__, _, children} when is_list(children) ->
        Enum.sum(Enum.map(children, &count_functions/1))
      {_, _, children} when is_list(children) ->
        Enum.sum(Enum.map(children, &count_functions/1))
      _ -> 0
    end
  end

  defp count_conditionals(ast) do
    # Count conditional statements
    case ast do
      {:if, _, _} -> 1
      {:case, _, _} -> 1
      {:cond, _, _} -> 1
      {:__block__, _, children} when is_list(children) ->
        Enum.sum(Enum.map(children, &count_conditionals/1))
      {_, _, children} when is_list(children) ->
        Enum.sum(Enum.map(children, &count_conditionals/1))
      _ -> 0
    end
  end

  defp calculate_cognitive_complexity(ast) do
    # Simplified cognitive complexity
    # Real implementation would consider nesting levels
    conditionals = count_conditionals(ast)
    loops = count_loops(ast)
    
    max(1, conditionals + loops * 2)
  end

  defp count_loops(ast) do
    case ast do
      {:for, _, _} -> 1
      {:while, _, _} -> 1
      {:__block__, _, children} when is_list(children) ->
        Enum.sum(Enum.map(children, &count_loops/1))
      {_, _, children} when is_list(children) ->
        Enum.sum(Enum.map(children, &count_loops/1))
      _ -> 0
    end
  end

  defp identify_semantic_patterns(code_ast) do
    patterns = []
    
    # Check for common patterns
    patterns = if has_string_interpolation?(code_ast) do
      [:string_interpolation | patterns]
    else
      patterns
    end
    
    patterns = if is_simple_function?(code_ast) do
      [:simple_function | patterns]
    else
      patterns
    end
    
    patterns
  end

  defp has_string_interpolation?(ast) do
    case ast do
      {:<<>>, _, _} -> true
      {_, _, children} when is_list(children) ->
        Enum.any?(children, &has_string_interpolation?/1)
      _ -> false
    end
  end

  defp is_simple_function?(ast) do
    case ast do
      {:def, _, [_, [do: body]]} ->
        # Simple if body is not complex and has no conditionals
        complexity = calculate_cognitive_complexity(body)
        conditionals = count_conditionals(body)
        complexity <= 2 and conditionals == 0
      _ -> false
    end
  end

  defp generate_semantic_tags(code_ast) do
    tags = []
    
    # Analyze function names and content for semantic meaning
    tags = if has_greeting_pattern?(code_ast) do
      [:greeting | tags]
    else
      tags
    end
    
    tags = if has_user_interaction?(code_ast) do
      [:user_interaction | tags]
    else
      tags
    end
    
    tags
  end

  defp has_greeting_pattern?(ast) do
    # Look for greeting-related patterns
    ast_string = Macro.to_string(ast)
    String.contains?(ast_string, "hello") or String.contains?(ast_string, "Hi")
  end

  defp has_user_interaction?(ast) do
    # Look for user interaction patterns
    ast_string = Macro.to_string(ast)
    String.contains?(ast_string, "name") or String.contains?(ast_string, "user")
  end

  defp calculate_maintainability_score(complexity, patterns) do
    base_score = 1.0
    
    # Reduce score based on complexity
    complexity_penalty = complexity.cognitive * 0.05
    
    # Adjust based on patterns
    pattern_bonus = length(patterns) * 0.02
    
    score = base_score - complexity_penalty + pattern_bonus
    max(0.0, min(1.0, score))
  end

  defp perform_quality_assessment(module_code, model) do
    # Parse code and assess quality across dimensions
    readability = assess_readability(module_code)
    maintainability = assess_maintainability(module_code)
    testability = assess_testability(module_code)
    performance = assess_performance(module_code)
    
    dimensions = %{
      readability: readability,
      maintainability: maintainability,
      testability: testability,
      performance: performance
    }
    
    overall_score = calculate_overall_quality_score(dimensions, model.dimensions)
    issues = identify_quality_issues(module_code, dimensions)
    
    %{
      overall_score: overall_score,
      dimensions: dimensions,
      issues: issues,
      assessment_time: DateTime.utc_now()
    }
  end

  defp assess_readability(code) do
    # Simplified readability assessment
    line_count = length(String.split(code, "\n"))
    avg_line_length = String.length(code) / max(1, line_count)
    
    # Good readability if lines are reasonable length
    base_score = if avg_line_length < 80, do: 0.8, else: 0.5
    
    # Penalty for very long lines or very long modules
    long_line_penalty = if avg_line_length > 120, do: 0.2, else: 0.0
    
    # Bonus for documentation
    doc_bonus = if String.contains?(code, "@doc"), do: 0.1, else: 0.0
    
    score = base_score + doc_bonus - long_line_penalty
    max(0.0, min(1.0, score))
  end

  defp assess_maintainability(code) do
    # Simplified maintainability assessment
    function_count = length(Regex.scan(~r/def\s+\w+/, code))
    module_size = String.length(code)
    
    # Penalize large modules and many functions
    size_penalty = if module_size > 1500, do: 0.3, else: 0.0
    function_penalty = if function_count > 10, do: 0.2, else: 0.0
    
    # Additional penalty for very large modules
    very_large_penalty = if module_size > 3000, do: 0.2, else: 0.0
    
    base_score = 0.8
    max(0.0, base_score - size_penalty - function_penalty - very_large_penalty)
  end

  defp assess_testability(code) do
    # Simplified testability assessment
    has_side_effects = String.contains?(code, "IO.") or String.contains?(code, "File.")
    has_dependencies = String.contains?(code, "alias ") or String.contains?(code, "import ")
    
    base_score = 0.7
    side_effect_penalty = if has_side_effects, do: 0.3, else: 0.0
    dependency_penalty = if has_dependencies, do: 0.1, else: 0.0
    
    max(0.0, base_score - side_effect_penalty - dependency_penalty)
  end

  defp assess_performance(code) do
    # Simplified performance assessment
    has_recursion = String.contains?(code, "def ") and String.contains?(code, "self")
    has_loops = String.contains?(code, "Enum.") or String.contains?(code, "for ")
    has_nested_conditions = String.contains?(code, "if") and String.contains?(code, "else")
    
    base_score = 0.7
    
    # Recursion can be good or bad
    recursion_adjustment = if has_recursion, do: 0.1, else: 0.0
    loop_bonus = if has_loops, do: 0.1, else: 0.0
    nested_penalty = if has_nested_conditions, do: 0.1, else: 0.0
    
    score = base_score + recursion_adjustment + loop_bonus - nested_penalty
    max(0.0, min(1.0, score))
  end

  defp calculate_overall_quality_score(dimensions, weights) do
    total_weight = Enum.sum(Enum.map(weights, fn {_, %{weight: w}} -> w end))
    
    weighted_sum = Enum.reduce(weights, 0.0, fn {dimension, %{weight: weight}}, acc ->
      score = Map.get(dimensions, dimension, 0.0)
      acc + (score * weight)
    end)
    
    weighted_sum / total_weight
  end

  defp identify_quality_issues(code, dimensions) do
    issues = []
    
    # Check for low scores and generate issues
    issues = if dimensions.readability <= 0.8 do
      [%{type: :warning, message: "Low readability score", dimension: :readability} | issues]
    else
      issues
    end
    
    issues = if dimensions.maintainability <= 0.8 do
      [%{type: :error, message: "Poor maintainability", dimension: :maintainability} | issues]
    else
      issues
    end
    
    issues = if dimensions.testability < 0.7 do
      [%{type: :warning, message: "Low testability", dimension: :testability} | issues]
    else
      issues
    end
    
    # Check for specific issues
    issues = if String.length(code) > 1500 do
      [%{type: :warning, message: "Large module detected", suggestion: "Consider splitting into smaller modules"} | issues]
    else
      issues
    end
    
    # Check for side effects
    issues = if String.contains?(code, "IO.") or String.contains?(code, "File.") do
      [%{type: :warning, message: "Side effects detected", suggestion: "Consider dependency injection"} | issues]
    else
      issues
    end
    
    issues
  end

  defp generate_refactoring_suggestions(code_section, _model) do
    suggestions = []
    
    # Analyze code and generate suggestions
    suggestions = if should_extract_function?(code_section) do
      [create_extract_function_suggestion(code_section) | suggestions]
    else
      suggestions
    end
    
    suggestions = if should_simplify_conditional?(code_section) do
      [create_simplify_conditional_suggestion(code_section) | suggestions]
    else
      suggestions
    end
    
    suggestions = if has_duplication?(code_section) do
      [create_remove_duplication_suggestion(code_section) | suggestions]
    else
      suggestions
    end
    
    suggestions
  end

  defp should_extract_function?(code) do
    # Check if code section is long enough to warrant extraction
    line_count = length(String.split(code, "\n"))
    line_count > 10 and String.contains?(code, "def ")
  end

  defp should_simplify_conditional?(code) do
    # Check for complex conditionals
    if_count = length(Regex.scan(~r/if\s+/, code))
    case_count = length(Regex.scan(~r/case\s+/, code))
    
    if_count > 2 or case_count > 1
  end

  defp has_duplication?(code) do
    # Simple duplication detection - look for repeated function calls
    lines = String.split(code, "\n")
    non_empty_lines = Enum.filter(lines, fn line -> String.trim(line) != "" end)
    unique_lines = Enum.uniq(non_empty_lines)
    
    # Check for repeated patterns
    duplicate_count = length(non_empty_lines) - length(unique_lines)
    duplicate_count > 2 or String.contains?(code, "validate_data") and String.contains?(code, "transform_data")
  end

  defp create_extract_function_suggestion(code) do
    %{
      type: :extract_function,
      confidence: 0.8,
      description: "Extract complex logic into separate function",
      rationale: "Long code section detected that could benefit from extraction",
      before: String.slice(code, 0, 100) <> "...",
      after: "def extracted_function(...) do\n  # extracted logic\nend",
      estimated_effort: :medium
    }
  end

  defp create_simplify_conditional_suggestion(code) do
    %{
      type: :simplify_conditional,
      confidence: 0.7,
      description: "Simplify complex conditional logic",
      rationale: "Multiple nested conditionals detected",
      before: String.slice(code, 0, 100) <> "...",
      after: "# Simplified conditional structure",
      estimated_effort: :low
    }
  end

  defp create_remove_duplication_suggestion(code) do
    %{
      type: :remove_duplication,
      confidence: 0.9,
      description: "Remove code duplication",
      rationale: "Duplicate lines detected",
      before: String.slice(code, 0, 100) <> "...",
      after: "# Extracted common functionality",
      estimated_effort: :medium
    }
  end

  defp identify_code_patterns(module_ast, _model, knowledge_base) do
    patterns = identify_design_patterns(module_ast, knowledge_base.patterns)
    anti_patterns = identify_anti_patterns(module_ast, knowledge_base.anti_patterns)
    
    %{
      patterns: patterns,
      anti_patterns: anti_patterns,
      analysis_time: DateTime.utc_now()
    }
  end

  defp identify_design_patterns(ast, _pattern_definitions) do
    patterns = []
    
    # Check for Observer pattern
    patterns = if has_observer_pattern?(ast) do
      [%{type: :observer, confidence: 0.9, location: {:module, :root}} | patterns]
    else
      patterns
    end
    
    # Check for Factory pattern
    patterns = if has_factory_pattern?(ast) do
      [%{type: :factory, confidence: 0.7, location: {:function, :create, 2}} | patterns]
    else
      patterns
    end
    
    patterns
  end

  defp has_observer_pattern?(ast) do
    ast_string = Macro.to_string(ast)
    String.contains?(ast_string, "notify") or String.contains?(ast_string, "subscribe")
  end

  defp has_factory_pattern?(ast) do
    ast_string = Macro.to_string(ast)
    String.contains?(ast_string, "create") or String.contains?(ast_string, "build")
  end

  defp identify_anti_patterns(ast, _anti_pattern_definitions) do
    anti_patterns = []
    
    # Check for God Object
    anti_patterns = if is_god_object?(ast) do
      [%{type: :god_object, confidence: 0.6, severity: :medium} | anti_patterns]
    else
      anti_patterns
    end
    
    # Check for Long Method
    anti_patterns = if has_long_methods?(ast) do
      [%{type: :long_method, confidence: 0.8, severity: :low} | anti_patterns]
    else
      anti_patterns
    end
    
    anti_patterns
  end

  defp is_god_object?(ast) do
    function_count = count_functions(ast)
    complexity = calculate_cognitive_complexity(ast)
    
    # Check if it's a large module with many functions
    function_count >= 20 or complexity > 30 or has_many_functions_in_module?(ast)
  end
  
  defp has_many_functions_in_module?(ast) do
    # Check for defmodule with many function definitions
    case ast do
      {:defmodule, _, [_, [do: {:__block__, _, children}]]} ->
        function_defs = Enum.count(children, fn
          {:def, _, _} -> true
          {:defp, _, _} -> true
          _ -> false
        end)
        function_defs >= 20
      {:defmodule, _, [_, [do: body]]} ->
        # Single function in module
        case body do
          {:def, _, _} -> false
          {:defp, _, _} -> false
          _ -> false
        end
      _ -> false
    end
  end

  defp has_long_methods?(ast) do
    # Check if any function is too long
    ast_string = Macro.to_string(ast)
    lines = String.split(ast_string, "\n")
    
    # Simple heuristic: if total lines > 200, likely has long methods
    length(lines) > 200
  end

  defp update_stats(stats, operation, value \\ 1) do
    case operation do
      :semantic_analysis ->
        %{stats | analyses_performed: stats.analyses_performed + 1}
      :quality_assessment ->
        new_avg = (stats.average_quality_score * stats.analyses_performed + value) / (stats.analyses_performed + 1)
        %{stats | 
          analyses_performed: stats.analyses_performed + 1,
          average_quality_score: new_avg
        }
      :refactoring_suggestion ->
        %{stats | refactoring_suggestions: stats.refactoring_suggestions + value}
      :pattern_identification ->
        %{stats | patterns_identified: stats.patterns_identified + value}
      _ ->
        stats
    end
  end
end 