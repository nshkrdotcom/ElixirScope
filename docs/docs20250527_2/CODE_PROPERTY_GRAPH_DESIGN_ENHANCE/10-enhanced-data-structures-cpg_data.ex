defmodule ElixirScope.ASTRepository.CPGData do
  @moduledoc """
  Defines the data structures for the Code Property Graph (CPG).
  This includes the main CPG container, CPG nodes, and CPG edges,
  unifying AST, CFG, and DFG information.

  Based on schemas from AST_REPOSITORY_DATA_SCHEMAS_AND_SPECIFICATIONS.md.
  """

  alias ElixirScope.ASTRepository.{EnhancedFunctionData, CFGData, DFGData} # For type hints if needed

  @typedoc """
  Unique identifier for a CPG node. Typically a string.
  """
  @type cpg_node_id :: String.t()

  @typedoc """
  Represents a node in the Code Property Graph.
  A CPG node can represent an AST construct, a CFG block, a DFG variable/operation,
  or a synthetic node (e.g., for Phi functions).
  """
  defmodule CPGNode do
    @type t :: %__MODULE__{
      id: cpg_node_id(),
      # Core type of the node in the CPG context
      type: :ast | :cfg | :dfg_def | :dfg_use | :dfg_phi | :call_site | :synthetic | :function_entry | :function_exit,
      # Human-readable label for visualization or debugging
      label: String.t(),
      # Source code information
      line: pos_integer() | nil,
      column: pos_integer() | nil,
      source_text: String.t() | nil, # Snippet of relevant source code

      # Links to original structures (optional, for traceability)
      original_ast_node_id: String.t() | nil, # If derived from an AST node with a persistent ID
      original_cfg_node_id: String.t() | nil, # If derived from a CFG node
      original_dfg_element_id: String.t() | nil, # If derived from a DFG element (e.g., SSA var name)

      # Data specific to the node's role(s)
      ast_data: map() | nil, # e.g., %{kind: :binary_op, operator: :+, original_ast: quoted_expr}
      cfg_data: map() | nil, # e.g., %{type: :condition, expression_ast: quoted_expr}
      dfg_data: map() | nil, # e.g., %{variable_version: VariableVersion.t(), operation: :phi}

      # Properties computed from analysis
      properties: map(), # e.g., %{complexity: 5, is_external_call: true, variable_name: "user_id"}

      # Relationships (often represented by edges, but can store summary here)
      # incoming_edges: %{edge_type :: atom => [cpg_node_id()]}, # Summarized for quick access
      # outgoing_edges: %{edge_type :: atom => [cpg_node_id()]},

      metadata: map() # For any other annotations or tool-specific data
    }
    defstruct [
      :id,
      :type,
      :label,
      :line,
      :column,
      :source_text,
      :original_ast_node_id,
      :original_cfg_node_id,
      :original_dfg_element_id,
      :ast_data,
      :cfg_data,
      :dfg_data,
      :properties,
      # :incoming_edges, # Usually better derived from the main CPG edge list
      # :outgoing_edges,
      :metadata
    ]
  end

  @typedoc """
  Represents an edge in the Code Property Graph.
  Edges define relationships between CPG nodes, such as AST parent-child,
  control flow, data flow, call relationships, etc.
  """
  defmodule CPGEdge do
    @type t :: %__MODULE__{
      from_node_id: cpg_node_id(),
      to_node_id: cpg_node_id(),
      # Type of relationship this edge represents
      type:
        :ast_child | # AST parent to child
        :cfg_flow | # Sequential control flow
        :cfg_conditional_true | # CFG true branch
        :cfg_conditional_false | # CFG false branch
        :cfg_exception_flow | # CFG exception path
        :dfg_reaches | # Data flow from definition to use (def-use chain)
        :dfg_influenced_by | # Data flow influence (more general)
        :dfg_phi_input | # From a variable version into a Phi node
        :dfg_phi_output | # From a Phi node to its resulting variable version
        :call_edge | # From a call site to a function (potentially symbolic target)
        :parameter_link | # From function entry to parameter CPG node
        :return_link | # From return statement to function exit CPG node
        :refers_to, # General reference (e.g., variable use to variable declaration node)
      # Human-readable label for the edge
      label: String.t() | nil,
      # Additional properties of the edge
      properties: map() # e.g., %{condition_ast: quoted_expr, variable_name: "x"}
    }
    defstruct [:from_node_id, :to_node_id, :type, :label, :properties]
  end

  @typedoc """
  The main container for a Code Property Graph of a function or module.
  """
  @type t :: %__MODULE__{
    # Identifier for what this CPG represents (e.g., function MFA)
    function_key: {module :: atom(), function :: atom(), arity :: non_neg_integer()} | atom(), # Or module_name for module-level CPG
    # Collection of all nodes in this CPG
    nodes: %{cpg_node_id() => CPGNode.t()},
    # Collection of all edges in this CPG
    edges: [CPGEdge.t()],
    # Mappings from original AST/CFG/DFG element IDs to CPG node IDs
    # Useful for correlating with other tools or parts of ElixirScope.
    node_mappings: %{
      ast: %{original_ast_id :: String.t() => cpg_node_id()},
      cfg: %{original_cfg_id :: String.t() => cpg_node_id()},
      dfg_defs: %{original_dfg_def_key :: term() => cpg_node_id()}, # e.g., {ssa_name, def_ast_id}
      dfg_uses: %{original_dfg_use_key :: term() => cpg_node_id()}, # e.g., {ssa_name, use_ast_id}
      dfg_phis: %{phi_target_ssa_name :: String.t() => cpg_node_id()}
    },
    # Optimized indexes for common CPG queries
    query_indexes: %{
      by_type: %{node_type :: atom() => [cpg_node_id()]},
      by_label_prefix: %{label_prefix :: String.t() => [cpg_node_id()]},
      by_line_number: %{line :: pos_integer() => [cpg_node_id()]}
      # Potentially more complex indexes, e.g., for specific properties
    },
    # Metadata about the CPG itself
    metadata: %{
      source_file: String.t() | nil,
      generation_timestamp: DateTime.t(),
      generator_version: String.t(),
      analysis_options_used: keyword()
      # Could include summary stats like node_count, edge_count
    }
  }
  defstruct [
    :function_key,
    :nodes,
    :edges,
    :node_mappings,
    :query_indexes,
    :metadata
  ]

  @doc """
  Creates a new, empty CPGData structure.
  """
  def new(function_key, metadata_opts \\ []) do
    %__MODULE__{
      function_key: function_key,
      nodes: %{},
      edges: [],
      node_mappings: %{ast: %{}, cfg: %{}, dfg_defs: %{}, dfg_uses: %{}, dfg_phis: %{}},
      query_indexes: %{by_type: %{}, by_label_prefix: %{}, by_line_number: %{}},
      metadata: Keyword.merge([
        generation_timestamp: DateTime.utc_now(),
        generator_version: Application.spec(:elixir_scope, :vsn) |> to_string()
      ], metadata_opts)
    }
  end

  # --- Helper functions for working with CPGData (examples) ---

  @doc """
  Adds a node to the CPG.
  """
  def add_node(%__MODULE__{} = cpg_data, %CPGNode{} = cpg_node) do
    updated_nodes = Map.put(cpg_data.nodes, cpg_node.id, cpg_node)
    # Basic indexing (can be more sophisticated)
    updated_indexes_type = Map.update(cpg_data.query_indexes.by_type, cpg_node.type, [cpg_node.id], &([cpg_node.id | &1]))
    updated_indexes_line = if cpg_node.line do
      Map.update(cpg_data.query_indexes.by_line_number, cpg_node.line, [cpg_node.id], &([cpg_node.id | &1]))
    else
      cpg_data.query_indexes.by_line_number
    end

    %{cpg_data |
      nodes: updated_nodes,
      query_indexes: %{cpg_data.query_indexes |
        by_type: updated_indexes_type,
        by_line_number: updated_indexes_line
      }
    }
  end

  @doc """
  Adds an edge to the CPG.
  """
  def add_edge(%__MODULE__{} = cpg_data, %CPGEdge{} = cpg_edge) do
    # Optionally validate that from_node_id and to_node_id exist in cpg_data.nodes
    %{cpg_data | edges: [cpg_edge | cpg_data.edges]}
  end

  @doc """
  Adds an AST node mapping.
  """
  def add_ast_mapping(%__MODULE__{} = cpg_data, original_ast_id, cpg_node_id) when is_binary(original_ast_id) and is_binary(cpg_node_id) do
    updated_ast_mappings = Map.put(cpg_data.node_mappings.ast, original_ast_id, cpg_node_id)
    %{cpg_data | node_mappings: %{cpg_data.node_mappings | ast: updated_ast_mappings}}
  end

  # Similar add_*_mapping functions for CFG, DFG can be added.
end
