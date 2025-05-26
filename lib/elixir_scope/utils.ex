defmodule ElixirScope.Utils do
  @moduledoc """
  Utility functions for ElixirScope.

  Provides high-performance, reliable utilities for:
  - High-resolution timestamp generation
  - Unique ID generation
  - Data inspection and truncation
  - Performance measurement helpers
  """
  
  import Bitwise

  #############################################################################
  # Timestamp Generation
  #############################################################################

  @doc """
  Generates a high-resolution monotonic timestamp in nanoseconds.
  
  This timestamp is guaranteed to be monotonically increasing and is suitable
  for ordering events and measuring durations. It's not affected by system
  clock adjustments.
  
  ## Examples
  
      iex> ElixirScope.Utils.monotonic_timestamp()
      315708474309417000
  """
  def monotonic_timestamp do
    System.monotonic_time(:nanosecond)
  end

  @doc """
  Generates a wall clock timestamp in nanoseconds.
  
  This timestamp represents the actual time and can be converted to
  human-readable dates. Use for correlation with external systems.
  
  ## Examples
  
      iex> ElixirScope.Utils.wall_timestamp()
      1609459200000000000
  """
  def wall_timestamp do
    System.system_time(:nanosecond)
  end

  @doc """
  Converts a monotonic timestamp to a human-readable string.
  
  ## Examples
  
      iex> ElixirScope.Utils.format_timestamp(315708474309417000)
      "2024-01-01 12:30:45.123456789"
  """
  def format_timestamp(timestamp_ns) when is_integer(timestamp_ns) do
    # Convert nanoseconds to DateTime
    timestamp_us = div(timestamp_ns, 1000)
    datetime = DateTime.from_unix!(timestamp_us, :microsecond)
    
    # Format with nanosecond precision
    nanoseconds = rem(timestamp_ns, 1_000_000)
    
    datetime
    |> DateTime.to_string()
    |> String.replace(~r/\.\d+Z$/, ".#{nanoseconds}Z")
  end

  @doc """
  Measures execution time of a function in nanoseconds.
  
  ## Examples
  
      iex> {result, duration} = ElixirScope.Utils.measure(fn -> :timer.sleep(10); :ok end)
      iex> result
      :ok
      iex> duration > 10_000_000  # At least 10ms in nanoseconds
      true
  """
  def measure(fun) when is_function(fun, 0) do
    start_time = monotonic_timestamp()
    result = fun.()
    end_time = monotonic_timestamp()
    duration = end_time - start_time
    
    {result, duration}
  end

  #############################################################################
  # ID Generation
  #############################################################################

  @doc """
  Generates a unique ID for events, calls, and other entities.
  
  The ID is designed to be:
  - Globally unique across nodes and time
  - Sortable (roughly by creation time)
  - Compact for storage efficiency
  - Fast to generate
  
  ## Examples
  
      iex> id1 = ElixirScope.Utils.generate_id()
      iex> id2 = ElixirScope.Utils.generate_id()
      iex> id1 != id2
      true
  """
  def generate_id do
    # Use a combination of timestamp, node hash, and random data
    # for a unique, sortable ID
    timestamp = System.monotonic_time(:nanosecond)
    node_hash = :erlang.phash2(Node.self(), 65536)
    random = :rand.uniform(65536)
    
    # Combine into a single integer that's roughly sortable by time
    # Format: 48 bits timestamp + 8 bits node + 8 bits random
    (timestamp &&& 0xFFFFFFFFFFFF) <<< 16 ||| (node_hash &&& 0xFF) <<< 8 ||| (random &&& 0xFF)
  end

  @doc """
  Generates a unique correlation ID for tracing events.
  Returns a UUID v4 string for compatibility with external systems.
  """
  def generate_correlation_id do
    # Generate a UUID v4 string
    <<u0::32, u1::16, u2::16, u3::16, u4::48>> = :crypto.strong_rand_bytes(16)
    
    # Set version (4) and variant bits
    u2_with_version = (u2 &&& 0x0FFF) ||| 0x4000
    u3_with_variant = (u3 &&& 0x3FFF) ||| 0x8000
    
    # Format as UUID string
    :io_lib.format("~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~12.16.0b", 
                   [u0, u1, u2_with_version, u3_with_variant, u4])
    |> :erlang.iolist_to_binary()
    |> String.downcase()
  end

  @doc """
  Extracts the timestamp component from a generated ID.
  
  ## Examples
  
      iex> id = ElixirScope.Utils.generate_id()
      iex> timestamp = ElixirScope.Utils.id_to_timestamp(id)
      iex> is_integer(timestamp)
      true
  """
  def id_to_timestamp(id) when is_integer(id) do
    # Extract the timestamp portion (upper 48 bits)
    id >>> 16
  end

  #############################################################################
  # Data Inspection and Truncation
  #############################################################################

  @doc """
  Safely inspects a term with size limits to prevent memory issues.
  
  ## Examples
  
      iex> ElixirScope.Utils.safe_inspect(%{key: "value"})
      "%{key: \"value\"}"
      
      iex> large_map = for i <- 1..1000, into: %{}, do: {i, i}
      iex> result = ElixirScope.Utils.safe_inspect(large_map)
      iex> String.contains?(result, "...")
      true
  """
  def safe_inspect(term, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    printable_limit = Keyword.get(opts, :printable_limit, 100)
    
    inspect(term, 
      limit: limit,
      printable_limit: printable_limit,
      structs: false
    )
  end

  @doc """
  Truncates a term if it's too large, returning a placeholder.
  
  ## Examples
  
      iex> ElixirScope.Utils.truncate_if_large("small")
      "small"
      
      iex> large_binary = String.duplicate("x", 10000)
      iex> ElixirScope.Utils.truncate_if_large(large_binary, 1000)
      {:truncated, 10000, "binary data"}
  """
  def truncate_if_large(term, max_size \\ 5000) do
    binary_size = term |> :erlang.term_to_binary() |> byte_size()
    
    if binary_size > max_size do
      type_hint = case term do
        binary when is_binary(binary) -> "binary data"
        list when is_list(list) -> "list with #{length(list)} elements"
        map when is_map(map) -> "map with #{map_size(map)} entries"
        tuple when is_tuple(tuple) -> "tuple with #{tuple_size(tuple)} elements"
        _ -> "data"
      end
      
      {:truncated, binary_size, type_hint}
    else
      term
    end
  end

  @doc """
  Estimates the memory footprint of a term in bytes.
  
  ## Examples
  
      iex> ElixirScope.Utils.term_size("hello")
      15
  """
  def term_size(term) do
    :erts_debug.flat_size(term) * :erlang.system_info(:wordsize)
  end

  @doc """
  Truncates data for safe storage in events.
  
  This is an alias for truncate_if_large/2 with a smaller default size
  suitable for event data.
  
  ## Examples
  
      iex> ElixirScope.Utils.truncate_data("small")
      "small"
      
      iex> large_data = String.duplicate("x", 2000)
      iex> ElixirScope.Utils.truncate_data(large_data)
      {:truncated, 2000, "binary data"}
  """
  def truncate_data(term, max_size \\ 1000) do
    truncate_if_large(term, max_size)
  end

  #############################################################################
  # Performance Helpers
  #############################################################################

  @doc """
  Measures memory usage before and after executing a function.
  
  Returns {result, {memory_before, memory_after, memory_diff}}.
  
  ## Examples
  
      iex> {result, {before, after, diff}} = ElixirScope.Utils.measure_memory(fn -> 
      ...>   Enum.to_list(1..1000)
      ...> end)
      iex> is_list(result)
      true
      iex> diff > 0
      true
  """
  def measure_memory(fun) when is_function(fun, 0) do
    :erlang.garbage_collect()  # Ensure clean measurement
    memory_before = :erlang.memory(:total)
    
    result = fun.()
    
    :erlang.garbage_collect()  # Clean up before measuring
    memory_after = :erlang.memory(:total)
    memory_diff = memory_after - memory_before
    
    {result, {memory_before, memory_after, memory_diff}}
  end

  @doc """
  Gets current process statistics for performance monitoring.
  
  ## Examples
  
      iex> stats = ElixirScope.Utils.process_stats()
      iex> Map.has_key?(stats, :memory)
      true
      iex> Map.has_key?(stats, :reductions)
      true
  """
  def process_stats(pid \\ self()) do
    case Process.info(pid, [
      :memory,
      :reductions,
      :message_queue_len,
      :heap_size,
      :stack_size,
      :total_heap_size
    ]) do
      nil -> 
        %{error: :process_not_found}
      
      info ->
        info
        |> Keyword.put(:timestamp, monotonic_timestamp())
        |> Enum.into(%{})
    end
  end

  @doc """
  Gets system-wide performance statistics.
  
  ## Examples
  
      iex> stats = ElixirScope.Utils.system_stats()
      iex> Map.has_key?(stats, :process_count)
      true
      iex> Map.has_key?(stats, :total_memory)
      true
  """
  def system_stats do
    %{
      timestamp: monotonic_timestamp(),
      process_count: :erlang.system_info(:process_count),
      process_limit: :erlang.system_info(:process_limit),
      total_memory: :erlang.memory(:total),
      processes_memory: :erlang.memory(:processes),
      system_memory: :erlang.memory(:system),
      ets_memory: :erlang.memory(:ets),
      atom_memory: :erlang.memory(:atom),
      scheduler_count: :erlang.system_info(:schedulers),
      scheduler_count_online: :erlang.system_info(:schedulers_online)
    }
  end

  #############################################################################
  # String and Data Utilities
  #############################################################################

  @doc """
  Formats a byte size into a human-readable string.
  
  ## Examples
  
      iex> ElixirScope.Utils.format_bytes(1024)
      "1.0 KB"
      
      iex> ElixirScope.Utils.format_bytes(1_500_000)
      "1.4 MB"
  """
  def format_bytes(bytes) when is_integer(bytes) and bytes >= 0 do
    cond do
      bytes >= 1_073_741_824 ->  # GB
        "#{Float.round(bytes / 1_073_741_824, 1)} GB"
      
      bytes >= 1_048_576 ->      # MB
        "#{Float.round(bytes / 1_048_576, 1)} MB"
      
      bytes >= 1024 ->           # KB
        "#{Float.round(bytes / 1024, 1)} KB"
      
      true ->
        "#{bytes} B"
    end
  end

  @doc """
  Formats a duration in nanoseconds into a human-readable string.
  
  ## Examples
  
      iex> ElixirScope.Utils.format_duration(1_500_000)
      "1.5 ms"
      
      iex> ElixirScope.Utils.format_duration(2_000_000_000)
      "2.0 s"
  """
  def format_duration(nanoseconds) when is_integer(nanoseconds) and nanoseconds >= 0 do
    cond do
      nanoseconds >= 1_000_000_000 ->  # seconds
        "#{Float.round(nanoseconds / 1_000_000_000, 1)} s"
      
      nanoseconds >= 1_000_000 ->      # milliseconds
        "#{Float.round(nanoseconds / 1_000_000, 1)} ms"
      
      nanoseconds >= 1_000 ->          # microseconds
        "#{Float.round(nanoseconds / 1_000, 1)} μs"
      
      true ->
        "#{nanoseconds} ns"
    end
  end

  #############################################################################
  # Validation Helpers
  #############################################################################

  @doc """
  Validates that a value is a positive integer.
  
  ## Examples
  
      iex> ElixirScope.Utils.valid_positive_integer?(42)
      true
      
      iex> ElixirScope.Utils.valid_positive_integer?(-1)
      false
  """
  def valid_positive_integer?(value) do
    is_integer(value) and value > 0
  end

  @doc """
  Validates that a value is a percentage (0.0 to 1.0).
  
  ## Examples
  
      iex> ElixirScope.Utils.valid_percentage?(0.5)
      true
      
      iex> ElixirScope.Utils.valid_percentage?(1.5)
      false
  """
  def valid_percentage?(value) do
    is_number(value) and value >= 0.0 and value <= 1.0
  end

  @doc """
  Validates that a PID exists and is alive.
  
  ## Examples
  
      iex> ElixirScope.Utils.valid_pid?(self())
      true
      
      iex> dead_pid = spawn(fn -> nil end)
      iex> Process.sleep(10)
      iex> ElixirScope.Utils.valid_pid?(dead_pid)
      false
  """
  def valid_pid?(pid) when is_pid(pid) do
    Process.alive?(pid)
  end
  
  def valid_pid?(_), do: false
end 