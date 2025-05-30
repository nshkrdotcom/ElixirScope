# ElixirScope Example App Development Plan

## 📋 Checklist
- [ ] Initial Project Setup
  - [ ] Create Phoenix project structure
  - [ ] Configure dependencies (Phoenix, LiveView, Jason, Heroicons)
  - [ ] Set up development environment
  - [ ] Initialize project directory structure
  - [ ] Configure Tailwind CSS and esbuild
- [ ] Core Infrastructure
  - [ ] Implement DataProvider module
    - [ ] Session listing functionality
    - [ ] Event data loading
    - [ ] Source code management
    - [ ] AST mapping
    - [ ] Error handling for JSON parsing
  - [ ] Implement PlaybackEngine
    - [ ] Registry setup for engine management
    - [ ] State management
    - [ ] Event processing
    - [ ] Playback controls
    - [ ] Variable state tracking
    - [ ] Timer-based auto-playback
  - [ ] Set up test data structure
    - [ ] Create sample events.json
    - [ ] Create sample source_code.json
    - [ ] Create sample ast_map.json
    - [ ] Create sample metadata.json
- [ ] UI Components
  - [ ] Create base layout with Tailwind CSS
  - [ ] Implement Session Selection view
    - [ ] Session card display
    - [ ] Navigation handling
  - [ ] Implement Playback view
    - [ ] Timeline & Controls panel
    - [ ] Event Log panel
    - [ ] Code View panel with syntax highlighting
    - [ ] State Inspector panel with tabs
  - [ ] Add Timeline controls with Heroicons
  - [ ] Create Code viewer with line highlighting
  - [ ] Add State inspector with variable tracking
- [ ] Testing & Documentation
  - [ ] Write unit tests
  - [ ] Add integration tests
  - [ ] Create documentation
  - [ ] Add example sessions

## 📚 Documentation Reference Map



##  Project Overview

This plan outlines the development of a Phoenix-based UI application to demonstrate ElixirScope's debugging capabilities. The application will focus on playback of pre-recorded debugging sessions, allowing users to step through code execution, view variable states, and understand program flow.

## 📁 Project Structure

```
phoenix_scope_player/
├── assets/
│   ├── css/
│   │   └── app.scss        # Tailwind CSS imports
│   └── js/
│       └── app.js          # LiveView configuration
├── lib/
│   ├── phoenix_scope_player/
│   │   ├── application.ex              # OTP Application setup
│   │   ├── playback_engine/
│   │   │   ├── registry.ex            # Registry for PlaybackEngines
│   │   │   └── engine.ex             # Main PlaybackEngine GenServer
│   │   └── data_provider.ex           # Data loading and management
│   └── phoenix_scope_player_web/
│       ├── components/
│       │   ├── layouts/
│       │   │   └── app.html.heex      # Main layout template
│       │   ├── code_view_live.ex      # Code display component
│       │   ├── event_log_live.ex      # Event list component
│       │   └── state_inspector_live.ex # Variable/state component
│       ├── live/
│       │   ├── session_list_live.ex   # Session selection
│       │   └── playback_live.ex       # Main playback UI
│       └── router.ex                   # Phoenix router
├── priv/
│   ├── captured_data/                 # Pre-recorded session data
│   │   └── sample_session_1/
│   │       ├── events.json
│   │       ├── source_code.json
│   │       ├── metadata.json
│   │       └── ast_map.json
│   └── static/
└── mix.exs                            # Project configuration
```

## 🔧 Technical Specifications

### 1. Core Components

#### A. PlaybackEngine Registry
```elixir
# lib/phoenix_scope_player/playback_engine/registry.ex
defmodule PhoenixScopePlayer.PlaybackEngine.Registry do
  use Registry, keys: :unique, name: __MODULE__
end
```

#### B. PlaybackEngine State Structure
```elixir
state = %{
  session_id: String.t(),
  session_data: %{
    id: String.t(),
    events: list(map()),
    source_code_map: map(),
    ast_map: map()
  },
  current_event_index: non_neg_integer(),
  is_playing: boolean(),
  parent_pid: pid() | nil,
  call_stack: list(String.t()),
  variables: map()
}
```

