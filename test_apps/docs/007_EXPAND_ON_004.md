I'll provide comprehensive technical details for implementing the Phoenix Rewind debugging tool with elixir_scope integration.

## Technical Implementation Guide for Phoenix Rewind

### 1. ElixirScope Plugin Architecture

```plaintext
defmodule ElixirScope do
  @moduledoc """
  Compile-time instrumentation plugin for automatic debugging capture.
  Hooks into the Elixir AST compilation process to inject debugging probes.
  """

  @doc """
  Macro that instruments function definitions at compile time.
  Usage: `use ElixirScope` in modules you want to instrument.
  """
  defmacro __using__(opts \\ []) do
    quote do
      @before_compile ElixirScope
      @elixir_scope_opts unquote(opts)
      
      # Register this module for instrumentation
      Module.register_attribute(__MODULE__, :elixir_scope_functions, accumulate: true)
    end
  end

  defmacro __before_compile__(env) do
    functions = Module.get_attribute(env.module, :elixir_scope_functions, [])
    
    quote do
      # Generate instrumented versions of all functions
      unquote_splicing(Enum.map(functions, &generate_instrumented_function/1))
    end
  end

  @doc """
  AST transformation that wraps function calls with debugging probes.
  """
  def instrument_ast(ast, session_id) do
    Macro.prewalk(ast, fn
      # Instrument function calls
      {{:., _, [{:__aliases__, _, module}, function]}, meta, args} = node ->
        if should_instrument?(module, function) do
          quote do
            ElixirScope.Capture.record_function_call(
              unquote(session_id),
              unquote(Module.concat(module)),
              unquote(function),
              unquote(length(args)),
              unquote(args),
              unquote(meta[:line])
            )
            
            result = unquote(node)
            
            ElixirScope.Capture.record_return_value(
              unquote(session_id),
              result,
              unquote(meta[:line])
            )
            
            result
          end
        else
          node
        end
      
      # Instrument variable assignments
      {:=, meta, [var, value]} = node ->
        quote do
          result = unquote(node)
          
          ElixirScope.Capture.record_variable_change(
            unquote(session_id),
            unquote(Macro.to_string(var)),
            result,
            unquote(meta[:line])
          )
          
          result
        end
      
      # Instrument conditional branches
      {:if, meta, [condition, [do: do_block] ++ else_block]} = node ->
        quote do
          condition_result = unquote(condition)
          
          ElixirScope.Capture.record_conditional_branch(
            unquote(session_id),
            condition_result,
            unquote(meta[:line])
          )
          
          if condition_result do
            unquote(do_block)
          else
            unquote(else_block[:else])
          end
        end
      
      # Pass through other nodes unchanged
      node -> node
    end)
  end

  defp should_instrument?(module, function) do
    # Configuration-based filtering
    config = Application.get_env(:elixir_scope, :instrumentation, [])
    
    excluded_modules = Keyword.get(config, :exclude_modules, [])
    excluded_functions = Keyword.get(config, :exclude_functions, [])
    
    not (Module.concat(module) in excluded_modules or 
         {Module.concat(module), function} in excluded_functions)
  end

  defp generate_instrumented_function({name, arity, original_ast}) do
    # Generate wrapper function that creates session and instruments the original
    quote do
      def unquote(name)(unquote_splicing(generate_args(arity))) do
        session_id = ElixirScope.SessionManager.create_session(
          __MODULE__,
          unquote(name),
          unquote(arity),
          [unquote_splicing(generate_args(arity))]
        )
        
        try do
          result = unquote(instrument_ast(original_ast, session_id))
          ElixirScope.SessionManager.complete_session(session_id, result)
          result
        rescue
          error ->
            ElixirScope.Capture.record_exception(session_id, error, __STACKTRACE__)
            ElixirScope.SessionManager.error_session(session_id, error)
            reraise error, __STACKTRACE__
        end
      end
    end
  end

  defp generate_args(0), do: []
  defp generate_args(arity) do
    1..arity |> Enum.map(&{:"arg#{&1}", [], nil})
  end
end
```

### 2. Session Management and Data Capture

