defmodule PhoenixScopePlayer.DataProvider do
  @moduledoc """
  Provides access to session data, source code, and AST mappings.
  Handles data loading, caching, and efficient retrieval.
  """

  require Logger

  @type session_meta :: %{
    id: String.t(),
    name: String.t(),
    description: String.t(),
    timestamp: DateTime.t(),
    event_count: integer(),
    trigger: String.t(),
    duration: integer(),
    status: :completed | :error
  }

  @doc """
  Lists all available debugging sessions
  """
  @spec list_sessions() :: [session_meta()]
  def list_sessions do
    captured_data_path = Path.join(:code.priv_dir(:phoenix_scope_player), "captured_data")
    
    case File.ls(captured_data_path) do
      {:ok, session_dirs} ->
        session_dirs
        |> Enum.map(&load_session_metadata/1)
        |> Enum.reject(&is_nil/1)
      
      {:error, reason} ->
        Logger.error("Failed to list sessions: #{inspect(reason)}")
        []
    end
  end

  @doc """
  Gets all data for a specific session
  """
  @spec get_session_data(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get_session_data(session_id) when is_binary(session_id) do
    with {:ok, events} <- load_events(session_id),
         {:ok, source_code} <- load_source_code(session_id),
         {:ok, ast_map} <- load_ast_map(session_id) do
      {:ok, %{
        events: events,
        source_code_map: source_code,
        ast_map: ast_map
      }}
    else
      error ->
        Logger.error("Failed to load session data: #{inspect(error)}")
        {:error, :not_found}
    end
  end

  @doc """
  Gets source code for a specific session
  """
  @spec get_session_source_code(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get_session_source_code(session_id) when is_binary(session_id) do
    load_source_code(session_id)
  end

  @doc """
  Gets AST mapping for a specific session
  """
  @spec get_session_ast_map(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get_session_ast_map(session_id) when is_binary(session_id) do
    load_ast_map(session_id)
  end

  # Private Functions

  defp load_session_metadata(session_id) do
    path = session_data_path(session_id, "metadata.json")
    
    case load_json_file(path) do
      {:ok, metadata} -> metadata
      {:error, _} -> nil
    end
  end

  defp load_events(session_id) do
    path = session_data_path(session_id, "events.json")
    load_json_file(path)
  end

  defp load_source_code(session_id) do
    path = session_data_path(session_id, "source_code.json")
    load_json_file(path)
  end

  defp load_ast_map(session_id) do
    path = session_data_path(session_id, "ast_map.json")
    load_json_file(path)
  end

  defp load_json_file(path) do
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> {:ok, data}
          {:error, reason} ->
            Logger.error("Failed to decode JSON from #{path}: #{inspect(reason)}")
            {:error, :invalid_json}
        end
      {:error, reason} ->
        Logger.error("Failed to read file #{path}: #{inspect(reason)}")
        {:error, :not_found}
    end
  end

  defp session_data_path(session_id, filename) do
    Path.join([
      :code.priv_dir(:phoenix_scope_player),
      "captured_data",
      session_id,
      filename
    ])
  end
end 