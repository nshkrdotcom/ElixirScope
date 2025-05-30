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
    Logger.info("\n=== Listing Sessions ===")
    case File.ls(@sessions_dir) do
      {:ok, session_dirs} ->
        Logger.info("Found #{length(session_dirs)} session directories")
        sessions = session_dirs
        |> Enum.map(&load_session_metadata/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.sort_by(& &1["date"], :desc)

        Logger.info("Processed #{length(sessions)} valid sessions:")
        Enum.each(sessions, fn session ->
          Logger.info("  - #{session["id"]}: #{session["event_count"]} events")
        end)
        
        sessions

      {:error, reason} ->
        Logger.error("Error listing sessions: #{inspect(reason)}")
        []
    end
  end

  @doc """
  Gets the complete data for a specific session.
  """
  def get_session_data(session_id) do
    Logger.info("\n=== Getting Session Data: #{session_id} ===")
    session_dir = Path.join(@sessions_dir, session_id)

    with {:ok, metadata} <- read_json_file(session_dir, "metadata.json"),
         {:ok, events_data} <- read_json_file(session_dir, "events.json"),
         {:ok, source_code} <- read_json_file(session_dir, "source_code.json") do
      
      # Transform events into the expected format
      transformed_events = Enum.map(events_data["events"] || [], fn event ->
        %{
          "type" => event["type"],
          "module" => event["module"],
          "function" => event["function"],
          "args" => format_args(event["args"]),
          "return_value" => format_return_value(event["return_value"]),
          "pid" => event["pid"],
          "timestamp" => event["timestamp"],
          "variables" => event["variables"],
          "call_stack" => event["call_stack"] || []
        }
      end)
      
      # Transform source code into the expected format
      transformed_source_code = %{
        "files" => Map.new(source_code["files"] || %{}, fn {module, data} ->
          {module, %{
            "content" => data["content"],
            "type" => "elixir"
          }}
        end)
      }
      
      Logger.info("Metadata: #{inspect(metadata)}")
      Logger.info("Events count: #{length(transformed_events)}")
      Logger.info("Source code files: #{inspect(Map.keys(transformed_source_code["files"]))}")
      
      {:ok, %{
        "metadata" => metadata,
        "events" => transformed_events,
        "source_code" => transformed_source_code
      }}
    else
      error -> 
        Logger.error("Error reading session data: #{inspect(error)}")
        {:error, :not_found}
    end
  end

  # Private helpers

  defp format_args(nil), do: nil
  defp format_args(args) when is_list(args) do
    args
  end

  defp format_return_value(nil), do: nil
  defp format_return_value(value), do: value

  defp format_value(%{"type" => type, "value" => value}) do
    "#{type}: #{value}"
  end
  defp format_value(value), do: value

  defp load_session_metadata(session_dir) do
    Logger.info("\nLoading metadata for session: #{session_dir}")
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
          "name" => metadata["name"] || session_dir |> String.replace("_", " ") |> String.capitalize(),
          "date" => metadata["timestamp"] || "Unknown",
          "description" => metadata["description"] || "Debug session with #{actual_event_count} events",
          "event_count" => actual_event_count
        })
        
        Logger.info("  Loaded session: #{inspect(session, pretty: true)}")
        session

      error -> 
        Logger.error("  Error loading metadata: #{inspect(error)}")
        nil
    end
  end

  defp read_json_file(dir, filename) do
    path = Path.join(dir, filename)
    Logger.info("Reading JSON file: #{path}")

    case File.read(path) do
      {:ok, content} -> 
        case Jason.decode(content) do
          {:ok, data} -> 
            Logger.info("  Successfully decoded JSON: #{inspect(String.slice(content, 0..100))}...")
            {:ok, data}
          error -> 
            Logger.error("  Error decoding JSON: #{inspect(error)}")
            error
        end
      {:error, reason} -> 
        Logger.error("  Error reading file: #{inspect(reason)}")
        {:error, :not_found}
    end
  end
end 