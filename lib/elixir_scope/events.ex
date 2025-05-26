defmodule ElixirScope.Events do
  @moduledoc """
  Core event structures for ElixirScope.

  Defines all event types that can be captured during execution and provides
  efficient serialization/deserialization for storage and transmission.

  Events are designed to be:
  - Lightweight with minimal overhead
  - Self-contained with all necessary context
  - Timestamped with high resolution
  - Correlated with unique IDs for causal analysis
  """

  #############################################################################
  # Base Event Structure
  #############################################################################

  @doc """
  Base event structure with common fields for all event types.
  """
  defstruct [
    :event_id,         # Unique identifier for this event
    :timestamp,        # High-resolution timestamp (monotonic nanoseconds)
    :wall_time,        # Wall clock time for human-readable timestamps
    :node,             # Node where event occurred
    :pid,              # Process ID where event occurred
    :correlation_id,   # Optional correlation ID for linking related events
    :parent_id,        # Optional parent event ID for hierarchical relationships
    :event_type,       # Type of event (:function_entry, :function_exit, etc.)
    :data              # Event-specific data
  ]

  #############################################################################
  # Function Execution Events
  #############################################################################

  defmodule FunctionExecution do
    @moduledoc "Event fired for function execution (call or return)"
    
    defstruct [
      :id,               # Unique event ID
      :timestamp,        # High-resolution timestamp
      :wall_time,        # Wall clock time
      :module,           # Module name
      :function,         # Function name  
      :arity,            # Function arity
      :args,             # Function arguments (may be truncated)
      :return_value,     # Return value (for return events)
      :duration_ns,      # Function execution time in nanoseconds
      :caller_pid,       # PID of calling process
      :correlation_id,   # Correlation ID for linking events
      :event_type        # :call or :return
    ]
  end

  defmodule FunctionEntry do
    @moduledoc "Event fired when entering a function"
    
    defstruct [
      :module,           # Module name
      :function,         # Function name  
      :arity,            # Function arity
      :args,             # Function arguments (may be truncated)
      :call_id,          # Unique call identifier for matching entry/exit
      :caller_module,    # Calling module (if available)
      :caller_function,  # Calling function (if available)
      :caller_line,      # Calling line number (if available)
      :pid,              # PID of the process (for runtime tracing)
      :correlation_id,   # Correlation ID for linking events
      :timestamp,        # High-resolution timestamp
      :wall_time         # Wall clock time
    ]
  end

  defmodule FunctionExit do
    @moduledoc "Event fired when exiting a function"
    
    defstruct [
      :module,           # Module name
      :function,         # Function name
      :arity,            # Function arity
      :call_id,          # Matching call identifier from entry
      :result,           # Return value or exception (may be truncated)
      :duration_ns,      # Function execution time in nanoseconds
      :exit_reason,      # :normal, :exception, :error, :exit, :throw
      :pid,              # PID of the process (for runtime tracing)
      :correlation_id,   # Correlation ID for linking events
      :timestamp,        # High-resolution timestamp
      :wall_time         # Wall clock time
    ]
  end

  #############################################################################
  # Process Events
  #############################################################################

  defmodule ProcessEvent do
    @moduledoc "Event fired for process lifecycle events"
    
    defstruct [
      :id,               # Unique event ID
      :timestamp,        # High-resolution timestamp
      :wall_time,        # Wall clock time
      :pid,              # PID of the process
      :parent_pid,       # PID of the parent process
      :event_type        # :spawn, :exit, :link, :unlink, etc.
    ]
  end

  defmodule ProcessSpawn do
    @moduledoc "Event fired when a process is spawned"
    
    defstruct [
      :spawned_pid,      # PID of the new process
      :parent_pid,       # PID of the spawning process
      :spawn_module,     # Module used for spawning
      :spawn_function,   # Function used for spawning
      :spawn_args,       # Arguments passed to spawn (may be truncated)
      :spawn_opts,       # Spawn options (if any)
      :registered_name   # Registered name (if any)
    ]
  end

  defmodule ProcessExit do
    @moduledoc "Event fired when a process exits"
    
    defstruct [
      :exited_pid,       # PID of the exiting process
      :exit_reason,      # Exit reason
      :lifetime_ns,      # Process lifetime in nanoseconds
      :message_count,    # Total messages processed (if available)
      :final_state,      # Final process state (if available, may be truncated)
      :pid,              # PID of the process (alias for exited_pid, for runtime tracing)
      :reason,           # Exit reason (alias for exit_reason, for runtime tracing)
      :correlation_id,   # Correlation ID for linking events
      :timestamp,        # High-resolution timestamp
      :wall_time         # Wall clock time
    ]
  end

  #############################################################################
  # Message Events
  #############################################################################

  defmodule MessageEvent do
    @moduledoc "Event fired for message passing events"
    
    defstruct [
      :id,               # Unique event ID
      :timestamp,        # High-resolution timestamp
      :wall_time,        # Wall clock time
      :from_pid,         # PID of the sending process
      :to_pid,           # PID of the receiving process
      :message,          # Message content (may be truncated)
      :event_type        # :send, :receive
    ]
  end

  defmodule MessageSend do
    @moduledoc "Event fired when a message is sent"
    
    defstruct [
      :sender_pid,       # PID of the sending process
      :receiver_pid,     # PID of the receiving process (or registered name)
      :message,          # Message content (may be truncated)
      :message_id,       # Unique message identifier
      :send_type,        # :send, :cast, :call, :info
      :call_ref          # Reference for call messages (if applicable)
    ]
  end

  defmodule MessageReceive do
    @moduledoc "Event fired when a message is received"
    
    defstruct [
      :receiver_pid,     # PID of the receiving process
      :sender_pid,       # PID of the sending process (if known)
      :message,          # Message content (may be truncated)
      :message_id,       # Matching message identifier from send
      :receive_type,     # :receive, :handle_call, :handle_cast, :handle_info
      :queue_time_ns,    # Time spent in message queue (nanoseconds)
      :pattern_matched   # Pattern that matched the message (if available)
    ]
  end

  # Alias for compatibility with runtime tracing code
  defmodule MessageReceived do
    @moduledoc "Alias for MessageReceive for runtime tracing compatibility"
    
    defstruct [
      :pid,              # PID of the receiving process
      :message,          # Message content (may be truncated)
      :correlation_id,   # Correlation ID for linking events
      :timestamp,        # High-resolution timestamp
      :wall_time         # Wall clock time
    ]
  end

  # Alias for compatibility with runtime tracing code  
  defmodule MessageSent do
    @moduledoc "Alias for MessageSend for runtime tracing compatibility"
    
    defstruct [
      :from_pid,         # PID of the sending process
      :to_pid,           # PID of the receiving process
      :message,          # Message content (may be truncated)
      :correlation_id,   # Correlation ID for linking events
      :timestamp,        # High-resolution timestamp
      :wall_time         # Wall clock time
    ]
  end

  #############################################################################
  # State Change Events
  #############################################################################

  defmodule StateChange do
    @moduledoc "Event fired when GenServer state changes"
    
    defstruct [
      :server_pid,       # PID of the GenServer
      :callback,         # Callback that caused the change (:handle_call, etc.)
      :old_state,        # Previous state (may be truncated)
      :new_state,        # New state (may be truncated)
      :state_diff,       # Diff between old and new state (if computed)
      :trigger_message,  # Message that triggered the change (if applicable)
      :trigger_call_id,  # Call ID that triggered the change (if applicable)
      :pid,              # PID of the process (alias for server_pid, for runtime tracing)
      :correlation_id,   # Correlation ID for linking events
      :timestamp,        # High-resolution timestamp
      :wall_time         # Wall clock time
    ]
  end

  defmodule StateSnapshot do
    @moduledoc "Event fired for periodic state snapshots during time-travel debugging"
    
    defstruct [
      :server_pid,       # PID of the GenServer
      :snapshot_id,      # Unique identifier for this snapshot
      :state,            # Complete state at this point in time
      :checkpoint_type,  # :periodic, :manual, :before_call, :after_call
      :sequence_number,  # Sequence number for ordering snapshots
      :memory_usage,     # Memory usage of the process at snapshot time
      :message_queue_len,# Length of message queue at snapshot time
      :pid,              # PID of the process (alias for server_pid, for runtime tracing)
      :session_id,       # Time-travel session ID
      :correlation_id,   # Correlation ID for linking events
      :timestamp,        # High-resolution timestamp
      :wall_time         # Wall clock time
    ]
  end

  defmodule CallbackReply do
    @moduledoc "Event fired when a GenServer callback returns a reply"
    
    defstruct [
      :server_pid,       # PID of the GenServer
      :callback,         # Callback that generated the reply
      :call_id,          # ID of the original call
      :reply,            # Reply value (may be truncated)
      :new_state,        # New state after callback (may be truncated)
      :timeout,          # Timeout value if set
      :hibernate,        # Whether process should hibernate
      :continue_data,    # Data for handle_continue if set
      :pid,              # PID of the process (alias for server_pid, for runtime tracing)
      :correlation_id,   # Correlation ID for linking events
      :timestamp,        # High-resolution timestamp
      :wall_time         # Wall clock time
    ]
  end

  defmodule VariableAssignment do
    @moduledoc "Event fired when a traced variable is assigned"
    
    defstruct [
      :variable_name,    # Name of the variable
      :old_value,        # Previous value (may be truncated)
      :new_value,        # New value (may be truncated)
      :assignment_type,  # :bind, :rebind, :pattern_match
      :scope_context,    # Function scope context
      :line_number       # Source code line number
    ]
  end

  #############################################################################
  # Performance Events
  #############################################################################

  defmodule PerformanceMetric do
    @moduledoc "Event fired for performance measurements"
    
    defstruct [
      :id,               # Unique event ID
      :timestamp,        # High-resolution timestamp
      :wall_time,        # Wall clock time
      :metric_name,      # Specific metric name
      :value,            # Metric value
      :metadata,         # Additional metadata
      :metric_type,      # :memory, :reductions, :garbage_collection, :scheduler
      :unit,             # Unit of measurement
      :source_context    # Where the metric was collected
    ]
  end

  defmodule GarbageCollection do
    @moduledoc "Event fired for garbage collection events"
    
    defstruct [
      :heap_size_before, # Heap size before GC (words)
      :heap_size_after,  # Heap size after GC (words)
      :old_heap_size,    # Old heap size (words)
      :stack_size,       # Stack size (words)
      :recent_size,      # Recent/younger generation size (words)
      :mbuf_size,        # Message buffer size (words)
      :gc_type,          # :minor, :major, :full
      :gc_reason,        # Reason for GC
      :duration_ns       # GC duration in nanoseconds
    ]
  end

  #############################################################################
  # Error Events
  #############################################################################

  defmodule ErrorEvent do
    @moduledoc "Event fired when an error occurs"
    
    defstruct [
      :error_type,       # Type of error (:exception, :error, :exit, :throw)
      :error_class,      # Error class (module name for exceptions)
      :error_message,    # Error message or reason (may be truncated)
      :stacktrace,       # Stack trace (may be truncated)
      :context,          # Context where error occurred
      :recovery_action   # Recovery action taken (if any)
    ]
  end

  defmodule CrashDump do
    @moduledoc "Event fired when a process crashes"
    
    defstruct [
      :crashed_pid,      # PID of the crashed process
      :supervisor_pid,   # PID of supervising process (if any)
      :restart_strategy, # Restart strategy used
      :restart_count,    # Number of restarts
      :crash_reason,     # Reason for crash
      :process_state,    # Final process state (may be truncated)
      :linked_pids,      # PIDs linked to crashed process
      :monitors          # Processes monitoring the crashed process
    ]
  end

  #############################################################################
  # VM Events
  #############################################################################

  defmodule VMEvent do
    @moduledoc "Event fired for VM-level events"
    
    defstruct [
      :event_type,       # VM event type
      :event_data,       # Event-specific data
      :scheduler_id,     # Scheduler ID (if relevant)
      :system_time,      # System timestamp
      :node_name         # Node where event occurred
    ]
  end

  defmodule SchedulerEvent do
    @moduledoc "Event fired for scheduler events"
    
    defstruct [
      :scheduler_id,     # Scheduler identifier
      :event_type,       # :in, :out, :exited, :started
      :process_count,    # Number of processes in scheduler queue
      :port_count,       # Number of ports in scheduler
      :run_queue_length, # Length of run queue
      :utilization       # Scheduler utilization percentage
    ]
  end

  defmodule NodeEvent do
    @moduledoc "Event fired for distributed node events"
    
    defstruct [
      :event_type,       # :nodeup, :nodedown, :net_tick_timeout
      :node_name,        # Name of the node
      :node_type,        # :visible, :hidden
      :connection_id,    # Connection identifier
      :extra_info        # Additional event-specific information
    ]
  end

  #############################################################################
  # ETS/DETS Events
  #############################################################################

  defmodule TableEvent do
    @moduledoc "Event fired for ETS/DETS table operations"
    
    defstruct [
      :table_name,       # Table name or reference
      :table_type,       # :ets or :dets
      :operation,        # :insert, :delete, :lookup, :select, etc.
      :key,              # Key involved in operation (may be truncated)
      :value,            # Value involved in operation (may be truncated)
      :operation_count,  # Number of records affected
      :execution_time_ns # Operation execution time
    ]
  end

  #############################################################################
  # Trace Control Events
  #############################################################################

  defmodule TraceControl do
    @moduledoc "Event fired for trace control operations"
    
    defstruct [
      :operation,        # :start, :stop, :pause, :resume
      :trace_type,       # Type of tracing being controlled
      :target,           # Target of trace control (process, module, etc.)
      :trace_flags,      # Trace flags being set/unset
      :reason            # Reason for trace control operation
    ]
  end

  #############################################################################
  # Event Wrapper and Utilities
  #############################################################################

  @doc """
  Creates a new event with automatic metadata injection.
  
  This is the recommended way to create events as it automatically populates
  common fields like timestamp, node, and generates unique IDs.
  """
  def new_event(event_type, data, opts \\ []) do
    %__MODULE__{
      event_id: Keyword.get_lazy(opts, :event_id, &ElixirScope.Utils.generate_id/0),
      timestamp: Keyword.get_lazy(opts, :timestamp, &ElixirScope.Utils.monotonic_timestamp/0),
      wall_time: Keyword.get_lazy(opts, :wall_time, &ElixirScope.Utils.wall_timestamp/0),
      node: Keyword.get(opts, :node, node()),
      pid: Keyword.get(opts, :pid, self()),
      correlation_id: Keyword.get(opts, :correlation_id),
      parent_id: Keyword.get(opts, :parent_id),
      event_type: event_type,
      data: data
    }
  end

  @doc """
  Serializes an event to binary format for efficient storage.
  """
  def serialize(event) do
    :erlang.term_to_binary(event, [:compressed])
  end

  @doc """
  Deserializes an event from binary format.
  """
  def deserialize(binary) when is_binary(binary) do
    :erlang.binary_to_term(binary, [:safe])
  end

  # Test helper functions (backward compatibility)
  def function_entry(module, function, arity, args, opts \\ []) do
    data = %FunctionEntry{
      module: module,
      function: function,
      arity: arity,
      args: args,
      call_id: ElixirScope.Utils.generate_id(),
      caller_module: Keyword.get(opts, :caller_module),
      caller_function: Keyword.get(opts, :caller_function),
      caller_line: Keyword.get(opts, :caller_line)
    }
    new_event(:function_entry, data, opts)
  end

  def message_send(sender_pid, receiver_pid, message, send_type, opts \\ []) do
    data = %MessageSend{
      sender_pid: sender_pid,
      receiver_pid: receiver_pid,
      message: message,
      message_id: ElixirScope.Utils.generate_id(),
      send_type: send_type,
      call_ref: Keyword.get(opts, :call_ref)
    }
    new_event(:message_send, data, opts)
  end

  def state_change(server_pid, callback, old_state, new_state, opts \\ []) do
    data = %StateChange{
      server_pid: server_pid,
      callback: callback,
      old_state: old_state,
      new_state: new_state,
      state_diff: if(old_state == new_state, do: :no_change, else: :changed),
      trigger_message: Keyword.get(opts, :trigger_message),
      trigger_call_id: Keyword.get(opts, :trigger_call_id)
    }
    new_event(:state_change, data, opts)
  end

  def function_exit(module, function, arity, call_id, result, duration_ns, exit_reason, opts \\ []) do
    data = %FunctionExit{
      module: module,
      function: function,
      arity: arity,
      call_id: call_id,
      result: result,
      duration_ns: duration_ns,
      exit_reason: exit_reason
    }
    new_event(:function_exit, data, opts)
  end

  def process_spawn(spawned_pid, parent_pid, spawn_module, spawn_function, spawn_args, opts \\ []) do
    data = %ProcessSpawn{
      spawned_pid: spawned_pid,
      parent_pid: parent_pid,
      spawn_module: spawn_module,
      spawn_function: spawn_function,
      spawn_args: spawn_args,
      spawn_opts: Keyword.get(opts, :spawn_opts),
      registered_name: Keyword.get(opts, :registered_name)
    }
    new_event(:process_spawn, data, opts)
  end

  def serialized_size(event) do
    event |> serialize() |> byte_size()
  end
end 