```plaintext
defmodule ElixirScope.SessionManager do
  @moduledoc """
  Manages debugging sessions lifecycle and metadata.
  """
  
  use GenServer
  
  defstruct [
    :sessions,
    :current_session,
    :max_sessions,
    :storage_backend
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    state = %__MODULE__{
      sessions: %{},
      current_session: nil,
      max_sessions: Keyword.get(opts, :max_sessions, 100),
      storage_backend: Keyword.get(opts, :storage_backend, :memory)
    }
    
    {:ok, state}
  end

  @doc """
  Creates a new debugging session for a function call.
  """
  def create_session(module, function, arity, args) do
    session_id = generate_session_id()
    
    session = %{
      id: session_id,
      module: module,
      function: function,
      arity: arity,
      args: args,
      start_time: System.monotonic_time(:millisecond),
      end_time: nil,
      status: :running,
      trigger: "#{module}.#{function}/#{arity}",
      events: [],
      process_id: self(),
      node: Node.self()
    }
    
    GenServer.call(__MODULE__, {:create_session, session})
    session_id
  end

  @doc """
  Marks a session as completed with final result.
  """
  def complete_session(session_id, result) do
    GenServer.call(__MODULE__, {:complete_session, session_id, result})
  end

  @doc """
  Marks a session as errored with exception details.
  """
  def error_session(session_id, error) do
    GenServer.call(__MODULE__, {:error_session, session_id, error})
  end

  @doc """
  Retrieves all sessions with optional filtering.
  """
  def list_sessions(filters \\ %{}) do
    GenServer.call(__MODULE__, {:list_sessions, filters})
  end

  @doc """
  Retrieves a specific session by ID.
  """
  def get_session(session_id) do
    GenServer.call(__MODULE__, {:get_session, session_id})
  end

  # GenServer Callbacks

  def handle_call({:create_session, session}, _from, state) do
    # Implement session rotation if max_sessions exceeded
    sessions = 
      if map_size(state.sessions) >= state.max_sessions do
        oldest_session_id = 
          state.sessions
          |> Enum.min_by(fn {_id, session} -> session.start_time end)
          |> elem(0)
        
        Map.delete(state.sessions, oldest_session_id)
      else
        state.sessions
      end
    
    new_sessions = Map.put(sessions, session.id, session)
    
    # Persist to storage backend
    persist_session(state.storage_backend, session)
    
    {:reply, :ok, %{state | sessions: new_sessions, current_session: session.id}}
  end

  def handle_call({:complete_session, session_id, result}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :not_found}, state}
      
      session ->
        updated_session = %{session | 
          end_time: System.monotonic_time(:millisecond),
          status: :completed,
          result: result
        }
        
        new_sessions = Map.put(state.sessions, session_id, updated_session)
        persist_session(state.storage_backend, updated_session)
        
        {:reply, :ok, %{state | sessions: new_sessions}}
    end
  end

  def handle_call({:error_session, session_id, error}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :not_found}, state}
      
      session ->
        updated_session = %{session | 
          end_time: System.monotonic_time(:millisecond),
          status: :error,
          error: %{
            type: error.__struct__,
            message: Exception.message(error),
            stacktrace: Process.info(self(), :current_stacktrace)
          }
        }
        
        new_sessions = Map.put(state.sessions, session_id, updated_session)
        persist_session(state.storage_backend, updated_session)
        
        {:reply, :ok, %{state | sessions: new_sessions}}
    end
  end

  def handle_call({:list_sessions, filters}, _from, state) do
    sessions = 
      state.sessions
      |> Map.values()
      |> apply_filters(filters)
      |> Enum.sort_by(& &1.start_time, :desc)
    
    {:reply, sessions, state}
  end

  def handle_call({:get_session, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil -> {:reply, {:error, :not_found}, state}
      session -> {:reply, {:ok, session}, state}
    end
  end

  # Private Functions

  defp generate_session_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp persist_session(:memory, _session), do: :ok
  
  defp persist_session(:disk, session) do
    # Implement disk persistence
    file_path = Path.join([
      Application.get_env(:elixir_scope, :storage_path, "/tmp/elixir_scope"),
      "#{session.id}.json"
    ])
    
    File.mkdir_p!(Path.dirname(file_path))
    File.write!(file_path, Jason.encode!(session))
  end

  defp persist_session(:database, session) do
    # Implement database persistence (PostgreSQL, etc.)
    # This would integrate with your application's Repo
    MyApp.Repo.insert!(%DebugSession{
      session_id: session.id,
      module: to_string(session.module),
      function: to_string(session.function),
      arity: session.arity,
      start_time: session.start_time,
      end_time: session.end_time,
      status: session.status,
      data: Jason.encode!(session)
    })
  end

  defp apply_filters(sessions, filters) do
    Enum.filter(sessions, fn session ->
      Enum.all?(filters, fn
        {:module, module} -> session.module == module
        {:function, function} -> session.function == function
        {:status, status} -> session.status == status
        {:after, timestamp} -> session.start_time >= timestamp
        {:before, timestamp} -> session.start_time <= timestamp
        {:search, term} -> String.contains?(session.trigger, term)
        _ -> true
      end)
    end)
  end
end
```

### 3. Event Capture System

