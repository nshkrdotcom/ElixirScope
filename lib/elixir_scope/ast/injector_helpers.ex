defmodule ElixirScope.AST.InjectorHelpers do
  @moduledoc """
  Helper functions for injecting ElixirScope instrumentation into AST nodes.
  
  Provides utilities for generating instrumentation calls while preserving
  original code semantics and structure.
  """

  @doc """
  Generates a function entry call for instrumentation.
  """
  def report_function_entry_call(signature, function_plan) do
    {function_name, arity} = extract_function_info(signature)
    
    quote do
      ElixirScope.Capture.InstrumentationRuntime.report_function_entry(
        unquote(function_name),
        unquote(arity),
        unquote(get_capture_args(function_plan)),
        unquote(generate_correlation_id())
      )
    end
  end

  @doc """
  Wraps function body with try/catch for exit and exception handling.
  """
  def wrap_with_try_catch(body, signature, function_plan) do
    {function_name, arity} = extract_function_info(signature)
    correlation_id = generate_correlation_id()

    quote do
      try do
        result = unquote(body)
        
        ElixirScope.Capture.InstrumentationRuntime.report_function_exit(
          unquote(function_name),
          unquote(arity),
          :normal,
          unquote(get_capture_return(function_plan, :result)),
          unquote(correlation_id)
        )
        
        result
      catch
        kind, reason ->
          ElixirScope.Capture.InstrumentationRuntime.report_function_exit(
            unquote(function_name),
            unquote(arity),
            kind,
            reason,
            unquote(correlation_id)
          )
          
          :erlang.raise(kind, reason, __STACKTRACE__)
      end
    end
  end

  @doc """
  Captures GenServer state before a callback call.
  """
  def capture_genserver_state_before_call(signature, callback_plan) do
    callback_name = extract_callback_name(signature)
    
    quote do
      ElixirScope.Capture.InstrumentationRuntime.report_genserver_callback_start(
        unquote(callback_name),
        self(),
        unquote(get_state_capture(callback_plan, :before))
      )
    end
  end

  @doc """
  Wraps GenServer callback body with state monitoring.
  """
  def wrap_genserver_callback_body(body, signature, _callback_plan) do
    callback_name = extract_callback_name(signature)
    
    quote do
      try do
        result = unquote(body)
        
        ElixirScope.Capture.InstrumentationRuntime.report_genserver_callback_success(
          unquote(callback_name),
          self(),
          result
        )
        
        result
      catch
        kind, reason ->
          ElixirScope.Capture.InstrumentationRuntime.report_genserver_callback_error(
            unquote(callback_name),
            self(),
            kind,
            reason
          )
          
          :erlang.raise(kind, reason, __STACKTRACE__)
      end
    end
  end

  @doc """
  Captures GenServer state after a callback call.
  """
  def capture_genserver_state_after_call(signature, callback_plan) do
    callback_name = extract_callback_name(signature)
    
    quote do
      ElixirScope.Capture.InstrumentationRuntime.report_genserver_callback_complete(
        unquote(callback_name),
        self(),
        unquote(get_state_capture(callback_plan, :after))
      )
    end
  end

  @doc """
  Captures Phoenix controller parameters.
  """
  def capture_phoenix_params(signature, action_plan) do
    action_name = extract_action_name(signature)
    
    quote do
      ElixirScope.Capture.InstrumentationRuntime.report_phoenix_action_params(
        unquote(action_name),
        var!(conn),
        var!(params),
        unquote(should_capture_params(action_plan))
      )
    end
  end

  @doc """
  Captures Phoenix connection state before action.
  """
  def capture_phoenix_conn_state_before(signature, action_plan) do
    action_name = extract_action_name(signature)
    
    quote do
      ElixirScope.Capture.InstrumentationRuntime.report_phoenix_action_start(
        unquote(action_name),
        var!(conn),
        unquote(should_capture_conn_state(action_plan))
      )
    end
  end

  @doc """
  Wraps Phoenix action body with monitoring.
  """
  def wrap_phoenix_action_body(body, signature, _action_plan) do
    action_name = extract_action_name(signature)
    
    quote do
      try do
        result = unquote(body)
        
        ElixirScope.Capture.InstrumentationRuntime.report_phoenix_action_success(
          unquote(action_name),
          var!(conn),
          result
        )
        
        result
      catch
        kind, reason ->
          ElixirScope.Capture.InstrumentationRuntime.report_phoenix_action_error(
            unquote(action_name),
            var!(conn),
            kind,
            reason
          )
          
          :erlang.raise(kind, reason, __STACKTRACE__)
      end
    end
  end

  @doc """
  Captures Phoenix connection state and response after action.
  """
  def capture_phoenix_conn_state_after_and_response(signature, action_plan) do
    action_name = extract_action_name(signature)
    
    quote do
      ElixirScope.Capture.InstrumentationRuntime.report_phoenix_action_complete(
        unquote(action_name),
        var!(conn),
        unquote(should_capture_response(action_plan))
      )
    end
  end

  @doc """
  Captures LiveView socket assigns.
  """
  def capture_liveview_socket_assigns(signature, callback_plan) do
    callback_name = extract_callback_name(signature)
    
    quote do
      ElixirScope.Capture.InstrumentationRuntime.report_liveview_assigns(
        unquote(callback_name),
        var!(socket),
        unquote(should_capture_assigns(callback_plan))
      )
    end
  end

  @doc """
  Captures LiveView event data.
  """
  def capture_liveview_event(signature, callback_plan) do
    callback_name = extract_callback_name(signature)
    
    case callback_name do
      :handle_event ->
        quote do
          ElixirScope.Capture.InstrumentationRuntime.report_liveview_event(
            var!(event),
            var!(params),
            var!(socket),
            unquote(should_capture_event_data(callback_plan))
          )
        end
      
      _ ->
        quote do
          ElixirScope.Capture.InstrumentationRuntime.report_liveview_callback(
            unquote(callback_name),
            var!(socket)
          )
        end
    end
  end

  @doc """
  Wraps LiveView callback body with monitoring.
  """
  def wrap_liveview_callback_body(body, signature, _callback_plan) do
    callback_name = extract_callback_name(signature)
    
    quote do
      try do
        result = unquote(body)
        
        ElixirScope.Capture.InstrumentationRuntime.report_liveview_callback_success(
          unquote(callback_name),
          var!(socket),
          result
        )
        
        result
      catch
        kind, reason ->
          ElixirScope.Capture.InstrumentationRuntime.report_liveview_callback_error(
            unquote(callback_name),
            var!(socket),
            kind,
            reason
          )
          
          :erlang.raise(kind, reason, __STACKTRACE__)
      end
    end
  end

  # Private helper functions

  defp extract_function_info({:when, _, [name_and_args, _]}) do
    extract_function_info(name_and_args)
  end
  defp extract_function_info({function_name, _, args}) when is_list(args) do
    {function_name, length(args)}
  end
  defp extract_function_info({function_name, _, _}) do
    {function_name, 0}
  end

  defp extract_callback_name({:when, _, [name_and_args, _]}) do
    extract_callback_name(name_and_args)
  end
  defp extract_callback_name({callback_name, _, _}), do: callback_name

  defp extract_action_name({:when, _, [name_and_args, _]}) do
    extract_action_name(name_and_args)
  end
  defp extract_action_name({action_name, _, _}), do: action_name

  defp generate_correlation_id do
    quote do
      ElixirScope.Utils.generate_correlation_id()
    end
  end

  defp get_capture_args(function_plan) do
    case function_plan do
      %{capture_args: true} -> true
      _ -> false
    end
  end

  defp get_capture_return(function_plan, default) do
    case function_plan do
      %{capture_return: true} -> quote(do: unquote(default))
      _ -> quote(do: nil)
    end
  end

  defp get_state_capture(callback_plan, timing) do
    case callback_plan do
      %{capture_state_before: true} when timing == :before -> true
      %{capture_state_after: true} when timing == :after -> true
      _ -> false
    end
  end

  defp should_capture_params(action_plan) do
    case action_plan do
      %{capture_params: true} -> true
      _ -> false
    end
  end

  defp should_capture_conn_state(action_plan) do
    case action_plan do
      %{capture_conn_state: true} -> true
      _ -> false
    end
  end

  defp should_capture_response(action_plan) do
    case action_plan do
      %{capture_response: true} -> true
      _ -> false
    end
  end

  defp should_capture_assigns(callback_plan) do
    case callback_plan do
      %{capture_socket_assigns: true} -> true
      _ -> false
    end
  end

  defp should_capture_event_data(callback_plan) do
    case callback_plan do
      %{capture_event_data: true} -> true
      _ -> false
    end
  end
end 