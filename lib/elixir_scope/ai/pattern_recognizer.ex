defmodule ElixirScope.AI.PatternRecognizer do
  @moduledoc """
  Pattern recognition for Elixir code structures.

  Identifies common OTP patterns, Phoenix patterns, and architectural structures
  to inform instrumentation decisions.
  """

  @doc """
  Identifies the primary type of an Elixir module based on its AST.
  """
  def identify_module_type(ast) do
    cond do
      has_genserver_use?(ast) -> :genserver
      has_supervisor_use?(ast) -> :supervisor
      has_phoenix_controller_use?(ast) -> :phoenix_controller
      has_phoenix_liveview_use?(ast) -> :phoenix_liveview
      has_phoenix_channel_use?(ast) -> :phoenix_channel
      has_ecto_schema_use?(ast) -> :ecto_schema
      true -> :regular
    end
  end

  @doc """
  Extracts patterns and characteristics from module AST.
  """
  def extract_patterns(ast) do
    %{
      callbacks: extract_callbacks(ast),
      actions: extract_phoenix_actions(ast),
      events: extract_liveview_events(ast),
      children: extract_supervisor_children(ast),
      strategy: extract_supervisor_strategy(ast),
      database_interactions: has_database_interactions?(ast),
      message_patterns: extract_message_patterns(ast),
      pubsub_usage: extract_pubsub_patterns(ast)
    }
  end

  # GenServer pattern recognition

  defp has_genserver_use?(ast) do
    ast_contains_use?(ast, GenServer) or 
    ast_contains_use?(ast, :GenServer) or
    ast_contains_genserver_use_pattern?(ast)
  end

  defp ast_contains_genserver_use_pattern?(ast) do
    Macro.prewalk(ast, false, fn
      {:use, _, [{:__aliases__, _, [:GenServer]}]}, _acc -> {true, true}
      {:use, _, [GenServer]}, _acc -> {true, true}
      node, acc -> {node, acc}
    end) |> elem(1)
  end

  defp extract_callbacks(ast) do
    callbacks = Macro.prewalk(ast, [], fn
      {:def, _, [{:handle_call, _, _}, _]}, acc -> {nil, [:handle_call | acc]}
      {:def, _, [{:handle_cast, _, _}, _]}, acc -> {nil, [:handle_cast | acc]}
      {:def, _, [{:handle_info, _, _}, _]}, acc -> {nil, [:handle_info | acc]}
      {:def, _, [{:terminate, _, _}, _]}, acc -> {nil, [:terminate | acc]}
      {:def, _, [{:code_change, _, _}, _]}, acc -> {nil, [:code_change | acc]}
      {:def, _, [{:init, _, _}, _]}, acc -> {nil, [:init | acc]}
      {:def, _, [{:mount, _, _}, _]}, acc -> {nil, [:mount | acc]}
      {:def, _, [{:handle_params, _, _}, _]}, acc -> {nil, [:handle_params | acc]}
      {:def, _, [{:handle_event, _, _}, _]}, acc -> {nil, [:handle_event | acc]}
      {:def, _, [{:render, _, _}, _]}, acc -> {nil, [:render | acc]}
      {:def, _, [{:start_link, _, _}, _]}, acc -> {nil, [:start_link | acc]}
      node, acc -> {node, acc}
    end) |> elem(1)
    
    Enum.reverse(callbacks)
  end

  # Supervisor pattern recognition

  defp has_supervisor_use?(ast) do
    ast_contains_use?(ast, Supervisor) or
    ast_contains_use?(ast, :Supervisor) or
    ast_contains_supervisor_use_pattern?(ast)
  end

  defp ast_contains_supervisor_use_pattern?(ast) do
    Macro.prewalk(ast, false, fn
      {:use, _, [{:__aliases__, _, [:Supervisor]}]}, _acc -> {true, true}
      {:use, _, [Supervisor]}, _acc -> {true, true}
      node, acc -> {node, acc}
    end) |> elem(1)
  end

  defp extract_supervisor_children(ast) do
    # Look for children list in init function
    Macro.prewalk(ast, [], fn
      {:def, _, [{:init, _, _}, body]}, acc ->
        children = extract_children_from_init(body)
        {children, children ++ acc}
      node, acc -> {node, acc}
    end) |> elem(1) |> List.flatten() |> Enum.uniq()
  end

  defp extract_supervisor_strategy(ast) do
    Macro.prewalk(ast, :one_for_one, fn
      {{:., _, [{:__aliases__, _, [:Supervisor]}, :init]}, _, [_children, [strategy: strategy]]}, _acc ->
        {strategy, strategy}
      node, acc -> {node, acc}
    end) |> elem(1)
  end

  # Phoenix pattern recognition

  defp has_phoenix_controller_use?(ast) do
    ast_contains_use_with_atom?(ast, :controller) or
    ast_contains_controller_pattern?(ast)
  end

  defp ast_contains_controller_pattern?(ast) do
    Macro.prewalk(ast, false, fn
      {:use, _, [{{:., _, [_module, :controller]}, _, _args}]}, _acc ->
        {true, true}
      node, acc -> {node, acc}
    end) |> elem(1)
  end

  defp has_phoenix_liveview_use?(ast) do
    ast_contains_use?(ast, Phoenix.LiveView)
  end

  defp has_phoenix_channel_use?(ast) do
    ast_contains_use?(ast, Phoenix.Channel)
  end

  defp extract_phoenix_actions(ast) do
    function_names = extract_function_names(ast)

    # Phoenix actions are typically public functions that take (conn, params)
    Enum.filter(function_names, fn name ->
      function_has_conn_params_signature?(ast, name)
    end)
  end

  defp extract_liveview_events(ast) do
    # Extract event names from handle_event functions
    Macro.prewalk(ast, [], fn
      {:def, _, [{:handle_event, _, [event_name | _]}, _]}, acc when is_binary(event_name) ->
        {event_name, [event_name | acc]}
      {:def, _, [{:handle_event, _, [{event_name, _, _} | _]}, _]}, acc when is_atom(event_name) ->
        {event_name, [Atom.to_string(event_name) | acc]}
      node, acc -> {node, acc}
    end) |> elem(1) |> Enum.uniq()
  end

  # Database interaction patterns

  defp has_database_interactions?(ast) do
    has_repo_calls?(ast) or has_ecto_queries?(ast)
  end

  defp has_repo_calls?(ast) do
    ast_contains_repo_pattern?(ast)
  end

  defp ast_contains_repo_pattern?(ast) do
    Macro.prewalk(ast, false, fn
      {{:., _, [{:__aliases__, _, [:Repo]}, _method]}, _, _args}, _acc ->
        {true, true}
      node, acc -> {node, acc}
    end) |> elem(1)
  end

  defp has_ecto_queries?(ast) do
    ast_contains_import?(ast, Ecto.Query)
  end

  defp has_ecto_schema_use?(ast) do
    ast_contains_use?(ast, Ecto.Schema)
  end

  # Message pattern extraction

  defp extract_message_patterns(ast) do
    Macro.prewalk(ast, [], fn
      # GenServer.call/cast patterns
      {{:., _, [{:__aliases__, _, [:GenServer]}, call_type]}, _, [_target, message]}, acc
        when call_type in [:call, :cast] ->
        pattern = extract_message_structure(message)
        {message, [{call_type, pattern} | acc]}

      # send patterns
      {{:., _, [{:__aliases__, _, [:Process]}, :send]}, _, [_pid, message]}, acc ->
        pattern = extract_message_structure(message)
        {message, [{:send, pattern} | acc]}

      node, acc -> {node, acc}
    end) |> elem(1)
  end

  defp extract_pubsub_patterns(ast) do
    Macro.prewalk(ast, [], fn
      # Phoenix.PubSub.broadcast
      {{:., _, [{:__aliases__, _, [:Phoenix, :PubSub]}, :broadcast]}, _, [_pubsub, topic, message]}, acc ->
        topic_pattern = extract_topic_structure(topic)
        message_pattern = extract_message_structure(message)
        pattern = %{type: :broadcast, topic: topic_pattern, message: message_pattern}
        {pattern, [pattern | acc]}

      # Phoenix.PubSub.subscribe
      {{:., _, [{:__aliases__, _, [:Phoenix, :PubSub]}, :subscribe]}, _, [_pubsub, topic]}, acc ->
        topic_pattern = extract_topic_structure(topic)
        pattern = %{type: :subscribe, topic: topic_pattern}
        {pattern, [pattern | acc]}

      node, acc -> {node, acc}
    end) |> elem(1)
  end

  # Utility functions

  defp ast_contains_use?(ast, module) do
    Macro.prewalk(ast, false, fn
      {:use, _, [{:__aliases__, _, module_parts}]}, _acc ->
        if Module.concat(module_parts) == module do
          {true, true}
        else
          {false, false}
        end
      {:use, _, [^module]}, _acc when is_atom(module) ->
        {true, true}
      {:use, _, [module_atom]}, _acc when is_atom(module_atom) ->
        if module_atom == module do
          {true, true}
        else
          {false, false}
        end
      node, acc -> {node, acc}
    end) |> elem(1)
  end

  defp ast_contains_use_with_atom?(ast, atom) do
    Macro.prewalk(ast, false, fn
      {:use, _, [_, ^atom]}, _acc ->
        {true, true}
      node, acc -> {node, acc}
    end) |> elem(1)
  end

  defp ast_contains_pattern?(ast, pattern) do
    Macro.prewalk(ast, false, fn
      ^pattern, _acc -> {true, true}
      node, acc -> {node, acc}
    end) |> elem(1)
  end

  defp ast_contains_import?(ast, module) do
    Macro.prewalk(ast, false, fn
      {:import, _, [^module]}, _acc -> {true, true}
      {:import, _, [{:__aliases__, _, module_parts}]}, _acc ->
        if Module.concat(module_parts) == module do
          {true, true}
        else
          {false, false}
        end
      node, acc -> {node, acc}
    end) |> elem(1)
  end

  defp extract_function_names(ast) do
    Macro.prewalk(ast, [], fn
      {:def, _, [{name, _, _}, _]}, acc when is_atom(name) -> {name, [name | acc]}
      {:defp, _, [{name, _, _}, _]}, acc when is_atom(name) -> {name, [name | acc]}
      node, acc -> {node, acc}
    end) |> elem(1) |> Enum.uniq()
  end

  defp function_has_conn_params_signature?(ast, function_name) do
    Macro.prewalk(ast, false, fn
      {:def, _, [{^function_name, _, [_conn, _params]}, _]}, _acc -> {true, true}
      node, acc -> {node, acc}
    end) |> elem(1)
  end

  defp extract_children_from_init(body) do
    Macro.prewalk(body, [], fn
      {:=, _, [{:children, _, _}, children_list]}, acc ->
        children = extract_child_specs(children_list)
        {children_list, children ++ acc}
      node, acc -> {node, acc}
    end) |> elem(1)
  end

  defp extract_child_specs({:__block__, _, specs}) when is_list(specs) do
    Enum.map(specs, &extract_single_child_spec/1)
  end
  defp extract_child_specs(specs) when is_list(specs) do
    Enum.map(specs, &extract_single_child_spec/1)
  end
  defp extract_child_specs([_ | _] = specs) do
    Enum.map(specs, &extract_single_child_spec/1)
  end
  defp extract_child_specs(_), do: []

  defp extract_single_child_spec({:__aliases__, _, module_parts}) do
    Module.concat(module_parts)
  end
  defp extract_single_child_spec({:{}, _, [module_ref | _]}) do
    extract_single_child_spec(module_ref)
  end
  defp extract_single_child_spec({{:., _, [{:__aliases__, _, module_parts}, _function]}, _, _args}) do
    Module.concat(module_parts)
  end
  defp extract_single_child_spec({module_ref, _options}) when is_tuple(module_ref) do
    extract_single_child_spec(module_ref)
  end
  defp extract_single_child_spec({module_ref, _options}) do
    extract_single_child_spec(module_ref)
  end
  defp extract_single_child_spec(_), do: :unknown

  defp extract_message_structure({:{}, _, [atom | _]}) when is_atom(atom) do
    atom
  end
  defp extract_message_structure(atom) when is_atom(atom) do
    atom
  end
  defp extract_message_structure(%{} = _map) do
    :map_message
  end
  defp extract_message_structure(_) do
    :unknown
  end

  defp extract_topic_structure({:<<>>, _, parts}) do
    # Handle string interpolation like "user:#{user_id}"
    case parts do
      [topic] when is_binary(topic) -> 
        topic
      [prefix, {:"::", _, [{{:., _, [Kernel, :to_string]}, _, [_expr]}, {:binary, _, _}]}] when is_binary(prefix) ->
        # Handle interpolation like "user:#{user_id}" -> "user:*"
        prefix <> "*"
      [prefix | _rest] when is_binary(prefix) ->
        # Handle any other interpolation patterns
        prefix <> "*"
      _ -> 
        :unknown
    end
  end
  defp extract_topic_structure(topic) when is_binary(topic) do
    topic
  end
  defp extract_topic_structure(_) do
    :unknown
  end
end