```plaintext
defmodule ElixirScope.Capture do
  @moduledoc """
  Captures and records debugging events during execution.
  """

  @doc """
  Records a function call event.
  """
  def record_function_call(session_id, module, function, arity, args, line) do
    event = %{
      type: :function_call,
      timestamp: System.monotonic_time(:microsecond),
      session_id: session_id,
      module: module,
      function: function,
      arity: arity,
      args: sanitize_args(args),
      line: line,
      process_id: self(),
      thread_id: :erlang.system_info(:scheduler_id)
    }
    
    ElixirScope.EventStore.store_event(session_id, event)
  end

  @doc """
  Records a return value event.
  """
  def record_return_value(session_id, value, line) do
    event = %{
      type: :return_value,
      timestamp: System.monotonic_time(:microsecond),
      session_id: session_id,
      value: sanitize_value(value),
      line: line,
      process_id: self()
    }
    
    ElixirScope.EventStore.store_event(session_id, event)
  end

  @doc """
  Records a variable assignment event.
  """
  def record_variable_change(session_id, variable_name, value, line) do
    event = %{
      type: :variable_change,
      timestamp: System.monotonic_time(:microsecond),
      session_id: session_id,
      variable: variable_name,
      value: sanitize_value(value),
      line: line,
      process_id: self()
    }
    
    ElixirScope.EventStore.store_event(session_id, event)
  end

  @doc """
  Records a conditional branch event.
  """
  def record_conditional_branch(session_id, condition_result, line) do
    event = %{
      type: :conditional_branch,
      timestamp: System.monotonic_time(:microsecond),
      session_id: session_id,
      condition: condition_result,
      line: line,
      process_id: self()
    }
    
    ElixirScope.EventStore.store_event(session_id, event)
  end

  @doc """
  Records an exception event.
  """
  def record_exception(session_id, error, stacktrace) do
    event = %{
      type: :exception,
      timestamp: System.monotonic_time(:microsecond),
      session_id: session_id,
      error_type: error.__struct__,
      message: Exception.message(error),
      stacktrace: format_stacktrace(stacktrace),
      process_id: self()
    }
    
    ElixirScope.EventStore.store_event(session_id, event)
  end

  # Private helper functions

  defp sanitize_args(args) when is_list(args) do
    Enum.map(args, &sanitize_value/1)
  end

  defp sanitize_value(value) do
    case value do
      # Limit large data structures
      value when is_binary(value) and byte_size(value) > 1000 ->
        binary_part(value, 0, 1000) <> "... (truncated)"
      
      value when is_list(value) and length(value) > 50 ->
        Enum.take(value, 50) ++ ["... (truncated)"]
      
      %{} = map when map_size(map) > 20 ->
        map
        |> Enum.take(20)
        |> Map.new()
        |> Map.put(:__truncated__, true)
      
      # Handle sensitive data
      %{password: _} = map ->
        Map.put(map, :password, "[REDACTED]")
      
      %{secret: _} = map ->
        Map.put(map, :secret, "[REDACTED]")
      
      # Handle PIDs and references
      pid when is_pid(pid) ->
        inspect(pid)
      
      ref when is_reference(ref) ->
        inspect(ref)
      
      # Pass through safe values
      value when is_atom(value) or is_number(value) or is_boolean(value) ->
        value
      
      # Convert other values to string representation
      value ->
        inspect(value, limit: 100, printable_limit: 100)
    end
  end

  defp format_stacktrace(stacktrace) do
    stacktrace
    |> Enum.take(10)  # Limit stacktrace depth
    |> Enum.map(fn
      {module, function, arity, location} ->
        %{
          module: module,
          function: function,
          arity: arity,
          file: Keyword.get(location, :file),
          line: Keyword.get(location, :line)
        }
      
      {module, function, args, location} when is_list(args) ->
        %{
          module: module,
          function: function,
          arity: length(args),
          file: Keyword.get(location, :file),
          line: Keyword.get(location, :line)
        }
    end)
  end
end
```

### 4. Event Storage Backend

