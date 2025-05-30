defmodule PhoenixScopePlayer.Instrumentation do
  @moduledoc """
  Handles code instrumentation and trace capture for the PhoenixScopePlayer demo.
  This module shows how ElixirScope instruments code and captures execution data.
  """

  use GenServer
  alias PhoenixScopePlayer.Calculator
  require Logger

  # Define the modules we want to trace
  @traced_modules [Calculator]

  def start_trace(session_id) do
    IO.puts("\n=== Starting trace for session #{session_id} ===")
    GenServer.start_link(__MODULE__, session_id)
  end

  def stop_trace(pid) do
    IO.puts("\n=== Stopping trace ===")
    GenServer.call(pid, :stop_trace)
  end

  def enable_tracing(pid, target_pid) do
    GenServer.call(pid, {:enable_tracing, target_pid})
  end

  @impl true
  def init(session_id) do
    IO.puts("Initializing tracer for session #{session_id}")
    Process.flag(:trap_exit, true)
    {:ok, %{events: [], session_id: session_id, call_stack: [], source_files: capture_source_files()}}
  end

  @impl true
  def handle_call({:enable_tracing, target_pid}, _from, state) do
    # First, clear any existing trace patterns and tracers
    :erlang.trace(target_pid, false, [:all])
    for module <- @traced_modules do
      :erlang.trace_pattern({module, :_, :_}, false, [:global])
    end

    # Set up trace patterns for each module
    for module <- @traced_modules do
      Logger.debug("Setting up trace pattern for module #{inspect(module)}")
      # Match spec to capture all function calls and returns
      match_spec = [{:_, [], [{:return_trace}]}]
      # Set up global pattern first
      :erlang.trace_pattern({module, :_, :_}, match_spec, [:global])
      # Then set up local pattern
      :erlang.trace_pattern({module, :_, :_}, match_spec, [:local])
    end

    # Enable tracing for the target process
    :erlang.trace(target_pid, true, [
      :call,           # Trace function calls
      :procs,          # Trace process events
      :set_on_spawn,   # Trace any processes spawned by this one
      :timestamp,      # Include timestamps
      {:tracer, self()} # Set the tracer process
    ])

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:stop_trace, _from, state) do
    IO.puts("Stopping trace and cleaning up...")
    
    # Clear trace patterns
    for module <- @traced_modules do
      :erlang.trace_pattern({module, :_, :_}, false, [:global])
    end

    # Save trace data
    save_trace_data(state)

    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:trace, pid, :call, {module, function, args}}, state) do
    Logger.debug("Trace call: #{inspect(module)}.#{function}/#{length(args)} from #{inspect(pid)}")
    event = %{
      type: :call,
      pid: inspect(pid),
      module: module |> inspect(),
      function: function |> Atom.to_string(),
      args: Enum.map(args, &inspect/1),
      timestamp: System.system_time(:microsecond)
    }
    
    {:noreply, %{state | events: [event | state.events], call_stack: [event | state.call_stack]}}
  end

  def handle_info({:trace_ts, pid, :call, {module, function, args}, timestamp}, state) do
    Logger.debug("Trace call (ts): #{inspect(module)}.#{function}/#{length(args)} from #{inspect(pid)}")
    {major, minor, micro} = timestamp
    timestamp_us = major * 1_000_000_000_000 + minor * 1_000 + div(micro, 1_000)
    event = %{
      type: :call,
      pid: inspect(pid),
      module: module |> inspect(),
      function: function |> Atom.to_string(),
      args: Enum.map(args, &inspect/1),
      timestamp: timestamp_us
    }
    
    {:noreply, %{state | events: [event | state.events], call_stack: [event | state.call_stack]}}
  end

  def handle_info({:trace, pid, :return_from, {module, function, arity}, return_value}, state) do
    Logger.debug("Trace return: #{inspect(module)}.#{function}/#{arity} from #{inspect(pid)}")
    event = %{
      type: :return,
      pid: inspect(pid),
      module: module |> inspect(),
      function: function |> Atom.to_string(),
      arity: arity,
      return_value: inspect(return_value),
      timestamp: System.system_time(:microsecond)
    }
    
    {:noreply, %{state | events: [event | state.events], call_stack: tl(state.call_stack)}}
  end

  def handle_info({:trace_ts, pid, :return_from, {module, function, arity}, return_value, timestamp}, state) do
    Logger.debug("Trace return (ts): #{inspect(module)}.#{function}/#{arity} from #{inspect(pid)}")
    {major, minor, micro} = timestamp
    timestamp_us = major * 1_000_000_000_000 + minor * 1_000 + div(micro, 1_000)
    event = %{
      type: :return,
      pid: inspect(pid),
      module: module |> inspect(),
      function: function |> Atom.to_string(),
      arity: arity,
      return_value: inspect(return_value),
      timestamp: timestamp_us
    }
    
    {:noreply, %{state | events: [event | state.events], call_stack: tl(state.call_stack)}}
  end

  def handle_info({:trace, pid, :exit, reason}, state) do
    Logger.debug("Trace exit: #{inspect(pid)} with reason #{inspect(reason)}")
    event = %{
      type: :exit,
      pid: inspect(pid),
      reason: inspect(reason),
      timestamp: System.system_time(:microsecond)
    }
    
    {:noreply, %{state | events: [event | state.events]}}
  end

  def handle_info({:trace_ts, pid, :exit, reason, timestamp}, state) do
    Logger.debug("Trace exit (ts): #{inspect(pid)} with reason #{inspect(reason)}")
    {major, minor, micro} = timestamp
    timestamp_us = major * 1_000_000_000_000 + minor * 1_000 + div(micro, 1_000)
    event = %{
      type: :exit,
      pid: inspect(pid),
      reason: inspect(reason),
      timestamp: timestamp_us
    }
    
    {:noreply, %{state | events: [event | state.events]}}
  end

  def handle_info(msg, state) do
    Logger.debug("Unhandled trace message: #{inspect(msg, pretty: true)}")
    {:noreply, state}
  end

  defp capture_source_files do
    IO.puts("Capturing source files for modules: #{inspect(@traced_modules)}")
    
    for module <- @traced_modules do
      source_path = module.__info__(:compile)[:source] |> List.to_string()
      IO.puts("  Found source for #{module}: #{source_path}")
      case File.read(source_path) do
        {:ok, source} -> {module, source}
        _ -> nil
      end
    end
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end

  defp save_trace_data(%{events: events, session_id: session_id, source_files: source_files}) do
    base_path = Path.join([
      File.cwd!(),
      "priv",
      "captured_data",
      session_id
    ])
    
    File.mkdir_p!(base_path)
    
    # Save metadata with correct event count
    metadata = %{
      session_id: session_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      event_count: length(events),
      name: "Fibonacci and Factorial Calculations",
      description: "Sample debug session showing recursive function calls"
    }
    
    IO.puts("\n=== Saving Session Data ===")
    IO.puts("Session ID: #{session_id}")
    IO.puts("Event count: #{length(events)}")
    
    metadata_path = Path.join(base_path, "metadata.json")
    File.write!(
      metadata_path,
      Jason.encode!(metadata, pretty: true)
    )
    IO.puts("Saved metadata to #{metadata_path}")
    
    # Save events with proper structure
    events_path = Path.join(base_path, "events.json")
    events_data = %{"events" => Enum.reverse(events)}
    File.write!(
      events_path,
      Jason.encode!(events_data, pretty: true)
    )
    IO.puts("Saved #{length(events)} events to #{events_path}")
    
    # Save source code
    source_code_map = Map.new(source_files, fn {module, source} -> 
      {Atom.to_string(module), %{
        "content" => source,
        "type" => "elixir"
      }}
    end)
    
    source_code_path = Path.join(base_path, "source_code.json")
    File.write!(
      source_code_path,
      Jason.encode!(%{"files" => source_code_map}, pretty: true)
    )
    IO.puts("Saved source code to #{source_code_path}")

    IO.puts("\nSaving trace data complete")
  end
end 