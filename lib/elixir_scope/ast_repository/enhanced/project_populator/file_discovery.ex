defmodule ElixirScope.ASTRepository.Enhanced.ProjectPopulator.FileDiscovery do
  @moduledoc """
  Handles discovery of Elixir files in a project directory.

  Provides functionality to:
  - Discover files based on include/exclude patterns
  - Filter files by size limits
  - Handle directory validation
  """

  require Logger

  @doc """
  Discovers all Elixir files in a project directory.
  """
  def discover_elixir_files(project_path, opts \\ []) do
    include_patterns = Keyword.get(opts, :include_patterns, ["**/*.ex", "**/*.exs"])
    exclude_patterns = Keyword.get(opts, :exclude_patterns, [])
    max_file_size = Keyword.get(opts, :max_file_size, 1_000_000)

    # Check if directory exists
    if not (File.exists?(project_path) and File.dir?(project_path)) do
      {:error, :directory_not_found}
    else
      try do
        files = include_patterns
        |> Enum.flat_map(fn pattern ->
          Path.wildcard(Path.join(project_path, pattern))
        end)
        |> Enum.uniq()
        |> Enum.reject(fn file ->
          Enum.any?(exclude_patterns, fn pattern ->
            String.contains?(file, pattern)
          end)
        end)
        |> Enum.filter(fn file ->
          case File.stat(file) do
            {:ok, %{size: size}} when size <= max_file_size -> true
            _ -> false
          end
        end)
        |> Enum.sort()

        Logger.debug("Discovered #{length(files)} Elixir files")
        {:ok, files}
      rescue
        e ->
          {:error, {:file_discovery_failed, Exception.message(e)}}
      end
    end
  end
end