```plaintext
defmodule ElixirScope.EventStore do
  @moduledoc """
  Handles storage and retrieval of debugging events.
  Supports multiple backends: memory, ETS, disk, database.
  """

  use GenServer

  defstruct [
    :backend,
    :storage,
    :max_events_per_session,
    :compression_enabled
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    backend = Keyword.get(opts, :backend, :memory)
    
    storage = case backend do
      :memory -> %{}
      :ets -> 
        table = :ets.new(:elixir_scope_events, [:set, :public, :named_table])
        table
      :disk -> 
        path = Keyword.get(opts, :storage_path, "/tmp/elixir_scope/events")
        File.mkdir_p!(path)
        path
      :database ->
        # Database connection would be initialized here
        nil
    end

    state = %__MODULE__{
      backend: backend,
      storage: storage,
      max_events_per_session: Keyword.get(opts, :max_events_per_session, 10_000),
      compression_enabled: Keyword.get(opts, :compression, true)
    }

    {:ok, state}
  end

  @doc """
  Stores a debugging event for a session.
  """
  def store_event(session_id, event) do
    GenServer.cast(__MODULE__, {:store_event, session_id, event})
  end

  @doc """
  Retrieves all events for a session.
  """
  def get_events(session_id) do
    GenServer.call(__MODULE__, {:get_events, session_id})
  end

  @doc """
  Retrieves a specific event by session and event number.
  """
  def get_event(session_id, event_number) do
    GenServer.call(__MODULE__, {:get_event, session_id, event_number})
  end

  @doc """
  Clears events for a session (useful for cleanup).
  """
  def clear_session_events(session_id) do
    GenServer.call(__MODULE__, {:clear_session_events, session_id})
  end

  # GenServer Callbacks

  def handle_cast({:store_event, session_id, event}, state) do
    # Add sequence number and relative timing
    events = get_session_events(state, session_id)
    
    enhanced_event = event
    |> Map.put(:sequence, length(events) + 1)
    |> Map.put(:relative_time, calculate_relative_time(events, event))

    # Check event limit per session
    events = if length(events) >= state.max_events_per_session do
      # Remove oldest event (FIFO)
      tl(events) ++ [enhanced_event]
    else
      events ++ [enhanced_event]
    end

    new_state = store_session_events(state, session_id, events)
    {:noreply, new_state}
  end

  def handle_call({:get_events, session_id}, _from, state) do
    events = get_session_events(state, session_id)
    {:reply, events, state}
  end

  def handle_call({:get_event, session_id, event_number}, _from, state) do
    events = get_session_events(state, session_id)
    
    event = case Enum.at(events, event_number - 1) do
      nil -> {:error, :not_found}
      event -> {:ok, event}
    end
    
    {:reply, event, state}
  end

  def handle_call({:clear_session_events, session_id}, _from, state) do
    new_state = clear_session_events_impl(state, session_id)
    {:reply, :ok, new_state}
  end

  # Backend-specific implementations

  defp get_session_events(%{backend: :memory, storage: storage}, session_id) do
    Map.get(storage, session_id, [])
  end

  defp get_session_events(%{backend: :ets, storage: table}, session_id) do
    case :ets.lookup(table, session_id) do
      [{^session_id, events}] -> events
      [] -> []
    end
  end

  defp get_session_events(%{backend: :disk, storage: path}, session_id) do
    file_path = Path.join(path, "#{session_id}.json")
    
    case File.read(file_path) do
      {:ok, content} -> 
        content
        |> Jason.decode!()
        |> decompress_if_needed()
      
      {:error, :enoent} -> []
    end
  end

  defp store_session_events(%{backend: :memory} = state, session_id, events) do
    new_storage = Map.put(state.storage, session_id, events)
    %{state | storage: new_storage}
  end

  defp store_session_events(%{backend: :ets, storage: table} = state, session_id, events) do
    :ets.insert(table, {session_id, events})
    state
  end

  defp store_session_events(%{backend: :disk, storage: path} = state, session_id, events) do
    file_path = Path.join(path, "#{session_id}.json")
    
    content = events
    |> compress_if_needed(state.compression_enabled)
    |> Jason.encode!()
    
    File.write!(file_path, content)
    state
  end

  defp clear_session_events_impl(%{backend: :memory} = state, session_id) do
    new_storage = Map.delete(state.storage, session_id)
    %{state | storage: new_storage}
  end

  defp clear_session_events_impl(%{backend: :ets, storage: table} = state, session_id) do
    :ets.delete(table, session_id)
    state
  end

  defp clear_session_events_impl(%{backend: :disk, storage: path} = state, session_id) do
    file_path = Path.join(path, "#{session_id}.json")
    File.rm(file_path)
    state
  end

  # Helper functions

  defp calculate_relative_time([], _event), do: 0
  
  defp calculate_relative_time(events, event) do
    first_timestamp = events |> List.first() |> Map.get(:timestamp)
    div(event.timestamp - first_timestamp, 1000)  # Convert to milliseconds
  end

  defp compress_if_needed(data, true) do
    :zlib.compress(Jason.encode!(data))
  end
  
  defp compress_if_needed(data, false), do: data

  defp decompress_if_needed(data) when is_binary(data) do
    try do
      :zlib.uncompress(data) |> Jason.decode!()
    rescue
      _ -> Jason.decode!(data)  # Fallback for uncompressed data
    end
  end
end
```

### 5. Phoenix Integration Layer

