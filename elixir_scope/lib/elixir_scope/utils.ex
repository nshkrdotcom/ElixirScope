defmodule ElixirScope.Utils do
  @moduledoc """
  Provides utility functions for the ElixirScope application.

  This module includes functions for generating unique identifiers and
  retrieving high-resolution monotonic timestamps, which are essential
  for event tracking and correlation.
  """

  alias UUID

  @doc """
  Generates a unique event identifier string.

  Uses UUID version 4 to ensure uniqueness.

  ## Examples

      iex> ElixirScope.Utils.generate_event_id()
      "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx" # A UUID v4 string
  """
  def generate_event_id do
    UUID.uuid4()
  end

  @doc """
  Returns the current monotonic time in nanoseconds.

  This time is suitable for measuring intervals and is not affected by
  system clock adjustments.

  ## Examples

      iex> ElixirScope.Utils.monotonic_time_ns()
      123456789012345 # An integer representing nanoseconds
  """
  def monotonic_time_ns do
    System.monotonic_time(:nanosecond)
  end
end
