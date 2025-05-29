defmodule ElixirScope.ASTRepository.PatternMatcher do
  @moduledoc """
  Advanced pattern matcher for the Enhanced AST Repository.

  Provides comprehensive pattern matching capabilities including:
  - AST pattern matching for structural code analysis
  - Behavioral pattern detection (OTP patterns, design patterns)
  - Anti-pattern and code smell detection
  - Configurable pattern library with extensible rules

  ## Pattern Types

  - **AST Patterns**: Structural code patterns in the AST
  - **Behavioral Patterns**: OTP patterns, design patterns, architectural patterns
  - **Anti-Patterns**: Code smells, performance issues, security vulnerabilities
  - **Custom Patterns**: User-defined patterns with custom rules

  ## Performance Targets

  - Pattern matching: <500ms for entire project
  - Individual pattern checks: <10ms per function
  - Memory usage: <100MB for pattern analysis

  # =============================================================================
  # README.md - Documentation

  ## Pattern Matcher System

  The Pattern Matcher is a comprehensive code analysis system for Elixir projects that can detect various patterns, anti-patterns, and code smells.

  ### Features

  - **AST Pattern Matching**: Detect structural code patterns
  - **Behavioral Pattern Detection**: Find OTP patterns, design patterns
  - **Anti-Pattern Detection**: Identify code smells and performance issues
  - **Configurable Rules**: Extensible pattern library
  - **Performance Optimized**: Built for analyzing large codebases

  ### Quick Start

  ```elixir
  # Start the pattern matcher
  {:ok, _pid} = ElixirScope.ASTRepository.PatternMatcher.start_link()

  # Find GenServer implementations
  {:ok, genservers} = PatternMatcher.match_behavioral_pattern(repo, %{
    pattern_type: :genserver,
    confidence_threshold: 0.8
  })

  # Detect anti-patterns
  {:ok, anti_patterns} = PatternMatcher.match_anti_pattern(repo, %{
    pattern_type: :n_plus_one_query,
    confidence_threshold: 0.7
  })
  ```

  ### Configuration

  Configure the pattern matcher in your `config/config.exs`:

  ```elixir
  config :elixir_scope, :pattern_matcher,
    pattern_match_timeout: 500,
    default_confidence_threshold: 0.7,
    enable_pattern_cache: true,
    cache_ttl_minutes: 30
  ```

  ### Architecture

  The system is organized into several modules:

  - `PatternMatcher` - Main GenServer and public API
  - `PatternMatcher.Core` - Core matching logic
  - `PatternMatcher.Types` - Type definitions
  - `PatternMatcher.Validators` - Input validation
  - `PatternMatcher.Analyzers` - Pattern analysis functions
  - `PatternMatcher.PatternLibrary` - Default patterns
  - `PatternMatcher.PatternRules` - Individual rule implementations
  - `PatternMatcher.Stats` - Statistical analysis
  - `PatternMatcher.Config` - Configuration management
  - `PatternMatcher.Cache` - Result caching

  ### Extending the System

  Add custom patterns:

  ```elixir
  PatternMatcher.register_pattern(:my_pattern, %{
    description: "My custom pattern",
    severity: :warning,
    suggestions: ["Consider refactoring"],
    metadata: %{category: :custom},
    rules: [&my_pattern_rule/1]
  })
  ```

  ### Performance

  The system is designed to meet these performance targets:

  - Pattern matching: <500ms for entire project
  - Individual pattern checks: <10ms per function
  - Memory usage: <100MB for pattern analysis

  ### Testing

  Run the test suite:

  ```bash
  mix test
  ```

  For more detailed testing:

  ```bash
  mix test --cover
  mix credo
  mix dialyzer
  ```
  """

  use GenServer
  require Logger

  alias ElixirScope.ASTRepository.PatternMatcher.{
    Core,
    PatternLibrary,
    Validators,
    Types
  }

  @table_name :pattern_cache
  @pattern_library :pattern_library
  @pattern_match_timeout 500

  # GenServer API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    # Create ETS tables for caching and pattern library
    :ets.new(@table_name, [:named_table, :public, :set, {:read_concurrency, true}])
    :ets.new(@pattern_library, [:named_table, :public, :set, {:read_concurrency, true}])

    # Load default pattern library
    PatternLibrary.load_all_patterns(@pattern_library)

    state = %{
      pattern_stats: %{},
      analysis_cache: %{},
      opts: opts
    }

    Logger.info("PatternMatcher started with default pattern library")
    {:ok, state}
  end

  # GenServer callbacks

  def handle_call({:match_ast_pattern, repo, pattern_spec}, _from, state) do
    result = Core.match_ast_pattern_with_timing(repo, pattern_spec)
    {:reply, result, state}
  end

  def handle_call({:match_behavioral_pattern, repo, pattern_spec}, _from, state) do
    result = Core.match_behavioral_pattern_with_timing(repo, pattern_spec, @pattern_library)
    {:reply, result, state}
  end

  def handle_call({:match_anti_pattern, repo, pattern_spec}, _from, state) do
    result = Core.match_anti_pattern_with_timing(repo, pattern_spec, @pattern_library)
    {:reply, result, state}
  end

  def handle_call({:register_pattern, pattern_name, pattern_def}, _from, state) do
    :ets.insert(@pattern_library, {pattern_name, pattern_def})
    {:reply, :ok, state}
  end

  def handle_call(:get_pattern_stats, _from, state) do
    {:reply, {:ok, state.pattern_stats}, state}
  end

  def handle_call(:clear_cache, _from, state) do
    :ets.delete_all_objects(@table_name)
    {:reply, :ok, %{state | analysis_cache: %{}}}
  end

  # Public API

  @doc """
  Matches AST patterns in the repository.
  """
  @spec match_ast_pattern(pid() | atom(), map()) :: {:ok, Types.pattern_result()} | {:error, term()}
  def match_ast_pattern(repo, pattern_spec) do
    GenServer.call(__MODULE__, {:match_ast_pattern, repo, pattern_spec}, @pattern_match_timeout)
  end

  @doc """
  Matches behavioral patterns (OTP, design patterns).
  """
  @spec match_behavioral_pattern(pid() | atom(), map()) :: {:ok, Types.pattern_result()} | {:error, term()}
  def match_behavioral_pattern(repo, pattern_spec) do
    GenServer.call(__MODULE__, {:match_behavioral_pattern, repo, pattern_spec}, @pattern_match_timeout)
  end

  @doc """
  Matches anti-patterns and code smells.
  """
  @spec match_anti_pattern(pid() | atom(), map()) :: {:ok, Types.pattern_result()} | {:error, term()}
  def match_anti_pattern(repo, pattern_spec) do
    GenServer.call(__MODULE__, {:match_anti_pattern, repo, pattern_spec}, @pattern_match_timeout)
  end

  @doc """
  Registers a custom pattern in the pattern library.
  """
  @spec register_pattern(atom(), map()) :: :ok
  def register_pattern(pattern_name, pattern_def) do
    GenServer.call(__MODULE__, {:register_pattern, pattern_name, pattern_def})
  end

  @doc """
  Gets pattern matching statistics.
  """
  @spec get_pattern_stats() :: {:ok, map()}
  def get_pattern_stats() do
    GenServer.call(__MODULE__, :get_pattern_stats)
  end

  @doc """
  Clears the pattern analysis cache.
  """
  @spec clear_cache() :: :ok
  def clear_cache() do
    GenServer.call(__MODULE__, :clear_cache)
  end
end
