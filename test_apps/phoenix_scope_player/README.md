# PhoenixScopePlayer - Debug Session Playback System

## Project Overview
This is a Phoenix LiveView application designed to replay and visualize debug sessions captured by ElixirScope. The application provides an interactive interface for stepping through function calls, examining arguments, return values, and the overall execution flow of Elixir programs.

## ElixirScope Integration

### Setup and Configuration

1. **ElixirScope Dependencies**
```elixir
# mix.exs
defp deps do
  [
    {:elixir_scope, "~> 0.0.1"},
    # ... other deps
  ]
end
```

2. **Configuration**
```elixir
# config/config.exs
config :elixir_scope,
  output_dir: Path.join([:code.priv_dir(:phoenix_scope_player), "captured_data"]),
  capture_source: true,
  capture_variables: true,
  capture_return_values: true
```

### Sample Application Integration

1. **Calculator Module** (`lib/phoenix_scope_player/calculator.ex`)
```elixir
defmodule PhoenixScopePlayer.Calculator do
  use ElixirScope  # Enables function tracing

  @trace true  # Trace this function
  def factorial(0), do: 1
  def factorial(n) when is_integer(n) and n > 0 do
    n * factorial(n - 1)
  end

  @trace true
  def sum_factorial_sequence(n) when is_integer(n) and n > 0 do
    1..n
    |> Enum.reduce(0, fn i, acc ->
      acc + factorial(i)
    end)
  end
end
```

### ElixirScope Commands and Usage

1. **Starting a Debug Session**
```bash
# Start IEx with ElixirScope
iex -S mix

# In IEx
iex> ElixirScope.start_session("factorial_test")
{:ok, "factorial_1748576175"}

# Run traced functions
iex> PhoenixScopePlayer.Calculator.factorial(5)
120

# End session
iex> ElixirScope.end_session()
:ok
```

2. **Session Management Commands**
```elixir
# List active sessions
ElixirScope.list_sessions()

# Get current session info
ElixirScope.current_session()

# Pause/Resume tracing
ElixirScope.pause_tracing()
ElixirScope.resume_tracing()

# Clear all sessions
ElixirScope.clear_sessions()
```

3. **Trace Configuration**
```elixir
# Configure tracing options at runtime
ElixirScope.configure(
  capture_variables: true,
  capture_source: true,
  max_events: 1000
)

# Add trace to module at runtime
ElixirScope.trace_module(PhoenixScopePlayer.Calculator)

# Remove trace
ElixirScope.untrace_module(PhoenixScopePlayer.Calculator)
```

### Generated Session Files

1. **Events File** (`events.json`)
```json
{
  "events": [
    {
      "type": "call",
      "module": "PhoenixScopePlayer.Calculator",
      "function": "factorial",
      "args": ["5"],
      "pid": "#PID<0.95.0>",
      "timestamp": 1748000576175451
    },
    // ... more events
  ]
}
```

2. **Metadata File** (`metadata.json`)
```json
{
  "name": "Factorial Test",
  "timestamp": "2025-05-30T03:36:15.453883Z",
  "description": "Testing factorial calculations",
  "session_id": "factorial_1748576175",
  "event_count": 64
}
```

3. **Source Code File** (`source_code.json`)
```json
{
  "files": {
    "Elixir.PhoenixScopePlayer.Calculator": {
      "content": "defmodule PhoenixScopePlayer.Calculator do\n...",
      "type": "elixir"
    }
  }
}
```

### Sample Debug Sessions

1. **Factorial Calculation**
```elixir
# Generate factorial debug session
iex> ElixirScope.start_session("factorial_test")
iex> PhoenixScopePlayer.Calculator.factorial(5)
iex> ElixirScope.end_session()
```

2. **Sum Factorial Sequence**
```elixir
# Generate sum factorial sequence debug session
iex> ElixirScope.start_session("sum_factorial_test")
iex> PhoenixScopePlayer.Calculator.sum_factorial_sequence(5)
iex> ElixirScope.end_session()
```

### Session Playback Features

1. **Event Navigation**
- Next/Previous event navigation
- Jump to specific event
- Filter events by type (call/return)
- Filter events by function name

2. **Data Display**
- Function call arguments
- Return values
- Process IDs
- Timestamps
- Call stack visualization

3. **Source Code Integration**
- View source code at each event
- Highlight current line
- Show variable values

### Debugging Tools

1. **Session Analysis**
```elixir
# Analyze session performance
ElixirScope.analyze_session("factorial_1748576175")

# Get session statistics
ElixirScope.session_stats("factorial_1748576175")

# Export session data
ElixirScope.export_session("factorial_1748576175", format: :json)
```

2. **Event Filtering**
```elixir
# Configure event filters
ElixirScope.configure(
  filter_modules: [PhoenixScopePlayer.Calculator],
  filter_functions: [:factorial],
  min_duration: 100  # microseconds
)
```

