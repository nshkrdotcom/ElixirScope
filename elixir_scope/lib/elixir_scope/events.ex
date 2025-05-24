defmodule ElixirScope.Events do
  @moduledoc """
  Defines the core data structures for events captured by ElixirScope.

  These events represent various activities within an Elixir application,
  such as function calls, state changes, and message passing. Each event
  is timestamped and carries relevant contextual information.
  """

  @typedoc """
  A unique identifier for an event. Typically a UUID.
  """
  @type event_id :: String.t()

  @typedoc """
  Timestamp in nanoseconds since the Unix epoch.
  """
  @type timestamp_ns :: integer()

  defmodule FunctionEntryEvent do
    @moduledoc """
    Event recorded when a function is entered.
    """
    @derive {Jason.Encoder, only: [:event_id, :timestamp, :pid, :module, :function, :args]}
    defstruct event_id: nil,    # Unique ID for this event
              timestamp: nil,   # Nanosecond precision timestamp
              pid: nil,         # PID of the process calling the function
              module: nil,      # Module of the function being called
              function: nil,    # Name of the function being called
              args: []          # Arguments passed to the function

    @type t :: %__MODULE__{
            event_id: ElixirScope.Events.event_id(),
            timestamp: ElixirScope.Events.timestamp_ns(),
            pid: pid(),
            module: module(),
            function: atom(),
            args: list()
          }
  end

  defmodule FunctionExitEvent do
    @moduledoc """
    Event recorded when a function exits.
    """
    @derive {Jason.Encoder, only: [:event_id, :timestamp, :pid, :module, :function, :result]}
    defstruct event_id: nil,    # Unique ID for this event
              timestamp: nil,   # Nanosecond precision timestamp
              pid: nil,         # PID of the process that called the function
              module: nil,      # Module of the function that was called
              function: nil,    # Name of the function that was called
              result: nil       # The value returned by the function

    @type t :: %__MODULE__{
            event_id: ElixirScope.Events.event_id(),
            timestamp: ElixirScope.Events.timestamp_ns(),
            pid: pid(),
            module: module(),
            function: atom(),
            result: any()
          }
  end

  defmodule StateChangeEvent do
    @moduledoc """
    Event recorded when a process's state changes.
    Relevant for GenServer, GenStatem, etc.
    """
    @derive {Jason.Encoder, only: [:event_id, :timestamp, :pid, :process_name, :old_state, :new_state]}
    defstruct event_id: nil,        # Unique ID for this event
              timestamp: nil,       # Nanosecond precision timestamp
              pid: nil,             # PID of the process whose state changed
              process_name: nil,    # Registered name of the process (optional)
              old_state: nil,       # The state before the change
              new_state: nil        # The state after the change

    @type t :: %__MODULE__{
            event_id: ElixirScope.Events.event_id(),
            timestamp: ElixirScope.Events.timestamp_ns(),
            pid: pid(),
            process_name: atom() | String.t() | nil,
            old_state: any(),
            new_state: any()
          }
  end

  defmodule MessageEvent do
    @moduledoc """
    Event recorded when a message is sent or received.
    """
    @derive {Jason.Encoder, only: [:event_id, :timestamp, :type, :pid_sender, :pid_receiver, :message]}
    defstruct event_id: nil,        # Unique ID for this event
              timestamp: nil,       # Nanosecond precision timestamp
              type: nil,            # :send or :receive
              pid_sender: nil,      # PID of the sending process
              pid_receiver: nil,    # PID of the receiving process (for :send) or current process (for :receive)
              message: nil          # The message content

    @type t :: %__MODULE__{
            event_id: ElixirScope.Events.event_id(),
            timestamp: ElixirScope.Events.timestamp_ns(),
            type: :send | :receive,
            pid_sender: pid(),
            pid_receiver: pid(),
            message: any()
          }
  end
end
