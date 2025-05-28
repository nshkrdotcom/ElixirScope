# Enhanced AST Repository - Integration Guide

## Table of Contents

1. [Overview](#overview)
2. [ElixirScope Component Integration](#elixirscope-component-integration)
3. [Runtime Correlation Setup](#runtime-correlation-setup)
4. [Advanced Debugging Features](#advanced-debugging-features)
5. [Performance Monitoring Integration](#performance-monitoring-integration)
6. [Testing Integration](#testing-integration)
7. [Troubleshooting Common Issues](#troubleshooting-common-issues)
8. [Configuration Examples](#configuration-examples)

## Overview

This guide covers how to integrate the Enhanced AST Repository with existing ElixirScope components, set up runtime correlation for dynamic analysis, and leverage advanced debugging features for comprehensive code analysis.

### Integration Architecture

```
ElixirScope Ecosystem
├── Enhanced AST Repository (Core)
├── Runtime Correlation Engine
├── Analysis Pipeline
├── Debugging Interface
└── Monitoring Dashboard
```

## ElixirScope Component Integration

### Core Repository Integration

#### Basic Setup

```elixir
# In your application.ex
defmodule MyApp.Application do
  use Application
  
  def start(_type, _args) do
    children = [
      # Core Enhanced Repository
      {ElixirScope.ASTRepository.EnhancedRepository, [
        memory_limit: 1024 * 1024 * 1024,  # 1GB
        cache_enabled: true,
        monitoring_enabled: true
      ]},
      
      # Memory Manager with production settings
      {ElixirScope.ASTRepository.MemoryManager, [
        monitoring_enabled: true,
        cleanup_interval: 300_000,      # 5 minutes
        compression_interval: 600_000,  # 10 minutes
        memory_check_interval: 30_000   # 30 seconds
      ]},
      
      # Performance Optimizer
      {ElixirScope.ASTRepository.PerformanceOptimizer, [
        lazy_loading_enabled: true,
        cache_warming_enabled: true
      ]},
      
      # Your existing ElixirScope components
      MyApp.AnalysisEngine,
      MyApp.CodeInspector
    ]
    
    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

#### Analysis Pipeline Integration

```elixir
defmodule MyApp.AnalysisEngine do
  use GenServer
  
  alias ElixirScope.ASTRepository.{EnhancedRepository, MemoryManager}
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def analyze_project(project_path) do
    GenServer.call(__MODULE__, {:analyze_project, project_path})
  end
  
  def init(_opts) do
    {:ok, %{analysis_queue: :queue.new()}}
  end
  
  def handle_call({:analyze_project, project_path}, _from, state) do
    # 1. Discover modules in project
    modules = discover_modules(project_path)
    
    # 2. Store modules in enhanced repository
    store_results = store_modules_batch(modules)
    
    # 3. Perform comprehensive analysis
    analysis_results = perform_analysis(modules)
    
    # 4. Update repository with analysis results
    update_analysis_results(analysis_results)
    
    {:reply, {:ok, analysis_results}, state}
  end
  
  defp discover_modules(project_path) do
    # Implementation for discovering Elixir modules
    project_path
    |> Path.join("**/*.ex")
    |> Path.wildcard()
    |> Enum.map(&parse_module_file/1)
    |> Enum.filter(& &1)
  end
  
  defp parse_module_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        case Code.string_to_quoted(content) do
          {:ok, ast} ->
            module_name = extract_module_name(ast)
            {module_name, ast, file_path}
          {:error, _} -> nil
        end
      {:error, _} -> nil
    end
  end
  
  defp store_modules_batch(modules) do
    module_data = Enum.map(modules, fn {module_name, ast, file_path} ->
      {module_name, ast}
    end)
    
    EnhancedRepository.store_modules_batch(module_data)
  end
  
  defp perform_analysis(modules) do
    Enum.map(modules, fn {module_name, _ast, file_path} ->
      case EnhancedRepository.get_enhanced_module(module_name) do
        {:ok, module_data} ->
          # Perform various analyses
          complexity_analysis = analyze_complexity(module_data)
          dependency_analysis = analyze_dependencies(module_data)
          security_analysis = analyze_security(module_data)
          
          %{
            module: module_name,
            file_path: file_path,
            complexity: complexity_analysis,
            dependencies: dependency_analysis,
            security: security_analysis
          }
        {:error, _} -> nil
      end
    end)
    |> Enum.filter(& &1)
  end
  
  defp update_analysis_results(results) do
    Enum.each(results, fn result ->
      EnhancedRepository.update_enhanced_module(result.module, [
        metadata: %{
          complexity_score: result.complexity.score,
          dependency_count: length(result.dependencies),
          security_issues: result.security.issues,
          last_analyzed: DateTime.utc_now()
        }
      ])
    end)
  end
end
```

### Code Inspector Integration

```elixir
defmodule MyApp.CodeInspector do
  alias ElixirScope.ASTRepository.EnhancedRepository
  
  def inspect_module(module_name) do
    case EnhancedRepository.get_enhanced_module(module_name) do
      {:ok, module_data} ->
        %{
          basic_info: extract_basic_info(module_data),
          functions: inspect_functions(module_data.functions),
          complexity: module_data.complexity_score,
          dependencies: extract_dependencies(module_data),
          issues: detect_issues(module_data)
        }
      {:error, :not_found} ->
        {:error, "Module not found in repository"}
    end
  end
  
  def inspect_function(module_name, function_name, arity) do
    case EnhancedRepository.get_enhanced_function(module_name, function_name, arity) do
      {:ok, function_data} ->
        %{
          signature: "#{function_name}/#{arity}",
          complexity: function_data.complexity_score,
          control_flow: function_data.control_flow_graph,
          data_flow: function_data.data_flow_graph,
          issues: detect_function_issues(function_data)
        }
      {:error, :not_found} ->
        {:error, "Function not found"}
    end
  end
  
  defp extract_basic_info(module_data) do
    %{
      name: module_data.module_name,
      file_path: module_data.file_path,
      function_count: length(module_data.functions),
      line_count: calculate_line_count(module_data.ast),
      created_at: module_data.metadata[:created_at]
    }
  end
  
  defp inspect_functions(functions) do
    Enum.map(functions, fn func ->
      %{
        name: func.function_name,
        arity: func.arity,
        visibility: func.visibility,
        complexity: func.complexity_score,
        line_range: "#{func.line_start}-#{func.line_end}"
      }
    end)
  end
end
```

## Runtime Correlation Setup

### Dynamic Analysis Integration

```elixir
defmodule MyApp.RuntimeCorrelation do
  use GenServer
  
  alias ElixirScope.ASTRepository.{EnhancedRepository, MemoryManager}
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def enable_tracing(modules) when is_list(modules) do
    GenServer.call(__MODULE__, {:enable_tracing, modules})
  end
  
  def disable_tracing() do
    GenServer.call(__MODULE__, :disable_tracing)
  end
  
  def get_runtime_stats(module_name) do
    GenServer.call(__MODULE__, {:get_runtime_stats, module_name})
  end
  
  def init(_opts) do
    # Initialize ETS table for runtime data
    :ets.new(:runtime_correlation, [:named_table, :public, :set])
    
    {:ok, %{
      traced_modules: MapSet.new(),
      trace_enabled: false
    }}
  end
  
  def handle_call({:enable_tracing, modules}, _from, state) do
    # Enable tracing for specified modules
    Enum.each(modules, &enable_module_tracing/1)
    
    new_state = %{state | 
      traced_modules: MapSet.union(state.traced_modules, MapSet.new(modules)),
      trace_enabled: true
    }
    
    {:reply, :ok, new_state}
  end
  
  def handle_call(:disable_tracing, _from, state) do
    # Disable all tracing
    Enum.each(state.traced_modules, &disable_module_tracing/1)
    
    new_state = %{state | 
      traced_modules: MapSet.new(),
      trace_enabled: false
    }
    
    {:reply, :ok, new_state}
  end
  
  def handle_call({:get_runtime_stats, module_name}, _from, state) do
    stats = case :ets.lookup(:runtime_correlation, module_name) do
      [{^module_name, runtime_data}] -> 
        correlate_with_static_analysis(module_name, runtime_data)
      [] -> 
        {:error, :no_runtime_data}
    end
    
    {:reply, stats, state}
  end
  
  defp enable_module_tracing(module_name) do
    # Enable function call tracing
    :erlang.trace_pattern({module_name, :_, :_}, [
      {:call_count, true},
      {:call_time, true}
    ])
    
    # Set up trace handler
    :erlang.trace(:all, true, [:call, {:tracer, self()}])
  end
  
  defp disable_module_tracing(module_name) do
    :erlang.trace_pattern({module_name, :_, :_}, false)
  end
  
  defp correlate_with_static_analysis(module_name, runtime_data) do
    case EnhancedRepository.get_enhanced_module(module_name) do
      {:ok, module_data} ->
        %{
          static_analysis: %{
            complexity: module_data.complexity_score,
            function_count: length(module_data.functions),
            estimated_performance: estimate_performance(module_data)
          },
          runtime_data: runtime_data,
          correlation: %{
            performance_match: compare_performance(module_data, runtime_data),
            hotspots: identify_hotspots(module_data, runtime_data),
            optimization_suggestions: suggest_optimizations(module_data, runtime_data)
          }
        }
      {:error, :not_found} ->
        {:error, :module_not_in_repository}
    end
  end
  
  # Handle trace messages
  def handle_info({:trace, pid, :call, {module, function, args}}, state) do
    # Record function call
    call_data = %{
      timestamp: System.monotonic_time(:nanosecond),
      pid: pid,
      function: function,
      arity: length(args)
    }
    
    update_runtime_data(module, call_data)
    {:noreply, state}
  end
  
  def handle_info(_msg, state) do
    {:noreply, state}
  end
  
  defp update_runtime_data(module, call_data) do
    case :ets.lookup(:runtime_correlation, module) do
      [{^module, existing_data}] ->
        updated_data = update_call_stats(existing_data, call_data)
        :ets.insert(:runtime_correlation, {module, updated_data})
      [] ->
        initial_data = initialize_runtime_data(call_data)
        :ets.insert(:runtime_correlation, {module, initial_data})
    end
  end
end
```

### Performance Correlation

```elixir
defmodule MyApp.PerformanceCorrelation do
  alias MyApp.RuntimeCorrelation
  alias ElixirScope.ASTRepository.EnhancedRepository
  
  def analyze_performance_correlation(module_name) do
    with {:ok, runtime_stats} <- RuntimeCorrelation.get_runtime_stats(module_name),
         {:ok, module_data} <- EnhancedRepository.get_enhanced_module(module_name) do
      
      correlation_analysis = %{
        complexity_vs_performance: analyze_complexity_performance(module_data, runtime_stats),
        function_hotspots: identify_function_hotspots(module_data, runtime_stats),
        memory_correlation: analyze_memory_usage(module_data, runtime_stats),
        optimization_opportunities: find_optimization_opportunities(module_data, runtime_stats)
      }
      
      # Store correlation results
      store_correlation_results(module_name, correlation_analysis)
      
      {:ok, correlation_analysis}
    else
      error -> error
    end
  end
  
  defp analyze_complexity_performance(module_data, runtime_stats) do
    static_complexity = module_data.complexity_score
    runtime_performance = calculate_average_execution_time(runtime_stats)
    
    correlation_coefficient = calculate_correlation(static_complexity, runtime_performance)
    
    %{
      static_complexity: static_complexity,
      runtime_performance: runtime_performance,
      correlation: correlation_coefficient,
      prediction_accuracy: assess_prediction_accuracy(correlation_coefficient)
    }
  end
  
  defp identify_function_hotspots(module_data, runtime_stats) do
    function_stats = runtime_stats.runtime_data.function_calls
    
    Enum.map(module_data.functions, fn func ->
      runtime_data = Map.get(function_stats, {func.function_name, func.arity}, %{})
      
      %{
        function: "#{func.function_name}/#{func.arity}",
        static_complexity: func.complexity_score,
        call_count: Map.get(runtime_data, :call_count, 0),
        total_time: Map.get(runtime_data, :total_time, 0),
        average_time: calculate_average_time(runtime_data),
        hotspot_score: calculate_hotspot_score(func, runtime_data)
      }
    end)
    |> Enum.sort_by(& &1.hotspot_score, :desc)
  end
  
  defp store_correlation_results(module_name, correlation_analysis) do
    EnhancedRepository.update_enhanced_module(module_name, [
      metadata: %{
        performance_correlation: correlation_analysis,
        last_correlation_analysis: DateTime.utc_now()
      }
    ])
  end
end
```

## Advanced Debugging Features

### Interactive Debugging Interface

```elixir
defmodule MyApp.DebugInterface do
  alias ElixirScope.ASTRepository.{EnhancedRepository, MemoryManager}
  alias MyApp.{RuntimeCorrelation, PerformanceCorrelation}
  
  def start_debug_session(module_name) do
    case EnhancedRepository.get_enhanced_module(module_name) do
      {:ok, module_data} ->
        session = %{
          module: module_name,
          module_data: module_data,
          breakpoints: [],
          watch_expressions: [],
          trace_enabled: false,
          session_id: generate_session_id()
        }
        
        store_debug_session(session)
        {:ok, session.session_id}
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  def set_breakpoint(session_id, function_name, arity, line \\ nil) do
    with {:ok, session} <- get_debug_session(session_id),
         {:ok, function_data} <- EnhancedRepository.get_enhanced_function(
           session.module, function_name, arity) do
      
      breakpoint = %{
        function: function_name,
        arity: arity,
        line: line || function_data.line_start,
        condition: nil,
        hit_count: 0
      }
      
      updated_session = %{session | 
        breakpoints: [breakpoint | session.breakpoints]
      }
      
      store_debug_session(updated_session)
      enable_breakpoint_tracing(session.module, function_name, arity)
      
      {:ok, breakpoint}
    else
      error -> error
    end
  end
  
  def add_watch_expression(session_id, expression) do
    with {:ok, session} <- get_debug_session(session_id) do
      watch = %{
        expression: expression,
        last_value: nil,
        last_updated: nil
      }
      
      updated_session = %{session | 
        watch_expressions: [watch | session.watch_expressions]
      }
      
      store_debug_session(updated_session)
      {:ok, watch}
    else
      error -> error
    end
  end
  
  def step_through_function(session_id, function_name, arity) do
    with {:ok, session} <- get_debug_session(session_id),
         {:ok, function_data} <- EnhancedRepository.get_enhanced_function(
           session.module, function_name, arity) do
      
      # Analyze control flow for stepping
      control_flow = function_data.control_flow_graph
      step_points = extract_step_points(control_flow)
      
      %{
        function: "#{function_name}/#{arity}",
        step_points: step_points,
        current_step: 0,
        total_steps: length(step_points)
      }
    else
      error -> error
    end
  end
  
  def analyze_execution_path(session_id, function_name, arity, input_args) do
    with {:ok, session} <- get_debug_session(session_id),
         {:ok, function_data} <- EnhancedRepository.get_enhanced_function(
           session.module, function_name, arity) do
      
      # Simulate execution path through control flow graph
      execution_path = simulate_execution(function_data, input_args)
      
      %{
        function: "#{function_name}/#{arity}",
        input_args: input_args,
        execution_path: execution_path,
        complexity_analysis: analyze_path_complexity(execution_path),
        potential_issues: detect_path_issues(execution_path)
      }
    else
      error -> error
    end
  end
  
  defp enable_breakpoint_tracing(module, function, arity) do
    :erlang.trace_pattern({module, function, arity}, [
      {:call_count, true},
      {:call_time, true}
    ])
  end
  
  defp extract_step_points(control_flow_graph) do
    # Extract meaningful step points from CFG
    control_flow_graph
    |> Map.get(:nodes, [])
    |> Enum.filter(&is_step_point?/1)
    |> Enum.sort_by(& &1.line_number)
  end
  
  defp simulate_execution(function_data, input_args) do
    # Simulate execution through the function's control flow
    cfg = function_data.control_flow_graph
    entry_node = find_entry_node(cfg)
    
    simulate_path(cfg, entry_node, input_args, [])
  end
end
```

### Code Quality Analysis

```elixir
defmodule MyApp.QualityAnalyzer do
  alias ElixirScope.ASTRepository.EnhancedRepository
  
  def analyze_code_quality(module_name) do
    case EnhancedRepository.get_enhanced_module(module_name) do
      {:ok, module_data} ->
        quality_metrics = %{
          complexity_metrics: analyze_complexity_metrics(module_data),
          maintainability: analyze_maintainability(module_data),
          testability: analyze_testability(module_data),
          security: analyze_security_issues(module_data),
          performance: analyze_performance_issues(module_data),
          documentation: analyze_documentation(module_data)
        }
        
        overall_score = calculate_quality_score(quality_metrics)
        
        %{
          module: module_name,
          overall_score: overall_score,
          metrics: quality_metrics,
          recommendations: generate_recommendations(quality_metrics)
        }
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp analyze_complexity_metrics(module_data) do
    functions = module_data.functions
    
    %{
      cyclomatic_complexity: module_data.complexity_score,
      function_complexity: Enum.map(functions, &{&1.function_name, &1.complexity_score}),
      average_function_complexity: calculate_average_complexity(functions),
      max_function_complexity: calculate_max_complexity(functions),
      complexity_distribution: analyze_complexity_distribution(functions)
    }
  end
  
  defp analyze_maintainability(module_data) do
    %{
      function_count: length(module_data.functions),
      average_function_length: calculate_average_function_length(module_data.functions),
      coupling: analyze_coupling(module_data),
      cohesion: analyze_cohesion(module_data),
      code_duplication: detect_code_duplication(module_data)
    }
  end
  
  defp analyze_testability(module_data) do
    %{
      public_function_ratio: calculate_public_function_ratio(module_data.functions),
      dependency_injection: analyze_dependency_injection(module_data),
      side_effects: analyze_side_effects(module_data),
      pure_functions: identify_pure_functions(module_data.functions)
    }
  end
  
  defp generate_recommendations(quality_metrics) do
    recommendations = []
    
    # Complexity recommendations
    recommendations = if quality_metrics.complexity_metrics.cyclomatic_complexity > 10 do
      ["Consider breaking down complex functions" | recommendations]
    else
      recommendations
    end
    
    # Maintainability recommendations
    recommendations = if quality_metrics.maintainability.function_count > 20 do
      ["Consider splitting large module into smaller modules" | recommendations]
    else
      recommendations
    end
    
    # Performance recommendations
    recommendations = if length(quality_metrics.performance.bottlenecks) > 0 do
      ["Address identified performance bottlenecks" | recommendations]
    else
      recommendations
    end
    
    recommendations
  end
end
```

## Performance Monitoring Integration

### Real-time Monitoring

```elixir
defmodule MyApp.PerformanceMonitor do
  use GenServer
  
  alias ElixirScope.ASTRepository.MemoryManager
  alias MyApp.RuntimeCorrelation
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def get_performance_dashboard() do
    GenServer.call(__MODULE__, :get_dashboard)
  end
  
  def init(_opts) do
    # Schedule periodic monitoring
    Process.send_after(self(), :collect_metrics, 5000)  # Every 5 seconds
    
    {:ok, %{
      metrics_history: [],
      alerts: [],
      thresholds: %{
        memory_usage: 80,      # 80% memory usage
        query_time: 100,       # 100ms query time
        cache_hit_ratio: 0.7   # 70% cache hit ratio
      }
    }}
  end
  
  def handle_call(:get_dashboard, _from, state) do
    dashboard = generate_dashboard(state)
    {:reply, dashboard, state}
  end
  
  def handle_info(:collect_metrics, state) do
    # Collect current metrics
    current_metrics = collect_current_metrics()
    
    # Check for alerts
    new_alerts = check_thresholds(current_metrics, state.thresholds)
    
    # Update state
    new_state = %{state |
      metrics_history: [current_metrics | Enum.take(state.metrics_history, 99)],
      alerts: new_alerts ++ Enum.take(state.alerts, 49)
    }
    
    # Schedule next collection
    Process.send_after(self(), :collect_metrics, 5000)
    
    {:noreply, new_state}
  end
  
  defp collect_current_metrics() do
    {:ok, memory_stats} = MemoryManager.monitor_memory_usage()
    
    %{
      timestamp: DateTime.utc_now(),
      memory: %{
        repository_memory: memory_stats.repository_memory,
        system_memory_usage: memory_stats.memory_usage_percent,
        cache_hit_ratio: memory_stats.cache_hit_ratio
      },
      performance: collect_performance_metrics(),
      repository: collect_repository_metrics()
    }
  end
  
  defp collect_performance_metrics() do
    # Collect performance metrics from various sources
    %{
      average_query_time: calculate_average_query_time(),
      throughput: calculate_current_throughput(),
      concurrent_operations: count_concurrent_operations()
    }
  end
  
  defp collect_repository_metrics() do
    modules = EnhancedRepository.list_modules()
    
    %{
      total_modules: length(modules),
      total_functions: calculate_total_functions(modules),
      analysis_coverage: calculate_analysis_coverage(modules)
    }
  end
  
  defp generate_dashboard(state) do
    latest_metrics = List.first(state.metrics_history)
    
    %{
      current_status: assess_system_health(latest_metrics),
      metrics: latest_metrics,
      trends: analyze_trends(state.metrics_history),
      alerts: state.alerts,
      recommendations: generate_performance_recommendations(state)
    }
  end
end
```

## Testing Integration

### Test Utilities

```elixir
defmodule MyApp.TestUtils do
  alias ElixirScope.ASTRepository.{EnhancedRepository, MemoryManager}
  
  def setup_test_repository(opts \\ []) do
    # Start repository with test configuration
    {:ok, repo} = EnhancedRepository.start_link([
      memory_limit: Keyword.get(opts, :memory_limit, 100 * 1024 * 1024),  # 100MB
      cache_enabled: Keyword.get(opts, :cache_enabled, true),
      monitoring_enabled: false  # Disable monitoring in tests
    ])
    
    {:ok, memory_manager} = MemoryManager.start_link([
      monitoring_enabled: false,
      cleanup_interval: :infinity,  # Disable automatic cleanup
      compression_interval: :infinity
    ])
    
    %{repo: repo, memory_manager: memory_manager}
  end
  
  def cleanup_test_repository(%{repo: repo, memory_manager: memory_manager}) do
    if Process.alive?(repo), do: GenServer.stop(repo)
    if Process.alive?(memory_manager), do: GenServer.stop(memory_manager)
  end
  
  def create_test_module(module_name, complexity \\ :simple) do
    ast = case complexity do
      :simple -> generate_simple_ast(module_name)
      :medium -> generate_medium_ast(module_name)
      :complex -> generate_complex_ast(module_name)
    end
    
    {module_name, ast}
  end
  
  def assert_module_stored(module_name) do
    case EnhancedRepository.get_enhanced_module(module_name) do
      {:ok, _module_data} -> :ok
      {:error, :not_found} -> raise "Module #{module_name} not found in repository"
    end
  end
  
  def assert_performance_within_limits(operation, max_time_ms) do
    {time_us, result} = :timer.tc(operation)
    time_ms = time_us / 1000
    
    if time_ms > max_time_ms do
      raise "Operation took #{time_ms}ms, exceeds limit of #{max_time_ms}ms"
    end
    
    result
  end
  
  defp generate_simple_ast(module_name) do
    quote do
      defmodule unquote(module_name) do
        def simple_function, do: :ok
      end
    end
  end
  
  defp generate_medium_ast(module_name) do
    quote do
      defmodule unquote(module_name) do
        def function_with_logic(x) do
          if x > 0 do
            x * 2
          else
            0
          end
        end
        
        def another_function(list) when is_list(list) do
          Enum.map(list, &(&1 + 1))
        end
      end
    end
  end
end
```

### Integration Test Examples

```elixir
defmodule MyApp.IntegrationTest do
  use ExUnit.Case, async: false
  
  alias MyApp.{TestUtils, AnalysisEngine, CodeInspector}
  
  setup do
    test_setup = TestUtils.setup_test_repository()
    
    on_exit(fn ->
      TestUtils.cleanup_test_repository(test_setup)
    end)
    
    test_setup
  end
  
  test "end-to-end analysis workflow", %{repo: _repo} do
    # 1. Create test modules
    {module1, ast1} = TestUtils.create_test_module(TestModule1, :simple)
    {module2, ast2} = TestUtils.create_test_module(TestModule2, :complex)
    
    # 2. Store modules
    :ok = EnhancedRepository.store_enhanced_module(module1, ast1)
    :ok = EnhancedRepository.store_enhanced_module(module2, ast2)
    
    # 3. Verify storage
    TestUtils.assert_module_stored(module1)
    TestUtils.assert_module_stored(module2)
    
    # 4. Perform analysis
    analysis_result = TestUtils.assert_performance_within_limits(fn ->
      AnalysisEngine.analyze_project("test_project")
    end, 1000)  # 1 second limit
    
    assert {:ok, _results} = analysis_result
    
    # 5. Inspect results
    inspection = CodeInspector.inspect_module(module1)
    assert inspection.basic_info.name == module1
    assert inspection.complexity > 0
  end
  
  test "memory management under load", %{repo: _repo} do
    # Generate many modules to test memory management
    modules = Enum.map(1..100, fn i ->
      TestUtils.create_test_module(:"TestModule#{i}", :medium)
    end)
    
    # Store all modules
    Enum.each(modules, fn {module_name, ast} ->
      :ok = EnhancedRepository.store_enhanced_module(module_name, ast)
    end)
    
    # Trigger memory management
    :ok = MemoryManager.cleanup_unused_data([])
    {:ok, _stats} = MemoryManager.compress_old_analysis([])
    
    # Verify modules are still accessible
    Enum.each(modules, fn {module_name, _ast} ->
      TestUtils.assert_module_stored(module_name)
    end)
  end
end
```

## Troubleshooting Common Issues

### Memory Issues

#### High Memory Usage

**Problem**: Repository consuming excessive memory

**Diagnosis**:
```elixir
{:ok, stats} = MemoryManager.monitor_memory_usage()
IO.inspect(stats, label: "Memory Stats")

# Check for memory leaks
cleanup_stats = MemoryManager.get_cleanup_stats()
IO.inspect(cleanup_stats, label: "Cleanup Stats")
```

**Solutions**:
1. Reduce cleanup intervals
2. Enable compression
3. Implement memory pressure handling
4. Check for circular references in AST data

#### Memory Leaks

**Problem**: Memory usage continuously growing

**Diagnosis**:
```elixir
# Monitor memory over time
Enum.each(1..10, fn i ->
  {:ok, stats} = MemoryManager.monitor_memory_usage()
  IO.puts("Iteration #{i}: #{stats.repository_memory} bytes")
  :timer.sleep(5000)
end)
```

**Solutions**:
1. Enable automatic cleanup
2. Check for unclosed processes
3. Verify proper cleanup in tests
4. Monitor ETS table growth

### Performance Issues

#### Slow Query Performance

**Problem**: Queries taking longer than expected

**Diagnosis**:
```elixir
# Benchmark specific operations
{time, result} = :timer.tc(fn ->
  EnhancedRepository.get_enhanced_module(MyModule)
end)
IO.puts("Query took #{time / 1000}ms")
```

**Solutions**:
1. Enable query caching
2. Warm cache with frequently accessed data
3. Use batch operations for multiple queries
4. Check for ETS table fragmentation

#### Cache Inefficiency

**Problem**: Low cache hit ratios

**Diagnosis**:
```elixir
{:ok, stats} = MemoryManager.monitor_memory_usage()
IO.puts("Cache hit ratio: #{stats.cache_hit_ratio * 100}%")
```

**Solutions**:
1. Increase cache size
2. Adjust TTL values
3. Implement cache warming
4. Review access patterns

### Integration Issues

#### Component Communication

**Problem**: Components not communicating properly

**Diagnosis**:
```elixir
# Check process status
processes = [
  EnhancedRepository,
  MemoryManager,
  MyApp.AnalysisEngine
]

Enum.each(processes, fn process ->
  case GenServer.whereis(process) do
    nil -> IO.puts("#{process} not running")
    pid -> IO.puts("#{process} running: #{inspect(pid)}")
  end
end)
```

**Solutions**:
1. Verify supervision tree setup
2. Check process dependencies
3. Add proper error handling
4. Implement health checks

## Configuration Examples

### Production Configuration

```elixir
# config/prod.exs
config :my_app, :enhanced_repository,
  memory_limit: 2 * 1024 * 1024 * 1024,  # 2GB
  cache_enabled: true,
  monitoring_enabled: true,
  cleanup_interval: 300_000,              # 5 minutes
  compression_interval: 600_000,          # 10 minutes
  memory_check_interval: 30_000,          # 30 seconds
  lazy_loading_enabled: true,
  cache_warming_enabled: true,
  performance_monitoring: true
```

### Development Configuration

```elixir
# config/dev.exs
config :my_app, :enhanced_repository,
  memory_limit: 512 * 1024 * 1024,        # 512MB
  cache_enabled: true,
  monitoring_enabled: true,
  cleanup_interval: 600_000,              # 10 minutes
  compression_interval: 1_200_000,        # 20 minutes
  memory_check_interval: 60_000,          # 1 minute
  lazy_loading_enabled: false,            # Disable for faster development
  cache_warming_enabled: false,
  performance_monitoring: false
```

### Test Configuration

```elixir
# config/test.exs
config :my_app, :enhanced_repository,
  memory_limit: 100 * 1024 * 1024,        # 100MB
  cache_enabled: true,
  monitoring_enabled: false,              # Disable monitoring in tests
  cleanup_interval: :infinity,            # Manual cleanup only
  compression_interval: :infinity,
  memory_check_interval: :infinity,
  lazy_loading_enabled: false,
  cache_warming_enabled: false,
  performance_monitoring: false
```

---

*This integration guide covers Enhanced AST Repository v0.1.0 integration patterns. For the latest updates and additional examples, please refer to the project repository and API documentation.* 