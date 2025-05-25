defmodule TestModule do
  @moduledoc """
  Simple test module for Mix compiler integration tests.
  """

  def add(x, y) do
    x + y
  end

  def multiply(x, y) do
    x * y
  end

  def calculate(x, y) do
    result = x + y
    result * 2
  end
end 