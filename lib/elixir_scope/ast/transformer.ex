defmodule ElixirScope.AST.Transformer do
  @moduledoc """
  Core AST transformation engine for ElixirScope instrumentation.

  This module provides the core logic for transforming Elixir ASTs to inject
  instrumentation calls while preserving original semantics and behavior.
  """

  alias ElixirScope.AST.InjectorHelpers

  @doc """
  Transforms a complete module AST based on the instrumentation plan.
  """
  def transform_module(ast, plan) do
    Macro.prewalk(ast, fn node ->
      case node do
        {:defmodule, meta, [module_name, [do: module_body]]} ->
          transformed_body = transform_module_body(module_body, plan)
          {:defmodule, meta, [module_name, [do: transformed_body]]}

        other -> other
      end
    end)
  end

  @doc """
  Transforms a function definition based on instrumentation plan.
  """
  def transform_function({:def, meta, [signature, body]}, plan) do
    function_name = extract_function_name(signature)
    arity = extract_arity(signature)

    case get_function_plan(plan, function_name, arity) do
      nil ->
        {:def, meta, [signature, body]}

      function_plan ->
        transformed_body = instrument_function_body(signature, body, function_plan)
        {:def, meta, [signature, transformed_body]}
    end
  end

  # Handle blocks containing multiple definitions and attributes
  def transform_function({:__block__, meta, statements}, plan) do
    case statements do
      statements_list when is_list(statements_list) ->
        transformed_statements = Enum.map(statements_list, fn
          {:def, _, _} = function_ast -> transform_function(function_ast, plan)
          {:defp, _, _} = function_ast -> transform_function(function_ast, plan) 
          other -> other  # Keep attributes and other statements as-is
        end)
        
        {:__block__, meta, transformed_statements}
      
      # If statements is not a list, return the block as-is
      _ ->
        {:__block__, meta, statements}
    end
  end

  # Handle private functions (defp) - same logic as public functions
  def transform_function({:defp, meta, [signature, body]}, plan) do
    function_name = extract_function_name(signature)
    arity = extract_arity(signature)

    case get_function_plan(plan, function_name, arity) do
      nil ->
        {:defp, meta, [signature, body]}

      function_plan ->
        transformed_body = instrument_function_body(signature, body, function_plan)
        {:defp, meta, [signature, transformed_body]}
    end
  end

  @doc """
  Transforms a GenServer callback based on instrumentation plan.
  """
  def transform_genserver_callback({:def, meta, [signature, body]}, plan) do
    callback_name = extract_function_name(signature)

    case get_genserver_callback_plan(plan, callback_name) do
      nil ->
        {:def, meta, [signature, body]}

      callback_plan ->
        transformed_body = instrument_genserver_callback_body(signature, body, callback_plan)
        {:def, meta, [signature, transformed_body]}
    end
  end

  @doc """
  Transforms a Phoenix controller action based on instrumentation plan.
  """
  def transform_phoenix_action({:def, meta, [signature, body]}, plan) do
    action_name = extract_function_name(signature)

    case get_phoenix_action_plan(plan, action_name) do
      nil ->
        {:def, meta, [signature, body]}

      action_plan ->
        transformed_body = instrument_phoenix_action_body(signature, body, action_plan)
        {:def, meta, [signature, transformed_body]}
    end
  end

  @doc """
  Transforms a LiveView callback based on instrumentation plan.
  """
  def transform_liveview_callback({:def, meta, [signature, body]}, plan) do
    callback_name = extract_function_name(signature)

    case get_liveview_callback_plan(plan, callback_name) do
      nil ->
        {:def, meta, [signature, body]}

      callback_plan ->
        transformed_body = instrument_liveview_callback_body(signature, body, callback_plan)
        {:def, meta, [signature, transformed_body]}
    end
  end

  # Private helper functions

  defp transform_module_body(body, plan) do
    case body do
      # Handle when body is a list of statements
      statements when is_list(statements) ->
        Enum.map(statements, fn
          {:def, _, _} = function_ast -> transform_function(function_ast, plan)
          {:defp, _, _} = function_ast -> transform_function(function_ast, plan)
          {:defmacro, _, _} = macro_ast -> macro_ast # Don't instrument macros directly
          {:defmacrop, _, _} = macro_ast -> macro_ast # Don't instrument macros directly
          {:defdelegate, _, _} = delegate_ast -> delegate_ast # Don't instrument delegates
          {:defoverridable, _, _} = override_ast -> override_ast # Don't instrument overrides
          {:defimpl, _, _} = impl_ast -> impl_ast # Don't instrument implementations
          {:defprotocol, _, _} = protocol_ast -> protocol_ast # Don't instrument protocols
          {:defrecord, _, _} = record_ast -> record_ast # Don't instrument records
          {:defstruct, _, _} = struct_ast -> struct_ast # Don't instrument structs
          {:defexception, _, _} = exception_ast -> exception_ast # Don't instrument exceptions
          {:defcallback, _, _} = callback_ast -> callback_ast # Don't instrument callbacks
          {:defmacrocallback, _, _} = macro_callback_ast -> macro_callback_ast # Don't instrument macro callbacks
          {:defmodule, _, _} = nested_module_ast -> transform_module(nested_module_ast, plan) # Recurse into nested modules
          other -> other
        end)
      
      # Handle when body is a single statement (not a list)
      {:def, _, _} = function_ast -> 
        transform_function(function_ast, plan)
      {:defp, _, _} = function_ast -> 
        transform_function(function_ast, plan)
      {:defmodule, _, _} = nested_module_ast -> 
        transform_module(nested_module_ast, plan)
      
      # For any other single statement, return as-is
      other -> other
    end
  end

  defp instrument_function_body(signature, body, function_plan) do
    # Inject entry instrumentation
    entry_call = InjectorHelpers.report_function_entry_call(signature, function_plan)

    # Wrap original body in try/catch for exit and exception handling
    wrapped_body = InjectorHelpers.wrap_with_try_catch(body, signature, function_plan)

    # Combine entry call with wrapped body
    quote do
      unquote(entry_call)
      unquote(wrapped_body)
    end
  end

  defp instrument_genserver_callback_body(signature, body, callback_plan) do
    # Inject state capture before call
    state_before_call = InjectorHelpers.capture_genserver_state_before_call(signature, callback_plan)

    # Wrap original body
    wrapped_body = InjectorHelpers.wrap_genserver_callback_body(body, signature, callback_plan)

    # Inject state capture after call
    state_after_call = InjectorHelpers.capture_genserver_state_after_call(signature, callback_plan)

    quote do
      unquote(state_before_call)
      result = unquote(wrapped_body)
      unquote(state_after_call)
      result
    end
  end

  defp instrument_phoenix_action_body(signature, body, action_plan) do
    # Inject params capture
    params_capture = InjectorHelpers.capture_phoenix_params(signature, action_plan)

    # Inject conn state capture before
    conn_state_before = InjectorHelpers.capture_phoenix_conn_state_before(signature, action_plan)

    # Wrap original body
    wrapped_body = InjectorHelpers.wrap_phoenix_action_body(body, signature, action_plan)

    # Inject conn state capture after and response capture
    conn_state_after_and_response = InjectorHelpers.capture_phoenix_conn_state_after_and_response(signature, action_plan)

    quote do
      unquote(params_capture)
      unquote(conn_state_before)
      result = unquote(wrapped_body)
      unquote(conn_state_after_and_response)
      result
    end
  end

  defp instrument_liveview_callback_body(signature, body, callback_plan) do
    # Inject socket assigns capture
    socket_assigns_capture = InjectorHelpers.capture_liveview_socket_assigns(signature, callback_plan)

    # Inject event capture
    event_capture = InjectorHelpers.capture_liveview_event(signature, callback_plan)

    # Wrap original body
    wrapped_body = InjectorHelpers.wrap_liveview_callback_body(body, signature, callback_plan)

    quote do
      unquote(socket_assigns_capture)
      unquote(event_capture)
      result = unquote(wrapped_body)
      result
    end
  end

  defp extract_function_name({:when, _, [name_and_args, _]}), do: extract_function_name(name_and_args)
  defp extract_function_name({name, _, _}), do: name

  defp extract_arity({:when, _, [name_and_args, _]}), do: extract_arity(name_and_args)
  defp extract_arity({_, _, args}) when is_list(args), do: length(args)
  defp extract_arity({_, _, nil}), do: 0
  defp extract_arity(_), do: 0

  defp get_function_plan(plan, function_name, arity) do
    functions_map = Map.get(plan, :functions, %{})
    
    # Try multiple key formats for flexibility
    cond do
      # Try with current module context (most common for tests)
      Map.has_key?(functions_map, {TestModule, function_name, arity}) ->
        Map.get(functions_map, {TestModule, function_name, arity})
      
      # Try with just function name and arity
      Map.has_key?(functions_map, {function_name, arity}) ->
        Map.get(functions_map, {function_name, arity})
      
      # Try any key that matches function name and arity (regardless of module)
      true ->
        Enum.find_value(functions_map, fn
          {{_module, ^function_name, ^arity}, plan} -> plan
          {{^function_name, ^arity}, plan} -> plan
          _ -> nil
        end)
    end
  end

  defp get_genserver_callback_plan(plan, callback_name) do
    Map.get(plan, :genserver_callbacks, %{})
    |> Map.get(callback_name)
  end

  defp get_phoenix_action_plan(plan, action_name) do
    Map.get(plan, :phoenix_controllers, %{})
    |> Map.get(action_name)
  end

  defp get_liveview_callback_plan(plan, callback_name) do
    Map.get(plan, :liveview_callbacks, %{})
    |> Map.get(callback_name)
  end
end
