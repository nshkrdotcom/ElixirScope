defmodule ElixirAnalyzerDemoTest do
  use ExUnit.Case
  doctest ElixirAnalyzerDemo

  test "greets the world" do
    assert ElixirAnalyzerDemo.hello() == :world
  end
end
