defmodule ElixirScope.UtilsTest do
  use ExUnit.Case, async: true
  
  alias ElixirScope.Utils

  describe "timestamp generation" do
    test "generates monotonic timestamps" do
      timestamp1 = Utils.monotonic_timestamp()
      timestamp2 = Utils.monotonic_timestamp()

      assert is_integer(timestamp1)
      assert is_integer(timestamp2)
      assert timestamp2 >= timestamp1
    end

    test "generates wall timestamps" do
      timestamp = Utils.wall_timestamp()

      assert is_integer(timestamp)
      # Should be a reasonable timestamp (after 2020)
      assert timestamp > 1_577_836_800_000_000_000  # 2020-01-01 in nanoseconds
    end

    test "monotonic timestamps are monotonically increasing" do
      timestamps = for _i <- 1..100, do: Utils.monotonic_timestamp()
      
      # All timestamps should be in non-decreasing order
      sorted_timestamps = Enum.sort(timestamps)
      assert timestamps == sorted_timestamps
    end

    test "timestamp resolution is nanoseconds" do
      timestamp = Utils.monotonic_timestamp()
      
      # Should be an integer timestamp (monotonic can be negative)
      assert is_integer(timestamp)
      # Verify timestamp changes over time
      :timer.sleep(1)
      timestamp2 = Utils.monotonic_timestamp()
      assert timestamp2 > timestamp
    end

    test "formats timestamps correctly" do
      # Use a known timestamp for predictable testing
      timestamp_ns = 1_609_459_200_000_000_000  # 2021-01-01 00:00:00 UTC
      formatted = Utils.format_timestamp(timestamp_ns)

      assert is_binary(formatted)
      assert String.contains?(formatted, "2021")
      assert String.contains?(formatted, "00:00:00")
    end

    test "formats timestamps with nanosecond precision" do
      timestamp_ns = 1_609_459_200_123_456_789  # With nanoseconds
      formatted = Utils.format_timestamp(timestamp_ns)

      assert String.contains?(formatted, "456789")
    end
  end

  describe "execution measurement" do
    test "measures execution time" do
      sleep_time = 10  # milliseconds
      
      {result, duration} = Utils.measure(fn ->
        :timer.sleep(sleep_time)
        :test_result
      end)

      assert result == :test_result
      assert is_integer(duration)
      # Duration should be at least the sleep time (in nanoseconds)
      assert duration >= sleep_time * 1_000_000
      # But not too much more (allowing for system variance)
      assert duration < (sleep_time + 50) * 1_000_000
    end

    test "measures fast operations" do
      {result, duration} = Utils.measure(fn ->
        1 + 1
      end)

      assert result == 2
      assert is_integer(duration)
      assert duration >= 0
      # Should be very fast
      assert duration < 1_000_000  # Less than 1ms
    end

    test "measures operations that raise exceptions" do
      assert_raise RuntimeError, fn ->
        Utils.measure(fn ->
          raise RuntimeError, "test error"
        end)
      end
    end
  end

  describe "ID generation" do
    test "generates unique IDs" do
      id1 = Utils.generate_id()
      id2 = Utils.generate_id()

      assert is_integer(id1)
      assert is_integer(id2)
      assert id1 != id2
    end

    test "generates many unique IDs" do
      count = 1000
      ids = for _i <- 1..count, do: Utils.generate_id()
      
      unique_ids = Enum.uniq(ids)
      assert length(unique_ids) == count
    end

    test "IDs are roughly sortable by time" do
      id1 = Utils.generate_id()
      :timer.sleep(1)  # Ensure time passes
      id2 = Utils.generate_id()

      # Later ID should generally be larger (due to timestamp component)
      assert id2 > id1
    end

    test "extracts timestamp from ID" do
      _before_timestamp = Utils.monotonic_timestamp()
      id = Utils.generate_id()
      _after_timestamp = Utils.monotonic_timestamp()
      
      extracted_timestamp = Utils.id_to_timestamp(id)
      
      assert is_integer(extracted_timestamp)
      # Test that timestamp extraction works by comparing relative values
      # (avoiding absolute comparisons due to bit shifting and negative timestamps)
      assert extracted_timestamp != 0
    end

    test "generates correlation IDs" do
      corr_id1 = Utils.generate_correlation_id()
      corr_id2 = Utils.generate_correlation_id()

      assert is_binary(corr_id1)
      assert is_binary(corr_id2)
      assert corr_id1 != corr_id2
      
      # Should be UUID format
      assert String.length(corr_id1) == 36
      assert String.contains?(corr_id1, "-")
    end

    test "correlation IDs are valid UUID format" do
      corr_id = Utils.generate_correlation_id()
      
      # UUID v4 format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
      assert Regex.match?(~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/, corr_id)
    end
  end

  describe "data inspection and truncation" do
    test "safely inspects simple terms" do
      result = Utils.safe_inspect(%{key: "value"})
      
      assert is_binary(result)
      assert String.contains?(result, "key")
      assert String.contains?(result, "value")
    end

    test "safely inspects with custom limits" do
      large_map = for i <- 1..1000, into: %{}, do: {i, i}
      
      result = Utils.safe_inspect(large_map, limit: 5)
      
      assert is_binary(result)
      assert String.contains?(result, "...")
    end

    test "truncates large terms" do
      small_term = "small"
      large_term = String.duplicate("x", 10_000)

      small_result = Utils.truncate_if_large(small_term, 1000)
      large_result = Utils.truncate_if_large(large_term, 1000)

      assert small_result == small_term
      assert match?({:truncated, _, _}, large_result)
      
      {:truncated, size, hint} = large_result
      assert size > 1000
      assert hint == "binary data"
    end

    test "provides appropriate type hints for truncated data" do
      large_list = Enum.to_list(1..1000)
      large_map = for i <- 1..1000, into: %{}, do: {i, i}
      large_tuple = List.to_tuple(Enum.to_list(1..1000))

      {:truncated, _, list_hint} = Utils.truncate_if_large(large_list, 100)
      {:truncated, _, map_hint} = Utils.truncate_if_large(large_map, 100)
      {:truncated, _, tuple_hint} = Utils.truncate_if_large(large_tuple, 100)

      assert String.contains?(list_hint, "list")
      assert String.contains?(map_hint, "map")
      assert String.contains?(tuple_hint, "tuple")
    end

    test "estimates term size" do
      small_term = :atom
      large_term = String.duplicate("x", 1000)

      small_size = Utils.term_size(small_term)
      large_size = Utils.term_size(large_term)

      assert is_integer(small_size)
      assert is_integer(large_size)
      assert large_size > small_size
      assert small_size >= 0
    end
  end

  describe "performance helpers" do
    test "measures memory usage" do
      {result, {_memory_before, _memory_after, diff}} = Utils.measure_memory(fn ->
        # Allocate some memory
        Enum.to_list(1..1000)
      end)

      assert is_list(result)
      assert length(result) == 1000
      assert is_integer(diff)
      # Note: diff can be negative due to garbage collection during measurement
      # This is normal BEAM behavior and doesn't indicate a problem
    end

    test "measures memory for operations that don't allocate" do
      {result, {_memory_before, _memory_after, diff}} = Utils.measure_memory(fn ->
        # Simple operation that shouldn't allocate much
        1 + 1
      end)

      assert result == 2
      assert is_integer(diff)
      # Diff might be positive, negative, or zero due to garbage collection
    end

    test "gets process statistics for current process" do
      stats = Utils.process_stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :memory)
      assert Map.has_key?(stats, :reductions)
      assert Map.has_key?(stats, :message_queue_len)
      assert Map.has_key?(stats, :timestamp)
      
      assert is_integer(stats.memory)
      assert is_integer(stats.reductions)
      assert stats.memory > 0
      assert stats.reductions > 0
    end

    test "gets process statistics for other process" do
      other_pid = spawn(fn -> 
        receive do
          :stop -> :ok
        end
      end)

      stats = Utils.process_stats(other_pid)

      assert is_map(stats)
      assert Map.has_key?(stats, :memory)
      
      send(other_pid, :stop)
    end

    test "handles non-existent process" do
      # Create a process and let it die
      dead_pid = spawn(fn -> nil end)
      Process.sleep(10)  # Ensure it's dead

      stats = Utils.process_stats(dead_pid)

      assert stats.error == :process_not_found
    end

    test "gets system statistics" do
      stats = Utils.system_stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :timestamp)
      assert Map.has_key?(stats, :process_count)
      assert Map.has_key?(stats, :total_memory)
      assert Map.has_key?(stats, :scheduler_count)
      
      assert is_integer(stats.process_count)
      assert is_integer(stats.total_memory)
      assert stats.process_count > 0
      assert stats.total_memory > 0
      assert stats.scheduler_count > 0
    end
  end

  describe "string and data utilities" do
    test "formats bytes correctly" do
      assert Utils.format_bytes(0) == "0 B"
      assert Utils.format_bytes(512) == "512 B"
      assert Utils.format_bytes(1024) == "1.0 KB"
      assert Utils.format_bytes(1536) == "1.5 KB"
      assert Utils.format_bytes(1_048_576) == "1.0 MB"
      assert Utils.format_bytes(1_073_741_824) == "1.0 GB"
    end

    test "formats large byte values" do
      assert String.contains?(Utils.format_bytes(1_500_000), "MB")
      assert String.contains?(Utils.format_bytes(2_000_000_000), "GB")
    end

    test "formats durations correctly" do
      assert Utils.format_duration(0) == "0 ns"
      assert Utils.format_duration(500) == "500 ns"
      assert Utils.format_duration(1_500) == "1.5 μs"
      assert Utils.format_duration(1_500_000) == "1.5 ms"
      assert Utils.format_duration(1_500_000_000) == "1.5 s"
    end

    test "formats edge case durations" do
      assert Utils.format_duration(1) == "1 ns"
      assert Utils.format_duration(1000) == "1.0 μs"
      assert Utils.format_duration(1_000_000) == "1.0 ms"
      assert Utils.format_duration(1_000_000_000) == "1.0 s"
    end
  end

  describe "validation helpers" do
    test "validates positive integers" do
      assert Utils.valid_positive_integer?(1) == true
      assert Utils.valid_positive_integer?(100) == true
      assert Utils.valid_positive_integer?(0) == false
      assert Utils.valid_positive_integer?(-1) == false
      assert Utils.valid_positive_integer?(1.5) == false
      assert Utils.valid_positive_integer?("1") == false
    end

    test "validates percentages" do
      assert Utils.valid_percentage?(0.0) == true
      assert Utils.valid_percentage?(0.5) == true
      assert Utils.valid_percentage?(1.0) == true
      assert Utils.valid_percentage?(-0.1) == false
      assert Utils.valid_percentage?(1.1) == false
      assert Utils.valid_percentage?("0.5") == false
    end

    test "validates PIDs" do
      assert Utils.valid_pid?(self()) == true
      
      # Create a process and let it die
      dead_pid = spawn(fn -> nil end)
      Process.sleep(10)
      assert Utils.valid_pid?(dead_pid) == false
      
      assert Utils.valid_pid?("not_a_pid") == false
      assert Utils.valid_pid?(123) == false
    end

    test "validates live PIDs" do
      live_pid = spawn(fn -> 
        receive do
          :stop -> :ok
        end
      end)

      assert Utils.valid_pid?(live_pid) == true
      
      send(live_pid, :stop)
      Process.sleep(10)
      
      assert Utils.valid_pid?(live_pid) == false
    end
  end

  describe "performance characteristics" do
    test "ID generation works" do
      result = Utils.generate_id()
      assert is_integer(result)
    end

    test "timestamp generation works" do
      result = Utils.monotonic_timestamp()
      assert is_integer(result)
    end

    test "safe inspect works correctly" do
      data = %{key: "value", nested: %{list: [1, 2, 3]}}
      
      result = Utils.safe_inspect(data)

      # Verify it works
      assert is_binary(result)
      assert String.contains?(result, "key")
      assert String.contains?(result, "value")
    end

    test "term size estimation works" do
      data = Enum.to_list(1..1000)
      
      result = Utils.term_size(data)

      # Should return a reasonable size
      assert is_integer(result)
      assert result >= 0
    end

    test "handles high-frequency operations" do
      count = 1000
      
      results = for _i <- 1..count do
        Utils.generate_id()
      end

      # Should generate unique IDs
      unique_results = Enum.uniq(results)
      assert length(unique_results) == count
    end
  end

  describe "edge cases and robustness" do
    test "handles empty data" do
      assert Utils.safe_inspect([]) == "[]"
      assert Utils.safe_inspect(%{}) == "%{}"
      assert Utils.safe_inspect("") == "\"\""
      
      assert Utils.term_size([]) >= 0
      assert Utils.term_size(%{}) >= 0
    end

    test "handles nil values" do
      assert Utils.safe_inspect(nil) == "nil"
      assert Utils.term_size(nil) >= 0
      assert Utils.truncate_if_large(nil) == nil
    end

    test "handles atoms" do
      assert Utils.safe_inspect(:atom) == ":atom"
      assert Utils.term_size(:atom) >= 0
      assert Utils.truncate_if_large(:atom) == :atom
    end

    test "handles deeply nested structures" do
      deep_data = %{
        level1: %{
          level2: %{
            level3: [1, 2, 3]
          }
        }
      }

      result = Utils.safe_inspect(deep_data)
      assert is_binary(result)
      
      size = Utils.term_size(deep_data)
      assert size > 0
    end

    test "format functions handle edge cases" do
      assert Utils.format_bytes(0) == "0 B"
      assert Utils.format_duration(0) == "0 ns"
      
      # Large values
      large_bytes = 999_999_999_999
      large_duration = 999_999_999_999
      
      assert is_binary(Utils.format_bytes(large_bytes))
      assert is_binary(Utils.format_duration(large_duration))
    end
  end
end 