# CinemaDemo - ElixirScope Cinema Debugger Demonstration

A comprehensive demonstration application showcasing ElixirScope's Cinema Debugger capabilities for real-time execution tracking and time-travel debugging.

## 🎯 Purpose

CinemaDemo demonstrates the full power of ElixirScope's temporal debugging system:

- **Real-time execution tracking** - Watch function calls and variable changes as they happen
- **Time-travel debugging** - Query execution state at any point in the past
- **AST correlation** - See how runtime events map to source code locations
- **Performance analysis** - Measure execution time and memory usage with temporal context
- **Complex flow visualization** - Track nested function calls and state transitions

## 🏗️ Architecture

```
CinemaDemo Application
├── TaskManager (GenServer)     - Complex state management demo
├── DataProcessor (GenServer)   - Data transformation pipeline demo
└── CinemaDemo (Main Module)    - Interactive demo orchestration

ElixirScope Integration
├── TemporalStorage            - Event persistence
├── TemporalBridge             - Event correlation and querying
└── InstrumentationRuntime     - Automatic event capture
```

## 🚀 Quick Start

### 1. Install Dependencies

```bash
cd test_apps/cinema_demo
mix deps.get
```

### 2. Start the Application

```bash
# Start IEx with the application
iex -S mix

# Or compile and run
mix compile
```

### 3. Run the Full Demo

```elixir
# Run all demonstrations
CinemaDemo.run_full_demo()
```

## 🎬 Demo Scenarios

### 1. Task Management Flow
```elixir
CinemaDemo.run_task_management_demo()
```

Demonstrates:
- GenServer state transitions
- Task lifecycle management
- Priority-based processing
- Error handling and retries

### 2. Data Processing Pipeline
```elixir
CinemaDemo.run_data_processing_demo()
```

Demonstrates:
- Complex data transformations
- Type-specific processing pipelines
- Batch vs individual processing
- Performance optimization patterns

### 3. Complex Nested Operations
```elixir
CinemaDemo.run_nested_operations_demo()
```

Demonstrates:
- Deep function call stacks
- Recursive operations (Fibonacci)
- Multi-step processing pipelines
- Variable state tracking through transformations

### 4. Error Handling and Recovery
```elixir
CinemaDemo.run_error_handling_demo()
```

Demonstrates:
- Exception handling patterns
- Graceful error recovery
- Error propagation through call stacks
- Debugging failed operations

### 5. Performance Analysis
```elixir
CinemaDemo.run_performance_demo()
```

Demonstrates:
- Execution time measurement
- Memory usage tracking
- Performance comparison across operations
- Bottleneck identification

### 6. Time-Travel Debugging
```elixir
CinemaDemo.run_timetravel_demo()
```

Demonstrates:
- Querying past execution states
- State reconstruction at specific timestamps
- Temporal correlation of events
- Historical debugging capabilities

## 🔍 Cinema Debugger Usage

### Real-Time State Inspection

```elixir
# Get the temporal bridge
bridge = :cinema_demo_bridge

# Query current execution state
{:ok, current_state} = ElixirScope.Capture.TemporalBridge.reconstruct_state_at(
  bridge, 
  System.monotonic_time(:nanosecond)
)

# Inspect active functions and variables
IO.inspect(current_state, label: "Current Execution State")
```

### Time-Travel Debugging

```elixir
# Record a timestamp before some operation
start_time = System.monotonic_time(:nanosecond)

# Perform some operations...
{:ok, task_id} = CinemaDemo.TaskManager.create_task("Debug test", :high)

# Record timestamp after operation
end_time = System.monotonic_time(:nanosecond)

# Query state at the start
{:ok, start_state} = ElixirScope.Capture.TemporalBridge.reconstruct_state_at(bridge, start_time)

# Query state at the end
{:ok, end_state} = ElixirScope.Capture.TemporalBridge.reconstruct_state_at(bridge, end_time)

# Compare states
IO.puts("State difference:")
IO.inspect(Map.keys(end_state) -- Map.keys(start_state), label: "New state keys")
```

### AST Node Event Tracking

```elixir
# Get events for a specific AST node
{:ok, events} = ElixirScope.Capture.TemporalBridge.get_events_for_ast_node(
  bridge, 
  "some_ast_node_id"
)

# Analyze event timeline
events
|> Enum.sort_by(& &1.timestamp)
|> Enum.each(fn event ->
  IO.puts("#{event.timestamp}: #{event.data.event_type} - #{inspect(event.data.data)}")
end)
```

