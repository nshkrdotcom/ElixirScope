defmodule ElixirScope.Capture.TemporalBridgeEnhancement.Types do
  @moduledoc """
  Type definitions for TemporalBridgeEnhancement.

  Contains all the type specifications used throughout the
  TemporalBridgeEnhancement system.
  """

  @type ast_enhanced_state :: %{
    original_state: map(),
    ast_context: map(),
    structural_info: map(),
    execution_path: list(map()),
    variable_flow: map(),
    timestamp: non_neg_integer()
  }

  @type ast_execution_trace :: %{
    events: list(map()),
    ast_flow: list(map()),
    state_transitions: list(ast_enhanced_state()),
    structural_patterns: list(map()),
    execution_metadata: map()
  }

  @type enhancement_stats :: %{
    states_reconstructed: non_neg_integer(),
    ast_contexts_added: non_neg_integer(),
    cache_hits: non_neg_integer(),
    cache_misses: non_neg_integer(),
    avg_reconstruction_time: float()
  }

  @type cache_stats :: %{
    state_cache_size: non_neg_integer(),
    trace_cache_size: non_neg_integer(),
    evictions: non_neg_integer()
  }

  @type execution_flow :: %{
    from_ast_node_id: String.t(),
    to_ast_node_id: String.t(),
    flow_events: list(map()),
    flow_states: list(ast_enhanced_state()),
    execution_paths: list(map()),
    time_range: tuple() | nil
  }

  @type server_state :: %{
    temporal_bridge: pid() | nil,
    ast_repo: pid() | nil,
    correlator: module(),
    event_store: pid() | nil,
    enhancement_stats: enhancement_stats(),
    cache_stats: cache_stats(),
    enabled: boolean()
  }
end
