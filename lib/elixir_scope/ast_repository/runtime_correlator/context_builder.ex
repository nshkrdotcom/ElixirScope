defmodule ElixirScope.ASTRepository.RuntimeCorrelator.ContextBuilder do
  @moduledoc """
  Context building and enhancement for the RuntimeCorrelator.

  Responsible for building comprehensive AST contexts with CFG/DFG data,
  variable scopes, and call hierarchies.
  """

  alias ElixirScope.ASTRepository.EnhancedRepository
  alias ElixirScope.ASTRepository.RuntimeCorrelator.Types

  @doc """
  Enhances an AST context with additional runtime information.
  """
  @spec enhance_context(pid() | atom(), Types.ast_context(), map()) :: {:ok, Types.ast_context()} | {:error, term()}
  def enhance_context(repo, ast_context, event) do
    with {:ok, cfg_context} <- get_cfg_context(repo, ast_context),
         {:ok, dfg_context} <- get_dfg_context(repo, ast_context),
         {:ok, variable_scope} <- get_variable_scope(repo, ast_context, event),
         {:ok, call_context} <- get_call_context(repo, event) do

      enhanced_context = %{
        ast_context |
        cfg_node: cfg_context,
        dfg_context: dfg_context,
        variable_scope: variable_scope,
        call_context: call_context
      }

      {:ok, enhanced_context}
    else
      error -> error
    end
  end

  @doc """
  Gets CFG (Control Flow Graph) context for an AST context.
  """
  @spec get_cfg_context(pid() | atom(), Types.ast_context()) :: {:ok, map() | nil} | {:error, term()}
  def get_cfg_context(repo, ast_context) do
    # Get CFG data for the function
    case EnhancedRepository.get_enhanced_function(ast_context.module, ast_context.function, ast_context.arity) do
      {:ok, function_data} ->
        # Find the CFG node for the current line
        cfg_node = find_cfg_node_for_line(function_data.cfg_data, ast_context.line_number)
        {:ok, cfg_node}

      {:error, :not_found} ->
        {:ok, nil}

      error ->
        error
    end
  end

  @doc """
  Gets DFG (Data Flow Graph) context for an AST context.
  """
  @spec get_dfg_context(pid() | atom(), Types.ast_context()) :: {:ok, map() | nil} | {:error, term()}
  def get_dfg_context(repo, ast_context) do
    # Get DFG data for the function
    case EnhancedRepository.get_enhanced_function(ast_context.module, ast_context.function, ast_context.arity) do
      {:ok, function_data} ->
        # Extract relevant DFG context for the current line
        dfg_context = extract_dfg_context_for_line(function_data.dfg_data, ast_context.line_number)
        {:ok, dfg_context}

      {:error, :not_found} ->
        {:ok, nil}

      error ->
        error
    end
  end

  @doc """
  Gets variable scope information for an AST context and runtime event.
  """
  @spec get_variable_scope(pid() | atom(), Types.ast_context(), map()) :: {:ok, map()} | {:error, term()}
  def get_variable_scope(_repo, ast_context, event) do
    # Extract variable scope from event if available
    variables = case Map.get(event, :variables) do
      nil -> %{}
      vars when is_map(vars) -> vars
      _ -> %{}
    end

    scope = %{
      local_variables: variables,
      scope_level: ast_context.line_number,
      binding_context: extract_binding_context(event)
    }

    {:ok, scope}
  end

  @doc """
  Gets call context information for a runtime event.
  """
  @spec get_call_context(pid() | atom(), map()) :: {:ok, list(map())} | {:error, term()}
  def get_call_context(_repo, event) do
    # Extract call context from correlation ID and call stack
    call_context = case Map.get(event, :correlation_id) do
      nil -> []
      correlation_id -> build_call_context_from_correlation(correlation_id)
    end

    {:ok, call_context}
  end

  @doc """
  Extracts timestamp from an event with fallback to current time.
  """
  def extract_timestamp(%{timestamp: timestamp}), do: timestamp
  def extract_timestamp(%{"timestamp" => timestamp}), do: timestamp
  def extract_timestamp(_), do: System.monotonic_time(:nanosecond)

  # Private Functions

  defp find_cfg_node_for_line(_cfg_data, _line_number) do
    # Placeholder implementation - would need actual CFG traversal logic
    nil
  end

  defp extract_dfg_context_for_line(_dfg_data, _line_number) do
    # Placeholder implementation - would need actual DFG analysis logic
    %{}
  end

  defp extract_binding_context(_event) do
    # Placeholder implementation - would extract variable bindings
    %{}
  end

  defp build_call_context_from_correlation(_correlation_id) do
    # Placeholder implementation - would build call hierarchy
    []
  end
end
