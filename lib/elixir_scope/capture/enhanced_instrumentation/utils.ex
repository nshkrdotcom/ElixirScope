defmodule ElixirScope.Capture.EnhancedInstrumentation.Utils do
  @moduledoc """
  Utility functions for enhanced instrumentation.

  This module contains helper functions for ID generation and other
  common operations used across the enhanced instrumentation system.
  """

  @doc """
  Generates a unique breakpoint ID with a specific type prefix.
  """
  @spec generate_breakpoint_id(String.t()) :: String.t()
  def generate_breakpoint_id(type) do
    "#{type}_bp_" <> Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)
  end

  @doc """
  Generates a unique watchpoint ID.
  """
  @spec generate_watchpoint_id() :: String.t()
  def generate_watchpoint_id() do
    "wp_" <> Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)
  end

  @doc """
  Generates a correlation ID for event tracking.
  """
  @spec generate_correlation_id() :: String.t()
  def generate_correlation_id() do
    "corr_" <> Base.encode16(:crypto.strong_rand_bytes(6), case: :lower)
  end

  @doc """
  Formats duration from nanoseconds to human-readable format.
  """
  @spec format_duration(non_neg_integer()) :: String.t()
  def format_duration(duration_ns) when duration_ns < 1_000 do
    "#{duration_ns}ns"
  end

  def format_duration(duration_ns) when duration_ns < 1_000_000 do
    "#{Float.round(duration_ns / 1_000, 2)}µs"
  end

  def format_duration(duration_ns) when duration_ns < 1_000_000_000 do
    "#{Float.round(duration_ns / 1_000_000, 2)}ms"
  end

  def format_duration(duration_ns) do
    "#{Float.round(duration_ns / 1_000_000_000, 2)}s"
  end

  @doc """
  Safely truncates a string to a maximum length.
  """
  @spec truncate_string(String.t(), non_neg_integer()) :: String.t()
  def truncate_string(str, max_length) when byte_size(str) <= max_length do
    str
  end

  def truncate_string(str, max_length) do
    String.slice(str, 0, max_length - 3) <> "..."
  end

  @doc """
  Sanitizes variable names for safe storage and display.
  """
  @spec sanitize_variable_name(String.t()) :: String.t()
  def sanitize_variable_name(name) do
    name
    |> String.replace(~r/[^a-zA-Z0-9_]/, "_")
    |> String.slice(0, 50)  # Limit length
  end

  @doc """
  Estimates memory size of a term (rough approximation).
  """
  @spec estimate_term_size(term()) :: non_neg_integer()
  def estimate_term_size(term) when is_binary(term), do: byte_size(term)
  def estimate_term_size(term) when is_list(term), do: length(term) * 8  # rough estimate
  def estimate_term_size(term) when is_map(term), do: map_size(term) * 16  # rough estimate
  def estimate_term_size(term) when is_tuple(term), do: tuple_size(term) * 8
  def estimate_term_size(_term), do: 8  # default word size
end
