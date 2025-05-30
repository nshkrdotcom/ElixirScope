defmodule PhoenixScopePlayer.SessionGenerator do
  @moduledoc """
  Helper module to generate sample debug sessions by running Calculator functions with tracing enabled.
  """

  alias PhoenixScopePlayer.{Calculator, Instrumentation}

  def generate_fibonacci_session(n \\ 5) do
    session_id = "fibonacci_#{System.system_time(:second)}"
    
    # Start tracer first
    {:ok, tracer_pid} = Instrumentation.start_trace(session_id)
    
    # Enable tracing for this process
    :ok = Instrumentation.enable_tracing(tracer_pid, self())
    
    # Run calculations
    result = Calculator.fibonacci(n)
    IO.puts("Fibonacci(#{n}) = #{result}")

    # Also calculate sum of sequence
    sum = Calculator.sum_fibonacci_sequence(n)
    IO.puts("Sum of Fibonacci sequence up to #{n} = #{sum}")

    # Stop tracing and save the session
    Instrumentation.stop_trace(tracer_pid)
    
    {:ok, session_id}
  end

  def generate_factorial_session(n \\ 5) do
    session_id = "factorial_#{System.system_time(:second)}"
    
    # Start tracer first
    {:ok, tracer_pid} = Instrumentation.start_trace(session_id)
    
    # Enable tracing for this process
    :ok = Instrumentation.enable_tracing(tracer_pid, self())
    
    # Run calculations
    result = Calculator.factorial(n)
    IO.puts("Factorial(#{n}) = #{result}")

    # Also calculate sum of sequence
    sum = Calculator.sum_factorial_sequence(n)
    IO.puts("Sum of Factorial sequence up to #{n} = #{sum}")

    # Stop tracing and save the session
    Instrumentation.stop_trace(tracer_pid)
    
    {:ok, session_id}
  end
end 