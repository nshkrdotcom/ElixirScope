defmodule ElixirScope.AI.Bridge do
  @moduledoc """
  Provides a bridge and defined interaction patterns for ElixirScope's AI components
  to interface with the `ElixirScope.ASTRepository` (especially CPG data)
  and the `ElixirScope.QueryEngine` (for runtime data).

  This module facilitates how AI components like `CodeAnalyzer`, `PatternRecognizer`,
  `ASTEmbeddings`, `PredictiveAnalyzer`, and LLM services consume static code
  information and correlated runtime data to generate insights, plans, and predictions.
  """

  alias ElixirScope.ASTRepository.Repository
  alias ElixirScope.ASTRepository.CPGData, as: CPGD # CPGData itself
  alias ElixirScope.ASTRepository.CPGData.CPGNode # CPGNode struct
  # alias ElixirScope.ASTRepository.CPGData.CPGEdge # CPGEdge struct
  alias ElixirScope.QueryEngine.ASTExtensions # For executing AST/CPG queries
  alias ElixirScope.QueryEngine # For executing runtime event queries

  # For specific AI components (assuming they exist or will be enhanced)
  alias ElixirScope.AI.{CodeAnalyzer, PatternRecognizer, ASTEmbeddings, PredictiveAnalyzer, LLMInterface}

  @type function_key :: {module :: atom(), function :: atom(), arity :: non_neg_integer()}

  # --- Data Fetching Facades for AI Components ---

  @doc """
  Fetches the full Code Property Graph for a given function, intended for AI analysis.
  """
  @spec get_function_cpg_for_ai(function_key :: function_key(), repo_pid :: pid() | atom()) ::
          {:ok, CPGD.t()} | {:error, term()}
  def get_function_cpg_for_ai(function_key, repo_pid \\ Repository) do
    # This might involve direct CPG fetch or ensuring it's built if not present.
    # The ASTExtensions query type already handles this.
    ASTExtensions.execute_ast_query(%{
      type: :get_cpg_for_function,
      params: %{function_key: function_key},
      opts: [cache_hint: :ai_analysis] # Optional hint for caching
    })
    # The result from execute_ast_query needs to be unwrapped if it has extra metadata
    |> case do
      {:ok, %{results: %CPGD{} = cpg_data}} -> {:ok, cpg_data} # If wrapped by a mock/generic executor
      {:ok, %CPGD{} = cpg_data} -> {:ok, cpg_data} # If directly returns CPGData
      error -> error
    end
  end

  @doc """
  Fetches relevant CPG nodes based on a structural or semantic pattern.
  Used by `PatternRecognizer` or other AI components looking for specific code constructs.
  """
  @spec find_cpg_nodes_for_ai_pattern(cpg_pattern_dsl :: map(), function_key :: function_key() | nil, repo_pid :: pid() | atom()) ::
          {:ok, [CPGNode.t()]} | {:error, term()}
  def find_cpg_nodes_for_ai_pattern(cpg_pattern_dsl, function_key \\ nil, _repo_pid \\ Repository) do
    query_spec = ElixirScope.ASTRepository.QueryBuilder.find_cpg_nodes()
                 |> ElixirScope.ASTRepository.QueryBuilder.match_cpg_pattern(cpg_pattern_dsl)
                 |> (fn q -> if function_key, do: ElixirScope.ASTRepository.QueryBuilder.where(q, "cpg_data.function_key", :eq, function_key), else: q end).()

    ASTExtensions.execute_ast_query(query_spec)
    |> case do
      {:ok, %{results: nodes_list}} when is_list(nodes_list) -> {:ok, nodes_list}
      {:ok, nodes_list} when is_list(nodes_list) -> {:ok, nodes_list}
      error -> error
    end
  end

  @doc """
  Retrieves correlated static (CPG node properties) and dynamic (runtime event summaries)
  data for a set of CPG nodes or function keys.
  Useful for `PredictiveAnalyzer` to build feature sets.
  """
  @spec get_correlated_features_for_ai(
          target_type :: :function_keys | :cpg_node_ids,
          ids :: list(function_key() | String.t()),
          runtime_event_filters :: map(), # Filters for runtime events (e.g., type, time_range)
          static_features :: list(atom), # e.g., [:complexity_score, :label]
          dynamic_features :: list(atom) # e.g., [:avg_duration_ms, :error_count]
        ) :: {:ok, list(map())} | {:error, term()}
  def get_correlated_features_for_ai(target_type, ids, runtime_event_filters, static_features, dynamic_features) do
    # This is a complex operation:
    # 1. For each ID, fetch its static features from ASTRepository (CPG).
    # 2. For each ID, query QueryEngine for summarized runtime events matching `runtime_event_filters`.
    #    The summarization (avg_duration, error_count) needs to happen in QueryEngine or here.
    # 3. Join the static and dynamic features.

    # Example for :function_keys
    if target_type == :function_keys do
      Enum.map_reduce(ids, [], fn function_key, errors_acc ->
        # Fetch static features
        static_data = case get_function_cpg_for_ai(function_key) do # or a more direct feature fetch
          {:ok, cpg} ->
            # Extract desired static_features from CPG (e.g., root function node)
            # This is simplified; would need to navigate CPG to get function-level summary features
            entry_node_id = "#{elem(function_key,0)}:#{elem(function_key,1)}:#{elem(function_key,2)}:entry" # Example CPG root ID for func
            root_node = Map.get(cpg.nodes, entry_node_id) # Or find by type :function_entry
            Map.take(root_node || %{}, static_features) |> Map.put(:function_key, function_key)
          _ -> %{function_key: function_key} # Default if static fetch fails
        end

        # Fetch dynamic features (summarized runtime data)
        # This query is conceptual and needs support from QueryEngine
        runtime_query = %{
          select: dynamic_features, # Tells QueryEngine what to aggregate
          from: :runtime_events,
          where: [
            %{field: :function_key, op: :eq, value: function_key}
            # Add filters from runtime_event_filters (e.g., time_range)
          ] ++ runtime_event_filters_to_conditions(runtime_event_filters),
          group_by: [:function_key] # To get aggregates per function
        }
        dynamic_data = case ElixirScope.QueryEngine.execute_event_query_with_aggregation(runtime_query) do # Assumes this exists
          {:ok, [%{function_key: ^function_key} = aggregates | _]} -> aggregates
          _ -> Enum.into(dynamic_features, %{}, fn feat -> {feat, nil} end) # Defaults if no runtime data
        end

        # Combine
        combined_features = Map.merge(static_data, dynamic_data)
        {{:ok, combined_features}, errors_acc}
      end)
      |> then(fn {results, _errors} -> {:ok, Enum.filter(results, fn r -> elem(r,0) == :ok end) |> Enum.map(&elem(&1,1))} end) # Filter out errors and unwrap
    else
      # Similar logic for :cpg_node_ids, joining on ast_node_id (or cpg_node.id)
      {:error, :not_implemented_for_cpg_node_ids}
    end
  end

  defp runtime_event_filters_to_conditions(filters_map) do
    Enum.map(filters_map, fn {field, value} ->
      # Simple :eq for now, can be extended
      %{field: field, op: :eq, value: value}
    end)
  end


  # --- AI Component Interaction Patterns ---

  @doc """
  Pattern for `AI.CodeAnalyzer` to generate an initial analysis plan.
  """
  def analyze_for_instrumentation_plan(module_ast :: Macro.t(), module_name :: atom(), file_path :: String.t()) :: {:ok, EnhancedModuleData.t(), instrumentation_plan :: map()} | {:error, term()} do
    # 1. Use ASTAnalyzer to get EnhancedModuleData (which includes basic analysis)
    with {:ok, %EnhancedModuleData{} = enhanced_module_data} <- ASTAnalyzer.analyze_module_ast(module_ast, module_name, file_path) do
      # 2. (Future) Store/Update this in ASTRepository
      #    Repository.store_module(enhanced_module_data)

      # 3. `CodeAnalyzer` (the AI component) uses this `enhanced_module_data`
      #    and potentially queries for CPGs of complex functions to decide on an
      #    instrumentation plan.
      #    For now, `CodeAnalyzer` might be simpler and just use `enhanced_module_data`.
      instrumentation_plan = ElixirScope.AI.CodeAnalyzer.generate_instrumentation_plan(enhanced_module_data)

      {:ok, enhanced_module_data, instrumentation_plan}
    else
      error -> error
    end
  end


  @doc """
  Pattern for `AI.ASTEmbeddings` to generate and store embeddings.
  """
  @spec generate_and_store_embeddings_for_module(module_name :: atom(), repo_pid :: pid() | atom()) :: :ok | {:error, term()}
  def generate_and_store_embeddings_for_module(module_name, repo_pid \\ Repository) do
    # 1. Fetch all functions for the module
    case Repository.get_functions_for_module(repo_pid, module_name) do
      {:ok, functions_data_list} ->
        Enum.each(functions_data_list, fn %EnhancedFunctionData{} = func_data ->
          function_key = {func_data.module_name, func_data.function_name, func_data.arity}
          # 2. Fetch/build CPG for each function
          case get_function_cpg_for_ai(function_key, repo_pid) do
            {:ok, cpg_data} ->
              # 3. Generate embedding using AI.ASTEmbeddings
              case ASTEmbeddings.generate_cpg_embedding(cpg_data) do # Assuming this function exists
                {:ok, embedding_vector} ->
                  # 4. Store the embedding, associated with the function_key or CPG ID.
                  # This might be in a vector DB or as metadata in ASTRepository.
                  ASTEmbeddings.store_embedding(function_key, embedding_vector) # Conceptual
                  Logger.debug("Generated and stored embedding for #{inspect(function_key)}")
                {:error, emb_err} ->
                  Logger.error("Failed to generate embedding for #{inspect(function_key)}: #{inspect(emb_err)}")
              end
            {:error, cpg_err} ->
              Logger.error("Failed to get CPG for #{inspect(function_key)} for embedding: #{inspect(cpg_err)}")
          end
        end)
        :ok
      {:error, repo_err} -> {:error, repo_err}
    end
  end


  @doc """
  Pattern for `AI.PredictiveAnalyzer` to make a prediction.
  """
  @spec predict_with_analyzer(analyzer_module :: module(), function_key :: function_key(), additional_context :: map()) ::
          {:ok, prediction_result :: map()} | {:error, term()}
  def predict_with_analyzer(PredictiveAnalyzer, function_key, additional_context \\ %{}) do
    # 1. Fetch static features (e.g., CPG sub-graph, complexity metrics)
    with {:ok, cpg_data} <- get_function_cpg_for_ai(function_key) do
      static_features = PredictiveAnalyzer.extract_static_features_from_cpg(cpg_data)

      # 2. Fetch relevant runtime history (e.g., recent error rate, avg execution time for this function)
      #    This uses the `get_correlated_features_for_ai` or similar.
      {:ok, correlated_data_list} = get_correlated_features_for_ai(
        :function_keys,
        [function_key],
        %{time_range: {:last_days, 7}}, # Example runtime filter
        [], # No extra static needed here
        [:avg_duration_ms, :error_count_last_7d] # Example dynamic features
      )
      runtime_features = List.first(correlated_data_list) || %{} # Expecting one result

      # 3. Combine features and make prediction
      all_features = Map.merge(static_features, runtime_features)
                     |> Map.merge(additional_context)

      PredictiveAnalyzer.predict(all_features) # Call the specific AI model
    else
      error -> error
    end
  end


  @doc """
  Pattern for using an LLM for code understanding or suggestions based on CPG context.
  """
  @spec query_llm_with_cpg_context(
          function_key :: function_key(),
          prompt_template :: String.t(), # e.g., "Explain this code: %{code_snippet}. What are potential issues?"
          llm_provider_opts :: keyword()
        ) :: {:ok, llm_response :: String.t()} | {:error, term()}
  def query_llm_with_cpg_context(function_key, prompt_template, llm_provider_opts \\ []) do
    with {:ok, cpg_data} <- get_function_cpg_for_ai(function_key) do
      # Extract relevant code snippet or structural summary from CPG
      # For simplicity, using the source text of the main function node (if CPG has one)
      # or reconstructing from EnhancedFunctionData.ast.
      {:ok, func_data} = Repository.get_function(elem(function_key,0), elem(function_key,1), elem(function_key,2))
      code_snippet = Macro.to_string(func_data.ast)

      # Other CPG-derived context:
      complexity = func_data.complexity_score # Or from cpg_data root node
      # key_data_flows = summarize_data_flows(cpg_data) # Needs helper

      prompt_params = %{
        code_snippet: String.slice(code_snippet, 0, 3000), # Limit context window
        function_mfa: "#{inspect(function_key)}",
        complexity_score: complexity
        # key_data_flows: key_data_flows
      }
      # Simple interpolation for now. Real templating might be better.
      prompt = prompt_template # Use a real templating engine for safety with `%{...}`
               |> String.replace("%{code_snippet}", prompt_params.code_snippet)
               |> String.replace("%{function_mfa}", prompt_params.function_mfa)
               |> String.replace("%{complexity_score}", to_string(prompt_params.complexity_score))


      LLMInterface.query(prompt, llm_provider_opts)
    else
      error -> error
    end
  end

end