### Complete ElixirScope Command Reference

1. **Session Generation Commands**
```elixir
# Generate factorial session
iex> ElixirScope.start_session("factorial_test", description: "Testing factorial function")
{:ok, "factorial_1748576175"}
iex> PhoenixScopePlayer.Calculator.factorial(5)
120
iex> ElixirScope.end_session()

# Generate fibonacci session
iex> ElixirScope.start_session("fibonacci_test", description: "Testing fibonacci function")
{:ok, "fibonacci_1748576175"}
iex> PhoenixScopePlayer.Calculator.fibonacci(10)
55
iex> ElixirScope.end_session()

# Generate sum factorial sequence session
iex> ElixirScope.start_session("sum_factorial_test", description: "Testing sum of factorials")
{:ok, "sum_factorial_1748576175"}
iex> PhoenixScopePlayer.Calculator.sum_factorial_sequence(5)
153
iex> ElixirScope.end_session()
```

2. **Session Management**
```elixir
# List all available sessions
iex> ElixirScope.list_sessions()
[
  %{
    id: "factorial_1748576175",
    name: "Factorial Test",
    timestamp: "2025-05-30T03:36:15.453883Z",
    event_count: 64
  },
  # ... more sessions
]

# Get specific session details
iex> ElixirScope.get_session("factorial_1748576175")
{:ok, %{
  metadata: %{...},
  events: [...],
  source_code: %{...}
}}

# Delete specific session
iex> ElixirScope.delete_session("factorial_1748576175")

# Clean all sessions
iex> ElixirScope.clean_sessions()
```

3. **Runtime Tracing Configuration**
```elixir
# Configure specific function tracing
iex> ElixirScope.trace_function(PhoenixScopePlayer.Calculator, :factorial, 1)
iex> ElixirScope.trace_function(PhoenixScopePlayer.Calculator, :sum_factorial_sequence, 1)

# Configure module-level tracing
iex> ElixirScope.trace_module(PhoenixScopePlayer.Calculator, 
  except: [:handle_info, :terminate]
)

# Configure capture options
iex> ElixirScope.configure(
  capture_args: true,
  capture_return: true,
  capture_variables: true,
  capture_source: true,
  max_event_count: 1000,
  max_arg_length: 1000,
  include_modules: [PhoenixScopePlayer.Calculator],
  exclude_modules: [],
  output_dir: "priv/captured_data"
)
```

4. **Debug Session Analysis**
```elixir
# Analyze function call patterns
iex> ElixirScope.analyze_calls("factorial_1748576175")
%{
  total_calls: 64,
  unique_functions: 2,
  max_stack_depth: 6,
  execution_time: 1234
}

# Get execution timeline
iex> ElixirScope.get_timeline("factorial_1748576175")
[
  %{event: "call", function: "factorial", timestamp: 1748000576175451},
  # ... more events
]

# Get function statistics
iex> ElixirScope.get_function_stats("factorial_1748576175")
%{
  "factorial/1" => %{
    calls: 32,
    avg_time: 123,
    max_time: 456
  },
  # ... more functions
}
```

5. **Data Export and Import**
```elixir
# Export session data
iex> ElixirScope.export_session("factorial_1748576175", 
  format: :json,
  path: "exports/factorial_analysis.json"
)

# Import external session
iex> ElixirScope.import_session("path/to/session.json")

# Export multiple sessions
iex> ElixirScope.export_sessions(["factorial_1748576175", "fibonacci_1748576175"],
  format: :json,
  path: "exports/"
)
```

6. **Real-time Monitoring**
```elixir
# Start live monitoring
iex> ElixirScope.start_monitoring(
  modules: [PhoenixScopePlayer.Calculator],
  callback: &IO.inspect/1
)

# Configure monitoring filters
iex> ElixirScope.configure_monitoring(
  min_duration: 100,  # microseconds
  max_events: 1000,
  include_types: [:call, :return]
)

# Stop monitoring
iex> ElixirScope.stop_monitoring()
```

7. **Source Code Integration**
```elixir
# Get source code for specific event
iex> ElixirScope.get_source_at_event("factorial_1748576175", 1)
{:ok, %{
  file: "lib/calculator.ex",
  line: 5,
  content: "def factorial(n) when is_integer(n) and n > 0 do"
}}

# Get variable values at event
iex> ElixirScope.get_variables_at_event("factorial_1748576175", 1)
{:ok, %{
  "n" => 5,
  "result" => nil
}}
```

8. **Session Playback Control**
```elixir
# Start interactive playback
iex> ElixirScope.start_playback("factorial_1748576175")

# Navigate events
iex> ElixirScope.next_event()
iex> ElixirScope.previous_event()
iex> ElixirScope.goto_event(10)

# Get current event details
iex> ElixirScope.current_event()
%{
  type: "call",
  function: "factorial",
  args: [5],
  line: 5
}
```

