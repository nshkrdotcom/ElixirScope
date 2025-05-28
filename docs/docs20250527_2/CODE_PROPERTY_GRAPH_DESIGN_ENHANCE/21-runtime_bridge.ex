defmodule ElixirScope.ASTRepository.RuntimeBridge do
  @moduledoc """
  Provides a bridge for `ElixirScope.Capture.InstrumentationRuntime` to interact
  with the `ElixirScope.ASTRepository` during runtime event capture.

  This module facilitates:
  - Validation or quick lookup of `ast_node_id` context if needed by the runtime.
  - Potential feedback from runtime to the AST Repository (e.g., about executed paths,
    though this is less common for a primarily static repository).
  - Ensuring that `ast_node_id`s generated at compile-time are meaningful and
    can be efficiently correlated.

  Primarily, this bridge ensures that the `InstrumentationRuntime` has access
  to any minimal static context it might need immediately upon event capture,
  before richer correlation happens in `TemporalBridge` or `QueryEngine`.
  However, to keep `InstrumentationRuntime` extremely lightweight, direct synchronous
  calls to the AST Repository from it should be minimal or non-existent.
  This bridge might be more about providing utilities *used by* the runtime
  or by downstream processors that get events from the runtime.
  """

  alias ElixirScope.ASTRepository.Repository
  alias ElixirScope.ASTRepository.NodeIdentifier # For parsing/understanding IDs
  # alias ElixirScope.ASTRepository.CPGData.CPGNode # If fetching CPG context

  @doc """
  Verifies if an `ast_node_id` is known to the AST Repository.
  This is a conceptual check; calling the repo synchronously from the runtime
  for every event is likely too slow. It's more for debugging or offline validation.
  """
  @spec ast_node_id_exists?(ast_node_id :: String.t(), repo_pid :: pid() | atom()) :: boolean()
  def ast_node_id_exists?(ast_node_id, repo_pid \\ Repository) do
    # This would check if a CPGNode corresponding to this ast_node_id (or the original_ast_node_id) exists.
    # The `Repository.find_cpg_node_by_ast_id` or `Repository.get_ast_node` could be used.
    case Repository.get_ast_node(repo_pid, ast_node_id) do # Or find_cpg_node_by_ast_id if that's the primary key
      {:ok, _} -> true
      _ -> false
    end
  end

  @doc """
  Fetches minimal static context for an AST Node ID.
  Designed for very fast lookups, potentially from a specialized cache or index if
  the main Repository query is too slow for runtime path.

  This function is more likely to be used by an *asynchronous processor* of runtime events
  rather than directly within the critical path of `InstrumentationRuntime`.
  """
  @spec get_minimal_ast_context(ast_node_id :: String.t(), repo_pid :: pid() | atom()) ::
          {:ok, map()} | {:error, :not_found | term()}
  def get_minimal_ast_context(ast_node_id, repo_pid \\ Repository) do
    # Option 1: Parse the ID itself for basic context (module, function)
    base_context = case NodeIdentifier.parse_id(ast_node_id) do
      {:ok, parsed_id} ->
        %{
          module: parsed_id.module,
          function: parsed_id.function,
          arity: parsed_id.arity,
          line_guess: parsed_id.path_info |> String.split("_") |> Enum.find_value(&String.starts_with?(&1, "L"), &(&1))
        }
      _ -> %{}
    end

    # Option 2: Quick lookup in Repository for essential CPGNode fields
    # This assumes `find_cpg_node_by_ast_id` is fast or hits a cache.
    case Repository.find_cpg_node_by_ast_id(repo_pid, ast_node_id) do # This needs to be defined in Repository API
      {:ok, %{label: label, line: line, type: type, source_text: src_text_summary}} ->
        enriched_context = base_context
                           |> Map.merge(%{
                             cpg_node_label: label,
                             cpg_node_type: type,
                             cpg_node_line: line,
                             cpg_node_source_snippet: String.slice(src_text_summary || "", 0, 30)
                           })
        {:ok, enriched_context}
      _ ->
        # If full CPG node lookup fails or is too slow, just return parsed ID info
        if map_size(base_context) > 0, do: {:ok, base_context}, else: {:error, :not_found}
    end
  end


  @doc """
  (Conceptual) Called by `InstrumentationRuntime` or a post-processor to indicate
  that a specific AST node (and thus a path) has been executed.
  The AST Repository could use this information for:
  - Hotness tracking of code paths.
  - Validating CFG reachability.
  - Guiding future AI analysis or adaptive instrumentation.

  This would likely be an asynchronous notification to avoid slowing down the runtime.
  """
  @spec notify_ast_node_executed(ast_node_id :: String.t(), function_key :: tuple(), correlation_id :: String.t() | nil, repo_pid :: pid() | atom()) ::
          :ok
  def notify_ast_node_executed(ast_node_id, function_key, correlation_id, repo_pid \\ Repository) do
    # This could send a cast to the Repository GenServer or a dedicated statistics collector.
    # For example, incrementing an execution counter for the CPG node.
    payload = %{
      ast_node_id: ast_node_id,
      function_key: function_key,
      correlation_id: correlation_id,
      timestamp: DateTime.utc_now()
    }
    # GenServer.cast(repo_pid, {:ast_node_executed, payload})
    # For now, just a log message to represent the idea:
    Logger.debug("[RuntimeBridge] AST Node Executed: #{inspect(payload)}")
    :ok
  end


  @doc """
  Provides utilities used by `ElixirScope.Capture.InstrumentationMapper` or
  `ElixirScope.AST.Transformer` during compile-time AST transformation.

  This is not called *at runtime*, but rather *for* the runtime instrumentation.
  """
  defmodule CompileTimeHelpers do
    @moduledoc false

    @doc """
    Generates the necessary AST Node ID for an expression that is about to be instrumented.
    This function would encapsulate the logic from `NodeIdentifier.assign_ids_custom_traverse`
    or similar, ensuring the ID is created correctly before injection.

    It needs the current AST node and the context (module, function, path from function root).
    """
    def ensure_and_get_ast_node_id(
          current_ast_node :: Macro.t(),
          id_generation_context :: ElixirScope.ASTRepository.NodeIdentifier.id_gen_context()
        ) :: {Macro.t(), String.t() | nil} do
      # 1. Check if ID already exists in meta
      existing_id = ElixirScope.ASTRepository.NodeIdentifier.get_id_from_ast_meta(
        ElixirScope.ASTRepository.NodeIdentifier.extract_meta(current_ast_node)
      )

      if existing_id do
        {current_ast_node, existing_id}
      else
        # This case implies that assign_ids_to_ast (or custom_traverse) wasn't run globally first,
        # or we are instrumenting a dynamically generated AST snippet.
        # For dynamically generated instrumentation calls themselves, they don't need an ID
        # from the original source code. But the *source code construct* being instrumented does.
        # This function is more about *retrieving* a pre-assigned ID.
        # If IDs are assigned in a separate pass, this would just be a lookup.
        Logger.warn("CompileTimeHelpers.ensure_and_get_ast_node_id: AST Node ID missing for #{Macro.to_string(current_ast_node) |> String.slice(0,50)}. ID generation should be a prior step.")
        # Fallback: generate a temporary or less stable ID if absolutely necessary, but this is not ideal.
        # For this bridge, we assume IDs are pre-assigned.
        {current_ast_node, nil} # Or raise an error if ID is expected.
      end
    end

    @doc """
    Prepares the arguments for an `InstrumentationRuntime` call,
    including the `ast_node_id` and any other static context.
    """
    def prepare_runtime_call_args(
          original_ast_node_with_id :: Macro.t(),
          runtime_function :: atom(), # e.g., :report_function_entry
          additional_static_args :: list() # e.g., [module_name_ast, fun_name_ast, arity_ast]
        ) :: Macro.t() do
      ast_node_id = ElixirScope.ASTRepository.NodeIdentifier.get_id_from_ast_meta(
        ElixirScope.ASTRepository.NodeIdentifier.extract_meta(original_ast_node_with_id)
      )

      unless ast_node_id do
        # This should ideally not happen if assign_ids_to_ast was run.
        # Handle error or use a placeholder ID.
        Logger.error("Missing AST Node ID during instrumentation argument preparation for: #{Macro.to_string(original_ast_node_with_id)}")
        # Fallback or error needed
      end

      # Construct the call to ElixirScope.Capture.InstrumentationRuntime
      # Example for report_ast_node_event(correlation_id, ast_node_id, event_type, payload)
      # The `correlation_id` is a runtime value, so it's passed as a variable name (e.g., `__elixir_scope_correlation_id__`)
      # The `ast_node_id` is a compile-time constant string.
      # `additional_static_args` are also compile-time constants or quoted ASTs.

      # This is a simplified example of constructing the call.
      # The actual AST for the call is more complex.
      # `ElixirScope.AST.InjectorHelpers` would handle the quoting properly.

      runtime_args_ast = [
        quote(do: __elixir_scope_correlation_id__), # Placeholder for runtime var
        ast_node_id, # Compile-time string
      ] ++ additional_static_args

      quote do
        ElixirScope.Capture.InstrumentationRuntime.unquote(runtime_function)(unquote_splicing(runtime_args_ast))
      end
    end
  end

  # Note: The primary role of this "RuntimeBridge" is less about direct, frequent runtime
  # calls *to* the AST Repository (which could be slow), and more about:
  # 1. Ensuring the `InstrumentationRuntime` *receives* well-formed, meaningful `ast_node_id`s.
  # 2. Providing utilities for *compile-time* instrumentation logic to correctly generate/use these IDs.
  # 3. Offering an interface for *post-runtime event processing* (e.g., by TemporalBridge or AI components)
  #    to fetch static context related to `ast_node_id`s found in events.
  #    The `get_minimal_ast_context` and `ast_node_id_exists?` lean towards this post-processing role.
  # The `notify_ast_node_executed` is the most "runtime-feedback" oriented function here.

end