```plaintext
defmodule PhoenixRewindWeb.DebugLive do
  @moduledoc """
  LiveView component for real-time debugging session playback.
  Provides interactive controls and live updates.
  """
  
  use PhoenixRewindWeb, :live_view
  
  alias ElixirScope.{SessionManager, EventStore}

  def mount(%{"session_id" => session_id}, _session, socket) do
    if connected?(socket) do
      # Subscribe to real-time updates for this session
      Phoenix.PubSub.subscribe(PhoenixRewind.PubSub, "debug_session:#{session_id}")
    end

    case SessionManager.get_session(session_id) do
      {:ok, session} ->
        events = EventStore.get_events(session_id)
        
        socket = socket
        |> assign(:session, session)
        |> assign(:events, events)
        |> assign(:current_event, 1)
        |> assign(:playing, false)
        |> assign(:playback_speed, 1000)  # milliseconds between events
        |> assign(:selected_event, nil)
        |> assign(:source_context, nil)
        |> assign(:call_stack, [])

        {:ok, socket}

      {:error, :not_found} ->
        {:ok, 
         socket
         |> put_flash(:error, "Debug session not found")
         |> redirect(to: ~p"/dev/rewind")}
    end
  end

  def handle_event("play_pause", _params, socket) do
    socket = if socket.assigns.playing do
      # Stop playback
      assign(socket, :playing, false)
    else
      # Start playback
      send(self(), :advance_playback)
      assign(socket, :playing, true)
    end

    {:noreply, socket}
  end

  def handle_event("step_forward", _params, socket) do
    current = socket.assigns.current_event
    max_events = length(socket.assigns.events)
    
    new_current = min(current + 1, max_events)
    
    socket = socket
    |> assign(:current_event, new_current)
    |> update_event_context(new_current)

    {:noreply, socket}
  end

  def handle_event("step_backward", _params, socket) do
    current = socket.assigns.current_event
    new_current = max(current - 1, 1)
    
    socket = socket
    |> assign(:current_event, new_current)
    |> update_event_context(new_current)

    {:noreply, socket}
  end

  def handle_event("goto_start", _params, socket) do
    socket = socket
    |> assign(:current_event, 1)
    |> assign(:playing, false)
    |> update_event_context(1)

    {:noreply, socket}
  end

  def handle_event("goto_end", _params, socket) do
    max_events = length(socket.assigns.events)
    
    socket = socket
    |> assign(:current_event, max_events)
    |> assign(:playing, false)
    |> update_event_context(max_events)

    {:noreply, socket}
  end

  def handle_event("select_event", %{"event_number" => event_number}, socket) do
    {event_num, ""} = Integer.parse(event_number)
    
    socket = socket
    |> assign(:current_event, event_num)
    |> assign(:playing, false)
    |> update_event_context(event_num)

    {:noreply, socket}
  end

  def handle_event("change_speed", %{"speed" => speed}, socket) do
    {speed_ms, ""} = Integer.parse(speed)
    {:noreply, assign(socket, :playback_speed, speed_ms)}
  end

  def handle_info(:advance_playback, socket) do
    if socket.assigns.playing do
      current = socket.assigns.current_event
      max_events = length(socket.assigns.events)
      
      if current < max_events do
        new_current = current + 1
        
        # Schedule next advancement
        Process.send_after(self(), :advance_playback, socket.assigns.playback_speed)
        
        socket = socket
        |> assign(:current_event, new_current)
        |> update_event_context(new_current)

        {:noreply, socket}
      else
        # Reached end, stop playing
        {:noreply, assign(socket, :playing, false)}
      end
    else
      {:noreply, socket}
    end
  end

  # Handle real-time session updates
  def handle_info({:session_updated, session}, socket) do
    {:noreply, assign(socket, :session, session)}
  end

  def handle_info({:new_event, event}, socket) do
    events = socket.assigns.events ++ [event]
    {:noreply, assign(socket, :events, events)}
  end

  defp update_event_context(socket, event_number) do
    events = socket.assigns.events
    
    case Enum.at(events, event_number - 1) do
      nil ->
        socket
      
      event ->
        # Get source context for this event
        source_context = get_source_context(event)
        
        # Build call stack up to this point
        call_stack = build_call_stack(events, event_number)
        
        # Get variable state at this point
        variable_state = get_variable_state(events, event_number)
        
        socket
        |> assign(:selected_event, event)
        |> assign(:source_context, source_context)
        |> assign(:call_stack, call_stack)
        |> assign(:variable_state, variable_state)
    end
  end

  defp get_source_context(event) do
    case event do
      %{module: module, line: line} when not is_nil(line) ->
        # Try to read source file and extract context
        module_path = module_to_file_path(module)
        
        case File.read(module_path) do
          {:ok, content} ->
            lines = String.split(content, "\n")
            
            start_line = max(1, line - 3)
            end_line = min(length(lines), line + 3)
            
            context_lines = 
              lines
              |> Enum.slice((start_line - 1)..(end_line - 1))
              |> Enum.with_index(start_line)
            
            %{
              file: module_path,
              current_line: line,
              context_lines: context_lines
            }
          
          {:error, _} ->
            %{
              file: "#{module} (source not available)",
              current_line: line,
              context_lines: []
            }
        end
      
      _ ->
        nil
    end
  end

  defp build_call_stack(events, current_event_number) do
    events
    |> Enum.take(current_event_number)
    |> Enum.filter(&(&1.type == :function_call))
    |> Enum.map(fn event ->
      %{
        module: event.module,
        function: event.function,
        arity: event.arity,
        line: event.line
      }
    end)
    |> Enum.reverse()  # Most recent call first
  end

  defp get_variable_state(events, current_event_number) do
    events
    |> Enum.take(current_event_number)
    |> Enum.filter(&(&1.type in [:variable_change, :function_call]))
    |> Enum.reduce(%{}, fn
      %{type: :variable_change, variable: var, value: value}, acc ->
        Map.put(acc, var, value)
      
      %{type: :function_call, args: args}, acc ->
        # Add function arguments to variable state
        args
        |> Enum.with_index()
        |> Enum.reduce(acc, fn {arg_value, index}, acc ->
          Map.put(acc, "arg#{index + 1}", arg_value)
        end)
      
      _, acc -> acc
    end)
  end

  defp module_to_file_path(module) do
    # Convert module name to file path
    module_string = to_string(module)
    
    path_parts = 
      module_string
      |> String.split(".")
      |> Enum.map(&Macro.underscore/1)
    
    Path.join(["lib"] ++ path_parts) <> ".ex"
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Header with session info and controls -->
      <header class="bg-white shadow">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex justify-between items-center py-6">
            <div>
              <h1 class="text-3xl font-bold text-gray-900">Phoenix Rewind</h1>
              <p class="text-sm text-gray-500">Session: <%= @session.trigger %></p>
            </div>
            <.link 
              href={~p"/dev/rewind"} 
              class="bg-gray-600 hover:bg-gray-700 text-white px-4 py-2 rounded-md text-sm font-medium"
            >
              Back to Sessions
            </.link>
          </div>
        </div>
      </header>

      <!-- Playback Controls -->
      <div class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <div class="bg-white shadow rounded-lg mb-6">
          <div class="px-4 py-5 sm:p-6">
            <!-- Control Buttons -->
            <div class="flex items-center justify-between mb-4">
              <div class="flex items-center space-x-4">
                <button 
                  phx-click="goto_start"
                  class="bg-gray-200 hover:bg-gray-300 text-gray-700 px-3 py-2 rounded-md text-sm font-medium"
                >
                  ⏮️ Start
                </button>
                <button 
                  phx-click="step_backward"
                  class="bg-gray-200 hover:bg-gray-300 text-gray-700 px-3 py-2 rounded-md text-sm font-medium"
                >
                  ⏪ Step Back
                </button>
                <button 
                  phx-click="play_pause"
                  class={[
                    "px-3 py-2 rounded-md text-sm font-medium",
                    if(@playing, do: "bg-red-600 hover:bg-red-700 text-white", else: "bg-blue-600 hover:bg-blue-700 text-white")
                  ]}
                >
                  <%= if @playing, do: "⏸️ Pause", else: "▶️ Play" %>
                </button>
                <button 
                  phx-click="step_forward"
                  class="bg-gray-200 hover:bg-gray-300 text-gray-700 px-3 py-2 rounded-md text-sm font-medium"
                >
                  ⏩ Step Forward
                </button>
                <button 
                  phx-click="goto_end"
                  class="bg-gray-200 hover:bg-gray-300 text-gray-700 px-3 py-2 rounded-md text-sm font-medium"
                >
                  ⏭️ End
                </button>
                
                <!-- Speed Control -->
                <select 
                  phx-change="change_speed" 
                  name="speed"
                  class="ml-4 px-3 py-2 border border-gray-300 rounded-md text-sm"
                >
                  <option value="2000" selected={@playback_speed == 2000}>0.5x Speed</option>
                  <option value="1000" selected={@playback_speed == 1000}>1x Speed</option>
                  <option value="500" selected={@playback_speed == 500}>2x Speed</option>
                  <option value="250" selected={@playback_speed == 250}>4x Speed</option>
                </select>
              </div>
              
              <div class="text-sm text-gray-500">
                Event <%= @current_event %> of <%= length(@events) %>
              </div>
            </div>
            
            <!-- Timeline Scrubber -->
            <div class="w-full bg-gray-200 rounded-full h-3 mb-4 cursor-pointer" phx-click="scrub_timeline">
              <div 
                class="bg-blue-600 h-3 rounded-full transition-all duration-200" 
                style={"width: #{if length(@events) > 0, do: (@current_event / length(@events)) * 100, else: 0}%"}
              ></div>
              
              <!-- Event markers on timeline -->
              <%= for {event, index} <- Enum.with_index(@events) do %>
                <% position = (index + 1) / length(@events) * 100 %>
                <div 
                  class={[
                    "absolute w-2 h-2 rounded-full transform -translate-y-1/2 cursor-pointer",
                    case event.type do
                      :exception -> "bg-red-500"
                      :function_call -> "bg-blue-500"
                      :return_value -> "bg-green-500"
                      _ -> "bg-gray-400"
                    end
                  ]}
                  style={"left: #{position}%; top: 50%"}
                  phx-click="select_event"
                  phx-value-event_number={index + 1}
                  title={"Event #{index + 1}: #{event.type}"}
                ></div>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Main Content Grid -->
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <!-- Event Stream -->
          <div class="lg:col-span-1">
            <div class="bg-white shadow rounded-lg">
              <div class="px-4 py-5 sm:p-6">
                <h3 class="text-lg font-medium text-gray-900 mb-4">Event Stream</h3>
                <div class="space-y-2 max-h-96 overflow-y-auto">
                  <%= for {event, index} <- Enum.with_index(@events, 1) do %>
                    <div 
                      class={[
                        "p-3 rounded-md border cursor-pointer hover:bg-gray-50 transition-colors",
                        if(index == @current_event, do: "bg-blue-50 border-blue-200 ring-2 ring-blue-300", else: "bg-white border-gray-200")
                      ]}
                      phx-click="select_event"
                      phx-value-event_number={index}
                    >
                      <div class="flex items-center justify-between">
                        <span class="text-xs font-medium text-gray-500">#<%= index %></span>
                        <span class="text-xs text-gray-500">+<%= event.relative_time %>ms</span>
                      </div>
                      <div class="mt-1">
                        <span class={[
                          "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                          case event.type do
                            :function_call -> "bg-blue-100 text-blue-800"
                            :return_value -> "bg-green-100 text-green-800"
                            :variable_change -> "bg-yellow-100 text-yellow-800"
                            :conditional_branch -> "bg-purple-100 text-purple-800"
                            :exception -> "bg-red-100 text-red-800"
                            _ -> "bg-gray-100 text-gray-800"
                          end
                        ]}>
                          <%= event.type %>
                        </span>
                      </div>
                      <div class="mt-2 text-sm text-gray-900 truncate">
                        <%= format_event_details(event) %>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>

          <!-- Source Context and State -->
          <div class="lg:col-span-2 space-y-6">
            <!-- Source Code Context -->
            <%= if @source_context do %>
              <div class="bg-white shadow rounded-lg">
                <div class="px-4 py-5 sm:p-6">
                  <h3 class="text-lg font-medium text-gray-900 mb-4">Source Code Context</h3>
                  <div class="bg-gray-900 text-gray-100 p-4 rounded-md font-mono text-sm overflow-x-auto">
                    <div class="text-gray-400 mb-2"><%= @source_context.file %></div>
                    <div class="space-y-1">
                      <%= for {line_content, line_number} <- @source_context.context_lines do %>
                        <div class={[
                          "flex",
                          if(line_number == @source_context.current_line, do: "bg-yellow-900 bg-opacity-50 px-2 py-1 rounded", else: "")
                        ]}>
                          <span class="text-gray-500 w-8 text-right mr-4"><%= line_number %></span>
                          <span class={if(line_number == @source_context.current_line, do: "text-yellow-200", else: "text-gray-300")}>
                            <%= line_content %>
                          </span>
                        </div>
                      <% end %>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>

            <!-- Call Stack -->
            <%= if @call_stack != [] do %>
              <div class="bg-white shadow rounded-lg">
                <div class="px-4 py-5 sm:p-6">
                  <h3 class="text-lg font-medium text-gray-900 mb-4">Call Stack</h3>
                  <div class="space-y-2">
                    <%= for {frame, index} <- Enum.with_index(@call_stack) do %>
                      <div class={[
                        "p-3 rounded-md border",
                        if(index == 0, do: "bg-blue-50 border-blue-200", else: "bg-gray-50 border-gray-200")
                      ]}>
                        <div class="font-mono text-sm">
                          <%= frame.module %>.<%= frame.function %>/<%= frame.arity %>
                        </div>
                        <%= if frame.line do %>
                          <div class="text-xs text-gray-500">Line <%= frame.line %></div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>

            <!-- Variable State Inspector -->
            <div class="bg-white shadow rounded-lg">
              <div class="px-4 py-5 sm:p-6">
                <h3 class="text-lg font-medium text-gray-900 mb-4">
                  Variable State at Event #<%= @current_event %>
                </h3>
                <%= if @variable_state && map_size(@variable_state) > 0 do %>
                  <div class="space-y-3">
                    <%= for {var_name, value} <- @variable_state do %>
                      <div class="border-l-4 border-blue-500 pl-4">
                        <div class="text-sm font-medium text-gray-700"><%= var_name %></div>
                        <div class="mt-1 bg-gray-50 p-2 rounded text-sm font-mono">
                          <%= inspect(value, pretty: true, limit: 100) %>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% else %>
                  <div class="text-gray-500 text-center py-8">
                    No variable state captured for this event
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp format_event_details(event) do
    case event.type do
      :function_call -> "#{event.module}.#{event.function}/#{event.arity}"
      :return_value -> inspect(event.value, limit: 50)
      :variable_change -> "#{event.variable} = #{inspect(event.value, limit: 30)}"
      :conditional_branch -> if event.condition, do: "condition was true", else: "else branch taken"
      :exception -> "#{event.error_type}: #{event.message}"
      _ -> "Unknown event"
    end
  end
end
```

