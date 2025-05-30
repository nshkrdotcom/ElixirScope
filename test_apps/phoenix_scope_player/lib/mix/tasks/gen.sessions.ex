defmodule Mix.Tasks.Gen.Sessions do
  @moduledoc """
  Mix task to generate sample debug sessions.

  ## Examples

      mix gen.sessions         # Generates default sessions
      mix gen.sessions 8      # Generates sessions with n=8
  """
  
  use Mix.Task
  alias PhoenixScopePlayer.SessionGenerator

  @impl Mix.Task
  def run(args) do
    # Start the application to ensure all modules are loaded
    Mix.Task.run("app.start")

    n = case args do
      [n_str] -> String.to_integer(n_str)
      _ -> 5
    end

    IO.puts("\n=== Generating sample debug sessions (n=#{n}) ===")

    # Generate Fibonacci session
    case SessionGenerator.generate_fibonacci_session(n) do
      {:ok, session_id} ->
        IO.puts("✓ Generated Fibonacci session: #{session_id}")
      error ->
        IO.puts("✗ Failed to generate Fibonacci session: #{inspect(error)}")
    end

    # Generate Factorial session
    case SessionGenerator.generate_factorial_session(n) do
      {:ok, session_id} ->
        IO.puts("✓ Generated Factorial session: #{session_id}")
      error ->
        IO.puts("✗ Failed to generate Factorial session: #{inspect(error)}")
    end

    IO.puts("\n=== Session generation complete ===")
  end
end 