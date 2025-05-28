defmodule ElixirScope.Capture.TemporalBridge.ASTIntegration do
  @moduledoc """
  Enhancements and integration points for `TemporalBridge` to leverage the
  rich data from the `ElixirScope.ASTRepository`.

  This module outlines how `TemporalBridge` can:
  - Correlate runtime events with more detailed AST/CPG information.
  - Provide richer context for state reconstruction and time-travel debugging.
  - Enable queries that combine temporal event data with static code structure.

  It assumes `TemporalBridge` continues to manage time-indexed runtime events,
  while `ASTRepository.Repository` provides access to static code analysis data.
  """

  alias ElixirScope.ASTRepository.Repository
  alias ElixirScope.ASTRepository.CPGData
  alias ElixirScope.ASTRepository.CPGNode
  alias ElixirScope.Capture.TemporalStorage # For accessing stored events
  # Assume Event struct includes :ast_node_id and :correlation_id

  @doc """
  Retrieves a runtime event and augments it with detailed context from the AST/CPG.
  """
  @spec get_event_with_ast_context(event_id :: term(), repo_pid :: pid() | atom()) ::
          {:ok, map()} | {:error, :event_not_found | :ast_context_not_found | term()}
  def get_event_with_ast_context(event_id, repo_pid \\ Repository) do
    with {:ok, event} <- TemporalStorage.get_event(event_id), # Assuming TemporalStorage has such a function
         ast_node_id when not is_nil(ast_node_id) <- Map.get(event, :ast_node_id) do
      # Fetch CPG node or relevant AST/CFG/DFG info for this ast_node_id
      case Repository.find_cpg_node_by_ast_id(repo_pid, ast_node_id) do # This function needs to exist in Repository
        {:ok, %CPGNode{} = cpg_node} ->
          enriched_event = Map.put(event, :ast_cpg_context, cpg_node)
          {:ok, enriched_event}
        {:error, :not_found} ->
          # Fallback: Try to get basic AST node if CPG node isn't directly mapped or CPG not built
          case Repository.get_ast_node(repo_pid, ast_node_id) do
            {:ok, {ast_snippet, ast_meta}} ->
              enriched_event = Map.put(event, :ast_basic_context, %{ast: ast_snippet, metadata: ast_meta})
              {:ok, enriched_event}
            _ ->
              {:ok, Map.put(event, :ast_context_error, :ast_node_id_not_resolved_in_repo)} # Event found, but AST context missing
          end
        {:error, repo_err} ->
          Logger.warn("Failed to get CPG context for event #{event_id}, ast_node_id #{ast_node_id}: #{inspect(repo_err)}")
          {:ok, Map.put(event, :ast_context_error, :repository_error)}
      end
    else
      {:error, :event_not_found} -> {:error, :event_not_found}
      _nil_ast_node_id -> {:ok, event} # Event found but has no ast_node_id
    end
  end

  @doc """
  Reconstructs the state of a process (e.g., GenServer) at a specific time
  and includes the CPG context of the function/callback that was executing
  or had just finished executing.
  """
  @spec reconstruct_state_with_ast_context(
          process_id_or_name :: pid() | atom() | String.t(),
          timestamp :: DateTime.t(),
          repo_pid :: pid() | atom()
        ) :: {:ok, map()} | {:error, term()}
  def reconstruct_state_with_ast_context(process_identifier, timestamp, repo_pid \\ Repository) do
    # This would be an enhanced version of TemporalBridge.reconstruct_state_at/2
    with {:ok, state_reconstruction} <- ElixirScope.Capture.TemporalBridge.reconstruct_state_at(process_identifier, timestamp),
         # state_reconstruction should include the event that led to this state, which has an ast_node_id
         last_event when not is_nil(last_event) <- Map.get(state_reconstruction, :triggering_event) || find_closest_event(process_identifier, timestamp),
         ast_node_id when not is_nil(ast_node_id) <- Map.get(last_event, :ast_node_id) do

      # Fetch CPG context for the ast_node_id of the triggering event
      case Repository.find_cpg_node_by_ast_id(repo_pid, ast_node_id) do
        {:ok, cpg_node_context} ->
          enriched_reconstruction = Map.put(state_reconstruction, :executing_ast_cpg_context, cpg_node_context)
          # Potentially fetch the CPG for the whole function if cpg_node_context is just one node
          if function_key = Map.get(cpg_node_context.metadata || %{}, :function_key) do # Assuming CPGNode metadata links to function
            case Repository.get_cpg(repo_pid, elem(function_key,0), elem(function_key,1), elem(function_key,2)) do
              {:ok, function_cpg} -> Map.put(enriched_reconstruction, :function_cpg, function_cpg)
              _ -> enriched_reconstruction
            end
          else
            enriched_reconstruction
          end
          |> then(&{:ok, &1})
        _ ->
          # No CPG context, return original reconstruction
          {:ok, state_reconstruction}
      end
    else
      {:error, reason} -> {:error, reason}
      _no_triggering_event_or_ast_id -> # Could not find event or ast_node_id
        # Fallback or return original reconstruction if already fetched
        case ElixirScope.Capture.TemporalBridge.reconstruct_state_at(process_identifier, timestamp) do
            {:ok, state_rec} -> {:ok, state_rec} # Return original if no AST context linkable
            err -> err
        end
    end
  end

  defp find_closest_event(process_identifier, timestamp) do
    # Helper to find the event closest to (and likely before) the timestamp for state context
    # This logic would live in TemporalStorage or be more complex.
    # Query TemporalStorage for events for `process_identifier` around `timestamp`.
    case TemporalStorage.query_events(%{
      process_filter: process_identifier,
      time_range: {DateTime.add(timestamp, -10, :second), timestamp}, # Look 10s back
      limit: 1,
      sort: :desc # Get the latest event before or at the timestamp
    }) do
      {:ok, [event | _]} -> event
      _ -> nil
    end
  end

  @doc """
  Provides an execution "story" or trace for a given correlation ID,
  where each step in the trace is augmented with its CPG node context.
  """
  @spec get_correlated_trace_with_ast_context(correlation_id :: String.t(), repo_pid :: pid() | atom()) ::
          {:ok, [map()]} | {:error, term()}
  def get_correlated_trace_with_ast_context(correlation_id, repo_pid \\ Repository) do
    with {:ok, events} <- TemporalStorage.get_events_by_correlation_id(correlation_id) do
      enriched_events = Enum.map(events, fn event ->
        case get_event_with_ast_context(event.id, repo_pid) do # Assuming event has an id field
          {:ok, enriched_event} -> enriched_event
          _ -> event # Fallback to original event if context fails
        end
      end)
      {:ok, Enum.sort_by(enriched_events, & &1.timestamp)} # Ensure sorted by time
    else
      error -> error
    end
  end

  @doc """
  Finds all runtime execution paths (sequences of AST Node IDs traversed)
  that occurred within a specific function during a given time range.
  This requires events to log AST Node IDs at a granular level (e.g., basic block entries).
  """
  @spec get_runtime_execution_paths_for_function(
          function_key :: {module, fun, arity},
          time_range :: {DateTime.t(), DateTime.t()},
          repo_pid :: pid() | atom()
        ) :: {:ok, list_of_paths :: [[String.t()]]} | {:error, term()}
  def get_runtime_execution_paths_for_function(function_key, time_range, _repo_pid \\ Repository) do
    # 1. Fetch CPG for the function to understand its structure and valid AST Node IDs.
    #    (Not strictly needed for this query if ast_node_ids are opaque, but good for validation)
    # 2. Query TemporalStorage for all events within `time_range` that have an `ast_node_id`
    #    belonging to `function_key`. (This requires `ast_node_id` to be queryable and filterable by function).
    #    Alternatively, filter events by `function_key` if events are tagged as such.
    # 3. Group events by `correlation_id` (or a session/trace ID).
    # 4. For each group, extract the sequence of `ast_node_id`s in chronological order.

    # This is a complex query relying on how events are stored and indexed.
    # Example using a conceptual event structure:
    # Event: %{timestamp: ..., correlation_id: ..., function_key: {M,F,A}, ast_node_id: "...", type: :ast_node_visit}

    {:ok, events} = TemporalStorage.query_events(%{
      function_key_filter: function_key,
      time_range: time_range,
      event_type_filter: :ast_node_visit # Assuming such an event type exists for path reconstruction
      # Or any event that has ast_node_id and function_key
    })

    paths = events
    |> Enum.group_by(& &1.correlation_id) # Group by trace/request
    |> Map.values()
    |> Enum.map(fn trace_events ->
      trace_events
      |> Enum.sort_by(& &1.timestamp)
      |> Enum.map(& &1.ast_node_id)
      |> Enum.reject(&is_nil/1)
    end)
    |> Enum.reject(&Enum.empty?/1) # Remove traces with no relevant AST node visits

    {:ok, paths}
  end

  @doc """
  Visualizes an execution path on the CPG.
  Returns data suitable for rendering (e.g., list of CPG node IDs and edge IDs to highlight).
  """
  @spec prepare_cpg_visualization_for_path(
          function_key :: {module, fun, arity},
          runtime_ast_node_id_path :: [String.t()],
          repo_pid :: pid() | atom()
        ) :: {:ok, map()} | {:error, :cpg_not_found | term()}
  def prepare_cpg_visualization_for_path(function_key, runtime_ast_node_id_path, repo_pid \\ Repository) do
    with {:ok, %CPGData{} = cpg} <- Repository.get_cpg(repo_pid, elem(function_key,0), elem(function_key,1), elem(function_key,2)) do
      # Map runtime AST Node IDs in the path to CPG Node IDs
      highlighted_cpg_nodes =
        runtime_ast_node_id_path
        |> Enum.map(&Map.get(cpg.node_mappings.ast, &1)) # Find CPG node ID for each AST ID
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()

      # Identify CPG edges connecting these highlighted CPG nodes (sequentially)
      highlighted_cpg_edges =
        runtime_ast_node_id_path
        |> Enum.chunk_every(2, 1, :discard) # Get pairs [n1, n2], [n2, n3], ...
        |> Enum.map(fn [ast_id1, ast_id2] ->
          cpg_id1 = Map.get(cpg.node_mappings.ast, ast_id1)
          cpg_id2 = Map.get(cpg.node_mappings.ast, ast_id2)
          if cpg_id1 && cpg_id2 do
            # Find direct CFG edge in CPG between cpg_id1 and cpg_id2
            Enum.find(cpg.edges, fn edge ->
              edge.from_node_id == cpg_id1 &&
              edge.to_node_id == cpg_id2 &&
              String.starts_with?(Atom.to_string(edge.type), "cfg_")
            end)
          else
            nil
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.map(& &1.id) # Assuming CPGEdge has an id, or just return the edge structs
        |> Enum.uniq()


      visualization_data = %{
        cpg_function_key: function_key,
        all_cpg_nodes: Map.keys(cpg.nodes), # or the full nodes map for rendering
        all_cpg_edges: Enum.map(cpg.edges, & &1.id), # or full edges list
        highlight_nodes: highlighted_cpg_nodes,
        highlight_edges: highlighted_cpg_edges,
        # Optionally, include runtime values associated with path nodes
        # runtime_values_on_path: fetch_values_for_path_nodes(runtime_ast_node_id_path, some_correlation_context)
      }
      {:ok, visualization_data}
    else
      {:error, :not_found} -> {:error, :cpg_not_found}
      error -> error
    end
  end

  # --- Helper for debugging/dev ---
  def dump_ast_context_for_correlation_id(correlation_id, repo_pid \\ Repository) do
    IO.puts "--- AST Context Dump for Correlation ID: #{correlation_id} ---"
    case get_correlated_trace_with_ast_context(correlation_id, repo_pid) do
      {:ok, events} ->
        if Enum.empty?(events) do
          IO.puts "No events found or no AST context available for this correlation ID."
        else
          Enum.each(events, fn event ->
            IO.puts "Timestamp: #{inspect event.timestamp}"
            IO.puts "Event Type: #{inspect Map.get(event, :type)}" # Assuming event has :type
            IO.puts "AST Node ID: #{inspect Map.get(event, :ast_node_id)}"
            if cpg_ctx = Map.get(event, :ast_cpg_context) do
              IO.puts "  CPG Context:"
              IO.puts "    ID: #{cpg_ctx.id}"
              IO.puts "    Label: #{cpg_ctx.label}"
              IO.puts "    Type: #{cpg_ctx.type}"
              IO.puts "    Line: #{cpg_ctx.line}"
              IO.puts "    Source: #{String.slice(cpg_ctx.source_text || "", 0, 50)}"
            else
              IO.puts "  No CPG context found."
            end
            IO.puts "---"
          end)
        end
      {:error, reason} ->
        IO.puts "Error fetching trace: #{inspect reason}"
    end
    :ok
  end

end
