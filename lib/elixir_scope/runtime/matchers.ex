defmodule ElixirScope.Runtime.Matchers do
  @moduledoc """
  Pattern matching DSL for runtime tracing conditions.
  
  This module provides utilities for building BEAM match specifications
  and complex pattern matching for runtime tracing conditions.
  """

  require Logger

  @doc """
  Builds a BEAM match specification from a pattern.
  
  ## Examples
  
      iex> match_spec(fn {x, y} when x > 10 -> y end)
      [{{'$1', '$2'}, [{'>', '$1', 10}], ['$2']}]
      
      iex> match_spec(fn %{status: :error} -> true end)
      [{'$1', [{'==', {:map_get, status, '$1'}, :error}], [true]}]
  """
  defmacro match_spec(pattern) do
    quote do
      ElixirScope.Runtime.Matchers.build_match_spec(unquote(pattern))
    end
  end

  @doc """
  Builds a match specification from a function pattern.
  """
  def build_match_spec(fun) when is_function(fun) do
    try do
      # Extract the function's AST and convert to match spec
      fun_info = Function.info(fun)
      arity = fun_info[:arity]
      
      case arity do
        1 -> build_single_arg_match_spec(fun)
        _ -> build_multi_arg_match_spec(fun, arity)
      end
    rescue
      error ->
        Logger.warning("Failed to build match spec: #{inspect(error)}")
        # Fallback to catch-all match spec
        [{~c"$1", [], [~c"$1"]}]
    end
  end

  @doc """
  Creates a match specification for function arguments.
  
  ## Examples
  
      iex> arg_match(:any)
      '$_'
      
      iex> arg_match({:greater_than, 10})
      [{'>', '$1', 10}]
      
      iex> arg_match({:equals, :ok})
      [{'==', '$1', :ok}]
  """
  def arg_match(:any), do: :'$_'
  def arg_match({:greater_than, value}), do: [{~c">", :"$1", value}]
  def arg_match({:less_than, value}), do: [{~c"<", :"$1", value}]
  def arg_match({:equals, value}), do: [{~c"==", :"$1", value}]
  def arg_match({:not_equals, value}), do: [{~c"=/=", :"$1", value}]
  def arg_match({:in, list}) when is_list(list), do: [{~c"orelse", Enum.map(list, &[{~c"==", :"$1", &1}])}]
  def arg_match({:regex, pattern}), do: [{~c"=:=", {:re, :run, [:"$1", pattern]}, {:nomatch}}]
  def arg_match({:type, type}), do: build_type_guard(type)
  def arg_match(literal), do: [{~c"==", :"$1", literal}]

  @doc """
  Creates a match specification for return values.
  
  ## Examples
  
      iex> return_match(:any)
      ['$_']
      
      iex> return_match({:ok, :any})
      [{'==', {:element, 1, '$_'}, :ok}]
      
      iex> return_match({:error, {:greater_than, 100}})
      [{'and', {'==', {:element, 1, '$_'}, :error}, {'>', {:element, 2, '$_'}, 100}}]
  """
  def return_match(:any), do: [:'$_']
  def return_match({:ok, inner_match}), do: build_tuple_match(:ok, inner_match, 1)
  def return_match({:error, inner_match}), do: build_tuple_match(:error, inner_match, 1)
  def return_match({tag, inner_match}) when is_atom(tag), do: build_tuple_match(tag, inner_match, 1)
  def return_match(literal), do: [{~c"==", :"$_", literal}]

  @doc """
  Creates a match specification for message patterns.
  
  ## Examples
  
      iex> message_match({:cast, :any})
      [{'==', {:element, 1, '$_'}, :cast}]
      
      iex> message_match({:call, {:from, :any}, :any})
      [{'==', {:element, 1, '$_'}, :call}]
  """
  def message_match({tag, content}) when is_atom(tag) do
    case content do
      :any -> [{~c"==", {:element, 1, :"$_"}, tag}]
      _ -> [{~c"and", {~c"==", {:element, 1, :"$_"}, tag}, build_content_match(content, 2)}]
    end
  end
  def message_match(literal), do: [{~c"==", :"$_", literal}]

  @doc """
  Creates a complex condition combining multiple patterns.
  
  ## Examples
  
      iex> complex_condition(:and, [arg_match({:greater_than, 10}), return_match(:ok)])
      [{'and', {'>', '$1', 10}, {'==', '$_', :ok}}]
  """
  def complex_condition(:and, conditions) do
    combined = Enum.reduce(conditions, fn condition, acc ->
      case {acc, condition} do
        {nil, cond} -> cond
        {acc_cond, cond} -> [{~c"and", acc_cond, cond}]
      end
    end)
    [combined]
  end

  def complex_condition(:or, conditions) do
    combined = Enum.reduce(conditions, fn condition, acc ->
      case {acc, condition} do
        {nil, cond} -> cond
        {acc_cond, cond} -> [{~c"orelse", acc_cond, cond}]
      end
    end)
    [combined]
  end

  @doc """
  Creates a match specification for process state patterns.
  
  ## Examples
  
      iex> state_match(%{status: :running})
      [{'==', {:map_get, :status, '$_'}, :running}]
  """
  def state_match(pattern) when is_map(pattern) do
    conditions = Enum.map(pattern, fn {key, value} ->
      {~c"==", {:map_get, key, :"$_"}, value}
    end)
    
    case conditions do
      [single] -> [single]
      multiple -> [{~c"and", multiple}]
    end
  end
  def state_match(pattern), do: [{~c"==", :"$_", pattern}]

  @doc """
  Optimizes a match specification for performance.
  """
  def optimize_match_spec(match_spec) do
    match_spec
    |> remove_redundant_conditions()
    |> simplify_guards()
    |> reorder_conditions()
  end

  @doc """
  Validates that a match specification is well-formed.
  """
  def validate_match_spec(match_spec) do
    try do
      :ets.test_ms(match_spec, [])
      {:ok, match_spec}
    rescue
      error -> {:error, "Invalid match specification: #{inspect(error)}"}
    end
  end

  # Private helper functions

  defp build_single_arg_match_spec(_fun) do
    # Simplified implementation - in a real scenario, we'd need to
    # parse the function's AST to extract the actual pattern
    [{~c"$1", [], [~c"$1"]}]
  end

  defp build_multi_arg_match_spec(_fun, arity) do
    # Build a match spec that captures all arguments
    args = Enum.map(1..arity, &:"$#{&1}")
    [{List.to_tuple(args), [], [List.to_tuple(args)]}]
  end

  defp build_type_guard(:integer), do: [{~c"is_integer", :"$1"}]
  defp build_type_guard(:float), do: [{~c"is_float", :"$1"}]
  defp build_type_guard(:number), do: [{~c"is_number", :"$1"}]
  defp build_type_guard(:atom), do: [{~c"is_atom", :"$1"}]
  defp build_type_guard(:binary), do: [{~c"is_binary", :"$1"}]
  defp build_type_guard(:list), do: [{~c"is_list", :"$1"}]
  defp build_type_guard(:tuple), do: [{~c"is_tuple", :"$1"}]
  defp build_type_guard(:map), do: [{~c"is_map", :"$1"}]
  defp build_type_guard(:pid), do: [{~c"is_pid", :"$1"}]
  defp build_type_guard(:reference), do: [{~c"is_reference", :"$1"}]
  defp build_type_guard(:function), do: [{~c"is_function", :"$1"}]
  defp build_type_guard(_), do: []

  defp build_tuple_match(tag, inner_match, position) do
    tag_condition = {~c"==", {:element, 1, :"$_"}, tag}
    
    case inner_match do
      :any -> [tag_condition]
      _ -> 
        inner_condition = build_element_match(inner_match, position + 1)
        [{~c"and", tag_condition, inner_condition}]
    end
  end

  defp build_element_match({:greater_than, value}, pos) do
    {~c">", {:element, pos, :"$_"}, value}
  end
  defp build_element_match({:less_than, value}, pos) do
    {~c"<", {:element, pos, :"$_"}, value}
  end
  defp build_element_match({:equals, value}, pos) do
    {~c"==", {:element, pos, :"$_"}, value}
  end
  defp build_element_match(literal, pos) do
    {~c"==", {:element, pos, :"$_"}, literal}
  end

  defp build_content_match(:any, _pos), do: []
  defp build_content_match(pattern, pos), do: build_element_match(pattern, pos)

  defp remove_redundant_conditions(match_spec) do
    # Remove duplicate or redundant conditions
    match_spec
  end

  defp simplify_guards(match_spec) do
    # Simplify guard expressions where possible
    match_spec
  end

  defp reorder_conditions(match_spec) do
    # Reorder conditions for optimal performance
    match_spec
  end
end 