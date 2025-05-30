defmodule PhoenixScopePlayer.Calculator do
  @moduledoc """
  A simple calculator module used to generate sample debug sessions.
  Contains functions that demonstrate various execution patterns for tracing.
  """

  @compile {:debug_info}

  @doc """
  Calculates the nth number in the Fibonacci sequence.
  """
  def fibonacci(n) when n <= 0, do: 0
  def fibonacci(1), do: 1
  def fibonacci(n) when n > 1 do
    fibonacci(n - 1) + fibonacci(n - 2)
  end

  @doc """
  Calculates the sum of the first n numbers in the Fibonacci sequence.
  """
  def sum_fibonacci_sequence(n) when n <= 0, do: 0
  def sum_fibonacci_sequence(n) when n > 0 do
    Enum.reduce(1..n, 0, fn i, acc ->
      acc + fibonacci(i)
    end)
  end

  @doc """
  Calculates factorial of n.
  """
  def factorial(0), do: 1
  def factorial(n) when n > 0 do
    n * factorial(n - 1)
  end

  @doc """
  Calculates the sum of factorials from 1 to n.
  """
  def sum_factorial_sequence(n) when n <= 0, do: 0
  def sum_factorial_sequence(n) when n > 0 do
    Enum.reduce(1..n, 0, fn i, acc ->
      acc + factorial(i)
    end)
  end
end 