# ElixirScope Test Applications

This directory contains demonstration applications that showcase ElixirScope's capabilities in real-world scenarios.

## 📁 Directory Structure

```
test_apps/
├── cinema_demo/          # Cinema Debugger demonstration app
│   ├── lib/
│   │   ├── cinema_demo.ex              # Main demo orchestration
│   │   ├── cinema_demo/
│   │   │   ├── application.ex          # Application supervisor
│   │   │   ├── task_manager.ex         # GenServer state management demo
│   │   │   └── data_processor.ex       # Data transformation pipeline demo
│   │   └── ...
│   ├── mix.exs                         # ElixirScope integration config
│   ├── README.md                       # Detailed usage guide
│   └── ...
└── README.md                           # This file
```

## 🎯 Purpose

These test applications serve multiple purposes:

1. **Demonstration** - Show ElixirScope's capabilities to users
2. **Testing** - Validate ElixirScope functionality in realistic scenarios
3. **Documentation** - Provide working examples of ElixirScope integration
4. **Development** - Test new features during ElixirScope development

## 🚀 Quick Start

### Cinema Demo

The Cinema Demo showcases ElixirScope's temporal debugging capabilities:

```bash
cd cinema_demo
mix deps.get
mix compile

# Run individual demos
mix run -e "CinemaDemo.run_task_management_demo()"
mix run -e "CinemaDemo.run_data_processing_demo()"
mix run -e "CinemaDemo.run_timetravel_demo()"

# Run full demonstration suite
mix run -e "CinemaDemo.run_full_demo()"
```

### Interactive Mode

For the best experience, use IEx for interactive exploration:

```bash
cd cinema_demo
iex -S mix

# In IEx:
iex> CinemaDemo.run_full_demo()
iex> bridge = :cinema_demo_bridge
iex> {:ok, state} = ElixirScope.Capture.TemporalBridge.reconstruct_state_at(bridge, System.monotonic_time(:nanosecond))
iex> IO.inspect(state, label: "Current State")
```

## 🎬 Demo Scenarios

### 1. Cinema Demo (`cinema_demo/`)

**Features Demonstrated:**
- Real-time execution tracking
- Time-travel debugging
- Function call correlation
- Variable state inspection
- Performance analysis
- Complex GenServer state management
- Data transformation pipelines
- Error handling patterns

**Key Components:**
- `TaskManager` - Demonstrates complex state transitions and task lifecycle management
- `DataProcessor` - Shows data transformation pipelines with type-specific processing
- `CinemaDemo` - Orchestrates comprehensive demonstrations of all features

**Demo Types:**
1. **Task Management** - GenServer state tracking, priority queues, retry logic
2. **Data Processing** - Transformation pipelines, batch processing, caching
3. **Nested Operations** - Deep call stacks, recursive functions, pipeline stages
4. **Error Handling** - Exception patterns, recovery mechanisms, error propagation
5. **Performance Analysis** - Timing measurements, memory tracking, bottleneck identification
6. **Time-Travel Debugging** - Historical state queries, temporal correlation

## 🔧 Integration Guide

### Adding ElixirScope to Your Application

Based on the cinema_demo example, here's how to integrate ElixirScope:

#### 1. Update `mix.exs`

```elixir
def project do
  [
    # ... existing config ...
    compilers: [:elixir_scope] ++ Mix.compilers(),
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
        buffer_size: 10_000
      ]
    ]
  ]
end

defp deps do
  [
    {:elixir_scope, path: "path/to/elixir_scope"},
    # ... other deps ...
  ]
end
```

#### 2. Update Application Supervisor

```elixir
def start(_type, _args) do
  children = [
    # Start ElixirScope services
    {ElixirScope.Capture.TemporalStorage, []},
    {ElixirScope.Capture.TemporalBridge, [name: :my_app_bridge]},
    
    # Your application processes
    MyApp.SomeGenServer,
    # ...
  ]
  
  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  
  case Supervisor.start_link(children, opts) do
    {:ok, pid} ->
      # Register the TemporalBridge for automatic event forwarding
      ElixirScope.Capture.TemporalBridge.register_as_handler(:my_app_bridge)
      {:ok, pid}
    error ->
      error
  end
end
```

#### 3. Query Execution State

```elixir
# Get current state
bridge = :my_app_bridge
{:ok, current_state} = ElixirScope.Capture.TemporalBridge.reconstruct_state_at(
  bridge, 
  System.monotonic_time(:nanosecond)
)

# Time-travel debugging
past_time = System.monotonic_time(:nanosecond) - 1_000_000_000  # 1 second ago
{:ok, past_state} = ElixirScope.Capture.TemporalBridge.reconstruct_state_at(bridge, past_time)

# Compare states
IO.inspect(Map.keys(current_state) -- Map.keys(past_state), label: "New state keys")
```

## 📊 Performance Characteristics

Based on cinema_demo testing:

- **Instrumentation Overhead**: ~100μs per function call
- **Memory Usage**: ~1KB per event stored
- **Buffer Management**: Automatic cleanup of old events
- **Async Processing**: Minimal impact on application performance

## 🧪 Testing

Each test application includes comprehensive tests:

```bash
# Run all tests
mix test

# Run specific test categories
mix test --only temporal
mix test --only performance
mix test --only integration
```

## 🔍 Debugging Tips

### Common Issues

1. **Events not appearing in queries**
   ```elixir
   # Ensure buffer is flushed
   :ok = ElixirScope.Capture.TemporalBridge.flush_buffer(:your_bridge_name)
   ```

2. **Time-travel queries returning empty results**
   ```elixir
   # Use minimum timestamp for full history
   start_time = -9_223_372_036_854_775_808
   {:ok, state} = TemporalBridge.reconstruct_state_at(bridge, start_time)
   ```

3. **Compilation issues**
   ```bash
   # Ensure ElixirScope is compiled first
   cd path/to/elixir_scope
   mix compile
   cd path/to/your/app
   mix deps.compile --force
   ```

### Debug Mode

Enable detailed logging:

```elixir
Logger.configure(level: :debug)
```

## 🚀 Future Test Applications

Planned additions:

- **Phoenix Web Demo** - Web application with HTTP request tracking
- **LiveView Demo** - Real-time UI with state synchronization
- **OTP Supervision Demo** - Process supervision tree visualization
- **Distributed Demo** - Multi-node temporal correlation
- **Performance Benchmark** - Comprehensive performance analysis suite

## 🤝 Contributing

To add new test applications:

1. Create a new directory under `test_apps/`
2. Follow the cinema_demo structure and patterns
3. Include comprehensive README and tests
4. Add integration with ElixirScope services
5. Document the specific features being demonstrated

## 📄 License

These test applications are part of the ElixirScope project and follow the same license terms. 