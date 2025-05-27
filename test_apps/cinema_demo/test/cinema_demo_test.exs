defmodule CinemaDemoTest do
  use ExUnit.Case
  doctest CinemaDemo

  test "greets the world" do
    assert CinemaDemo.hello() == :world
  end
end
