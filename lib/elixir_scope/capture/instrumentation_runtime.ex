defmodule ElixirScope.Capture.InstrumentationRuntime do
  @moduledoc """
  Main runtime API for instrumented code to report events to ElixirScope.

  This module provides the primary interface that AST-transformed code will call.
  It delegates to specialized modules for different concerns while maintaining
  the same public API for backward compatibility.

  Key design principles:
  - Minimal overhead when disabled (single boolean check)
  - No crashes if ElixirScope is not running
  - Efficient correlation ID management
  - Support for nested function calls
  """

  alias ElixirScope.Capture.InstrumentationRuntime.{
    Context,
    CoreReporting,
    ASTReporting,
    PhoenixReporting,
    EctoReporting,
    GenServerReporting,
    DistributedReporting,
    Performance
  }

  @type correlation_id :: term()
  @type instrumentation_context :: Context.t()

  # Delegate core functionality to specialized modules
  defdelegate initialize_context(), to: Context
  defdelegate clear_context(), to: Context
  defdelegate enabled?(), to: Context
  defdelegate current_correlation_id(), to: Context
  defdelegate with_instrumentation_disabled(fun), to: Context
  defdelegate measure_overhead(iterations \\ 10000), to: Performance

  # Core reporting functions
  defdelegate report_function_entry(module, function, args), to: CoreReporting
  defdelegate report_function_entry(function_name, arity, capture_args, correlation_id), to: CoreReporting
  defdelegate report_function_exit(correlation_id, return_value, duration_ns), to: CoreReporting
  defdelegate report_function_exit(function_name, arity, exit_type, return_value, correlation_id), to: CoreReporting
  defdelegate report_process_spawn(child_pid), to: CoreReporting
  defdelegate report_message_send(to_pid, message), to: CoreReporting
  defdelegate report_state_change(old_state, new_state), to: CoreReporting
  defdelegate report_error(error, reason, stacktrace), to: CoreReporting

  # AST reporting functions
  defdelegate report_local_variable_snapshot(correlation_id, variables, line, source \\ :ast), to: ASTReporting
  defdelegate report_ast_variable_snapshot(correlation_id, variables, line, ast_node_id), to: ASTReporting
  defdelegate report_expression_value(correlation_id, expression, value, line, source \\ :ast), to: ASTReporting
  defdelegate report_line_execution(correlation_id, line, context, source \\ :ast), to: ASTReporting
  defdelegate report_ast_function_entry(module, function, args, correlation_id), to: ASTReporting
  defdelegate report_ast_function_entry_with_node_id(module, function, args, correlation_id, ast_node_id), to: ASTReporting
  defdelegate report_ast_function_exit(correlation_id, return_value, duration_ns), to: ASTReporting
  defdelegate report_ast_function_exit_with_node_id(correlation_id, return_value, duration_ns, ast_node_id), to: ASTReporting
  defdelegate report_ast_expression_value(correlation_id, expression, value, line, ast_node_id), to: ASTReporting
  defdelegate report_ast_line_execution(correlation_id, line, context, ast_node_id), to: ASTReporting
  defdelegate report_ast_pattern_match(correlation_id, pattern, value, match_success, line, ast_node_id), to: ASTReporting
  defdelegate report_ast_branch_execution(correlation_id, branch_type, condition, branch_taken, line, ast_node_id), to: ASTReporting
  defdelegate report_ast_loop_iteration(correlation_id, loop_type, iteration_count, current_value, line, ast_node_id), to: ASTReporting
  defdelegate get_ast_correlation_metadata(), to: ASTReporting
  defdelegate validate_ast_node_id(ast_node_id), to: ASTReporting
  defdelegate report_ast_correlation_performance(correlation_id, operation, duration_ns), to: ASTReporting

  # Phoenix integration functions
  defdelegate report_phoenix_request_start(correlation_id, method, path, params, remote_ip), to: PhoenixReporting
  defdelegate report_phoenix_request_complete(correlation_id, status_code, content_type, duration_ms), to: PhoenixReporting
  defdelegate report_phoenix_controller_entry(correlation_id, controller, action, metadata), to: PhoenixReporting
  defdelegate report_phoenix_controller_exit(correlation_id, controller, action, result), to: PhoenixReporting
  defdelegate report_liveview_mount_start(correlation_id, module, params, session), to: PhoenixReporting
  defdelegate report_liveview_mount_complete(correlation_id, module, socket_assigns), to: PhoenixReporting
  defdelegate report_liveview_handle_event_start(correlation_id, event, params, socket_assigns), to: PhoenixReporting
  defdelegate report_liveview_handle_event_complete(correlation_id, event, params, before_assigns, result), to: PhoenixReporting
  defdelegate report_phoenix_channel_join_start(correlation_id, topic, payload, socket), to: PhoenixReporting
  defdelegate report_phoenix_channel_join_complete(correlation_id, topic, payload, result), to: PhoenixReporting
  defdelegate report_phoenix_channel_message_start(correlation_id, event, payload, socket), to: PhoenixReporting
  defdelegate report_phoenix_channel_message_complete(correlation_id, event, payload, result), to: PhoenixReporting
  defdelegate report_phoenix_action_params(action_name, conn, params, should_capture), to: PhoenixReporting
  defdelegate report_phoenix_action_start(action_name, conn, should_capture_state), to: PhoenixReporting
  defdelegate report_phoenix_action_success(action_name, conn, result), to: PhoenixReporting
  defdelegate report_phoenix_action_error(action_name, conn, kind, reason), to: PhoenixReporting
  defdelegate report_phoenix_action_complete(action_name, conn, should_capture_response), to: PhoenixReporting
  defdelegate report_liveview_assigns(callback_name, socket, should_capture), to: PhoenixReporting
  defdelegate report_liveview_event(event, params, socket, should_capture), to: PhoenixReporting
  defdelegate report_liveview_callback(callback_name, socket), to: PhoenixReporting
  defdelegate report_liveview_callback_success(callback_name, socket, result), to: PhoenixReporting
  defdelegate report_liveview_callback_error(callback_name, socket, kind, reason), to: PhoenixReporting

  # Ecto integration functions
  defdelegate report_ecto_query_start(correlation_id, query, params, metadata, repo), to: EctoReporting
  defdelegate report_ecto_query_complete(correlation_id, query, params, result, duration_us), to: EctoReporting

  # GenServer integration functions
  defdelegate report_genserver_callback_start(callback_name, pid, capture_state), to: GenServerReporting
  defdelegate report_genserver_callback_success(callback_name, pid, result), to: GenServerReporting
  defdelegate report_genserver_callback_error(callback_name, pid, kind, reason), to: GenServerReporting
  defdelegate report_genserver_callback_complete(callback_name, pid, capture_state), to: GenServerReporting

  # Distributed/Node functions
  defdelegate report_node_event(event_type, node_name, metadata), to: DistributedReporting
  defdelegate report_partition_detected(partitioned_nodes, metadata), to: DistributedReporting
end
