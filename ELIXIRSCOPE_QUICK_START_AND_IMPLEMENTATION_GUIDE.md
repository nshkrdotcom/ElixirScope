# ElixirScope: Quick Start & Implementation Guide
**Get up and running with the world's first hybrid AST-runtime correlation system**

## Table of Contents

1. [Quick Start (5 minutes)](#quick-start-5-minutes)
2. [Basic Setup & Configuration](#basic-setup--configuration)
3. [Your First AST Repository](#your-first-ast-repository)
4. [Runtime Correlation in Action](#runtime-correlation-in-action)
5. [AI-Powered Analysis](#ai-powered-analysis)
6. [Advanced Features](#advanced-features)
7. [Production Deployment](#production-deployment)
8. [Troubleshooting](#troubleshooting)

---

## Quick Start (5 minutes)

### Step 1: Installation

Add ElixirScope to your `mix.exs`:

```elixir
def deps do
  [
    {:elixir_scope, "~> 0.1.0"}
  ]
end
```

```bash
mix deps.get
```

### Step 2: Basic Configuration

Create `config/elixir_scope.exs`:

```elixir
import Config

config :elixir_scope,
  # Start with minimal configuration
  capture: [
    buffer_size: 1_000,
    enabled: true
  ],
  ai: [
    llm_provider: :mock  # Use mock provider for quick start
  ],
  ast_repository: [
    enabled: true
  ]
```

### Step 3: Start ElixirScope

```elixir
# In your application.ex or IEx
{:ok, _pid} = ElixirScope.start()

# Check status
status = ElixirScope.status()
IO.inspect(status)
# %{
#   repositories: %{active: 1, modules: 0},
#   capture: %{events_captured: 0, buffer_usage: 0.0},
#   ai: %{provider: :mock, analysis_count: 0}
# }
```

### Step 4: Your First Analysis

```elixir
# Create a simple test module
defmodule MyTestModule do
  def hello(name) do
    "Hello, #{name}!"
  end
end

# Analyze with ElixirScope
{:ok, analysis} = ElixirScope.analyze_project("./lib")
IO.inspect(analysis.modules)
# Shows detected modules with their patterns and complexity
```

**🎉 Congratulations!** ElixirScope is now running and analyzing your code. Let's dive deeper...

---

## Basic Setup & Configuration

### Environment-Specific Configuration

#### Development Environment
```elixir
# config/dev.exs
import Config

config :elixir_scope,
  capture: [
    buffer_size: 5_000,
    flush_interval: 500,
    debug_mode: true
  ],
  ai: [
    llm_provider: :mock,
    verbose_logging: true
  ],
  ast_repository: [
    correlation_enabled: true,
    cache_size_mb: 128
  ]
```

#### Test Environment
```elixir
# config/test.exs
import Config

config :elixir_scope,
  capture: [
    buffer_size: 100,
    test_mode: true
  ],
  ai: [
    llm_provider: :mock
  ],
  ast_repository: [
    enabled: false  # Disable for faster tests
  ]
```

#### Production Environment
```elixir
# config/prod.exs
import Config

config :elixir_scope,
  capture: [
    buffer_size: 50_000,
    flush_interval: 2_000,
    async_processing: true
  ],
  ai: [
    llm_provider: :gemini,  # Use real LLM in production
    analysis_timeout: 30_000
  ],
  ast_repository: [
    correlation_enabled: true,
    max_correlations: 1_000_000,
    cache_size_mb: 2_048
  ]
```

### LLM Provider Setup

#### Option 1: Google Gemini (Recommended)
```bash
# Set environment variable
export GOOGLE_API_KEY="your-gemini-api-key-here"
```

```elixir
# Update configuration
config :elixir_scope,
  ai: [
    llm_provider: :gemini,
    gemini: [
      api_key: System.get_env("GOOGLE_API_KEY"),
      model: "gemini-pro",
      timeout: 30_000
    ]
  ]
```

#### Option 2: Vertex AI
```bash
# Set service account file
export VERTEX_JSON_FILE="/path/to/service-account.json"
```

```elixir
config :elixir_scope,
  ai: [
    llm_provider: :vertex,
    vertex: [
      project_id: "your-gcp-project",
      location: "us-central1",
      credentials_file: System.get_env("VERTEX_JSON_FILE")
    ]
  ]
```

#### Option 3: Mock Provider (for development/testing)
```elixir
config :elixir_scope,
  ai: [
    llm_provider: :mock,
    mock: [
      response_delay: 100,  # Simulate API delay
      success_rate: 0.95    # Simulate occasional failures
    ]
  ]
```

---

## Your First AST Repository

### Step 1: Start the Repository

```elixir
# Start the AST repository
{:ok, repo_pid} = ElixirScope.ASTRepository.Repository.start_link()

# Check repository health
{:ok, health} = ElixirScope.ASTRepository.Repository.health_check(repo_pid)
IO.inspect(health)
# %{status: :healthy, memory_usage: 1_234_567, module_count: 0}
```

### Step 2: Store Your First Module

```elixir
# Create a GenServer module for analysis
source_code = """
defmodule MyApp.UserCache do
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def get_user(id) do
    GenServer.call(__MODULE__, {:get_user, id})
  end
  
  def put_user(id, user) do
    GenServer.cast(__MODULE__, {:put_user, id, user})
  end
  
  def init(_opts) do
    {:ok, %{}}
  end
  
  def handle_call({:get_user, id}, _from, state) do
    {:reply, Map.get(state, id), state}
  end
  
  def handle_cast({:put_user, id, user}, state) do
    {:noreply, Map.put(state, id, user)}
  end
end
"""

# Parse and analyze the module
{:ok, ast} = Code.string_to_quoted(source_code)

# Create module data
module_data = %ElixirScope.ASTRepository.ModuleData{
  module_name: MyApp.UserCache,
  ast: ast,
  source_file: "lib/my_app/user_cache.ex",
  source_code: source_code
}

# Store in repository
:ok = ElixirScope.ASTRepository.Repository.store_module(repo_pid, module_data)

# Verify storage
{:ok, stored_module} = ElixirScope.ASTRepository.Repository.get_module(repo_pid, MyApp.UserCache)
IO.inspect(stored_module.module_type)
# :genserver

IO.inspect(stored_module.patterns)
# [:cache_pattern, :genserver_pattern]

IO.inspect(stored_module.callbacks)
# [:init, :handle_call, :handle_cast]
```

### Step 3: Query Repository Data

```elixir
# List all modules
{:ok, modules} = ElixirScope.ASTRepository.Repository.list_modules(repo_pid)
IO.inspect(modules)
# [MyApp.UserCache]

# Get repository statistics
{:ok, stats} = ElixirScope.ASTRepository.Repository.get_statistics(repo_pid)
IO.inspect(stats)
# %{
#   module_count: 1,
#   total_functions: 6,
#   correlation_count: 0,
#   memory_usage_bytes: 1_234_567
# }

# Query modules by pattern
genserver_modules = ElixirScope.ASTRepository.Repository.query_modules(repo_pid, %{
  module_type: :genserver
})
IO.inspect(genserver_modules)
# [%{module_name: MyApp.UserCache, patterns: [:cache_pattern, :genserver_pattern]}]
```

---

## Runtime Correlation in Action

### Step 1: Start Runtime Correlation

```elixir
# Start the runtime correlator
{:ok, correlator_pid} = ElixirScope.ASTRepository.RuntimeCorrelator.start_link(
  repository: repo_pid
)

# Initialize instrumentation context
:ok = ElixirScope.Capture.InstrumentationRuntime.initialize_context(
  buffer_size: 1_000,
  correlation_enabled: true
)
```

### Step 2: Manual Instrumentation Example

```elixir
defmodule InstrumentedExample do
  def process_data(input) do
    # Generate correlation IDs
    correlation_id = "process_#{System.unique_integer()}"
    ast_node_id = "node_process_data_#{System.unique_integer()}"
    
    # Report function entry
    :ok = ElixirScope.Capture.InstrumentationRuntime.report_ast_function_entry_with_node_id(
      __MODULE__, :process_data, [input], correlation_id, ast_node_id
    )
    
    try do
      # Simulate processing
      result = String.upcase(input)
      
      # Capture intermediate state
      :ok = ElixirScope.Capture.InstrumentationRuntime.report_ast_variable_snapshot(
        correlation_id, %{input: input, result: result}, __ENV__.line, ast_node_id
      )
      
      # Report successful exit
      :ok = ElixirScope.Capture.InstrumentationRuntime.report_ast_function_exit_with_node_id(
        __MODULE__, :process_data, {:ok, result}, correlation_id
      )
      
      {:ok, result}
    rescue
      error ->
        # Report error exit
        :ok = ElixirScope.Capture.InstrumentationRuntime.report_ast_function_exit_with_node_id(
          __MODULE__, :process_data, {:error, error}, correlation_id
        )
        
        {:error, error}
    end
  end
end

# Execute instrumented code
{:ok, result} = InstrumentedExample.process_data("hello world")
IO.inspect(result)
# "HELLO WORLD"
```

### Step 3: Verify Correlation

```elixir
# Check correlation statistics
stats = ElixirScope.ASTRepository.RuntimeCorrelator.get_correlation_stats(correlator_pid)
IO.inspect(stats)
# %{
#   total_correlations: 1,
#   successful_correlations: 1,
#   correlation_accuracy: 1.0,
#   average_latency_ms: 0.8
# }

# Get correlated events for a specific correlation ID
correlation_id = "process_1234"  # Use actual correlation ID from above
{:ok, ast_node_id} = ElixirScope.ASTRepository.RuntimeCorrelator.get_ast_node_by_correlation(
  correlator_pid, correlation_id
)
IO.inspect(ast_node_id)
# "node_process_data_5678"
```

### Step 4: Automatic Pattern Detection

```elixir
# Store the instrumented module in repository
instrumented_source = """
defmodule InstrumentedExample do
  def process_data(input) do
    String.upcase(input)
  end
end
"""

{:ok, ast} = Code.string_to_quoted(instrumented_source)
module_data = %ElixirScope.ASTRepository.ModuleData{
  module_name: InstrumentedExample,
  ast: ast,
  source_file: "lib/instrumented_example.ex"
}

:ok = ElixirScope.ASTRepository.Repository.store_module(repo_pid, module_data)

# ElixirScope automatically detects:
{:ok, stored} = ElixirScope.ASTRepository.Repository.get_module(repo_pid, InstrumentedExample)
IO.inspect(stored.patterns)
# [:string_processing, :transformation_pattern]

IO.inspect(stored.complexity_metrics)
# %{functions: 1, lines_of_code: 3, cyclomatic_complexity: 1}
```

---

## AI-Powered Analysis

### Step 1: Basic AI Analysis

```elixir
# Analyze a module with AI
module_source = """
defmodule MyApp.OrderProcessor do
  def process_order(order) do
    with {:ok, validated} <- validate_order(order),
         {:ok, payment} <- process_payment(validated),
         {:ok, shipment} <- create_shipment(payment) do
      {:ok, shipment}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp validate_order(order) do
    if order.total > 0, do: {:ok, order}, else: {:error, :invalid_total}
  end
  
  defp process_payment(order) do
    # Simulate payment processing
    :timer.sleep(100)
    {:ok, Map.put(order, :payment_id, "pay_123")}
  end
  
  defp create_shipment(order) do
    {:ok, Map.put(order, :shipment_id, "ship_456")}
  end
end
"""

# Analyze with AI
{:ok, ai_analysis} = ElixirScope.AI.CodeAnalyzer.analyze_code(module_source)
IO.inspect(ai_analysis.summary)
# "Order processing module using with statement for error handling pipeline"

IO.inspect(ai_analysis.patterns_detected)
# [:pipeline_pattern, :error_handling_pattern, :with_statement]

IO.inspect(ai_analysis.suggestions)
# [
#   "Consider adding timeout handling for payment processing",
#   "Add logging for audit trail of order processing steps",
#   "Consider implementing retry logic for payment failures"
# ]
```

### Step 2: AI-Powered Instrumentation Planning

```elixir
# Generate instrumentation plan with AI
{:ok, plan} = ElixirScope.AI.Orchestrator.plan_for_module(module_source,
  strategy: :comprehensive,
  focus: [:performance, :error_handling]
)

IO.inspect(plan.instrumentation_points)
# [
#   %{location: {:function, :process_order, 1}, type: :performance_critical},
#   %{location: {:function, :process_payment, 1}, type: :async_operation},
#   %{location: {:line, 15}, type: :error_handling}
# ]

IO.inspect(plan.estimated_overhead)
# 0.002  # 0.2% performance overhead

IO.inspect(plan.recommendations)
# [
#   "Monitor payment processing latency",
#   "Track error rates for each validation step",
#   "Add circuit breaker pattern for payment gateway"
# ]
```

### Step 3: AI Analysis with Runtime Data

```elixir
# First, let's simulate some runtime data
runtime_data = %{
  function_calls: %{
    {:process_order, 1} => %{count: 1500, avg_duration_ms: 125.5, error_rate: 0.02},
    {:process_payment, 1} => %{count: 1470, avg_duration_ms: 98.2, error_rate: 0.01},
    {:create_shipment, 1} => %{count: 1455, avg_duration_ms: 12.1, error_rate: 0.001}
  },
  error_patterns: [
    %{type: :payment_timeout, frequency: 15, location: {:process_payment, 1}},
    %{type: :invalid_total, frequency: 30, location: {:validate_order, 1}}
  ]
}

# Create hybrid context
hybrid_context = %{
  static_context: %{
    ast_analysis: ai_analysis,
    code_structure: module_source
  },
  runtime_context: runtime_data
}

# Analyze with hybrid context
{:ok, hybrid_analysis} = ElixirScope.AI.LLM.Client.analyze_with_context(
  hybrid_context,
  "How can I optimize this order processing pipeline based on the runtime data?",
  include_code_examples: true
)

IO.inspect(hybrid_analysis.insights)
# [
#   "Payment processing is the main bottleneck (98ms avg)",
#   "Error rate is acceptable but payment timeouts need attention",
#   "Shipment creation is very fast - consider batching"
# ]

IO.inspect(hybrid_analysis.optimizations)
# [
#   %{
#     type: :async_optimization,
#     description: "Make payment processing asynchronous",
#     estimated_improvement: "40% latency reduction",
#     code_example: "Consider using Task.async for payment processing"
#   }
# ]
```

---

## Advanced Features

### Real-Time Event Monitoring

```elixir
# Set up real-time event monitoring
defmodule MyApp.EventMonitor do
  use GenServer
  
  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end
  
  def init([]) do
    # Subscribe to ElixirScope events
    :ok = ElixirScope.Events.subscribe(self(), [:function_entry, :function_exit, :error])
    {:ok, %{events: []}}
  end
  
  def handle_info({:elixir_scope_event, event}, state) do
    IO.puts("📊 Event: #{event.type} in #{event.module}.#{event.function}")
    
    # Store recent events
    new_events = [event | Enum.take(state.events, 99)]
    {:noreply, %{state | events: new_events}}
  end
end

# Start monitoring
{:ok, _monitor} = MyApp.EventMonitor.start_link()

# Execute some code to see events
InstrumentedExample.process_data("test")
# 📊 Event: function_entry in InstrumentedExample.process_data
# 📊 Event: function_exit in InstrumentedExample.process_data
```

### Custom Pattern Detection

```elixir
# Define custom pattern detector
defmodule MyApp.CustomPatterns do
  @behaviour ElixirScope.AI.PatternDetector
  
  def detect_patterns(ast) do
    patterns = []
    
    # Detect database interaction pattern
    patterns = if has_ecto_queries?(ast) do
      [:database_heavy | patterns]
    else
      patterns
    end
    
    # Detect API client pattern
    patterns = if has_http_calls?(ast) do
      [:api_client | patterns]
    else
      patterns
    end
    
    patterns
  end
  
  defp has_ecto_queries?(ast) do
    # Simple detection - look for Repo module calls
    ast
    |> Macro.prewalk(false, fn
      {{:., _, [{:__aliases__, _, [:Repo]}, _]}, _, _}, _ -> {true, true}
      node, acc -> {node, acc}
    end)
    |> elem(1)
  end
  
  defp has_http_calls?(ast) do
    # Look for HTTPoison, Tesla, or Req calls
    ast
    |> Macro.prewalk(false, fn
      {{:., _, [{:__aliases__, _, [http_client]}, _]}, _, _}, _ 
      when http_client in [:HTTPoison, :Tesla, :Req] -> {true, true}
      node, acc -> {node, acc}
    end)
    |> elem(1)
  end
end

# Register custom pattern detector
:ok = ElixirScope.AI.PatternRecognizer.register_detector(MyApp.CustomPatterns)

# Test with a module that uses Ecto
ecto_module = """
defmodule MyApp.UserRepository do
  alias MyApp.Repo
  alias MyApp.User
  
  def get_user(id) do
    Repo.get(User, id)
  end
  
  def list_users do
    Repo.all(User)
  end
end
"""

{:ok, ast} = Code.string_to_quoted(ecto_module)
patterns = ElixirScope.AI.PatternRecognizer.extract_patterns(ast)
IO.inspect(patterns)
# [:database_heavy, :repository_pattern, :ecto_pattern]
```

### Performance Profiling Integration

```elixir
# Create a performance profiler using ElixirScope
defmodule MyApp.Profiler do
  def profile_function(module, function, arity, duration_seconds \\ 30) do
    IO.puts("🔍 Profiling #{module}.#{function}/#{arity} for #{duration_seconds}s")
    
    # Start collecting correlation data
    start_time = System.monotonic_time(:second)
    end_time = start_time + duration_seconds
    
    # Execute the function multiple times while profiling
    spawn(fn -> simulate_load(module, function, end_time) end)
    
    # Wait for profiling to complete
    :timer.sleep(duration_seconds * 1000)
    
    # Analyze collected data
    analyze_profiling_results(module, function, arity)
  end
  
  defp simulate_load(module, function, end_time) do
    if System.monotonic_time(:second) < end_time do
      try do
        apply(module, function, ["test_data"])
      rescue
        _ -> :ok
      end
      
      :timer.sleep(10)  # Small delay between calls
      simulate_load(module, function, end_time)
    end
  end
  
  defp analyze_profiling_results(module, function, arity) do
    # Get correlation statistics
    {:ok, correlator} = ElixirScope.ASTRepository.RuntimeCorrelator.start_link()
    stats = ElixirScope.ASTRepository.RuntimeCorrelator.get_correlation_stats(correlator)
    
    # Filter for our function
    function_stats = stats.function_stats
    |> Enum.filter(fn {mod, func, ar} -> 
      mod == module and func == function and ar == arity 
    end)
    
    case function_stats do
      [{_mod, _func, _ar} = key] ->
        function_data = stats.detailed_stats[key]
        
        %{
          total_calls: function_data.call_count,
          average_duration_ms: function_data.avg_duration,
          p95_duration_ms: function_data.p95_duration,
          error_rate: function_data.error_rate,
          recommendations: generate_recommendations(function_data)
        }
      
      [] ->
        %{error: "No profiling data found for #{module}.#{function}/#{arity}"}
    end
  end
  
  defp generate_recommendations(function_data) do
    recommendations = []
    
    recommendations = if function_data.avg_duration > 100 do
      ["Function is slow (#{function_data.avg_duration}ms avg) - consider optimization" | recommendations]
    else
      recommendations
    end
    
    recommendations = if function_data.error_rate > 0.01 do
      ["High error rate (#{function_data.error_rate * 100}%) - improve error handling" | recommendations]
    else
      recommendations
    end
    
    recommendations
  end
end

# Profile our example function
profile_results = MyApp.Profiler.profile_function(InstrumentedExample, :process_data, 1, 10)
IO.inspect(profile_results)
# %{
#   total_calls: 892,
#   average_duration_ms: 0.12,
#   p95_duration_ms: 0.25,
#   error_rate: 0.0,
#   recommendations: []
# }
```

---

## Production Deployment

### Step 1: Production Configuration

```elixir
# config/prod.exs
import Config

config :elixir_scope,
  # High-performance capture settings
  capture: [
    buffer_size: 100_000,
    batch_size: 1_000,
    flush_interval: 5_000,
    async_processing: true,
    worker_pool_size: 4
  ],
  
  # Production AI settings
  ai: [
    llm_provider: :gemini,
    analysis_timeout: 60_000,
    max_concurrent_analyses: 2,
    cache_results: true,
    cache_ttl_hours: 24
  ],
  
  # Production repository settings
  ast_repository: [
    enabled: true,
    correlation_enabled: true,
    max_correlations: 10_000_000,
    correlation_timeout_ms: 3_000,
    cache_size_mb: 4_096,
    cleanup_interval_ms: 3_600_000  # 1 hour
  ],
  
  # Production monitoring
  monitoring: [
    metrics_enabled: true,
    health_check_interval_ms: 30_000,
    performance_tracking: true,
    alert_thresholds: %{
      correlation_accuracy: 0.95,
      latency_p95_ms: 10.0,
      memory_usage_gb: 8.0,
      error_rate: 0.01
    }
  ]
```

### Step 2: Application Integration

```elixir
# lib/my_app/application.ex
defmodule MyApp.Application do
  use Application
  
  def start(_type, _args) do
    children = [
      # Your application children
      MyApp.Repo,
      MyAppWeb.Endpoint,
      
      # ElixirScope integration
      {ElixirScope, []},
      
      # Optional: Custom ElixirScope monitoring
      MyApp.ElixirScopeMonitor
    ]
    
    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### Step 3: Health Monitoring

```elixir
# lib/my_app/elixir_scope_monitor.ex
defmodule MyApp.ElixirScopeMonitor do
  use GenServer
  require Logger
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    # Schedule regular health checks
    :timer.send_interval(30_000, :health_check)
    {:ok, %{}}
  end
  
  def handle_info(:health_check, state) do
    case ElixirScope.Monitor.health_check() do
      {:ok, health} -> 
        log_health_status(health)
        
      {:error, issues} ->
        Logger.error("ElixirScope health check failed: #{inspect(issues)}")
        # Could trigger alerts here
    end
    
    {:noreply, state}
  end
  
  defp log_health_status(health) do
    Logger.info("ElixirScope Health: #{health.status}")
    
    if health.status != :healthy do
      Logger.warn("ElixirScope issues detected: #{inspect(health.issues)}")
    end
    
    # Log key metrics
    metrics = ElixirScope.Monitor.collect_performance_metrics()
    Logger.info("ElixirScope Metrics: " <>
      "Correlation accuracy: #{metrics.correlation.accuracy}, " <>
      "Latency P95: #{metrics.correlation.p95_latency_ms}ms, " <>
      "Memory usage: #{metrics.memory.total_usage_mb}MB"
    )
  end
end
```

### Step 4: Production Monitoring Dashboard

```elixir
# lib/my_app_web/live/elixir_scope_dashboard.ex
defmodule MyAppWeb.ElixirScopeDashboard do
  use MyAppWeb, :live_view
  
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(1000, self(), :update_metrics)
    end
    
    {:ok, assign(socket, :metrics, get_metrics())}
  end
  
  def handle_info(:update_metrics, socket) do
    {:noreply, assign(socket, :metrics, get_metrics())}
  end
  
  def render(assigns) do
    ~H"""
    <div class="elixir-scope-dashboard">
      <h1>ElixirScope Production Dashboard</h1>
      
      <div class="metrics-grid">
        <div class="metric-card">
          <h3>Correlation Accuracy</h3>
          <div class="metric-value">
            <%= Float.round(@metrics.correlation.accuracy * 100, 1) %>%
          </div>
        </div>
        
        <div class="metric-card">
          <h3>P95 Latency</h3>
          <div class="metric-value">
            <%= Float.round(@metrics.correlation.p95_latency_ms, 1) %>ms
          </div>
        </div>
        
        <div class="metric-card">
          <h3>Memory Usage</h3>
          <div class="metric-value">
            <%= Float.round(@metrics.memory.total_usage_mb, 0) %>MB
          </div>
        </div>
        
        <div class="metric-card">
          <h3>Events/Second</h3>
          <div class="metric-value">
            <%= @metrics.throughput.events_per_second %>
          </div>
        </div>
      </div>
      
      <div class="recent-activity">
        <h3>Recent Analysis</h3>
        <ul>
          <%= for analysis <- @metrics.recent_analyses do %>
            <li>
              <strong><%= analysis.module %></strong> - 
              <%= analysis.patterns |> Enum.join(", ") %>
              <span class="timestamp">(<%= analysis.timestamp %>)</span>
            </li>
          <% end %>
        </ul>
      </div>
    </div>
    """
  end
  
  defp get_metrics do
    ElixirScope.Monitor.collect_performance_metrics()
  end
end
```

---

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: High Memory Usage

**Symptoms**: System memory grows continuously, performance degrades
**Diagnosis**:
```elixir
# Check memory usage
metrics = ElixirScope.Monitor.get_memory_usage()
IO.inspect(metrics)
# %{
#   total_usage_mb: 2048,
#   repository_mb: 1200,
#   correlation_cache_mb: 600,
#   event_buffer_mb: 248
# }
```

**Solutions**:
```elixir
# Option 1: Reduce cache sizes
config :elixir_scope,
  ast_repository: [
    cache_size_mb: 512,  # Reduce from default
    max_correlations: 500_000  # Reduce correlation limit
  ]

# Option 2: Enable more aggressive cleanup
config :elixir_scope,
  ast_repository: [
    cleanup_interval_ms: 1_800_000,  # Clean every 30 minutes
    correlation_ttl_hours: 4  # Shorter correlation lifetime
  ]

# Option 3: Manual cleanup
:ok = ElixirScope.ASTRepository.Repository.vacuum()
```

#### Issue 2: Poor Correlation Accuracy

**Symptoms**: Correlation accuracy below 90%
**Diagnosis**:
```elixir
# Check correlation statistics
stats = ElixirScope.ASTRepository.RuntimeCorrelator.get_correlation_stats()
IO.inspect(stats.correlation_accuracy)
# 0.78  # Too low!

# Check for common issues
diagnostics = ElixirScope.ASTRepository.RuntimeCorrelator.diagnose_correlation_issues()
IO.inspect(diagnostics)
# [
#   {:missing_ast_nodes, 120},
#   {:invalid_correlation_ids, 45},
#   {:timing_mismatches, 23}
# ]
```

**Solutions**:
```elixir
# Option 1: Validate AST node IDs
correlation_id = "test_correlation"
ast_node_id = "test_node"

valid = ElixirScope.Capture.InstrumentationRuntime.validate_ast_node_id(ast_node_id)
if not valid do
  IO.puts("Invalid AST node ID format: #{ast_node_id}")
end

# Option 2: Check instrumentation timing
# Ensure function entry and exit events have matching correlation IDs

# Option 3: Increase correlation timeout
config :elixir_scope,
  ast_repository: [
    correlation_timeout_ms: 10_000  # Increase from 5000ms
  ]
```

#### Issue 3: AI Analysis Failures

**Symptoms**: AI analysis timeouts or error responses
**Diagnosis**:
```elixir
# Check AI provider status
status = ElixirScope.AI.LLM.Client.get_provider_status()
IO.inspect(status)
# %{
#   provider: :gemini,
#   status: :error,
#   last_error: "API quota exceeded",
#   success_rate: 0.65
# }
```

**Solutions**:
```elixir
# Option 1: Switch to fallback provider
:ok = ElixirScope.AI.LLM.Client.set_provider(:mock)

# Option 2: Increase timeouts
config :elixir_scope,
  ai: [
    analysis_timeout: 60_000,  # Increase to 60 seconds
    retry_attempts: 3
  ]

# Option 3: Check API credentials
case System.get_env("GOOGLE_API_KEY") do
  nil -> IO.puts("Missing GOOGLE_API_KEY environment variable")
  key -> IO.puts("API key configured: #{String.slice(key, 0, 10)}...")
end
```

### Debug Mode

Enable comprehensive debugging:

```elixir
# config/dev.exs
config :elixir_scope,
  debug_mode: true,
  verbose_logging: true,
  capture: [
    debug_events: true,
    log_all_correlations: true
  ]

# Check debug information
debug_info = ElixirScope.Debug.get_system_info()
IO.inspect(debug_info, pretty: true)
# %{
#   version: "0.1.0",
#   uptime_seconds: 3600,
#   modules_analyzed: 150,
#   correlations_processed: 85000,
#   ai_analyses_completed: 25,
#   current_memory_mb: 128,
#   performance_targets_met: true
# }
```

### Performance Tuning

Optimize for your specific use case:

```elixir
# For high-throughput applications
config :elixir_scope,
  capture: [
    buffer_size: 50_000,
    batch_size: 500,
    worker_pool_size: 8
  ]

# For memory-constrained environments
config :elixir_scope,
  ast_repository: [
    cache_size_mb: 128,
    max_correlations: 50_000
  ]

# For AI-heavy workloads
config :elixir_scope,
  ai: [
    max_concurrent_analyses: 4,
    analysis_cache_enabled: true,
    analysis_cache_size: 1000
  ]
```

---

## Next Steps

### Learning Path

1. **Basic Usage** (1-2 hours)
   - Complete this quick start guide
   - Experiment with AST repository and correlation
   - Try AI analysis on your existing code

2. **Advanced Features** (1-2 days)
   - Implement custom pattern detectors
   - Set up performance profiling
   - Integrate with your CI/CD pipeline

3. **Production Deployment** (1 week)
   - Configure for production environment
   - Set up monitoring and alerting
   - Train your team on ElixirScope features

4. **Custom Extensions** (ongoing)
   - Develop custom analysis plugins
   - Contribute patterns back to the community
   - Explore Cinema Debugger when released

### Community Resources

- **Documentation**: [ElixirScope Docs](link-to-docs)
- **GitHub**: [ElixirScope Repository](link-to-repo)
- **Discord**: Join the ElixirScope community chat
- **Forum**: [Elixir Forum ElixirScope Tag](link-to-forum)

### Getting Help

1. **Check the troubleshooting section** above
2. **Search existing GitHub issues**
3. **Join the community Discord** for real-time help
4. **Open a GitHub issue** for bugs or feature requests

---

**🎉 Congratulations!** You're now ready to leverage ElixirScope's revolutionary hybrid AST-runtime correlation system to transform your Elixir development experience. Start with the basics and gradually explore the advanced features as you become more comfortable with the platform.

The future of Elixir development is here - enjoy exploring it! 🚀ELIXIRSCOPE_DEVELOPMENT_ROADMAP_AND_IMPLMENTATION_STRATEGY.md