### 6. Configuration and Setup

```plaintext
# ElixirScope Configuration
config :elixir_scope,
  # Enable/disable instrumentation globally
  enabled: true,
  
  # Automatic capture on function entry
  auto_capture: true,
  
  # Maximum number of sessions to keep in memory
  max_sessions: 100,
  
  # Maximum events per session before rotation
  max_events_per_session: 10_000,
  
  # Storage backend: :memory, :ets, :disk, :database
  storage_backend: :memory,
  
  # Compression for event storage
  compression: true,
  
  # Storage path for disk backend
  storage_path: "/tmp/elixir_scope",
  
  # Event types to capture
  capture_events: [
    :function_call,
    :return_value, 
    :variable_change,
    :conditional_branch,
    :exception
  ],
  
  # Instrumentation filters
  instrumentation: [
    # Modules to exclude from instrumentation
    exclude_modules: [
      Logger,
      Phoenix.Logger,
      Plug.Logger,
      ElixirScope,
      PhoenixRewind
    ],
    
    # Specific functions to exclude
    exclude_functions: [
      {Enum, :map},
      {Enum, :reduce},
      {String, :split}
    ],
    
    # Only instrument specific modules (if specified)
    include_modules: [],
    
    # Performance thresholds
    max_arg_size: 1000,      # bytes
    max_return_size: 1000,   # bytes
    max_stacktrace_depth: 10
  ],
  
  # Security settings
  security: [
    # Redact sensitive fields
    redact_fields: [:password, :secret, :token, :api_key],
    
    # Disable in production by default
    production_enabled: false
  ]

# Phoenix Rewind Web Configuration
config :phoenix_rewind, PhoenixRewindWeb.Endpoint,
  # Development routes for debugging UI
  dev_routes: [
    debug_dashboard: true,
    live_dashboard: true
  ]
```

