defmodule ElixirScope.Unified.ModeSelector do
  @moduledoc """
  Intelligent mode selection engine for ElixirScope unified tracing.
  
  Determines the optimal tracing mode (runtime, AST, hybrid, or auto) based on:
  - Target characteristics (module, function complexity)
  - User preferences and options
  - System capabilities and current load
  - Performance requirements
  
  ## Mode Selection Logic
  
  - **Runtime**: Fast, low-overhead, production-ready
  - **AST**: Detailed instrumentation, compile-time injection
  - **Hybrid**: Coordinated runtime + AST for maximum insight
  - **Auto**: Intelligent selection based on context
  """

  alias ElixirScope.{Config, Utils}

  @type trace_target :: {module(), atom(), arity()} | module()
  @type trace_mode :: :runtime | :ast | :hybrid | :auto
  @type selection_options :: map()

  @doc """
  Selects the optimal tracing mode for the given target and options.
  
  ## Examples
  
      # Explicit mode selection
      {:ok, :runtime} = select_mode({MyModule, :func, 2}, %{mode: :runtime})
      
      # Auto mode selection
      {:ok, :runtime} = select_mode({MyModule, :func, 2}, %{mode: :auto})
      
      # With performance constraints
      {:ok, :runtime} = select_mode({MyModule, :func, 2}, %{
        mode: :auto,
        max_overhead: 5.0,
        capture: [:args, :return]
      })
  """
  @spec select_mode(trace_target(), selection_options()) :: 
    {:ok, trace_mode()} | {:error, term()}
  def select_mode(target, options \\ %{}) do
    requested_mode = Map.get(options, :mode, :auto)
    
    case requested_mode do
      :auto -> 
        {:ok, auto_select_mode(target, options)}
      explicit_mode when explicit_mode in [:runtime, :ast, :hybrid] ->
        validate_and_select_mode(explicit_mode, target, options)
      invalid_mode ->
        {:error, {:invalid_mode, invalid_mode}}
    end
  end

  @doc """
  Gets the capabilities and limitations of each tracing mode.
  """
  @spec get_mode_capabilities() :: map()
  def get_mode_capabilities do
    %{
      runtime: %{
        available: true,
        overhead: :low,
        detail_level: :medium,
        production_ready: true,
        capabilities: [:function_calls, :returns, :exceptions, :messages, :state_changes],
        limitations: [:no_local_variables, :no_expression_tracing]
      },
      ast: %{
        available: false,  # Phase 2
        overhead: :medium,
        detail_level: :high,
        production_ready: false,
        capabilities: [:local_variables, :expression_tracing, :line_level, :custom_injection],
        limitations: [:compile_time_only, :module_recompilation_required]
      },
      hybrid: %{
        available: false,  # Phase 2
        overhead: :medium_high,
        detail_level: :very_high,
        production_ready: false,
        capabilities: [:all_runtime_features, :all_ast_features, :cross_correlation],
        limitations: [:complex_setup, :higher_overhead]
      }
    }
  end

  @doc """
  Explains why a particular mode was selected for a target.
  """
  @spec explain_selection(trace_target(), selection_options()) :: map()
  def explain_selection(target, options \\ %{}) do
    {:ok, selected_mode} = select_mode(target, options)
    
    %{
      selected_mode: selected_mode,
      reasoning: get_selection_reasoning(target, options, selected_mode),
      alternatives: get_alternative_modes(target, options),
      recommendations: get_mode_recommendations(target, options)
    }
  end

  # ============================================================================
  # Private Implementation
  # ============================================================================

  defp auto_select_mode(target, options) do
    # Phase 1: Always select runtime mode since it's the only stable option
    # Phase 2: Will implement intelligent selection logic
    
    cond do
      # High performance requirements -> Runtime
      requires_low_overhead?(options) -> 
        :runtime
      
      # Production environment -> Runtime
      in_production_environment?() -> 
        :runtime
      
      # Complex analysis requested but AST not available -> Runtime
      requires_detailed_analysis?(options) and not ast_available?() -> 
        :runtime
      
      # Default to runtime for Phase 1
      true -> 
        :runtime
    end
  end

  defp validate_and_select_mode(mode, target, options) do
    capabilities = get_mode_capabilities()
    mode_info = Map.get(capabilities, mode)
    
    cond do
      # Mode not available
      not mode_info.available ->
        suggest_fallback_mode(mode, target, options)
      
      # Mode available but not suitable for production
      in_production_environment?() and not mode_info.production_ready ->
        {:error, {:mode_not_production_ready, mode}}
      
      # Mode available and suitable
      true ->
        {:ok, mode}
    end
  end

  defp suggest_fallback_mode(:ast, target, options) do
    # AST not available in Phase 1, suggest runtime
    {:ok, :runtime}
  end

  defp suggest_fallback_mode(:hybrid, target, options) do
    # Hybrid not available in Phase 1, suggest runtime
    {:ok, :runtime}
  end

  defp suggest_fallback_mode(mode, _target, _options) do
    {:error, {:mode_not_available, mode}}
  end

  defp requires_low_overhead?(options) do
    max_overhead = Map.get(options, :max_overhead, 10.0)
    sample_rate = Map.get(options, :sample_rate, 1.0)
    
    max_overhead < 5.0 or sample_rate < 0.1
  end

  defp in_production_environment? do
    Mix.env() == :prod or 
    Application.get_env(:elixir_scope, :environment) == :production
  end

  defp requires_detailed_analysis?(options) do
    capture_options = Map.get(options, :capture, [])
    
    :locals in capture_options or 
    :expressions in capture_options or
    Map.has_key?(options, :custom_injections)
  end

  defp ast_available? do
    # Phase 1: AST not available
    # Phase 2: Will check actual AST system availability
    false
  end

  defp get_selection_reasoning(target, options, selected_mode) do
    reasons = []
    
    reasons = if requires_low_overhead?(options) do
      ["Low overhead required (max: #{Map.get(options, :max_overhead, "default")}%)" | reasons]
    else
      reasons
    end
    
    reasons = if in_production_environment?() do
      ["Production environment detected" | reasons]
    else
      reasons
    end
    
    reasons = if requires_detailed_analysis?(options) and not ast_available?() do
      ["Detailed analysis requested but AST not available, using runtime fallback" | reasons]
    else
      reasons
    end
    
    reasons = if selected_mode == :runtime and ast_available?() do
      ["Runtime selected for stability and performance" | reasons]
    else
      reasons
    end
    
    case reasons do
      [] -> ["Default mode selection based on current system capabilities"]
      _ -> reasons
    end
  end

  defp get_alternative_modes(target, options) do
    capabilities = get_mode_capabilities()
    
    Enum.filter([:runtime, :ast, :hybrid], fn mode ->
      mode_info = Map.get(capabilities, mode)
      mode_info.available and 
      (not in_production_environment?() or mode_info.production_ready)
    end)
  end

  defp get_mode_recommendations(target, options) do
    recommendations = []
    
    recommendations = if requires_detailed_analysis?(options) do
      ["Consider using AST mode when available for detailed local variable capture" | recommendations]
    else
      recommendations
    end
    
    recommendations = if Map.get(options, :duration, 0) > 300_000 do
      ["For long-running traces, consider using sampling to reduce overhead" | recommendations]
    else
      recommendations
    end
    
    recommendations = if in_production_environment?() do
      ["In production, runtime mode is recommended for stability" | recommendations]
    else
      recommendations
    end
    
    case recommendations do
      [] -> ["Current selection is optimal for the given requirements"]
      _ -> recommendations
    end
  end

  # ============================================================================
  # Future Phase 2 Implementation Hooks
  # ============================================================================

  # These functions will be implemented in Phase 2 when AST and hybrid modes are available

  defp analyze_target_complexity(_target) do
    # Will analyze function complexity, call patterns, etc.
    :medium
  end

  defp estimate_overhead_for_mode(_mode, _target, _options) do
    # Will provide accurate overhead estimates
    %{runtime: 2.5, ast: 8.0, hybrid: 12.0}
  end

  defp check_system_load do
    # Will check current system performance and load
    :normal
  end

  defp get_historical_performance(_target) do
    # Will use historical data to inform mode selection
    %{avg_execution_time: 1000, call_frequency: :medium}
  end
end 