#### C. DataProvider API
```elixir
defmodule PhoenixScopePlayer.DataProvider do
  @type session_meta :: %{
    id: String.t(),
    name: String.t(),
    description: String.t(),
    timestamp: DateTime.t(),
    event_count: integer()
  }

  @callback list_sessions() :: [session_meta()]
  @callback get_session_data(String.t()) :: {:ok, map()} | {:error, :not_found}
  @callback get_session_source_code(String.t()) :: {:ok, map()} | {:error, :not_found}
  @callback get_session_ast_map(String.t()) :: {:ok, map()} | {:error, :not_found}
end
```

### 2. LiveView Components

#### A. PlaybackLive Assigns
```elixir
assigns = %{
  session_id: nil,
  playback_engine_pid: nil,
  current_event: nil,
  current_event_index: 0,
  total_events: 0,
  current_source_code: "",
  current_module: nil,
  highlight_line_start: nil,
  highlight_line_end: nil,
  variables: %{},
  call_stack: [],
  playback_status: :paused,
  source_code_map: %{},
  ast_map: %{}
}
```

### 3. Data Formats

#### A. Event Types
```json
{
  "FUNCTION_ENTRY": {
    "module": "MyModule",
    "function": "process",
    "arity": 2,
    "args": [{"type": "integer", "value": 42}]
  },
  "FUNCTION_EXIT": {
    "module": "MyModule",
    "function": "process",
    "arity": 2,
    "return_value": {"type": "ok", "value": "success"},
    "duration_ns": 125000000
  },
  "LINE_EXECUTION": {
    "module": "MyModule",
    "line": 23
  },
  "VAR_SNAPSHOT": {
    "module": "MyModule",
    "line": 25,
    "variables": {
      "count": {"type": "integer", "value": 42},
      "name": {"type": "string", "value": "test"}
    }
  }
}
```

### 4. Implementation Details

#### A. Error Handling
- JSON parsing errors in DataProvider
- Missing files handling
- Invalid session data handling
- PlaybackEngine state validation

#### B. Performance Considerations
- Caching of session data
- Efficient event processing
- UI component optimization
- Large file handling

#### C. UI/UX Features
- Responsive design with Tailwind CSS
- Keyboard shortcuts for playback control
- Syntax highlighting for code view
- Variable state visualization
- Call stack navigation

## 📈 Progress Tracking

This section will be updated as development progresses. Each completed item in the checklist will be marked with a completion date and any relevant notes.

## 🎯 Next Steps

1. Initialize Phoenix project with LiveView and required dependencies:
   ```bash
   mix phx.new phoenix_scope_player --live
   cd phoenix_scope_player
   mix deps.get
   ```

2. Set up development environment:
   - Configure Tailwind CSS
   - Set up esbuild
   - Configure Heroicons

3. Create initial directory structure:
   - Set up PlaybackEngine registry
   - Create component hierarchy
   - Initialize data provider

4. Begin implementation of core modules:
   - DataProvider with JSON handling
   - PlaybackEngine with state management
   - LiveView components for UI

## 📝 Implementation Notes

### Phase 1: Initial Setup
- Use Phoenix 1.7+ for latest LiveView features
- Configure JSON parsing with Jason
- Set up development database if needed
- Initialize Git repository
- Configure Tailwind CSS and esbuild

### Phase 2: Core Infrastructure
- Implement caching strategy for session data
- Add error handling for file operations
- Create sample debugging sessions for testing
- Set up PlaybackEngine registry

### Phase 3: UI Development
- Use CSS Grid for multi-panel layout
- Implement responsive design
- Add keyboard shortcuts for playback control
- Add syntax highlighting for code view
- Implement variable state visualization

### Phase 4: Testing
- Create comprehensive test data
- Test edge cases in playback
- Verify performance with large sessions
- Document all test scenarios

Progress updates and additional details will be added to this document as development continues. 