### 7. Database Schema (Optional)

```plaintext
defmodule PhoenixRewind.Repo.Migrations.CreateDebugSessions do
  use Ecto.Migration

  def change do
    create table(:debug_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, :string, null: false
      add :module, :string, null: false
      add :function, :string, null: false
      add :arity, :integer, null: false
      add :trigger, :string, null: false
      add :start_time, :bigint, null: false
      add :end_time, :bigint
      add :duration, :integer
      add :status, :string, null: false
      add :event_count, :integer, default: 0
      add :process_id, :string
      add :node, :string
      add :metadata, :map
      add :error_info, :map
      
      timestamps()
    end

    create unique_index(:debug_sessions, [:session_id])
    create index(:debug_sessions, [:start_time])
    create index(:debug_sessions, [:status])
    create index(:debug_sessions, [:module, :function])
  end
end
```

```plaintext
defmodule PhoenixRewind.Repo.Migrations.CreateDebugEvents do
  use Ecto.Migration

  def change do
    create table(:debug_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, :string, null: false
      add :sequence, :integer, null: false
      add :timestamp, :bigint, null: false
      add :relative_time, :integer, null: false
      add :event_type, :string, null: false
      add :module, :string
      add :function, :string
      add :arity, :integer
      add :line, :integer
      add :file, :string
      add :process_id, :string
      add :thread_id, :integer
      add :data, :binary  # Compressed JSON data
      
      timestamps()
    end

    create index(:debug_events, [:session_id, :sequence])
    create index(:debug_events, [:timestamp])
    create index(:debug_events, [:event_type])
  end
end
```

