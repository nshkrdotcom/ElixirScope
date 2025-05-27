defmodule ElixirScope.ASTRepository.Parser do
  @moduledoc """
  Enhanced AST parser that assigns unique node IDs to instrumentable AST nodes,
  extracts instrumentation points, and builds correlation indexes for runtime correlation.
  
  This module is the foundation for compile-time AST analysis with runtime correlation.
  """

  @doc """
  Assigns unique node IDs to instrumentable AST nodes.
  
  Instrumentable nodes include:
  - Function definitions (def, defp)
  - Pipe operations (|>)
  - Case statements
  - Try-catch blocks
  - Module attributes
  
  Returns {:ok, enhanced_ast} or {:error, reason}.
  """
  @spec assign_node_ids(Macro.t()) :: {:ok, Macro.t()} | {:error, term()}
  def assign_node_ids(nil), do: {:error, :empty_ast}
  def assign_node_ids(ast) when not is_tuple(ast), do: {:error, :invalid_ast}
  
  def assign_node_ids(ast) do
    try do
      {enhanced_ast, _counter} = assign_node_ids_recursive(ast, 0)
      {:ok, enhanced_ast}
    rescue
      error -> {:error, "Failed to assign node IDs: #{inspect(error)}"}
    end
  end

  @doc """
  Extracts instrumentation points from an enhanced AST.
  
  Returns {:ok, instrumentation_points} or {:error, reason}.
  """
  @spec extract_instrumentation_points(Macro.t()) :: {:ok, [map()]} | {:error, term()}
  def extract_instrumentation_points(ast) do
    try do
      points = extract_points_recursive(ast, [])
      {:ok, points}
    rescue
      error -> {:error, "Failed to extract instrumentation points: #{inspect(error)}"}
    end
  end

  @doc """
  Builds a correlation index from enhanced AST and instrumentation points.
  
  Returns {:ok, correlation_index} where correlation_index is a map of
  correlation_id -> ast_node_id.
  """
  @spec build_correlation_index(Macro.t(), [map()]) :: {:ok, map()} | {:error, term()}
  def build_correlation_index(_ast, instrumentation_points) do
    try do
      correlation_index = 
        instrumentation_points
        |> Enum.with_index()
        |> Enum.map(fn {point, index} ->
          correlation_id = generate_correlation_id(point, index)
          {correlation_id, point.ast_node_id}
        end)
        |> Map.new()
      
      {:ok, correlation_index}
    rescue
      error -> {:error, "Failed to build correlation index: #{inspect(error)}"}
    end
  end

  # Private functions

  defp assign_node_ids_recursive(ast, counter) do
    case ast do
      # Function definitions - always instrumentable
      {:def, meta, args} ->
        {new_meta, new_counter} = add_node_id_to_meta(meta, counter)
        {enhanced_args, final_counter} = assign_node_ids_to_args(args, new_counter)
        {{:def, new_meta, enhanced_args}, final_counter}
      
      {:defp, meta, args} ->
        {new_meta, new_counter} = add_node_id_to_meta(meta, counter)
        {enhanced_args, final_counter} = assign_node_ids_to_args(args, new_counter)
        {{:defp, new_meta, enhanced_args}, final_counter}
      
      # Pipe operations - instrumentable for data flow tracking
      {:|>, meta, args} ->
        {new_meta, new_counter} = add_node_id_to_meta(meta, counter)
        {enhanced_args, final_counter} = assign_node_ids_to_args(args, new_counter)
        {{:|>, new_meta, enhanced_args}, final_counter}
      
      # Case statements - instrumentable for control flow tracking
      {:case, meta, args} ->
        {new_meta, new_counter} = add_node_id_to_meta(meta, counter)
        {enhanced_args, final_counter} = assign_node_ids_to_args(args, new_counter)
        {{:case, new_meta, enhanced_args}, final_counter}
      
      # Try-catch blocks - instrumentable for error tracking
      {:try, meta, args} ->
        {new_meta, new_counter} = add_node_id_to_meta(meta, counter)
        {enhanced_args, final_counter} = assign_node_ids_to_args(args, new_counter)
        {{:try, new_meta, enhanced_args}, final_counter}
      
      # Module attributes - instrumentable for metadata tracking
      {:@, meta, args} ->
        {new_meta, new_counter} = add_node_id_to_meta(meta, counter)
        {enhanced_args, final_counter} = assign_node_ids_to_args(args, new_counter)
        {{:@, new_meta, enhanced_args}, final_counter}
      
      # Generic tuple with metadata - recurse into children
      {form, meta, args} when is_list(meta) ->
        {enhanced_args, new_counter} = assign_node_ids_to_args(args, counter)
        {{form, meta, enhanced_args}, new_counter}
      
      # Generic tuple without metadata - recurse into children
      {form, args} ->
        {enhanced_args, new_counter} = assign_node_ids_to_args(args, counter)
        {{form, enhanced_args}, new_counter}
      
      # Lists - recurse into elements
      list when is_list(list) ->
        {enhanced_list, new_counter} = 
          Enum.reduce(list, {[], counter}, fn item, {acc, cnt} ->
            {enhanced_item, new_cnt} = assign_node_ids_recursive(item, cnt)
            {[enhanced_item | acc], new_cnt}
          end)
        {Enum.reverse(enhanced_list), new_counter}
      
      # Atoms, numbers, strings, etc. - no enhancement needed
      other ->
        {other, counter}
    end
  end

  defp assign_node_ids_to_args(args, counter) when is_list(args) do
    Enum.reduce(args, {[], counter}, fn arg, {acc, cnt} ->
      {enhanced_arg, new_cnt} = assign_node_ids_recursive(arg, cnt)
      {[enhanced_arg | acc], new_cnt}
    end)
    |> then(fn {acc, cnt} -> {Enum.reverse(acc), cnt} end)
  end

  defp assign_node_ids_to_args(args, counter) do
    assign_node_ids_recursive(args, counter)
  end

  defp add_node_id_to_meta(meta, counter) do
    node_id = "ast_node_#{counter}_#{:erlang.unique_integer([:positive])}"
    new_meta = Keyword.put(meta, :ast_node_id, node_id)
    {new_meta, counter + 1}
  end

  defp extract_points_recursive(ast, acc) do
    case ast do
      # Module definitions - recurse into module body
      {:defmodule, _meta, [_module_name, [do: body]]} ->
        extract_points_recursive(body, acc)
      
      # Block structures - recurse into block contents
      {:__block__, _meta, statements} when is_list(statements) ->
        Enum.reduce(statements, acc, fn statement, statement_acc ->
          extract_points_recursive(statement, statement_acc)
        end)
      
      # Function definitions - match the actual AST structure
      {:def, meta, [{name, _meta2, args} | _rest]} when is_list(args) ->
        case Keyword.get(meta, :ast_node_id) do
          nil -> extract_from_children(ast, acc)
          node_id ->
            point = create_instrumentation_point(node_id, :function_entry, {name, length(args)}, meta, :public)
            extract_from_children(ast, [point | acc])
        end
      
      {:def, meta, [{name, _meta2, _args} | _rest]} ->
        case Keyword.get(meta, :ast_node_id) do
          nil -> extract_from_children(ast, acc)
          node_id ->
            point = create_instrumentation_point(node_id, :function_entry, {name, 0}, meta, :public)
            extract_from_children(ast, [point | acc])
        end
      
      {:defp, meta, [{name, _meta2, args} | _rest]} when is_list(args) ->
        case Keyword.get(meta, :ast_node_id) do
          nil -> extract_from_children(ast, acc)
          node_id ->
            point = create_instrumentation_point(node_id, :function_entry, {name, length(args)}, meta, :private)
            extract_from_children(ast, [point | acc])
        end
      
      {:defp, meta, [{name, _meta2, _args} | _rest]} ->
        case Keyword.get(meta, :ast_node_id) do
          nil -> extract_from_children(ast, acc)
          node_id ->
            point = create_instrumentation_point(node_id, :function_entry, {name, 0}, meta, :private)
            extract_from_children(ast, [point | acc])
        end
      
      # Pipe operations
      {:|>, meta, _args} ->
        case Keyword.get(meta, :ast_node_id) do
          nil -> extract_from_children(ast, acc)
          node_id ->
            point = create_instrumentation_point(node_id, :pipe_operation, nil, meta, :public)
            extract_from_children(ast, [point | acc])
        end
      
      # Case statements
      {:case, meta, _args} ->
        case Keyword.get(meta, :ast_node_id) do
          nil -> extract_from_children(ast, acc)
          node_id ->
            point = create_instrumentation_point(node_id, :case_statement, nil, meta, :public)
            extract_from_children(ast, [point | acc])
        end
      
      # Try-catch blocks
      {:try, meta, _args} ->
        case Keyword.get(meta, :ast_node_id) do
          nil -> extract_from_children(ast, acc)
          node_id ->
            point = create_instrumentation_point(node_id, :try_block, nil, meta, :public)
            extract_from_children(ast, [point | acc])
        end
      
      # Module attributes
      {:@, meta, _args} ->
        case Keyword.get(meta, :ast_node_id) do
          nil -> extract_from_children(ast, acc)
          node_id ->
            point = create_instrumentation_point(node_id, :module_attribute, nil, meta, :public)
            extract_from_children(ast, [point | acc])
        end
      
      # Recurse into other structures
      _ ->
        extract_from_children(ast, acc)
    end
  end

  defp extract_from_children(ast, acc) do
    case ast do
      {_form, _meta, args} when is_list(args) ->
        Enum.reduce(args, acc, fn child, child_acc ->
          extract_points_recursive(child, child_acc)
        end)
      
      {_form, args} when is_list(args) ->
        Enum.reduce(args, acc, fn child, child_acc ->
          extract_points_recursive(child, child_acc)
        end)
      
      list when is_list(list) ->
        Enum.reduce(list, acc, fn child, child_acc ->
          extract_points_recursive(child, child_acc)
        end)
      
      # Handle keyword lists (like [do: body])
      keyword_list when is_list(keyword_list) ->
        Enum.reduce(keyword_list, acc, fn
          {_key, value}, child_acc ->
            extract_points_recursive(value, child_acc)
          other, child_acc ->
            extract_points_recursive(other, child_acc)
        end)
      
      _ ->
        acc
    end
  end

  defp create_instrumentation_point(ast_node_id, type, function_info, meta, visibility) do
    base_point = %{
      ast_node_id: ast_node_id,
      type: determine_instrumentation_type(type, function_info, meta),
      function: function_info,
      visibility: visibility,
      has_pattern_matching: has_pattern_matching?(meta),
      has_guards: has_guards?(meta),
      line: Keyword.get(meta, :line),
      file: Keyword.get(meta, :file)
    }
    
    # Add type-specific metadata
    case type do
      :function_entry ->
        Map.merge(base_point, %{
          instrumentation_strategy: :function_tracing,
          capture_args: true,
          capture_return: true
        })
      
      :pipe_operation ->
        Map.merge(base_point, %{
          instrumentation_strategy: :data_flow_tracing,
          capture_input: true,
          capture_output: true
        })
      
      :case_statement ->
        Map.merge(base_point, %{
          instrumentation_strategy: :control_flow_tracing,
          capture_condition: true,
          capture_branches: true
        })
      
      _ ->
        base_point
    end
  end

  defp determine_instrumentation_type(:function_entry, {name, _arity}, meta) do
    cond do
      is_genserver_callback?(name) -> :genserver_callback
      is_phoenix_controller_action?(name, meta) -> :controller_action
      is_phoenix_live_view_callback?(name) -> :live_view_callback
      true -> :function_entry
    end
  end

  defp determine_instrumentation_type(type, _function_info, _meta), do: type

  defp has_pattern_matching?(_meta) do
    # This would require more sophisticated AST analysis
    # For now, we'll default to false and enhance later
    false
  end

  defp has_guards?(_meta) do
    # This would require more sophisticated AST analysis
    # For now, we'll default to false and enhance later
    false
  end

  defp is_genserver_callback?(name) do
    name in [:init, :handle_call, :handle_cast, :handle_info, :terminate, :code_change]
  end

  defp is_phoenix_controller_action?(name, _meta) do
    # Common Phoenix controller actions
    name in [:index, :show, :new, :create, :edit, :update, :delete]
  end

  defp is_phoenix_live_view_callback?(name) do
    name in [:mount, :handle_params, :handle_event, :handle_info, :render]
  end

  defp generate_correlation_id(point, index) do
    base = "corr_#{point.type}_#{index}"
    hash = :crypto.hash(:md5, "#{base}_#{point.ast_node_id}") |> Base.encode16(case: :lower)
    "#{base}_#{String.slice(hash, 0, 8)}"
  end
end 