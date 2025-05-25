defmodule Mix.Tasks.Compile.ElixirScope do
  @moduledoc """
  Mix compiler that transforms Elixir ASTs to inject ElixirScope instrumentation.

  This compiler:
  1. Runs before the standard Elixir compiler
  2. Transforms ASTs based on AI-generated instrumentation plans
  3. Preserves original code semantics and metadata
  4. Injects calls to ElixirScope.Capture.InstrumentationRuntime
  """

  use Mix.Task.Compiler

  alias ElixirScope.AST.Transformer
  alias ElixirScope.AI.Orchestrator

  @impl true
  def run(argv) do
    config = parse_argv(argv)

    # Get instrumentation plan from AI
    case Orchestrator.get_instrumentation_plan() do
      {:ok, plan} ->
        transform_project(plan, config)

      {:error, :no_plan} ->
        # Generate plan if none exists
        case Orchestrator.analyze_and_plan(File.cwd!()) do
          {:ok, plan} -> transform_project(plan, config)
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        Mix.shell().error("ElixirScope instrumentation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Transforms an AST directly with a given plan (used by tests).
  """
  def transform_ast(ast, plan) do
    Transformer.transform_function(ast, plan)
  end

  defp transform_project(plan, config) do
    # Find all .ex files in the project
    elixir_files = find_elixir_files(config.source_paths)

    # Transform each file
    results = Enum.map(elixir_files, fn file_path ->
      transform_file(file_path, plan, config)
    end)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil ->
        Mix.shell().info("ElixirScope: Instrumented #{length(elixir_files)} files")
        :ok
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp transform_file(file_path, plan, config) do
    try do
      # Read and parse the file
      source = File.read!(file_path)
      {:ok, ast} = Code.string_to_quoted(source, file: file_path)

      # Get module-specific instrumentation plan
      module_plan = extract_module_plan(ast, plan)

      # Transform the AST
      transformed_ast = Transformer.transform_module(ast, module_plan)

      # Generate output path
      output_path = generate_output_path(file_path, config)

      # Write transformed code
      transformed_code = Macro.to_string(transformed_ast)
      File.write!(output_path, transformed_code)

      :ok
    rescue
      error ->
        Mix.shell().error("Failed to transform #{file_path}: #{inspect(error)}")
        {:error, error}
    end
  end

  # Implementation details for file handling, path management, etc.
  defp find_elixir_files(source_paths) do
    source_paths
    |> Enum.flat_map(fn path ->
      Path.wildcard(Path.join(path, "**/*.ex"))
    end)
    |> Enum.reject(&String.contains?(&1, "/_build/"))
  end

  defp extract_module_plan(ast, global_plan) do
    module_name = extract_module_name(ast)
    Map.get(global_plan.modules, module_name, %{})
  end

  defp generate_output_path(input_path, config) do
    # Generate path in _build directory to avoid overwriting source
    relative_path = Path.relative_to(input_path, File.cwd!())
    Path.join([config.build_path, "elixir_scope", relative_path])
  end

  # Stub implementations for missing functions
  # TODO: Implement these functions properly in future phases

  defp parse_argv(_argv) do
    # TODO: Implement proper argument parsing
    %{
      source_paths: ["lib"],
      build_path: "_build/dev"
    }
  end

  defp extract_module_name(ast) do
    # TODO: Implement proper module name extraction from AST
    case ast do
      {:defmodule, _, [{:__aliases__, _, module_parts}, _]} ->
        Module.concat(module_parts)
      _ ->
        :unknown
    end
  end
end

# Backwards compatibility alias for tests
defmodule ElixirScope.Compiler.MixTask do
  defdelegate transform_ast(ast, plan), to: Mix.Tasks.Compile.ElixirScope
end