### 8. Performance Considerations

```plaintext
defmodule ElixirScope.Performance do
  @moduledoc """
  Performance monitoring and optimization for debugging instrumentation.
  """

  @doc """
  Measures the overhead of instrumentation.
  """
  def measure_overhead(module, function, args) do
    # Measure without instrumentation
    {time_without, _result} = :timer.tc(fn ->
      apply(module, function, args)
    end)

    # Measure with instrumentation
    {time_with, _result} = :timer.tc(fn ->
      # Simulate instrumented call
      session_id = ElixirScope.SessionManager.create_session(module, function, length(args), args)
      
      try do
        result = apply(module, function, args)
        ElixirScope.SessionManager.complete_session(session_id, result)
        result
      rescue
        error ->
          ElixirScope.SessionManager.error_session(session_id, error)
          reraise error, __STACKTRACE__
      end
    end)

    overhead_percentage = ((time_with - time_without) / time_without) * 100
    
    %{
      time_without_us: time_without,
      time_with_us: time_with,
      overhead_us: time_with - time_without,
      overhead_percentage: overhead_percentage
    }
  end

  @doc """
  Adaptive instrumentation based on performance impact.
  """
  def should_instrument?(module, function, arity) do
    # Check if this function has high overhead
    overhead_key = {module, function, arity}
    
    case :ets.lookup(:elixir_scope_overhead, overhead_key) do
      [{^overhead_key, overhead_percentage}] when overhead_percentage > 50.0 ->
        false  # Skip instrumentation for high-overhead functions
      
      _ ->
        true   # Instrument by default
    end
  end

  @doc """
  Sampling strategy to reduce overhead.
  """
  def should_sample?(sampling_rate \\ 0.1) do
    :rand.uniform() < sampling_rate
  end
end
```

This comprehensive technical implementation provides:

1. **Complete AST instrumentation system** with compile-time code injection
2. **Flexible storage backends** (memory, ETS, disk, database)
3. **Real-time LiveView interface** with interactive playback controls
4. **Performance monitoring** and adaptive instrumentation
5. **Security considerations** with data sanitization
6. **Scalable architecture** supporting distributed systems
7. **Database schemas** for persistent storage
8. **Configuration management** for different environments


The system can be extended with additional features like distributed tracing, performance profiling, and integration with existing monitoring tools.
