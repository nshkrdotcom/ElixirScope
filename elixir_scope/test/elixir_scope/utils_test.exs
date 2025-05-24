defmodule ElixirScope.UtilsTest do
  use ExUnit.Case, async: true
  alias ElixirScope.Utils
  import Kernel # Explicitly import Kernel to see if it resolves is_string/is_integer issues

  describe "generate_event_id/0" do
    test "returns a string" do
      event_id = Utils.generate_event_id()
      assert Kernel.is_string(event_id) # Using Kernel.is_string explicitly
    end

    test "returns different IDs on consecutive calls" do
      event_id_1 = Utils.generate_event_id()
      event_id_2 = Utils.generate_event_id()
      assert event_id_1 != event_id_2
    end

    test "returns an ID matching UUID format" do
      event_id = Utils.generate_event_id()
      # Basic UUID v4 format regex (xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx)
      # y can be 8, 9, a, or b.
      assert Regex.match?(~r/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i, event_id)
    end
  end

  describe "monotonic_time_ns/0" do
    test "returns an integer" do
      time_ns = Utils.monotonic_time_ns()
      assert Kernel.is_integer(time_ns) # Using Kernel.is_integer explicitly
    end

    test "subsequent calls return non-decreasing time" do
      time_ns_1 = Utils.monotonic_time_ns()
      time_ns_2 = Utils.monotonic_time_ns()
      assert time_ns_2 >= time_ns_1
    end

    test "returns a positive integer" do
      time_ns = Utils.monotonic_time_ns()
      assert time_ns > 0
    end
  end
end
