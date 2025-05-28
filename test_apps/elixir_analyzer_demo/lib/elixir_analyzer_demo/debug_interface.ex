defmodule ElixirAnalyzerDemo.DebugInterface do
  @moduledoc """
  Interactive debugging interface for the Enhanced AST Repository demo.
  """
  
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def start_debug_session(module_name) do
    GenServer.call(__MODULE__, {:start_session, module_name})
  end
  
  def set_breakpoint(session_id, function_name, arity) do
    GenServer.call(__MODULE__, {:set_breakpoint, session_id, function_name, arity})
  end
  
  def add_watch_expression(session_id, expression) do
    GenServer.call(__MODULE__, {:add_watch, session_id, expression})
  end
  
  def analyze_execution_path(session_id, function_name, arity, args) do
    GenServer.call(__MODULE__, {:analyze_path, session_id, function_name, arity, args})
  end
  
  def init(_opts) do
    {:ok, %{sessions: %{}, next_session_id: 1}}
  end
  
  def handle_call({:start_session, module_name}, _from, state) do
    session_id = "session_#{state.next_session_id}"
    session = %{
      id: session_id,
      module: module_name,
      breakpoints: [],
      watches: [],
      started_at: DateTime.utc_now()
    }
    
    new_sessions = Map.put(state.sessions, session_id, session)
    new_state = %{state | sessions: new_sessions, next_session_id: state.next_session_id + 1}
    
    {:reply, {:ok, session_id}, new_state}
  end
  
  def handle_call({:set_breakpoint, session_id, function_name, arity}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}
      session ->
        breakpoint = %{
          id: "bp_#{:rand.uniform(1000)}",
          function: function_name,
          arity: arity,
          set_at: DateTime.utc_now()
        }
        
        updated_session = %{session | breakpoints: [breakpoint | session.breakpoints]}
        new_sessions = Map.put(state.sessions, session_id, updated_session)
        new_state = %{state | sessions: new_sessions}
        
        {:reply, {:ok, breakpoint.id}, new_state}
    end
  end
  
  def handle_call({:add_watch, session_id, expression}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}
      session ->
        watch = %{
          id: "watch_#{:rand.uniform(1000)}",
          expression: expression,
          added_at: DateTime.utc_now()
        }
        
        updated_session = %{session | watches: [watch | session.watches]}
        new_sessions = Map.put(state.sessions, session_id, updated_session)
        new_state = %{state | sessions: new_sessions}
        
        {:reply, {:ok, watch.id}, new_state}
    end
  end
  
  def handle_call({:analyze_path, session_id, function_name, arity, args}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}
      _session ->
        analysis = %{
          function: "#{function_name}/#{arity}",
          args: args,
          complexity_analysis: %{
            score: 3.5,
            paths: 2,
            branches: 1
          },
          potential_issues: [
            "Mixed data types in list",
            "No input validation"
          ],
          analyzed_at: DateTime.utc_now()
        }
        
        {:reply, analysis, state}
    end
  end
end 