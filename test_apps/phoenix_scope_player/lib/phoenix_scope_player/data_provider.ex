defmodule PhoenixScopePlayer.DataProvider do
  @moduledoc """
  Provides access to debug session data stored in the priv directory.
  """

  require Logger

  @sessions_dir Path.join([:code.priv_dir(:phoenix_scope_player), "captured_data"])

  @doc """
  Lists all available debug sessions.
  """
  def list_sessions do
    IO.puts("\n=== Listing Sessions ===")
    case File.ls(@sessions_dir) do
      {:ok, session_dirs} ->
        IO.puts("Found #{length(session_dirs)} session directories")
        sessions = session_dirs
        |> Enum.map(&load_session_metadata/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.sort_by(& &1["date"], :desc)

        IO.puts("Processed #{length(sessions)} valid sessions:")
        Enum.each(sessions, fn session ->
          IO.puts("  - #{session["id"]}: #{session["event_count"]} events")
        end)
        
        sessions

      {:error, reason} ->
        IO.puts("Error listing sessions: #{inspect(reason)}")
        []
    end
  end

  @doc """
  Gets the complete data for a specific session.
  """
  def get_session_data(session_id) do
    IO.puts("\n=== Getting Session Data: #{session_id} ===")
    session_dir = Path.join(@sessions_dir, session_id)

    with {:ok, metadata} <- read_json_file(session_dir, "metadata.json"),
         {:ok, events} <- read_json_file(session_dir, "events.json"),
         {:ok, source_code} <- read_json_file(session_dir, "source_code.json") do
      
      IO.puts("Metadata: #{inspect(metadata)}")
      IO.puts("Events count: #{length(events["events"] || [])}")
      
      {:ok, %{
        metadata: metadata,
        events: events["events"] || [],
        source_code: source_code
      }}
    else
      error -> 
        IO.puts("Error reading session data: #{inspect(error)}")
        {:error, :not_found}
    end
  end

  # Private helpers

  defp load_session_metadata(session_dir) do
    IO.puts("\nLoading metadata for session: #{session_dir}")
    case read_json_file(Path.join(@sessions_dir, session_dir), "metadata.json") do
      {:ok, metadata} ->
        # Read events file to get actual event count
        events_path = Path.join([@sessions_dir, session_dir, "events.json"])
        actual_event_count = case File.read(events_path) do
          {:ok, content} ->
            case Jason.decode(content) do
              {:ok, %{"events" => events}} -> length(events)
              _ -> 0
            end
          _ -> 0
        end

        session = Map.merge(metadata, %{
          "id" => session_dir,
          "name" => session_dir |> String.replace("_", " ") |> String.capitalize(),
          "date" => metadata["timestamp"] || "Unknown",
          "description" => "Debug session with #{actual_event_count} events"
        })
        
        IO.puts("  Loaded session: #{inspect(session, pretty: true)}")
        session

      error -> 
        IO.puts("  Error loading metadata: #{inspect(error)}")
        nil
    end
  end

  defp read_json_file(dir, filename) do
    path = Path.join(dir, filename)
    IO.puts("Reading JSON file: #{path}")

    case File.read(path) do
      {:ok, content} -> 
        case Jason.decode(content) do
          {:ok, data} -> 
            IO.puts("  Successfully decoded JSON")
            {:ok, data}
          error -> 
            IO.puts("  Error decoding JSON: #{inspect(error)}")
            error
        end
      {:error, reason} -> 
        IO.puts("  Error reading file: #{inspect(reason)}")
        {:error, :not_found}
    end
  end
end 