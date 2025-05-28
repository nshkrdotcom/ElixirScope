defmodule ElixirScope.ASTRepository.NodeIdentifier do
  @moduledoc """
  Manages the generation, parsing, and validation of unique and stable AST Node IDs.

  These IDs are crucial for correlating static analysis information (AST, CFG, DFG, CPG)
  with runtime events and for uniquely identifying AST elements across ElixirScope.

  The ID schema aims for stability across non-structural code changes and
  uniqueness within the scope of a project or analysis session.

  Schema (Conceptual): `module_qualifier:function_qualifier:ast_path_or_hash`
  - `module_qualifier`: e.g., "MyApp.MyModule" (escaped)
  - `function_qualifier`: e.g., "my_function_2_clause_0" (name, arity, clause index for multi-clause heads)
  - `ast_path_or_hash`:
    - Path: A sequence of indices representing traversal from the function root AST (e.g., "0_1_2" for `body.stmts[0].args[1].value[2]`). Prone to instability with minor refactors.
    - Hash: A content-aware hash of the node and its context (more stable but can have collisions or be complex to compute reliably for partial stability).
    - Line/Column + Type: "L10_C5_IfExpr" (can be unstable if lines shift).

  This module will initially focus on a path-based approach within a function's AST,
  prefixed by module and function identifiers. Stability across major refactors is a known challenge.
  """

  require Logger

  @typedoc "A unique string identifier for an AST node."
  @type ast_node_id :: String.t()

  @typedoc "Context for generating IDs, includes parent path and counters."
  @type id_gen_context :: %{
    module_name: atom() | nil,
    function_name: atom() | nil,
    arity: non_neg_integer() | nil,
    clause_index: non_neg_integer() | nil, # For multi-clause functions
    current_path: [non_neg_integer()], # e.g., [body_idx, stmt_idx, arg_idx]
    # Sibling counter can help differentiate nodes at the same path level if path alone isn't enough
    # sibling_counters: %{path_tuple => integer}
  }

  @doc """
  Assigns unique AST node IDs to all traversable nodes in a given AST.
  The IDs are injected into the metadata of each AST node under the `:ast_node_id` key.

  `ast` is the quoted expression (e.g., a full module AST or a function AST).
  `initial_context` should provide module/function scope information.
  """
  @spec assign_ids_to_ast(ast :: Macro.t(), initial_context :: id_gen_context()) :: Macro.t()
  def assign_ids_to_ast(ast, initial_context) do
    # We use Macro.traverse/4 to walk the AST and modify nodes.
    # The accumulator will carry the `id_gen_context`.
    # The pre-function (first callback) is where we generate and assign the ID.
    # The post-function (second callback) is where we pop from the path when leaving a node with children.

    {transformed_ast, _final_context} =
      Macro.traverse(
        ast,
        initial_context,
        # Pre-traversal function (assign ID before visiting children)
        fn
          # For quoted expressions (tuples representing AST nodes)
          {op, meta, children} = current_ast_node, context when is_list(meta) and is_list(children) ->
            # Only assign ID if it's not a literal list/tuple as a child argument directly
            # Check if 'op' is an atom (common for AST operations like :def, :+, :case)
            # or if it's a variable/alias __aliases__ node.
            is_structural_node = is_atom(op) || (is_tuple(op) && elem(op,0) == :__aliases__)

            if is_structural_node do
              node_id = generate_id_for_current_node(current_ast_node, context)
              updated_meta = Keyword.put(meta, :ast_node_id, node_id)
              new_node = {op, updated_meta, children}

              # Prepare context for children: extend path
              # Each child will get an index based on its position in `children`
              # This context is passed to recursive calls of Macro.traverse for children.
              # We don't manage child_context path extension here directly, Macro.traverse does it by iterating.
              # We need to ensure our `generate_id_for_current_node` uses the path correctly.
              # The challenge is that Macro.traverse doesn't give us the child index directly in the pre-fn.
              # So, `current_path` in context should be for the PARENT of `current_ast_node`.
              # This means `initial_context` path should be for the parent of the root `ast`.

              # Let's redefine context.current_path to be the path *to the current node*.
              # This requires careful management in a custom traversal or more complex Macro.traverse usage.

              # Simpler approach for Macro.traverse:
              # The context's path will be built up by `generate_id_for_current_node` itself,
              # assuming it can know its "index" relative to siblings if needed.
              # However, standard Macro.traverse doesn't easily provide sibling index.

              # Alternative: Post-order traversal for path-based IDs, or a custom walker.
              # For now, let's assume `generate_id_for_current_node` can produce something unique
              # based on the node type and limited context, and we'll refine pathing.
              # The current_path in context will be more of a conceptual scope path.
              {new_node, context} # Context might be updated if we track sibling counts
            else
              # Not a structural node we want to ID separately (e.g., list of args itself)
              {current_ast_node, context}
            end

          # For atoms, numbers, strings etc. (usually leaves or simple arguments)
          leaf_node, context ->
            # We generally don't assign IDs to simple literals unless they are significant.
            # If leaf_node is a variable atom used as an arg, its parent (the call) gets the ID.
            {leaf_node, context}
        end,
        # Post-traversal function (after visiting children)
        fn
          # Pop from path if we were managing it strictly per node with children.
          # For now, no change to context here.
          node, context -> {node, context}
        end
      )
    transformed_ast
  end

  @doc """
  Generates a unique and descriptive AST Node ID.
  This is a simplified version. A robust one would handle more context.
  """
  @spec generate_id_for_current_node(node :: Macro.t(), context :: id_gen_context()) :: ast_node_id()
  def generate_id_for_current_node(node, context) do
    # Basic components of the ID
    mod_name = context.module_name || "unknown_mod"
    fun_name = context.function_name || "nofunc"
    arity = context.arity || "X"
    clause_idx = context.clause_index || 0

    # Path component: for simplicity, we'll use a hash of the node structure itself + line
    # This is not strictly path-based but provides some uniqueness within a function.
    # A true path (e.g., "body.0.args.1") is more stable for some changes but brittle for others.
    line = Keyword.get(extract_meta(node), :line, "L?")
    node_type_or_op = case node do
      {op, _, _} when is_atom(op) -> Atom.to_string(op)
      {var, _, ctx} when is_atom(var) and not is_nil(ctx) -> "var_#{var}" # Variable node
      _ -> Macro.type(node) |> Atom.to_string()
    end

    # Hash a string representation of the node, but this can be too volatile.
    # A combination of type, line, and a limited structural hash is better.
    # For now, a simple combination:
    path_like_element = "#{node_type_or_op}_#{line}"

    # Add a hash of the specific node to ensure uniqueness if multiple same-type nodes on same line
    # This hash should ideally be based on a canonical representation of the node.
    # Using :erlang.phash2 on a limited part of the node can work.
    node_specific_hash = :erlang.term_to_binary(node, [compressed: 0, minor_version: 2])
                         |> :crypto.hash(:md5) # MD5 for short hash, consider SHA1 for more uniqueness
                         |> Base.encode16(case: :lower)
                         |> String.slice(0, 8) # Short hash

    id_string = "#{mod_name}:#{fun_name}_#{arity}_c#{clause_idx}:#{path_like_element}:#{node_specific_hash}"
    # Sanitize the ID string (e.g., replace special chars if any problem for storage/query)
    # String.replace(id_string, ~r/[^A-Za-z0-9\-_:]/, "_")
    id_string
  end

  @doc """
  Extracts an AST Node ID from a node's metadata.
  """
  @spec get_id_from_ast_meta(meta :: keyword() | nil) :: ast_node_id() | nil
  def get_id_from_ast_meta(meta) when is_list(meta) do
    Keyword.get(meta, :ast_node_id)
  end
  def get_id_from_ast_meta(_), do: nil

  @doc """
  Parses an AST Node ID string into its constituent parts.
  Returns a map with keys like :module, :function, :arity, :path_hash etc.
  This depends heavily on the `generate_id_for_current_node` format.
  """
  @spec parse_id(ast_node_id :: ast_node_id()) :: {:ok, map()} | {:error, :invalid_format}
  def parse_id(id) when is_binary(id) do
    parts = String.split(id, ":", parts: 4) # Expecting 4 main parts now
    case parts do
      [mod_str, func_arity_clause_str, path_like_str, hash_str] ->
        {func_name_str, arity_str, clause_str} = parse_func_arity_clause(func_arity_clause_str)
        {:ok, %{
          module: String.to_atom(mod_str), # Assuming module name doesn't need special unescaping
          function: String.to_atom(func_name_str),
          arity: String.to_integer(arity_str),
          clause_index: String.to_integer(String.trim_leading(clause_str, "c")),
          path_info: path_like_str,
          node_hash: hash_str,
          original_id: id
        }}
      _ ->
        Logger.warn("Could not parse AST Node ID: #{id}. Expected format 'Module:Function_Arity_Clause:PathLike:Hash'. Got #{inspect(parts)}")
        {:error, :invalid_format}
    end
  end
  def parse_id(_), do: {:error, :invalid_input_type}

  defp parse_func_arity_clause(str) do
    # "my_function_2_clause_0"
    case Regex.run(~r/(.+)_(\d+)_c(\d+)/, str, capture: :all_but_first) do
      [func_name, arity, clause] -> {func_name, arity, clause}
      _ -> {"unknownfunc", "X", "0"} # Fallback
    end
  end

  # --- Internal Helpers ---
  defp extract_meta({_op, meta, _args}) when is_list(meta), do: meta
  defp extract_meta({_var, meta, _context}) when is_list(meta), do: meta
  defp extract_meta(_), do: []


  # --- Example: Initial context for a module ---
  @doc false
  def initial_context_for_module(module_name) do
    %{
      module_name: module_name,
      function_name: nil, # Not inside a function yet
      arity: nil,
      clause_index: nil,
      current_path: [] # Path from module root
    }
  end

  # --- Example: Initial context for a function within a module ---
  @doc false
  def initial_context_for_function(module_name, function_name, arity, clause_index \\ 0) do
    %{
      module_name: module_name,
      function_name: function_name,
      arity: arity,
      clause_index: clause_index,
      current_path: [] # Path from function AST root
    }
  end

  @doc """
  A utility to recursively traverse an AST and attach node IDs using the specified context.
  This is an alternative to Macro.traverse if more control over context passing is needed,
  especially for path generation.
  """
  def assign_ids_custom_traverse(ast_node, context) do
    # 1. Generate ID for current_node using context
    current_node_id = generate_id_for_current_node(ast_node, context)

    # 2. Create updated_node with ID in metadata
    updated_node = case ast_node do
      {op, meta, children} when is_list(meta) ->
        {op, Keyword.put(meta, :ast_node_id, current_node_id), children}
      leaf_or_simple_arg -> leaf_or_simple_arg # No meta to update for simple leaves typically
    end

    # 3. Recursively process children
    case updated_node do
      {op, meta, children} when is_list(children) ->
        new_children = Enum.with_index(children)
        |> Enum.map(fn {child_ast, child_index} ->
          if Macro.quoted?(child_ast) do
            # Update context for child: append child_index to current_path
            child_context = %{context | current_path: context.current_path ++ [child_index]}
            assign_ids_custom_traverse(child_ast, child_context)
          else
            child_ast # Literal, not a node to assign ID to
          end
        end)
        {op, meta, new_children}

      # Handle {:__block__, meta, stmts} similarly
      {:__block__, meta, stmts} ->
         new_stmts = Enum.with_index(stmts)
        |> Enum.map(fn {stmt_ast, stmt_index} ->
          child_context = %{context | current_path: context.current_path ++ [stmt_index]}
          assign_ids_custom_traverse(stmt_ast, child_context)
        end)
        {:__block__, meta, new_stmts}

      # For other node types like fn clauses {:->, meta, [pattern, body]}
      {:->, meta, [pattern, body]} ->
        pattern_context = %{context | current_path: context.current_path ++ [0]}
        body_context = %{context | current_path: context.current_path ++ [1]}
        new_pattern = if Macro.quoted?(pattern), do: assign_ids_custom_traverse(pattern, pattern_context), else: pattern
        new_body = if Macro.quoted?(body), do: assign_ids_custom_traverse(body, body_context), else: body
        {:->, meta, [new_pattern, new_body]}

      final_node -> # Leaf or node without standard children list
        final_node
    end
  end
  # Note: The `assign_ids_custom_traverse` with path-based IDs in context is more robust
  # for generating strictly hierarchical path IDs. The `Macro.traverse` approach is simpler
  # to write but getting precise child indices into the `pre` function is harder.
  # The `generate_id_for_current_node` using `current_path` from context would be:
  # path_str = Enum.join(context.current_path, "_")
  # id_string = "#{mod_name}:#{fun_name}_#{arity}_c#{clause_idx}:path_#{path_str}:#{node_type_or_op}"
  # This makes IDs more stable against content changes if path is same.
end
