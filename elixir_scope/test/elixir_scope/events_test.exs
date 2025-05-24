defmodule ElixirScope.EventsTest do
  use ExUnit.Case, async: true

  alias ElixirScope.Events.FunctionEntryEvent
  alias ElixirScope.Events.FunctionExitEvent
  alias ElixirScope.Events.StateChangeEvent
  alias ElixirScope.Events.MessageEvent

  describe "FunctionEntryEvent" do
    test "can be created with default values" do
      event = %FunctionEntryEvent{}
      assert event.event_id == nil
      assert event.timestamp == nil
      assert event.pid == nil
      assert event.module == nil
      assert event.function == nil
      assert event.args == []
    end

    test "can be created with specific values" do
      pid = self()
      timestamp = System.os_time(:nanosecond)
      event = %FunctionEntryEvent{
        event_id: "uuid-entry-123",
        timestamp: timestamp,
        pid: pid,
        module: MyModule,
        function: :my_function,
        args: [1, :two, "three"]
      }
      assert event.event_id == "uuid-entry-123"
      assert event.timestamp == timestamp
      assert event.pid == pid
      assert event.module == MyModule
      assert event.function == :my_function
      assert event.args == [1, :two, "three"]
    end
  end

  describe "FunctionExitEvent" do
    test "can be created with default values" do
      event = %FunctionExitEvent{}
      assert event.event_id == nil
      assert event.timestamp == nil
      assert event.pid == nil
      assert event.module == nil
      assert event.function == nil
      assert event.result == nil
    end

    test "can be created with specific values" do
      pid = self()
      timestamp = System.os_time(:nanosecond)
      event = %FunctionExitEvent{
        event_id: "uuid-exit-456",
        timestamp: timestamp,
        pid: pid,
        module: AnotherModule,
        function: :another_function,
        result: {:ok, "success"}
      }
      assert event.event_id == "uuid-exit-456"
      assert event.timestamp == timestamp
      assert event.pid == pid
      assert event.module == AnotherModule
      assert event.function == :another_function
      assert event.result == {:ok, "success"}
    end
  end

  describe "StateChangeEvent" do
    test "can be created with default values" do
      event = %StateChangeEvent{}
      assert event.event_id == nil
      assert event.timestamp == nil
      assert event.pid == nil
      assert event.process_name == nil
      assert event.old_state == nil
      assert event.new_state == nil
    end

    test "can be created with specific values" do
      pid = self()
      timestamp = System.os_time(:nanosecond)
      event = %StateChangeEvent{
        event_id: "uuid-state-789",
        timestamp: timestamp,
        pid: pid,
        process_name: :my_genserver,
        old_state: %{count: 0},
        new_state: %{count: 1}
      }
      assert event.event_id == "uuid-state-789"
      assert event.timestamp == timestamp
      assert event.pid == pid
      assert event.process_name == :my_genserver
      assert event.old_state == %{count: 0}
      assert event.new_state == %{count: 1}
    end
  end

  describe "MessageEvent" do
    test "can be created with default values" do
      event = %MessageEvent{}
      assert event.event_id == nil
      assert event.timestamp == nil
      assert event.type == nil
      assert event.pid_sender == nil
      assert event.pid_receiver == nil
      assert event.message == nil
    end

    test "can be created with specific values" do
      sender_pid = self()
      receiver_pid = spawn(fn -> :timer.sleep(10) end)
      timestamp = System.os_time(:nanosecond)
      event = %MessageEvent{
        event_id: "uuid-message-012",
        timestamp: timestamp,
        type: :send,
        pid_sender: sender_pid,
        pid_receiver: receiver_pid,
        message: {:ping, "hello"}
      }
      assert event.event_id == "uuid-message-012"
      assert event.timestamp == timestamp
      assert event.type == :send
      assert event.pid_sender == sender_pid
      assert event.pid_receiver == receiver_pid
      assert event.message == {:ping, "hello"}
    end
  end
end
