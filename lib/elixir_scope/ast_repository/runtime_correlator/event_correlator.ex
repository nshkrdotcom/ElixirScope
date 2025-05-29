defmodule ElixirScope.ASTRepository.RuntimeCorrelator.EventCorrelator do
  @moduledoc """
  Core event correlation logic for the RuntimeCorrelator.

  Handles the mapping between runtime events and AST nodes,
  providing context enrichment and metadata extraction.
  """

  require Logger

  alias ElixirScope.ASTRepository.EnhancedRepository
  alias ElixirScope.ASTRepository.Enhanced.{
    EnhancedFunctionData,
    EnhancedModuleData,
    CFGData,
    DFGData
  }
  alias ElixirScope.ASTRepository.RuntimeCorrelator.{Types, CacheManager, ContextBuilder}

  # Cache TTL (5 minutes)
  @cache_ttl 300_000

  @doc """
  Correlates a runtime event to its corresponding AST nodes.
  """
  @spec correlate_event_to_ast(pid() | atom(), map(), map()) :: {:ok, Types.ast_context()} | {:error, term()}
  def correlate_event_to_ast(repo, event, state) do
    # Validate event first
    with :ok <- validate_event(event),
         {:ok, ast_context} <- correlate_event_internal(repo, event, state) do
      {:ok, ast_context}
    else
      error -> error
    end
  end

  @doc """
  Gets comprehensive runtime context for an event.
  """
  @spec get_runtime_context(pid() | atom(), map(), map()) :: {:ok, Types.ast_context()} | {:error, term()}
  def get_runtime_context(repo, event, state) do
    with {:ok, ast_context} <- correlate_event_to_ast(repo, event, state),
         {:ok, enhanced_context} <- ContextBuilder.enhance_context(repo, ast_context, event) do
      {:ok, enhanced_context}
    else
      error -> error
    end
  end

  @doc """
  Enhances a runtime event with AST metadata.
  """
  @spec enhance_event_with_ast(pid() | atom(), map(), map()) :: {:ok, Types.enhanced_event()} | {:error, term()}
  def enhance_event_with_ast(repo, event, state) do
    with {:ok, ast_context} <- correlate_event_to_ast(repo, event, state),
         {:ok, structural_info} <- extract_structural_info(ast_context),
         {:ok, data_flow_info} <- extract_data_flow_info(repo, ast_context, event) do

      enhanced_event = %{
        original_event: event,
        ast_context: ast_context,
        correlation_metadata: %{
          correlation_time: System.monotonic_time(:nanosecond),
          correlation_version: "1.0"
        },
        structural_info: structural_info,
        data_flow_info: data_flow_info
      }

      {:ok, enhanced_event}
    else
      error -> error
    end
  end

  # Private Functions

  defp validate_event(nil), do: {:error, :nil_event}
  defp validate_event(event) when not is_map(event), do: {:error, :invalid_event_type}
  defp validate_event(event) do
    module = extract_module(event)
    function = extract_function(event)

    cond do
      is_nil(module) -> {:error, :missing_module}
      is_nil(function) -> {:error, :missing_function}
      not is_atom(module) -> {:error, :invalid_module_type}
      not is_atom(function) -> {:error, :invalid_function_type}
      true -> :ok
    end
  end

  defp correlate_event_internal(repo, event, state) do
    # Check cache first
    cache_key = CacheManager.generate_correlation_cache_key(event)

    case CacheManager.get_from_context_cache(cache_key) do
      {:ok, ast_context} ->
        # Cache hit
        {:ok, ast_context}

      :cache_miss ->
        # Cache miss - perform fresh correlation
        correlate_event_fresh(repo, event, cache_key, state)
    end
  end

  defp correlate_event_fresh(repo, event, cache_key, _state) do
    with {:ok, module_data} <- get_module_data(repo, extract_module(event)),
         {:ok, function_data} <- get_function_data(module_data, extract_function(event), extract_arity(event)),
         {:ok, ast_node_id} <- generate_ast_node_id(event, function_data),
         {:ok, ast_context} <- build_ast_context(function_data, ast_node_id, event) do

      # Cache the result
      CacheManager.put_in_context_cache(cache_key, ast_context)

      {:ok, ast_context}
    else
      error -> error
    end
  end

  defp get_module_data(repo, module) when not is_nil(module) do
    case EnhancedRepository.get_enhanced_module(module) do
      {:ok, module_data} -> {:ok, module_data}
      {:error, :not_found} -> {:error, :module_not_found}
      error -> error
    end
  end

  defp get_module_data(_repo, nil), do: {:error, :invalid_module}

  defp get_function_data(module_data, function, arity) when not is_nil(function) do
    case Map.get(module_data.functions, {function, arity}) do
      nil -> {:error, :function_not_found}
      function_data -> {:ok, function_data}
    end
  end

  defp get_function_data(_module_data, nil, _arity), do: {:error, :invalid_function}

  defp generate_ast_node_id(event, function_data) do
    # Check if event already has ast_node_id
    case Map.get(event, :ast_node_id) do
      nil ->
        # Generate ast_node_id from event data
        module = extract_module(event)
        function = extract_function(event)
        arity = extract_arity(event)
        line = extract_line_number(event, function_data)

        # Use short module name (last part after the last dot)
        short_module_name = case to_string(module) do
          "Elixir." <> rest ->
            rest |> String.split(".") |> List.last()
          module_str ->
            module_str |> String.split(".") |> List.last()
        end

        node_id = "#{short_module_name}.#{function}/#{arity}:line_#{line}"
        {:ok, node_id}

      existing_ast_node_id ->
        # Use existing ast_node_id from event
        {:ok, existing_ast_node_id}
    end
  end

  defp build_ast_context(function_data, ast_node_id, event) do
    context = %{
      module: function_data.module_name,
      function: function_data.function_name,
      arity: function_data.arity,
      ast_node_id: ast_node_id,
      line_number: extract_line_number(event, function_data),
      ast_metadata: %{
        complexity: function_data.complexity,
        visibility: function_data.visibility,
        file_path: function_data.file_path,
        line_start: function_data.line_start,
        line_end: function_data.line_end
      },
      cfg_node: nil,
      dfg_context: nil,
      variable_scope: %{},
      call_context: []
    }

    {:ok, context}
  end

  defp extract_structural_info(ast_context) do
    structural_info = %{
      ast_node_type: determine_ast_node_type(ast_context),
      structural_depth: calculate_structural_depth(ast_context),
      pattern_context: extract_pattern_context(ast_context),
      control_flow_position: determine_control_flow_position(ast_context)
    }

    {:ok, structural_info}
  end

  defp extract_data_flow_info(repo, ast_context, event) do
    with {:ok, dfg_context} <- ContextBuilder.get_dfg_context(repo, ast_context) do
      data_flow_info = %{
        variable_definitions: extract_variable_definitions(dfg_context),
        variable_uses: extract_variable_uses(dfg_context),
        data_dependencies: extract_data_dependencies(dfg_context),
        flow_direction: determine_flow_direction(event, dfg_context)
      }

      {:ok, data_flow_info}
    else
      error -> error
    end
  end

  # Event field extraction helpers

  defp extract_module(%{module: module}), do: module
  defp extract_module(%{"module" => module}), do: module
  defp extract_module(_), do: nil

  defp extract_function(%{function: function}), do: function
  defp extract_function(%{"function" => function}), do: function
  defp extract_function(_), do: nil

  defp extract_arity(%{arity: arity}), do: arity
  defp extract_arity(%{"arity" => arity}), do: arity
  defp extract_arity(_), do: 0

  defp extract_line_number(event, function_data) do
    # Try to extract line number from event or use function start line
    cond do
      Map.has_key?(event, :caller_line) and not is_nil(Map.get(event, :caller_line)) ->
        Map.get(event, :caller_line)
      Map.has_key?(event, :line) and not is_nil(Map.get(event, :line)) ->
        Map.get(event, :line)
      true ->
        function_data.line_start
    end
  end

  # Placeholder implementations for complex analysis functions

  defp determine_ast_node_type(_ast_context), do: :function_call
  defp calculate_structural_depth(_ast_context), do: 1
  defp extract_pattern_context(_ast_context), do: %{}
  defp determine_control_flow_position(_ast_context), do: :sequential
  defp extract_variable_definitions(_dfg_context), do: []
  defp extract_variable_uses(_dfg_context), do: []
  defp extract_data_dependencies(_dfg_context), do: []
  defp determine_flow_direction(_event, _dfg_context), do: :forward
end
