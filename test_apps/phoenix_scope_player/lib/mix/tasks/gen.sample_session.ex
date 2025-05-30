defmodule Mix.Tasks.Gen.SampleSession do
  @moduledoc """
  Generates a sample debug session for testing the Phoenix Scope Player.

  Usage:
      mix gen.sample_session
  """
  use Mix.Task
  alias PhoenixScopePlayer.SessionGenerator

  @shortdoc "Generates a sample debug session"
  def run(_) do
    Mix.Task.run("app.start")
    
    # Generate both types of sessions with default n=5
    SessionGenerator.generate_fibonacci_session()
    SessionGenerator.generate_factorial_session()
  end
end 