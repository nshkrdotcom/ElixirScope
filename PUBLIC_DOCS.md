# ElixirScope Public API Documentation

**Version**: 0.1.0  
**Last Updated**: December 2024  
**Status**: Active Development

ElixirScope is an AI-powered execution cinema debugger for Elixir applications that provides deep observability, time-travel debugging, and comprehensive event capture with minimal overhead.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Core API](#core-api)
3. [Configuration Management](#configuration-management)
4. [Event Querying](#event-querying)
5. [Cinema Debugger](#cinema-debugger)
6. [Phoenix Integration](#phoenix-integration)
7. [AST Repository](#ast-repository)
8. [Performance Monitoring](#performance-monitoring)
9. [Advanced Usage](#advanced-usage)
10. [Error Handling](#error-handling)
11. [Best Practices](#best-practices)

---

## Quick Start

### Installation

Add ElixirScope to your `mix.exs`:

```elixir
def deps do
  [
    {:elixir_scope, "~> 0.1.0"}
  ]
end
```

### Basic Usage

```elixir
# Start ElixirScope with default configuration
:ok = ElixirScope.start()

# Check if running
ElixirScope.running?()
# => true

# Get system status
status = ElixirScope.status()
# => %{running: true, config: %{...}, stats: %{...}}

# Stop ElixirScope
:ok = ElixirScope.stop()
```

### Configuration

```elixir
# config/config.exs
config :elixir_scope,
  ai: [
    provider: :mock,  # :mock, :gemini, :vertex
    planning: [
      default_strategy: :balanced,  # :minimal, :balanced, :full_trace
      sampling_rate: 1.0
    ]
  ],
  capture: [
    ring_buffer: [
      size: 1_048_576,
      max_events: 100_000
    ]
  ]
```

---

## Core API

### ElixirScope Main Module

The primary interface for all ElixirScope operations.

#### Application Lifecycle

```elixir
@spec start(keyword()) :: :ok | {:error, term()}
def start(opts \\ [])
```

Starts ElixirScope with optional configuration overrides.

**Options:**
- `:strategy` - Instrumentation strategy (`:minimal`, `:balanced`, `:full_trace`)
- `:sampling_rate` - Event sampling rate (0.0 to 1.0)
- `:modules` - Specific modules to instrument
- `:exclude_modules` - Modules to exclude from instrumentation

**Examples:**

```elixir
# Start with default configuration
ElixirScope.start()

# Start with full tracing for debugging
ElixirScope.start(strategy: :full_trace, sampling_rate: 1.0)

# Start with minimal overhead for production
ElixirScope.start(strategy: :minimal, sampling_rate: 0.1)

# Instrument only specific modules
ElixirScope.start(modules: [MyApp.Worker, MyApp.Server])
```

---

```elixir
@spec stop() :: :ok
def stop()
```

Stops ElixirScope and all tracing.

**Example:**

```elixir
ElixirScope.stop()
```

---

```elixir
@spec status() :: map()
def status()
```

Gets comprehensive system status including configuration, performance stats, and storage usage.

**Returns:**

```elixir
%{
  running: true,
  timestamp: 1640995200000000000,
  config: %{
    strategy: :balanced,
    sampling_rate: 1.0,
    performance_target: 0.01,
    ring_buffer_size: 1048576,
    hot_storage_limit: 100000
  },
  stats: %{
    events_captured: 12345,
    events_per_second: 1250,
    memory_usage: 2048576,
    ring_buffer_utilization: 0.7
  },
  storage: %{
    hot_events: 5000,
    warm_events: 25000,
    cold_events: 100000,
    memory_usage: "2.1 MB",
    disk_usage: "15.3 MB"
  }
}
```

---

```elixir
@spec running?() :: boolean()
def running?()
```

Checks if ElixirScope is currently active.

**Example:**

```elixir
if ElixirScope.running?() do
  # ElixirScope is active
  events = ElixirScope.get_events(limit: 100)
end
```

---

## Configuration Management

### ElixirScope.Config

Centralized configuration management with validation and runtime updates.

#### Configuration Access

```elixir
@spec get() :: ElixirScope.Config.t() | {:error, term()}
def get()
```

Gets the complete current configuration.

**Example:**

```elixir
config = ElixirScope.get_config()
sampling_rate = config.ai.planning.sampling_rate
```

---

```elixir
@spec get([atom()]) :: term()
def get(path)
```

Gets a specific configuration value by path.

**Examples:**

```elixir
# Get AI provider
provider = ElixirScope.Config.get([:ai, :provider])
# => :mock

# Get ring buffer size
buffer_size = ElixirScope.Config.get([:capture, :ring_buffer, :size])
# => 1048576

# Get sampling rate
sampling_rate = ElixirScope.Config.get([:ai, :planning, :sampling_rate])
# => 1.0
```

---

```elixir
@spec update([atom()], term()) :: :ok | {:error, term()}
def update(path, value)
```

Updates configuration at runtime. Only certain paths can be updated for safety.

**Updatable Paths:**
- `[:ai, :planning, :sampling_rate]`
- `[:ai, :planning, :default_strategy]`
- `[:capture, :processing, :batch_size]`
- `[:capture, :processing, :flush_interval]`
- `[:interface, :query_timeout]`

**Examples:**

```elixir
# Update sampling rate
:ok = ElixirScope.update_config([:ai, :planning, :sampling_rate], 0.8)

# Update instrumentation strategy
:ok = ElixirScope.update_config([:ai, :planning, :default_strategy], :full_trace)

# Update query timeout
:ok = ElixirScope.update_config([:interface, :query_timeout], 10_000)

# Attempt to update non-updatable path (will fail)
{:error, :not_updatable} = ElixirScope.update_config([:ai, :provider], :openai)
```

#### Configuration Structure

```elixir
%ElixirScope.Config{
  ai: %{
    provider: :mock | :gemini | :vertex,
    api_key: String.t() | nil,
    model: String.t(),
    analysis: %{
      max_file_size: pos_integer(),
      timeout: pos_integer(),
      cache_ttl: pos_integer()
    },
    planning: %{
      default_strategy: :minimal | :balanced | :full_trace,
      performance_target: float(),
      sampling_rate: float()
    }
  },
  capture: %{
    ring_buffer: %{
      size: pos_integer(),
      max_events: pos_integer(),
      overflow_strategy: :drop_oldest | :drop_newest | :block,
      num_buffers: pos_integer() | :schedulers
    },
    processing: %{
      batch_size: pos_integer(),
      flush_interval: pos_integer(),
      max_queue_size: pos_integer()
    }
  },
  storage: %{
    hot: %{
      max_events: pos_integer(),
      max_age_seconds: pos_integer(),
      prune_interval: pos_integer()
    },
    warm: %{
      enable: boolean(),
      path: String.t(),
      max_size_mb: pos_integer(),
      compression: :zstd | :gzip | :none
    }
  },
  interface: %{
    iex_helpers: boolean(),
    query_timeout: pos_integer(),
    web: %{
      enable: boolean(),
      port: pos_integer()
    }
  }
}
```

---

## Event Querying

### ElixirScope.get_events/1

Primary interface for querying captured events.

```elixir
@spec get_events(keyword()) :: [ElixirScope.Events.t()] | {:error, term()}
def get_events(query \\ [])
```

**Query Options:**
- `:pid` - Filter by process ID (`:all` for all processes)
- `:event_type` - Filter by event type (`:all` for all types)
- `:since` - Events since timestamp or DateTime
- `:until` - Events until timestamp or DateTime
- `:limit` - Maximum number of events to return

**Examples:**

```elixir
# Get last 100 events for current process
events = ElixirScope.get_events(pid: self(), limit: 100)

# Get all function entry events
events = ElixirScope.get_events(event_type: :function_entry)

# Get events from the last minute
since = DateTime.utc_now() |> DateTime.add(-60, :second)
events = ElixirScope.get_events(since: since)

# Get events in a specific time range
start_time = DateTime.utc_now() |> DateTime.add(-300, :second)
end_time = DateTime.utc_now()
events = ElixirScope.get_events(since: start_time, until: end_time, limit: 1000)

# Get all events for a specific process
events = ElixirScope.get_events(pid: worker_pid, limit: 500)
```

### State History Queries

```elixir
@spec get_state_history(pid()) :: [ElixirScope.Events.StateChange.t()] | {:error, term()}
def get_state_history(pid)
```

Gets the complete state change history for a GenServer process.

**Example:**

```elixir
# Get state history for a GenServer
{:ok, worker} = MyApp.Worker.start_link()
history = ElixirScope.get_state_history(worker)

# Each entry shows state transitions
[
  %ElixirScope.Events.StateChange{
    timestamp: 1640995200000000000,
    old_state: %{count: 0},
    new_state: %{count: 1},
    reason: {:handle_cast, :increment}
  },
  # ... more state changes
]
```

---

```elixir
@spec get_state_at(pid(), integer()) :: term() | {:error, term()}
def get_state_at(pid, timestamp)
```

Reconstructs the state of a GenServer at a specific timestamp (time-travel debugging).

**Example:**

```elixir
# Get state at a specific point in time
timestamp = System.monotonic_time(:nanosecond) - 60_000_000_000  # 60 seconds ago
state = ElixirScope.get_state_at(worker_pid, timestamp)
# => %{count: 42, status: :active}
```

### Message Flow Analysis

```elixir
@spec get_message_flow(pid(), pid(), keyword()) :: [ElixirScope.Events.MessageSend.t()] | {:error, term()}
def get_message_flow(sender_pid, receiver_pid, opts \\ [])
```

Gets message flow between two processes.

**Options:**
- `:since` - Start timestamp
- `:until` - End timestamp
- `:limit` - Maximum messages to return

**Examples:**

```elixir
# Get all messages between two processes
messages = ElixirScope.get_message_flow(sender_pid, receiver_pid)

# Get messages in a time range
start_time = DateTime.utc_now() |> DateTime.add(-300, :second)
end_time = DateTime.utc_now()
messages = ElixirScope.get_message_flow(
  sender_pid, 
  receiver_pid, 
  since: start_time, 
  until: end_time
)

# Analyze message patterns
messages
|> Enum.group_by(& &1.message_type)
|> Enum.map(fn {type, msgs} -> {type, length(msgs)} end)
# => [call: 45, cast: 23, info: 12]
```

---

## Cinema Debugger

The Cinema Debugger provides time-travel debugging capabilities with AST correlation.

### TemporalStorage

High-performance temporal event storage with AST correlation.

```elixir
# Start temporal storage
{:ok, storage} = ElixirScope.Capture.TemporalStorage.start_link()

# Store events with temporal indexing
event = %{
  timestamp: System.monotonic_time(:nanosecond),
  ast_node_id: "MyModule:my_function:42:function_def",
  correlation_id: "corr_123",
  data: %{type: :function_entry, args: [1, 2, 3]}
}
:ok = ElixirScope.Capture.TemporalStorage.store_event(storage, event)

# Query events by time range
{:ok, events} = ElixirScope.Capture.TemporalStorage.get_events_in_range(
  storage, 
  start_time, 
  end_time
)

# Query events for specific AST node
{:ok, node_events} = ElixirScope.Capture.TemporalStorage.get_events_for_ast_node(
  storage, 
  "MyModule:my_function:42:function_def"
)
```

### TemporalBridge

Bridges runtime events with temporal storage for Cinema Debugger functionality.

```elixir
# Start temporal bridge
{:ok, bridge} = ElixirScope.Capture.TemporalBridge.start_link(
  name: :my_bridge,
  buffer_size: 1000,
  flush_interval: 100
)

# Register as event handler
:ok = ElixirScope.Capture.TemporalBridge.register_as_handler(bridge)

# Query current execution state
{:ok, state} = ElixirScope.Capture.TemporalBridge.query_current_state(bridge)

# Reconstruct state at specific time
{:ok, historical_state} = ElixirScope.Capture.TemporalBridge.reconstruct_state_at(
  bridge, 
  timestamp
)

# Time-travel debugging: replay events
{:ok, replay_state} = ElixirScope.Capture.TemporalBridge.replay_events_for_state(
  bridge,
  start_time,
  end_time
)
```

### Cinema Demo Usage

```elixir
# Run comprehensive demo scenarios
result = CinemaDemo.run_full_demo()

# Individual demo scenarios
task_result = CinemaDemo.run_task_management_demo()
data_result = CinemaDemo.run_data_processing_demo()
nested_result = CinemaDemo.run_complex_nested_operations_demo()
error_result = CinemaDemo.run_error_handling_demo()
perf_result = CinemaDemo.run_performance_analysis_demo()
time_travel_result = CinemaDemo.run_time_travel_debugging_demo()

# Each result contains:
%{
  demo_type: :task_management,
  execution_time_ms: 1250,
  events_captured: 45,
  tasks_processed: 4,
  success_rate: 1.0,
  statistics: %{...}
}
```

---

## Phoenix Integration

ElixirScope provides specialized Phoenix integration for web applications.

### Setup

```elixir
# In your Phoenix application
defmodule MyAppWeb.Application do
  def start(_type, _args) do
    children = [
      MyAppWeb.Endpoint,
      # Add ElixirScope
      {ElixirScope, [
        capture: [buffer_size: 20_000],
        ai: [provider: :gemini]
      ]}
    ]
    
    opts = [strategy: :one_for_one, name: MyAppWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### Enable Phoenix Instrumentation

```elixir
# Enable Phoenix-specific tracing
ElixirScope.Phoenix.Integration.enable()

# Disable when not needed
ElixirScope.Phoenix.Integration.disable()
```

### Instrumented Components

**HTTP Requests:**
- Request start/stop with timing
- Controller action entry/exit
- Route dispatch timing
- Response size and status codes

**LiveView:**
- Mount lifecycle
- Event handling (`handle_event`, `handle_info`)
- State changes and assigns tracking
- Render performance

**Channels:**
- Channel join/leave events
- Message handling
- Real-time communication patterns

**Ecto Queries:**
- Query execution timing
- Parameter binding
- Result set analysis
- Database correlation

### Phoenix Query Examples

```elixir
# Get all HTTP requests in the last hour
requests = ElixirScope.get_events(
  event_type: :phoenix_request_start,
  since: DateTime.utc_now() |> DateTime.add(-3600, :second)
)

# Analyze controller performance
controller_events = ElixirScope.get_events(event_type: :phoenix_controller_entry)
|> Enum.group_by(fn event -> 
  {event.data.controller, event.data.action} 
end)
|> Enum.map(fn {{controller, action}, events} ->
  avg_duration = events 
    |> Enum.map(& &1.data.duration_ms) 
    |> Enum.sum() 
    |> div(length(events))
  
  {controller, action, avg_duration, length(events)}
end)

# LiveView event analysis
liveview_events = ElixirScope.get_events(event_type: :liveview_handle_event)
|> Enum.group_by(& &1.data.event)
|> Enum.map(fn {event_name, events} -> 
  {event_name, length(events)} 
end)
```

---

## AST Repository

The AST Repository provides static analysis integration with runtime correlation.

### Repository Management

```elixir
# Start AST repository
{:ok, repo} = ElixirScope.ASTRepository.Repository.start_link()

# Store module data
module_data = ElixirScope.ASTRepository.ModuleData.new(MyModule, ast)
:ok = ElixirScope.ASTRepository.Repository.store_module(repo, module_data)

# Get module information
{:ok, module_data} = ElixirScope.ASTRepository.Repository.get_module(repo, MyModule)

# Store function data
function_data = ElixirScope.ASTRepository.FunctionData.new(
  {MyModule, :my_function, 2}, 
  function_ast
)
:ok = ElixirScope.ASTRepository.Repository.store_function(repo, function_data)

# Get repository statistics
{:ok, stats} = ElixirScope.ASTRepository.Repository.get_statistics(repo)
```

### Runtime Correlation

```elixir
# Start runtime correlator
{:ok, correlator} = ElixirScope.ASTRepository.RuntimeCorrelator.start_link(
  repository_pid: repo
)

# Correlate runtime event with AST
runtime_event = %{
  correlation_id: "corr_123",
  module: MyModule,
  function: :my_function,
  timestamp: System.monotonic_time(:nanosecond)
}

{:ok, {correlation_id, ast_node_id}} = 
  ElixirScope.ASTRepository.RuntimeCorrelator.correlate_event(correlator, runtime_event)

# Get events for specific AST node
{:ok, events} = ElixirScope.ASTRepository.RuntimeCorrelator.get_events_for_ast_node(
  correlator, 
  ast_node_id
)

# Query temporal events
{:ok, temporal_events} = ElixirScope.ASTRepository.RuntimeCorrelator.query_temporal_events(
  correlator,
  start_time,
  end_time
)

# Get correlation statistics
{:ok, stats} = ElixirScope.ASTRepository.RuntimeCorrelator.get_statistics(correlator)
```

### AST Analysis

```elixir
# Parse module AST with instrumentation points
{:ok, {ast, instrumentation_points}} = 
  ElixirScope.ASTRepository.Parser.parse_module_with_instrumentation(MyModule)

# Get instrumentation recommendations
{:ok, recommendations} = ElixirScope.Core.AIManager.recommend_instrumentation([MyModule])

# Analyze codebase
{:ok, analysis} = ElixirScope.analyze_codebase(modules: [MyModule, OtherModule])
```

---

## Performance Monitoring

### System Metrics

```elixir
# Get performance statistics
stats = ElixirScope.status()

# Memory usage breakdown
memory_stats = %{
  total_usage_mb: 48.2,
  repository_mb: 32.1,
  correlation_cache_mb: 8.4,
  event_buffer_mb: 7.7
}

# Throughput metrics
throughput_stats = %{
  events_per_second: 12_500,
  correlations_per_second: 11_200,
  queries_per_second: 450
}

# Correlation accuracy
correlation_stats = %{
  total_events: 125_000,
  successful_correlations: 121_875,
  accuracy: 0.975,
  avg_latency_ms: 1.8,
  p95_latency_ms: 4.1,
  p99_latency_ms: 8.7
}
```

### Health Monitoring

```elixir
# System health check
health = ElixirScope.status()
case health do
  %{running: true, stats: %{events_per_second: eps}} when eps > 1000 ->
    IO.puts("System healthy - high throughput")
  
  %{running: true, stats: %{memory_usage: mem}} when mem > 1_000_000_000 ->
    IO.puts("Warning - high memory usage")
  
  %{running: false} ->
    IO.puts("ElixirScope not running")
end

# Component health
{:ok, repo_health} = ElixirScope.ASTRepository.Repository.health_check(repo)
{:ok, correlator_health} = ElixirScope.ASTRepository.RuntimeCorrelator.health_check(correlator)
```

### Performance Tuning

```elixir
# Adjust sampling rate for performance
ElixirScope.update_config([:ai, :planning, :sampling_rate], 0.1)  # 10% sampling

# Increase buffer size for high-throughput applications
ElixirScope.update_config([:capture, :processing, :batch_size], 2000)

# Adjust flush interval for latency vs throughput trade-off
ElixirScope.update_config([:capture, :processing, :flush_interval], 50)  # 50ms
```

---

## Advanced Usage

### Custom Event Types

```elixir
# Define custom event structure
defmodule MyApp.CustomEvent do
  defstruct [:custom_field, :timestamp, :metadata]
end

# Ingest custom events
custom_event = %MyApp.CustomEvent{
  custom_field: "important_data",
  timestamp: System.monotonic_time(:nanosecond),
  metadata: %{source: :my_system}
}

# Store via ring buffer
{:ok, buffer} = ElixirScope.Capture.RingBuffer.new(size: 1024)
:ok = ElixirScope.Capture.RingBuffer.write(buffer, custom_event)
```

### Distributed Tracing

```elixir
# Synchronize events across cluster nodes
cluster_nodes = [:"app@node1", :"app@node2", :"app@node3"]
{:ok, sync_results} = ElixirScope.Distributed.EventSynchronizer.sync_with_cluster(cluster_nodes)

# Force full synchronization
{:ok, full_sync_results} = ElixirScope.Distributed.EventSynchronizer.full_sync_with_cluster(cluster_nodes)

# Get distributed correlation
{:ok, distributed_events} = ElixirScope.Distributed.EventSynchronizer.get_distributed_events(
  correlation_id,
  cluster_nodes
)
```

### AI Integration

```elixir
# Configure AI provider
ElixirScope.AI.LLM.Config.get_primary_provider()
# => :gemini

# Analyze codebase with AI
{:ok, analysis} = ElixirScope.analyze_codebase()

# Get AI recommendations
{:ok, recommendations} = ElixirScope.Core.AIManager.recommend_instrumentation([MyModule])

# Update instrumentation based on AI analysis
{:ok, updated_plan} = ElixirScope.update_instrumentation(
  strategy: :balanced,
  add_modules: [NewModule]
)
```

---

## Error Handling

### Common Error Patterns

```elixir
# Handle ElixirScope not running
case ElixirScope.get_events(limit: 100) do
  {:error, :not_running} ->
    IO.puts("ElixirScope is not started")
    ElixirScope.start()
    
  events when is_list(events) ->
    IO.puts("Got #{length(events)} events")
    
  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
end

# Handle configuration errors
case ElixirScope.update_config([:ai, :planning, :sampling_rate], 1.5) do
  :ok ->
    IO.puts("Configuration updated")
    
  {:error, reason} ->
    IO.puts("Configuration error: #{inspect(reason)}")
end

# Handle correlation failures
case ElixirScope.ASTRepository.RuntimeCorrelator.correlate_event(correlator, event) do
  {:ok, {correlation_id, ast_node_id}} ->
    IO.puts("Correlated: #{correlation_id} -> #{ast_node_id}")
    
  {:error, :no_correlation_id} ->
    IO.puts("Event missing correlation ID")
    
  {:error, :not_found} ->
    IO.puts("No AST correlation found")
    
  {:error, reason} ->
    IO.puts("Correlation failed: #{inspect(reason)}")
end
```

### Error Recovery

```elixir
# Graceful degradation
defmodule MyApp.SafeTracing do
  def trace_function(module, function, args) do
    if ElixirScope.running?() do
      try do
        # Attempt to trace
        ElixirScope.Capture.InstrumentationRuntime.report_function_entry(
          module, function, args, self()
        )
      rescue
        error ->
          Logger.warning("Tracing failed: #{inspect(error)}")
          :ok  # Continue execution
      end
    else
      :ok  # No tracing when not running
    end
  end
end
```

---

## Best Practices

### Performance Optimization

1. **Sampling Strategy:**
   ```elixir
   # Production: Use minimal sampling
   ElixirScope.start(strategy: :minimal, sampling_rate: 0.1)
   
   # Development: Use balanced approach
   ElixirScope.start(strategy: :balanced, sampling_rate: 0.5)
   
   # Debugging: Use full tracing
   ElixirScope.start(strategy: :full_trace, sampling_rate: 1.0)
   ```

2. **Memory Management:**
   ```elixir
   # Configure appropriate buffer sizes
   config :elixir_scope,
     capture: [
       ring_buffer: [
         size: 2_097_152,      # 2MB for high-throughput
         max_events: 200_000   # Adjust based on memory constraints
       ]
     ]
   ```

3. **Query Optimization:**
   ```elixir
   # Use specific time ranges
   events = ElixirScope.get_events(
     since: DateTime.utc_now() |> DateTime.add(-300, :second),
     until: DateTime.utc_now(),
     limit: 1000
   )
   
   # Filter by process for focused analysis
   events = ElixirScope.get_events(pid: worker_pid, limit: 500)
   ```

### Production Deployment

1. **Configuration:**
   ```elixir
   # config/prod.exs
   config :elixir_scope,
     ai: [
       provider: :mock,  # Disable AI in production
       planning: [
         default_strategy: :minimal,
         sampling_rate: 0.05  # 5% sampling
       ]
     ],
     storage: [
       hot: [
         max_events: 50_000,
         max_age_seconds: 1800  # 30 minutes
       ]
     ]
   ```

2. **Monitoring:**
   ```elixir
   # Regular health checks
   defmodule MyApp.ElixirScopeMonitor do
     use GenServer
     
     def init(_) do
       :timer.send_interval(30_000, :health_check)
       {:ok, %{}}
     end
     
     def handle_info(:health_check, state) do
       case ElixirScope.status() do
         %{running: true, stats: %{memory_usage: mem}} when mem > 100_000_000 ->
           Logger.warning("ElixirScope high memory usage: #{mem}")
         
         %{running: false} ->
           Logger.error("ElixirScope not running")
         
         _ ->
           :ok
       end
       
       {:noreply, state}
     end
   end
   ```

### Development Workflow

1. **Testing Integration:**
   ```elixir
   # test/test_helper.exs
   ExUnit.start()
   
   # Configure for testing
   Application.put_env(:elixir_scope, :test_mode, true)
   
   # Start ElixirScope for integration tests
   if System.get_env("ELIXIR_SCOPE_TESTS") == "true" do
     ElixirScope.start(strategy: :balanced, sampling_rate: 1.0)
   end
   ```

2. **Debugging Sessions:**
   ```elixir
   # Start with full tracing
   ElixirScope.start(strategy: :full_trace)
   
   # Run problematic code
   MyApp.problematic_function()
   
   # Analyze events
   events = ElixirScope.get_events(
     since: DateTime.utc_now() |> DateTime.add(-60, :second),
     limit: 1000
   )
   
   # Focus on specific process
   process_events = ElixirScope.get_events(pid: problematic_pid)
   
   # Time-travel debugging
   historical_state = ElixirScope.get_state_at(pid, timestamp)
   ```

### Security Considerations

1. **Data Sanitization:**
   ```elixir
   # ElixirScope automatically truncates large data
   # Configure truncation limits
   config :elixir_scope,
     capture: [
       processing: [
         max_data_size: 1024,  # Truncate data larger than 1KB
         sanitize_sensitive: true
       ]
     ]
   ```

2. **Access Control:**
   ```elixir
   # Restrict ElixirScope access in production
   defmodule MyApp.ElixirScopeAuth do
     def authorized?(user) do
       user.role in [:admin, :developer] and 
       Application.get_env(:my_app, :environment) != :production
     end
   end
   ```

---

## API Reference Summary

### Core Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `ElixirScope.start/1` | Start ElixirScope with options | `:ok \| {:error, term()}` |
| `ElixirScope.stop/0` | Stop ElixirScope | `:ok` |
| `ElixirScope.status/0` | Get system status | `map()` |
| `ElixirScope.running?/0` | Check if running | `boolean()` |
| `ElixirScope.get_events/1` | Query events | `[event()] \| {:error, term()}` |
| `ElixirScope.get_config/0` | Get configuration | `Config.t() \| {:error, term()}` |
| `ElixirScope.update_config/2` | Update configuration | `:ok \| {:error, term()}` |

### Event Querying

| Function | Description | Returns |
|----------|-------------|---------|
| `get_state_history/1` | Get GenServer state history | `[StateChange.t()] \| {:error, term()}` |
| `get_state_at/2` | Get state at timestamp | `term() \| {:error, term()}` |
| `get_message_flow/3` | Get message flow between processes | `[MessageSend.t()] \| {:error, term()}` |

### Configuration

| Function | Description | Returns |
|----------|-------------|---------|
| `Config.get/0` | Get full configuration | `Config.t()` |
| `Config.get/1` | Get configuration by path | `term()` |
| `Config.update/2` | Update configuration path | `:ok \| {:error, term()}` |
| `Config.validate/1` | Validate configuration | `:ok \| {:error, term()}` |

### Phoenix Integration

| Function | Description | Returns |
|----------|-------------|---------|
| `Phoenix.Integration.enable/0` | Enable Phoenix tracing | `:ok` |
| `Phoenix.Integration.disable/0` | Disable Phoenix tracing | `:ok` |

---

**For more detailed examples and advanced usage patterns, see the [Cinema Demo Application](test_apps/cinema_demo/) and [Integration Tests](test/elixir_scope/capture/instrumentation_runtime_temporal_integration_test.exs).**

**Support**: For issues and questions, please refer to the project repository and documentation. 