9. **Error Handling and Recovery**
```elixir
# Handle corrupted session
iex> ElixirScope.repair_session("factorial_1748576175")

# Validate session data
iex> ElixirScope.validate_session("factorial_1748576175")
{:ok, [:events_valid, :metadata_valid, :source_valid]}

# Backup session data
iex> ElixirScope.backup_session("factorial_1748576175")
{:ok, "backup_factorial_1748576175_20250530"}
```

10. **Mix Tasks**
```bash
# Clean all sessions
mix elixir_scope.clean

# Generate test sessions
mix elixir_scope.generate_test_sessions

# Analyze all sessions
mix elixir_scope.analyze_all

# Export all sessions
mix elixir_scope.export_all
```

## Current Implementation Status

### Core Components

1. **DataProvider Module** (`lib/phoenix_scope_player/data_provider.ex`)
   - Handles reading and transforming debug session data
   - Session data location: `priv/captured_data/<session_id>/`
   - Files per session:
     - `events.json`: Contains function calls, returns, args, etc.
     - `metadata.json`: Session info, timestamps, description
     - `source_code.json`: Original source code files

2. **PlaybackLive Module** (`lib/phoenix_scope_player_web/live/playback_live.ex`)
   - Manages the LiveView session playback interface
   - Handles event navigation (next/previous)
   - Current event tracking and display

### Data Structures

1. **Event Format**:
```elixir
%{
  "type" => "call" | "return",
  "module" => "ModuleName",
  "function" => "function_name",
  "args" => ["arg1", "arg2"],  # Present for "call" events
  "return_value" => "value",   # Present for "return" events
  "pid" => "#PID<x.y.z>",
  "timestamp" => timestamp_ns,
  "variables" => nil | map(),
  "call_stack" => []
}
```

2. **Session Metadata**:
```elixir
%{
  "name" => "Session Name",
  "timestamp" => "ISO8601 timestamp",
  "description" => "Session description",
  "event_count" => integer(),
  "session_id" => "unique_session_id"
}
```

### Current Working Features
1. Session listing and selection
2. Basic event navigation
3. Function call and return visualization
4. PID tracking
5. Argument and return value display

### Known Implementation Details
1. Events are stored chronologically in `events.json`
2. All timestamps are in nanoseconds since UNIX epoch
3. PIDs are preserved from the original execution
4. Source code files are stored with module names as keys

## Development Guidelines

### Testing
- Use `mix test.trace` for non-LLM tests
- Use `mix test.live` for LLM integration tests
- Use `mix test.all` for complete test suite

### Code Organization
1. Core Logic:
   - `lib/phoenix_scope_player/` - Business logic
   - `lib/phoenix_scope_player_web/` - Web interface

2. Data Storage:
   - `priv/captured_data/` - Debug sessions
   - Each session in its own directory named by timestamp

### Current Focus Areas
1. Event data transformation and display
2. Session navigation and playback controls
3. Source code integration with events

### Recent Changes
1. Fixed event data structure handling in DataProvider
2. Improved argument and return value formatting
3. Corrected JSON parsing for events

## Implementation Notes

### Event Processing
- Events are captured in real-time during function execution
- Each function call generates at least two events (call and return)
- Recursive calls maintain proper nesting in the event stream
- Timestamps are captured with nanosecond precision
- Variable state is captured at each event point when configured

### Session File Structure
```
priv/captured_data/
├── factorial_1748576175/
│   ├── events.json
│   ├── metadata.json
│   └── source_code.json
└── fibonacci_1748576175/
    ├── events.json
    ├── metadata.json
    └── source_code.json
```

### Data Flow
1. Session Selection → `DataProvider.get_session_data/1`
2. Event Loading → Transform to display format
3. LiveView Updates → Event navigation

### Error Handling
- JSON parsing errors are logged and return {:error, :not_found}
- Missing files are handled gracefully
- Invalid session IDs return appropriate errors

## Development Environment
- Elixir 1.18.3
- Phoenix 1.7.21
- Phoenix.LiveView 1.0.13
- Running on port 4000

## Current Challenges
1. Maintaining event order during playback
2. Efficient source code file handling
3. Complex recursive call visualization

## Next Steps
1. Enhance event visualization
2. Improve source code integration
3. Add more detailed call stack display
4. Implement variable state tracking

## Important Paths
- Main entry: `lib/phoenix_scope_player/application.ex`
- Data handling: `lib/phoenix_scope_player/data_provider.ex`
- LiveView: `lib/phoenix_scope_player_web/live/playback_live.ex`
- Templates: `lib/phoenix_scope_player_web/live/playback_live.html.heex`

## Warning
This README is specifically for LLM consumption and contains implementation details that may not be relevant for end users. For user documentation, refer to the user guide.