## 📊 Understanding the Output

### Demo Results Structure

Each demo returns a structured result:

```elixir
%{
  demo_type: :task_management,
  tasks_created: ["task_id_1", "task_id_2", ...],
  final_stats: %{
    tasks_created: 4,
    tasks_completed: 2,
    success_rate: 0.75,
    # ... more stats
  }
}
```

### Performance Metrics

Performance demos include detailed timing:

```elixir
%{
  execution_time_us: 1250,      # Microseconds
  memory_delta_bytes: 8192,     # Memory change
  result: :operation_result
}
```

### Temporal State Structure

Time-travel queries return execution state:

```elixir
%{
  # Active function states
  "Elixir.CinemaDemo.TaskManager.create_task" => %{
    status: :active,
    correlation_id: "correlation_123",
    started_at: 1234567890,
    variables: %{task_name: "Test Task", priority: :high}
  },
  
  # Global variable snapshots
  task_count: 5,
  processing_queue_size: 2,
  
  # Metadata
  :_metadata => %{
    query_timestamp: 1234567890,
    events_processed: 42
  }
}
```

## 🛠️ Customization

### Adding New Demo Scenarios

1. Create a new demo function in `CinemaDemo`:

```elixir
def run_custom_demo do
  Logger.info("Running custom demo...")
  
  # Your demo logic here
  result = perform_custom_operations()
  
  %{
    result: result,
    demo_type: :custom_demo
  }
end
```

2. Add it to the full demo:

```elixir
def run_full_demo do
  # ... existing demos ...
  custom_result = run_custom_demo()
  
  # Include in summary
  summary = %{
    # ... existing results ...
    custom_demo: custom_result
  }
end
```

### Configuring ElixirScope

Modify `mix.exs` to adjust ElixirScope settings:

```elixir
elixir_scope: [
  enabled: true,
  instrumentation: [
    functions: true,
    variables: true,
    expressions: true,
    temporal_correlation: true
  ],
  cinema_debugger: [
    enabled: true,
    buffer_size: 10_000,        # Increase for more history
    flush_interval_ms: 1000     # Adjust flush frequency
  ]
]
```

## 🧪 Testing

Run the test suite:

```bash
mix test
```

Test specific scenarios:

```bash
# Test task management
mix test --only task_management

# Test data processing
mix test --only data_processing

# Test temporal features
mix test --only temporal
```

## 📈 Performance Considerations

### Buffer Management

- Default buffer size: 10,000 events
- Automatic cleanup of old events
- Configurable flush intervals

### Memory Usage

- Events are stored in ETS tables
- Automatic garbage collection of old data
- Memory usage scales with buffer size

### CPU Overhead

- Instrumentation adds ~100μs per function call
- Async event processing minimizes impact
- Configurable instrumentation levels

## 🔧 Troubleshooting

### Common Issues

1. **Events not appearing in queries**
   ```elixir
   # Ensure buffer is flushed
   :ok = ElixirScope.Capture.TemporalBridge.flush_buffer(:cinema_demo_bridge)
   ```

2. **Time-travel queries returning empty results**
   ```elixir
   # Check timestamp range - use negative values for monotonic time
   start_time = -9_223_372_036_854_775_808  # Minimum timestamp
   {:ok, state} = TemporalBridge.reconstruct_state_at(bridge, start_time)
   ```

3. **Application startup issues**
   ```bash
   # Ensure ElixirScope is compiled
   cd ../..  # Back to main ElixirScope directory
   mix compile
   cd test_apps/cinema_demo
   mix deps.compile --force
   ```

### Debug Mode

Enable debug logging:

```elixir
Logger.configure(level: :debug)
```

## 📚 Further Reading

- [ElixirScope Documentation](../../README.md)
- [Cinema Debugger Guide](../../docs/cinema_debugger.md)
- [Temporal Debugging Concepts](../../docs/temporal_debugging.md)
- [Performance Optimization](../../docs/performance.md)

## 🤝 Contributing

To add new demo scenarios or improve existing ones:

1. Fork the repository
2. Create your feature branch
3. Add comprehensive tests
4. Update documentation
5. Submit a pull request

## 📄 License

This demo application is part of the ElixirScope project and follows the same license terms.

