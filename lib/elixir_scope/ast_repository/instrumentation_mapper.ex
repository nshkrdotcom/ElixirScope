defmodule ElixirScope.ASTRepository.InstrumentationMapper do
  @moduledoc """
  Maps AST nodes to instrumentation strategies and points.
  
  Provides systematic instrumentation point mapping for compile-time transformation.
  This module analyzes AST structures and determines the optimal instrumentation
  strategy for each node type, enabling intelligent compile-time instrumentation.
  
  Key responsibilities:
  - Map AST nodes to appropriate instrumentation strategies
  - Generate instrumentation point configurations
  - Support different instrumentation levels (function, expression, line)
  - Integrate with the Enhanced Parser for systematic instrumentation
  """
  

  
  @type ast_node :: term()
  @type ast_node_id :: binary()
  @type instrumentation_strategy :: :function_boundary | :expression_trace | :line_execution | :variable_capture | :none
  @type instrumentation_level :: :minimal | :balanced | :comprehensive | :debug
  @type context :: %{
    module_name: atom(),
    function_name: atom() | nil,
    arity: non_neg_integer() | nil,
    instrumentation_level: instrumentation_level(),
    parent_context: context() | nil
  }
  
  @type instrumentation_point :: %{
    ast_node_id: ast_node_id(),
    strategy: instrumentation_strategy(),
    priority: non_neg_integer(),
    metadata: map(),
    configuration: map()
  }
  
  @doc """
  Maps AST nodes to instrumentation points with appropriate strategies.
  
  Analyzes the AST structure and generates a comprehensive list of instrumentation
  points, each with an appropriate strategy based on the node type and context.
  
  ## Options
  - `:instrumentation_level` - :minimal, :balanced, :comprehensive, or :debug
  - `:include_expressions` - Whether to instrument individual expressions
  - `:include_variables` - Whether to capture variable snapshots
  - `:performance_focus` - Optimize for performance vs. completeness
  """
  @spec map_instrumentation_points(ast_node(), keyword()) :: {:ok, [instrumentation_point()]} | {:error, term()}
  def map_instrumentation_points(ast, opts \\ []) do
    instrumentation_level = Keyword.get(opts, :instrumentation_level, :balanced)
    include_expressions = Keyword.get(opts, :include_expressions, instrumentation_level in [:comprehensive, :debug])
    include_variables = Keyword.get(opts, :include_variables, instrumentation_level == :debug)
    
    try do
      context = build_initial_context(ast, instrumentation_level)
      instrumentation_points = traverse_ast_for_instrumentation(ast, context, %{
        include_expressions: include_expressions,
        include_variables: include_variables,
        instrumentation_level: instrumentation_level
      })
      
      # Sort by priority (higher priority first)
      sorted_points = Enum.sort_by(instrumentation_points, & &1.priority, :desc)
      
      {:ok, sorted_points}
    rescue
      error -> {:error, {:instrumentation_mapping_failed, error}}
    end
  end
  
  @doc """
  Selects the appropriate instrumentation strategy for a specific AST node.
  
  Determines the best instrumentation approach based on the node type,
  context, and configuration preferences.
  """
  @spec select_instrumentation_strategy(ast_node(), context()) :: instrumentation_strategy()
  def select_instrumentation_strategy(ast_node, context) do
    case ast_node do
      # Function definitions - always instrument boundaries
      {:def, _meta, _args} -> :function_boundary
      {:defp, _meta, _args} -> :function_boundary
      {:defmacro, _meta, _args} -> :function_boundary
      
      # Variable assignments - only for debug level (must come before function calls)
      {:=, _meta, _args} when context.instrumentation_level == :debug -> :variable_capture
      
      # Control flow - instrument for debugging
      {:if, _meta, _args} when context.instrumentation_level in [:comprehensive, :debug] -> :expression_trace
      {:case, _meta, _args} when context.instrumentation_level in [:comprehensive, :debug] -> :expression_trace
      {:cond, _meta, _args} when context.instrumentation_level in [:comprehensive, :debug] -> :expression_trace
      
      # Pipe operations - instrument for comprehensive+
      {:|>, _meta, _args} when context.instrumentation_level in [:comprehensive, :debug] -> :expression_trace
      
      # Function calls - instrument based on level (must come last among atom-based patterns)
      {function_name, _meta, args} when is_atom(function_name) and is_list(args) ->
        case context.instrumentation_level do
          :minimal -> :none
          :balanced -> if important_function?(function_name), do: :expression_trace, else: :none
          :comprehensive -> :expression_trace
          :debug -> :expression_trace
        end
      
      # Everything else
      _ -> :none
    end
  end
  
  @doc """
  Configures instrumentation for a specific point.
  
  Generates the configuration map that will be used by the AST transformer
  to inject the appropriate instrumentation code.
  """
  @spec configure_instrumentation(instrumentation_point(), keyword()) :: map()
  def configure_instrumentation(instrumentation_point, opts \\ []) do
    base_config = %{
      ast_node_id: instrumentation_point.ast_node_id,
      strategy: instrumentation_point.strategy,
      enabled: true,
      correlation_id_required: true
    }
    
    strategy_config = case instrumentation_point.strategy do
      :function_boundary ->
        %{
          capture_entry: true,
          capture_exit: true,
          capture_args: Keyword.get(opts, :capture_args, true),
          capture_return: Keyword.get(opts, :capture_return, true),
          performance_tracking: Keyword.get(opts, :performance_tracking, true)
        }
      
      :expression_trace ->
        %{
          capture_value: true,
          capture_context: Keyword.get(opts, :capture_context, false),
          trace_evaluation: true
        }
      
      :line_execution ->
        %{
          capture_line: true,
          capture_context: Keyword.get(opts, :capture_context, false)
        }
      
      :variable_capture ->
        %{
          capture_variables: true,
          variable_filter: Keyword.get(opts, :variable_filter, :all),
          capture_bindings: true
        }
      
      :none ->
        %{enabled: false}
    end
    
    Map.merge(base_config, strategy_config)
  end
  
  @doc """
  Estimates the performance impact of an instrumentation configuration.
  
  Returns a performance impact score from 0.0 (no impact) to 1.0 (high impact).
  """
  @spec estimate_performance_impact([instrumentation_point()]) :: float()
  def estimate_performance_impact(instrumentation_points) do
    total_impact = Enum.reduce(instrumentation_points, 0.0, fn point, acc ->
      impact = case point.strategy do
        :function_boundary -> 0.1  # Low impact
        :expression_trace -> 0.3   # Medium impact
        :line_execution -> 0.2     # Low-medium impact
        :variable_capture -> 0.5   # High impact
        :none -> 0.0              # No impact
      end
      acc + impact
    end)
    
    # Normalize to 0.0-1.0 range (assuming max 10 high-impact points)
    min(total_impact / 5.0, 1.0)
  end
  
  @doc """
  Optimizes instrumentation points for performance.
  
  Reduces the number of instrumentation points while maintaining
  essential debugging capabilities.
  """
  @spec optimize_for_performance([instrumentation_point()], keyword()) :: [instrumentation_point()]
  def optimize_for_performance(instrumentation_points, opts \\ []) do
    max_impact = Keyword.get(opts, :max_impact, 0.3)
    preserve_functions = Keyword.get(opts, :preserve_functions, true)
    
    # Always preserve function boundaries if requested
    {function_points, other_points} = Enum.split_with(instrumentation_points, fn point ->
      point.strategy == :function_boundary
    end)
    
    preserved_points = if preserve_functions, do: function_points, else: []
    
    # Sort other points by priority and add until we hit the impact limit
    sorted_other = Enum.sort_by(other_points, & &1.priority, :desc)
    
    {optimized_other, _} = Enum.reduce_while(sorted_other, {[], 0.0}, fn point, {acc, current_impact} ->
      point_impact = case point.strategy do
        :expression_trace -> 0.3
        :line_execution -> 0.2
        :variable_capture -> 0.5
        _ -> 0.1
      end
      
      new_impact = current_impact + point_impact
      
      if new_impact <= max_impact do
        {:cont, {[point | acc], new_impact}}
      else
        {:halt, {acc, current_impact}}
      end
    end)
    
    preserved_points ++ Enum.reverse(optimized_other)
  end
  
  #############################################################################
  # Private Implementation Functions
  #############################################################################
  
  defp build_initial_context(ast, instrumentation_level) do
    module_name = extract_module_name(ast)
    
    %{
      module_name: module_name,
      function_name: nil,
      arity: nil,
      instrumentation_level: instrumentation_level,
      parent_context: nil
    }
  end
  
  defp extract_module_name(ast) do
    case ast do
      {:defmodule, _meta, [{:__aliases__, _meta2, name_parts} | _]} ->
        Module.concat(name_parts)
      
      {:defmodule, _meta, [name | _]} when is_atom(name) ->
        name
      
      _ ->
        :"UnknownModule#{:erlang.unique_integer([:positive])}"
    end
  end
  
  defp traverse_ast_for_instrumentation(ast, context, opts, acc \\ [])
  
  defp traverse_ast_for_instrumentation({:defmodule, _meta, [name | body]}, context, opts, acc) do
    module_name = case name do
      {:__aliases__, _meta, name_parts} -> Module.concat(name_parts)
      name when is_atom(name) -> name
      _ -> context.module_name
    end
    
    new_context = %{context | module_name: module_name}
    
    # Handle the body which might be wrapped in a :do block
    actual_body = case body do
      [[do: do_body]] -> do_body
      [do: do_body] -> do_body
      other -> other
    end
    
    traverse_ast_for_instrumentation(actual_body, new_context, opts, acc)
  end
  
  defp traverse_ast_for_instrumentation({:def, meta, [function_head | body]} = ast_node, context, opts, acc) do
    {function_name, arity} = extract_function_info(function_head)
    ast_node_id = generate_ast_node_id(ast_node, context)
    
    # Create instrumentation point for function
    instrumentation_point = %{
      ast_node_id: ast_node_id,
      strategy: :function_boundary,
      priority: 100,  # High priority for functions
      metadata: %{
        node_type: :function_def,
        function_name: function_name,
        arity: arity,
        line: Keyword.get(meta, :line, 0)
      },
      configuration: %{}
    }
    
    new_context = %{context | function_name: function_name, arity: arity}
    new_acc = [instrumentation_point | acc]
    
    # Handle the body which might be wrapped in a :do block
    actual_body = case body do
      [[do: do_body]] -> do_body
      [do: do_body] -> do_body
      other -> other
    end
    
    # Traverse function body
    traverse_ast_for_instrumentation(actual_body, new_context, opts, new_acc)
  end
  
  defp traverse_ast_for_instrumentation({:defp, meta, [function_head | body]} = ast_node, context, opts, acc) do
    # Same as :def but private
    {function_name, arity} = extract_function_info(function_head)
    ast_node_id = generate_ast_node_id(ast_node, context)
    
    instrumentation_point = %{
      ast_node_id: ast_node_id,
      strategy: :function_boundary,
      priority: 90,  # Slightly lower priority for private functions
      metadata: %{
        node_type: :private_function_def,
        function_name: function_name,
        arity: arity,
        line: Keyword.get(meta, :line, 0)
      },
      configuration: %{}
    }
    
    new_context = %{context | function_name: function_name, arity: arity}
    new_acc = [instrumentation_point | acc]
    
    # Handle the body which might be wrapped in a :do block
    actual_body = case body do
      [[do: do_body]] -> do_body
      [do: do_body] -> do_body
      other -> other
    end
    
    traverse_ast_for_instrumentation(actual_body, new_context, opts, new_acc)
  end
  
  defp traverse_ast_for_instrumentation({function_name, meta, args} = ast_node, context, opts, acc) 
       when is_atom(function_name) and is_list(args) do
    
    strategy = select_instrumentation_strategy(ast_node, context)
    
    new_acc = if strategy != :none do
      ast_node_id = generate_ast_node_id(ast_node, context)
      
      instrumentation_point = %{
        ast_node_id: ast_node_id,
        strategy: strategy,
        priority: calculate_priority(strategy, function_name, context),
        metadata: %{
          node_type: :function_call,
          function_name: function_name,
          arity: length(args),
          line: Keyword.get(meta, :line, 0)
        },
        configuration: %{}
      }
      
      [instrumentation_point | acc]
    else
      acc
    end
    
    # Traverse arguments
    traverse_ast_list(args, context, opts, new_acc)
  end
  
  defp traverse_ast_for_instrumentation({:=, meta, [_left, right]} = ast_node, context, opts, acc) do
    strategy = select_instrumentation_strategy(ast_node, context)
    
    new_acc = if strategy != :none do
      ast_node_id = generate_ast_node_id(ast_node, context)
      
      instrumentation_point = %{
        ast_node_id: ast_node_id,
        strategy: strategy,
        priority: 30,  # Medium-low priority for assignments
        metadata: %{
          node_type: :assignment,
          line: Keyword.get(meta, :line, 0)
        },
        configuration: %{}
      }
      
      [instrumentation_point | acc]
    else
      acc
    end
    
    # Traverse right side of assignment
    traverse_ast_for_instrumentation(right, context, opts, new_acc)
  end
  
  defp traverse_ast_for_instrumentation({node_type, _meta, children} = ast_node, context, opts, acc) 
       when node_type in [:if, :case, :cond, :|>] do
    
    strategy = select_instrumentation_strategy(ast_node, context)
    
    new_acc = if strategy != :none do
      ast_node_id = generate_ast_node_id(ast_node, context)
      
      instrumentation_point = %{
        ast_node_id: ast_node_id,
        strategy: strategy,
        priority: 50,  # Medium priority for control flow
        metadata: %{
          node_type: node_type,
          line: 0  # Meta might not have line info for all nodes
        },
        configuration: %{}
      }
      
      [instrumentation_point | acc]
    else
      acc
    end
    
    # Traverse children
    traverse_ast_list(children, context, opts, new_acc)
  end
  
  defp traverse_ast_for_instrumentation(ast_node, context, opts, acc) when is_tuple(ast_node) do
    # Generic tuple traversal
    children = Tuple.to_list(ast_node) |> Enum.drop(2)  # Skip node type and meta
    traverse_ast_list(children, context, opts, acc)
  end
  
  defp traverse_ast_for_instrumentation(ast_node, context, opts, acc) when is_list(ast_node) do
    traverse_ast_list(ast_node, context, opts, acc)
  end
  
  defp traverse_ast_for_instrumentation(_ast_node, _context, _opts, acc) do
    # Leaf nodes (atoms, numbers, strings, etc.)
    acc
  end
  
  defp traverse_ast_list(ast_list, context, opts, acc) when is_list(ast_list) do
    Enum.reduce(ast_list, acc, fn ast_node, acc ->
      traverse_ast_for_instrumentation(ast_node, context, opts, acc)
    end)
  end
  
  defp traverse_ast_list(ast_node, context, opts, acc) do
    traverse_ast_for_instrumentation(ast_node, context, opts, acc)
  end
  
  defp extract_function_info({function_name, _meta, args}) when is_atom(function_name) do
    arity = if is_list(args), do: length(args), else: 0
    {function_name, arity}
  end
  
  defp extract_function_info(function_name) when is_atom(function_name) do
    {function_name, 0}
  end
  
  defp extract_function_info(_), do: {:unknown_function, 0}
  
  defp generate_ast_node_id(ast_node, context) do
    # Create a unique ID based on the AST node content and context
    content = "#{inspect(ast_node)}#{context.module_name}#{context.function_name}"
    hash = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
    "ast_node_#{String.slice(hash, 0, 16)}"
  end
  
  defp calculate_priority(strategy, function_name, context) do
    base_priority = case strategy do
      :function_boundary -> 100
      :expression_trace -> 50
      :line_execution -> 30
      :variable_capture -> 20
      :none -> 0
    end
    
    # Boost priority for important functions
    function_boost = if important_function?(function_name), do: 20, else: 0
    
    # Boost priority based on instrumentation level
    level_boost = case context.instrumentation_level do
      :debug -> 10
      :comprehensive -> 5
      :balanced -> 0
      :minimal -> -10
    end
    
    base_priority + function_boost + level_boost
  end
  
  defp important_function?(function_name) do
    function_name in [
      # OTP callbacks
      :init, :handle_call, :handle_cast, :handle_info, :terminate,
      # Phoenix callbacks
      :index, :show, :create, :update, :delete,
      # Common important functions
      :start_link, :start, :stop, :call, :cast,
      # Error-prone functions
      :send, :receive, :spawn, :spawn_link
    ]
  end
end 