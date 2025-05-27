defmodule ElixirScope.ASTRepository.TestSupport.Helpers do
  @moduledoc """
  Test helper functions for AST repository testing.
  """

  import ExUnit.Assertions

  alias ElixirScope.ASTRepository.Repository
  alias ElixirScope.ASTRepository.RuntimeCorrelator
  alias ElixirScope.ASTRepository.TestSupport.Fixtures.SampleASTs

  @doc """
  Sets up a test repository with sample data.
  """
  def setup_test_repository(opts \\ []) do
    # Start the repository as a GenServer process
    {:ok, repo_pid} = Repository.start_link(name: :"test_repo_#{:erlang.unique_integer([:positive])}")
    
    if Keyword.get(opts, :with_samples, false) do
      load_sample_data(repo_pid)
    end
    
    repo_pid
  end

  @doc """
  Loads sample AST data into a repository.
  """
  def load_sample_data(repo) do
    alias ElixirScope.ASTRepository.ModuleData
    
    SampleASTs.all_sample_asts()
    |> Enum.each(fn sample ->
      # Extract module name from AST
      module_name = extract_module_name_from_ast(sample.ast)
      
      # Create ModuleData struct
      module_data = ModuleData.new(module_name, sample.ast, [
        instrumentation_points: sample.expected_points
      ])
      
      Repository.store_module(repo, module_data)
    end)
    
    repo
  end

  @doc """
  Creates a test runtime correlator with repository.
  """
  def setup_test_correlator(repo \\ nil) do
    repo = repo || setup_test_repository()
    {:ok, correlator} = RuntimeCorrelator.start_link(repository_pid: repo)
    {repo, correlator}
  end

  @doc """
  Generates a unique AST node ID for testing.
  """
  def generate_node_id do
    "ast_node_" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
  end

  @doc """
  Generates a unique correlation ID for testing.
  """
  def generate_correlation_id do
    "corr_" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
  end

  @doc """
  Creates a test runtime event with correlation metadata.
  """
  def create_test_event(opts \\ []) do
    %{
      correlation_id: Keyword.get(opts, :correlation_id, generate_correlation_id()),
      event_type: Keyword.get(opts, :event_type, :function_call),
      module: Keyword.get(opts, :module, TestModule),
      function: Keyword.get(opts, :function, :test_function),
      arity: Keyword.get(opts, :arity, 1),
      timestamp: Keyword.get(opts, :timestamp, DateTime.utc_now()),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Creates a sequence of temporal events for testing.
  """
  def create_temporal_event_sequence(count, opts \\ []) do
    base_time = Keyword.get(opts, :base_time, DateTime.utc_now())
    interval_ms = Keyword.get(opts, :interval_ms, 100)
    
    1..count
    |> Enum.map(fn i ->
      timestamp = DateTime.add(base_time, (i - 1) * interval_ms, :millisecond)
      create_test_event([
        timestamp: timestamp,
        correlation_id: "seq_#{i}_#{generate_correlation_id()}"
      ] ++ opts)
    end)
  end

  @doc """
  Extracts function definitions from an AST.
  """
  def extract_function_definitions(ast) do
    {_ast, functions} = Macro.prewalk(ast, [], fn
      {:def, _meta, [{name, _meta2, args} | _]} = node, acc when is_list(args) ->
        arity = length(args)
        {node, [{name, arity} | acc]}
      
      {:defp, _meta, [{name, _meta2, args} | _]} = node, acc when is_list(args) ->
        arity = length(args)
        {node, [{name, arity} | acc]}
      
      node, acc ->
        {node, acc}
    end)
    
    Enum.reverse(functions)
  end

  @doc """
  Counts instrumentable nodes in an AST.
  """
  def count_instrumentable_nodes(ast) do
    {_ast, count} = Macro.prewalk(ast, 0, fn
      {:def, _meta, _args} = node, acc -> {node, acc + 1}
      {:defp, _meta, _args} = node, acc -> {node, acc + 1}
      {:|>, _meta, _args} = node, acc -> {node, acc + 1}  # Pipe operations
      {:case, _meta, _args} = node, acc -> {node, acc + 1}  # Case statements
      node, acc -> {node, acc}
    end)
    
    count
  end

  @doc """
  Validates that an AST has been enhanced with node IDs.
  """
  def validate_ast_enhancement(ast) do
    {_ast, node_ids} = Macro.prewalk(ast, [], fn
      {_form, meta, _args} = node, acc ->
        case Keyword.get(meta, :ast_node_id) do
          nil -> {node, acc}
          node_id -> {node, [node_id | acc]}
        end
      
      node, acc -> {node, acc}
    end)
    
    %{
      has_node_ids: length(node_ids) > 0,
      node_id_count: length(node_ids),
      unique_node_ids: length(Enum.uniq(node_ids)),
      all_unique: length(node_ids) == length(Enum.uniq(node_ids))
    }
  end

  @doc """
  Compares two ASTs for structural equality (ignoring metadata).
  """
  def ast_structurally_equal?(ast1, ast2) do
    clean_ast(ast1) == clean_ast(ast2)
  end

  @doc """
  Removes metadata from AST for comparison.
  """
  def clean_ast(ast) do
    Macro.prewalk(ast, fn
      {form, _meta, args} -> {form, [], args}
      other -> other
    end)
  end

  @doc """
  Waits for a condition to be true with timeout.
  """
  def wait_for(condition_fn, timeout_ms \\ 1000) do
    end_time = System.monotonic_time(:millisecond) + timeout_ms
    wait_for_condition(condition_fn, end_time)
  end

  defp wait_for_condition(condition_fn, end_time) do
    if condition_fn.() do
      :ok
    else
      if System.monotonic_time(:millisecond) < end_time do
        Process.sleep(10)
        wait_for_condition(condition_fn, end_time)
      else
        {:error, :timeout}
      end
    end
  end

  @doc """
  Asserts that a correlation exists between an event and AST node.
  """
  def assert_correlation_exists(correlator, event, expected_ast_node_id \\ nil) do
    case RuntimeCorrelator.correlate_event(correlator, event) do
      {:ok, ast_node_id} ->
        if expected_ast_node_id do
          assert ast_node_id == expected_ast_node_id, 
            "Expected correlation to AST node #{expected_ast_node_id}, got #{ast_node_id}"
        end
        {:ok, ast_node_id}
      
      {:error, reason} ->
        flunk("Expected correlation to exist, but got error: #{inspect(reason)}")
    end
  end

  @doc """
  Asserts that correlation accuracy is above threshold.
  """
  def assert_correlation_accuracy(correlator, events, threshold \\ 0.95) do
    successful_correlations = 
      events
      |> Enum.count(fn event ->
        case RuntimeCorrelator.correlate_event(correlator, event) do
          {:ok, _} -> true
          {:error, _} -> false
        end
      end)
    
    total_events = length(events)
    accuracy = successful_correlations / total_events
    
    assert accuracy >= threshold,
      "Correlation accuracy #{accuracy} below threshold #{threshold} (#{successful_correlations}/#{total_events})"
    
    accuracy
  end

  @doc """
  Creates a mock module for testing.
  """
  defmacro create_test_module(name, do: body) do
    quote do
      defmodule unquote(name) do
        unquote(body)
      end
    end
  end

  @doc """
  Extracts module name from AST.
  """
  def extract_module_name_from_ast(ast) do
    case ast do
      {:defmodule, _meta, [{:__aliases__, _meta2, name_parts} | _]} ->
        Module.concat(name_parts)
      
      {:defmodule, _meta, [name | _]} when is_atom(name) ->
        name
      
      _ ->
        # Default fallback for test modules
        :"TestModule#{:erlang.unique_integer([:positive])}"
    end
  end
end 