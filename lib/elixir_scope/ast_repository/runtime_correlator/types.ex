defmodule ElixirScope.ASTRepository.RuntimeCorrelator.Types do
  @moduledoc """
  Type definitions for the RuntimeCorrelator system.

  Contains all the type specifications used across the RuntimeCorrelator
  modules to ensure consistency and proper documentation.
  """

  @type ast_context :: %{
    module: atom(),
    function: atom(),
    arity: non_neg_integer(),
    ast_node_id: String.t(),
    line_number: pos_integer(),
    ast_metadata: map(),
    cfg_node: map() | nil,
    dfg_context: map() | nil,
    variable_scope: map(),
    call_context: list(map())
  }

  @type enhanced_event :: %{
    original_event: map(),
    ast_context: ast_context() | nil,
    correlation_metadata: map(),
    structural_info: map(),
    data_flow_info: map()
  }

  @type execution_trace :: %{
    events: list(enhanced_event()),
    ast_flow: list(map()),
    variable_flow: map(),
    structural_patterns: list(map()),
    performance_correlation: map(),
    trace_metadata: map()
  }

  @type structural_breakpoint :: %{
    id: String.t(),
    pattern: Macro.t(),
    condition: atom(),
    ast_path: list(String.t()),
    enabled: boolean(),
    hit_count: non_neg_integer(),
    metadata: map()
  }

  @type data_flow_breakpoint :: %{
    id: String.t(),
    variable: String.t(),
    ast_path: list(String.t()),
    flow_conditions: list(atom()),
    enabled: boolean(),
    hit_count: non_neg_integer(),
    metadata: map()
  }

  @type semantic_watchpoint :: %{
    id: String.t(),
    variable: String.t(),
    track_through: list(atom()),
    ast_scope: String.t(),
    enabled: boolean(),
    value_history: list(map()),
    metadata: map()
  }

  @type correlation_stats :: %{
    events_correlated: non_neg_integer(),
    context_lookups: non_neg_integer(),
    cache_hits: non_neg_integer(),
    cache_misses: non_neg_integer()
  }

  @type cache_stats :: %{
    context_cache_size: non_neg_integer(),
    trace_cache_size: non_neg_integer(),
    evictions: non_neg_integer()
  }
end
