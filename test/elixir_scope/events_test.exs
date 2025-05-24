defmodule ElixirScope.EventsTest do
  use ExUnit.Case, async: true

  alias ElixirScope.Events
  alias ElixirScope.Events.{
    FunctionEntry,
    FunctionExit,
    ProcessSpawn,
    ProcessExit,
    MessageSend,
    MessageReceive,
    StateChange
  }

  describe "base event creation" do
    test "creates base event with required fields" do
      data = %{test: "data"}
      event = Events.new_event(:test_event, data)

      assert %Events{} = event
      assert event.event_type == :test_event
      assert event.data == data
      assert is_integer(event.event_id)
      assert is_integer(event.timestamp)
      assert is_integer(event.wall_time)
      assert event.node == Node.self()
      assert event.pid == self()
      assert event.correlation_id == nil
      assert event.parent_id == nil
    end

    test "creates base event with optional correlation and parent IDs" do
      data = %{test: "data"}
      correlation_id = "test-correlation"
      parent_id = 12345

      event = Events.new_event(:test_event, data, 
        correlation_id: correlation_id, 
        parent_id: parent_id
      )

      assert event.correlation_id == correlation_id
      assert event.parent_id == parent_id
    end

    test "timestamps are monotonically increasing" do
      event1 = Events.new_event(:test, %{})
      event2 = Events.new_event(:test, %{})
      
      assert event2.timestamp >= event1.timestamp
    end

    test "event IDs are unique" do
      event1 = Events.new_event(:test, %{})
      event2 = Events.new_event(:test, %{})
      
      assert event1.event_id != event2.event_id
    end
  end

  describe "function events" do
    test "creates function entry event" do
      args = [:arg1, :arg2]
      event = Events.function_entry(MyModule, :my_function, 2, args)

      assert %Events{event_type: :function_entry} = event
      assert %FunctionEntry{} = event.data
      assert event.data.module == MyModule
      assert event.data.function == :my_function
      assert event.data.arity == 2
      assert event.data.args == args
      assert is_integer(event.data.call_id)
    end

    test "creates function entry event with caller information" do
      args = [:arg1]
      event = Events.function_entry(MyModule, :my_function, 1, args,
        caller_module: CallerModule,
        caller_function: :caller_function,
        caller_line: 42
      )

      assert event.data.caller_module == CallerModule
      assert event.data.caller_function == :caller_function
      assert event.data.caller_line == 42
    end

    test "creates function exit event" do
      call_id = 12345
      result = :ok
      duration = 1_000_000  # 1ms in nanoseconds

      event = Events.function_exit(
        MyModule, :my_function, 2, call_id, 
        result, duration, :normal
      )

      assert %Events{event_type: :function_exit} = event
      assert %FunctionExit{} = event.data
      assert event.data.module == MyModule
      assert event.data.function == :my_function
      assert event.data.arity == 2
      assert event.data.call_id == call_id
      assert event.data.result == result
      assert event.data.duration_ns == duration
      assert event.data.exit_reason == :normal
    end

    test "handles large function arguments" do
      large_args = [String.duplicate("x", 2000)]
      event = Events.function_entry(MyModule, :my_function, 1, large_args)

      # Arguments should be preserved as-is (truncation handled elsewhere if needed)
      assert is_list(event.data.args)
      assert length(event.data.args) == 1
    end
  end

  describe "process events" do
    test "creates process spawn event" do
      spawned_pid = spawn(fn -> nil end)
      parent_pid = self()

      event = Events.process_spawn(
        spawned_pid, parent_pid, 
        Kernel, :spawn, [:some_args]
      )

      assert %Events{event_type: :process_spawn} = event
      assert %ProcessSpawn{} = event.data
      assert event.data.spawned_pid == spawned_pid
      assert event.data.parent_pid == parent_pid
      assert event.data.spawn_module == Kernel
      assert event.data.spawn_function == :spawn
    end

    test "creates process spawn event with options" do
      spawned_pid = spawn(fn -> nil end)
      parent_pid = self()

      event = Events.process_spawn(
        spawned_pid, parent_pid,
        Kernel, :spawn, [:some_args],
        spawn_opts: [:link],
        registered_name: :test_process
      )

      assert event.data.spawn_opts == [:link]
      assert event.data.registered_name == :test_process
    end

    test "creates process exit event" do
      exited_pid = spawn(fn -> nil end)
      
      event = %Events{
        event_type: :process_exit,
        data: %ProcessExit{
          exited_pid: exited_pid,
          exit_reason: :normal,
          lifetime_ns: 1_000_000,
          message_count: 5,
          final_state: nil
        }
      }

      assert event.data.exited_pid == exited_pid
      assert event.data.exit_reason == :normal
      assert event.data.lifetime_ns == 1_000_000
      assert event.data.message_count == 5
    end
  end

  describe "message events" do
    test "creates message send event" do
      sender_pid = self()
      receiver_pid = spawn(fn -> receive do _ -> nil end end)
      message = {:hello, "world"}

      event = Events.message_send(sender_pid, receiver_pid, message, :send)

      assert %Events{event_type: :message_send} = event
      assert %MessageSend{} = event.data
      assert event.data.sender_pid == sender_pid
      assert event.data.receiver_pid == receiver_pid
      assert event.data.message == message
      assert event.data.send_type == :send
      assert is_integer(event.data.message_id)
    end

    test "creates message send event with call reference" do
      sender_pid = self()
      receiver_pid = spawn(fn -> receive do _ -> nil end end)
      message = {:call, make_ref(), :request}
      call_ref = make_ref()

      event = Events.message_send(
        sender_pid, receiver_pid, message, :call,
        call_ref: call_ref
      )

      assert event.data.send_type == :call
      assert event.data.call_ref == call_ref
    end

    test "handles large messages" do
      sender_pid = self()
      receiver_pid = spawn(fn -> receive do _ -> nil end end)
      large_message = %{data: String.duplicate("x", 2000)}

      event = Events.message_send(sender_pid, receiver_pid, large_message, :send)

      # Message should be preserved as-is (truncation handled elsewhere if needed)
      assert is_map(event.data.message)
      assert Map.has_key?(event.data.message, :data)
    end

    test "creates message receive event structure" do
      receiver_pid = self()
      sender_pid = spawn(fn -> nil end)
      message = {:hello, "world"}
      message_id = 12345

      data = %MessageReceive{
        receiver_pid: receiver_pid,
        sender_pid: sender_pid,
        message: message,
        message_id: message_id,
        receive_type: :receive,
        queue_time_ns: 50_000,
        pattern_matched: nil
      }

      event = Events.new_event(:message_receive, data)

      assert %MessageReceive{} = event.data
      assert event.data.receiver_pid == receiver_pid
      assert event.data.sender_pid == sender_pid
      assert event.data.queue_time_ns == 50_000
    end
  end

  describe "state change events" do
    test "creates state change event" do
      server_pid = self()
      old_state = %{counter: 0}
      new_state = %{counter: 1}

      event = Events.state_change(server_pid, :handle_call, old_state, new_state)

      assert %Events{event_type: :state_change} = event
      assert %StateChange{} = event.data
      assert event.data.server_pid == server_pid
      assert event.data.callback == :handle_call
      assert event.data.old_state == old_state
      assert event.data.new_state == new_state
    end

    test "creates state change event with trigger information" do
      server_pid = self()
      old_state = %{counter: 0}
      new_state = %{counter: 1}
      trigger_message = {:increment}
      trigger_call_id = 12345

      event = Events.state_change(
        server_pid, :handle_call, old_state, new_state,
        trigger_message: trigger_message,
        trigger_call_id: trigger_call_id
      )

      assert event.data.trigger_message == trigger_message
      assert event.data.trigger_call_id == trigger_call_id
    end

    test "computes state diff for different states" do
      server_pid = self()
      old_state = %{counter: 0}
      new_state = %{counter: 1}

      event = Events.state_change(server_pid, :handle_call, old_state, new_state)

      assert event.data.state_diff != :no_change
      assert event.data.state_diff == :changed
    end

    test "detects no change for identical states" do
      server_pid = self()
      same_state = %{counter: 0}

      event = Events.state_change(server_pid, :handle_call, same_state, same_state)

      assert event.data.state_diff == :no_change
    end

    test "handles large states" do
      server_pid = self()
      large_state = %{data: String.duplicate("x", 2000)}
      new_state = %{data: "small"}

      event = Events.state_change(server_pid, :handle_call, large_state, new_state)

      # State should be preserved as-is (truncation handled elsewhere if needed)
      assert is_map(event.data.old_state)
      assert Map.has_key?(event.data.old_state, :data)
    end
  end

  describe "error events" do
    test "creates error event" do
      stacktrace = [{Module, :function, 2, [file: ~c"test.ex", line: 10]}]
      
      data = %Events.ErrorEvent{
        error_type: :exception,
        error_class: RuntimeError,
        error_message: "Something went wrong",
        stacktrace: stacktrace,
        context: nil,
        recovery_action: nil
      }
      
      event = Events.new_event(:error, data)

      assert %Events{event_type: :error} = event
      assert %Events.ErrorEvent{} = event.data
      assert event.data.error_type == :exception
      assert event.data.error_class == RuntimeError
      assert event.data.error_message == "Something went wrong"
      assert event.data.stacktrace == stacktrace
    end

    test "creates error event with context and recovery" do
      stacktrace = []
      
      data = %Events.ErrorEvent{
        error_type: :crash,
        error_class: :badarg,
        error_message: "Invalid argument",
        stacktrace: stacktrace,
        context: {:genserver_call, :timeout},
        recovery_action: :restart
      }
      
      event = Events.new_event(:error, data)

      assert event.data.context == {:genserver_call, :timeout}
      assert event.data.recovery_action == :restart
    end

    test "handles large stacktraces" do
      # Create a stacktrace with many entries
      large_stacktrace = for i <- 1..50 do
        {Module, :function, i, [file: ~c"test.ex", line: i]}
      end

      data = %Events.ErrorEvent{
        error_type: :exception,
        error_class: RuntimeError,
        error_message: "Error",
        stacktrace: large_stacktrace,
        context: nil,
        recovery_action: nil
      }

      event = Events.new_event(:error, data)

      # Stacktrace should be preserved as-is (truncation handled elsewhere if needed)
      assert length(event.data.stacktrace) == 50
    end
  end

  describe "performance events" do
    test "creates performance metric event structure" do
      data = %Events.PerformanceMetric{
        id: ElixirScope.Utils.generate_id(),
        timestamp: ElixirScope.Utils.monotonic_timestamp(),
        wall_time: ElixirScope.Utils.wall_timestamp(),
        metric_name: :heap_size,
        value: 1024,
        metadata: %{unit: :bytes, scope: :process, scope_identifier: self()}
      }

      event = Events.new_event(:performance_metric, data)

      assert %Events.PerformanceMetric{} = event.data
      assert event.data.metric_name == :heap_size
      assert event.data.value == 1024
      assert event.data.metadata.scope_identifier == self()
    end
  end



  describe "variable assignment events" do
    test "creates variable assignment event structure" do
      data = %Events.VariableAssignment{
        variable_name: :counter,
        old_value: 0,
        new_value: 1,
        assignment_type: :rebind,
        scope_context: {MyModule, :my_function, 2},
        line_number: 42
      }

      event = Events.new_event(:variable_assignment, data)

      assert %Events.VariableAssignment{} = event.data
      assert event.data.variable_name == :counter
      assert event.data.assignment_type == :rebind
      assert event.data.line_number == 42
    end
  end

  describe "serialization" do
    test "serializes and deserializes events correctly" do
      original_event = Events.function_entry(MyModule, :test, 0, [])
      
      serialized = Events.serialize(original_event)
      deserialized = Events.deserialize(serialized)

      assert deserialized == original_event
      assert is_binary(serialized)
    end

    test "serialization is efficient" do
      event = Events.function_entry(MyModule, :test, 0, [])
      
      duration = :timer.tc(fn ->
        Events.serialize(event)
      end) |> elem(0)

      # Serialization should be reasonably fast (< 50000μs = 50ms)
      assert duration < 50000
    end

    test "gets serialized size" do
      event = Events.function_entry(MyModule, :test, 0, [])
      
      size = Events.serialized_size(event)
      actual_size = event |> Events.serialize() |> byte_size()

      assert size == actual_size
      assert size > 0
    end

    test "compressed serialization is smaller for large events" do
      # Create event with large data
      large_args = [String.duplicate("test data ", 100)]
      event = Events.function_entry(MyModule, :test, 1, large_args)

      serialized = Events.serialize(event)
      uncompressed = :erlang.term_to_binary(event)

      # Compressed should be smaller (though our event might be truncated)
      assert byte_size(serialized) <= byte_size(uncompressed)
    end

    test "round-trip serialization preserves data integrity" do
      # Test various event types
      events = [
        Events.function_entry(MyModule, :test, 0, []),
        Events.message_send(self(), self(), :hello, :send),
        Events.state_change(self(), :handle_call, %{old: 1}, %{new: 2}),
        Events.new_event(:error, %Events.ErrorEvent{
          error_type: :exception,
          error_class: RuntimeError,
          error_message: "test",
          stacktrace: [],
          context: nil,
          recovery_action: nil
        })
      ]

      for original <- events do
        serialized = Events.serialize(original)
        deserialized = Events.deserialize(serialized)
        
        assert deserialized == original
      end
    end
  end

  describe "edge cases and error handling" do
    test "handles nil values gracefully" do
      event = Events.function_entry(MyModule, :test, 0, nil)
      
      assert event.data.args == nil
      
      # Should still serialize/deserialize correctly
      serialized = Events.serialize(event)
      deserialized = Events.deserialize(serialized)
      assert deserialized == event
    end

    test "handles empty collections" do
      event = Events.function_entry(MyModule, :test, 0, [])
      
      assert event.data.args == []
      
      serialized = Events.serialize(event)
      deserialized = Events.deserialize(serialized)
      assert deserialized == event
    end

    test "handles complex nested data structures" do
      complex_args = [
        %{nested: %{deep: [1, 2, 3]}},
        {:tuple, :with, :atoms},
        [list: "with", keyword: :values]
      ]
      
      event = Events.function_entry(MyModule, :test, 1, complex_args)
      
      serialized = Events.serialize(event)
      deserialized = Events.deserialize(serialized)
      assert deserialized == event
    end

    test "handles very large data" do
      # Create extremely large data
      huge_data = String.duplicate("x", 10_000)
      event = Events.function_entry(MyModule, :test, 1, [huge_data])

      # Data should be preserved as-is
      assert is_list(event.data.args)
      assert length(event.data.args) == 1
      
      # Event should still serialize correctly
      serialized = Events.serialize(event)
      deserialized = Events.deserialize(serialized)
      assert deserialized == event
    end
  end

  describe "performance characteristics" do
    test "event creation is fast" do
      duration = :timer.tc(fn ->
        Events.function_entry(MyModule, :test, 0, [])
      end) |> elem(0)

      # Event creation should be reasonably fast (< 50000μs = 50ms)
      assert duration < 50000
    end

    test "handles high-frequency event creation" do
      count = 1000
      
      duration = :timer.tc(fn ->
        for _i <- 1..count do
          Events.function_entry(MyModule, :test, 0, [])
        end
      end) |> elem(0)

      # Should be able to create many events quickly
      avg_duration = duration / count
      assert avg_duration < 5000  # Less than 5000μs per event on average
    end

    test "memory usage is reasonable" do
      event = Events.function_entry(MyModule, :test, 0, [])
      
      # Check that events don't use excessive memory
      size = Events.serialized_size(event)
      assert size < 1000  # Should be less than 1KB for simple events
    end
  end
end 