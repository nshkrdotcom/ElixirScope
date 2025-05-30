defmodule Mix.Tasks.Clean.Sessions do
  @moduledoc """
  Mix task to clean out all debug sessions.

  ## Examples

      mix clean.sessions         # Cleans all sessions
      mix clean.sessions --keep-sample  # Keeps sample_session_1
  """
  
  use Mix.Task
  require Logger

  @impl Mix.Task
  def run(args) do
    keep_sample = "--keep-sample" in args
    
    captured_data_dir = Path.join([
      :code.priv_dir(:phoenix_scope_player),
      "captured_data"
    ])

    Logger.info("\n=== Cleaning debug sessions ===")
    
    # Ensure directory exists
    File.mkdir_p!(captured_data_dir)
    
    case File.ls(captured_data_dir) do
      {:ok, files} ->
        files
        |> Enum.filter(fn file ->
          if keep_sample do
            file != "sample_session_1"
          else
            true
          end
        end)
        |> Enum.each(fn file ->
          path = Path.join(captured_data_dir, file)
          case File.rm_rf(path) do
            {:ok, _} ->
              Logger.info("✓ Removed #{file}")
            {:error, posix, reason} ->
              Logger.error("✗ Failed to remove #{file}: #{inspect(posix)} - #{inspect(reason)}")
          end
        end)
        
        Logger.info("\n=== Session cleanup complete ===")

      {:error, reason} ->
        Logger.error("Error listing sessions: #{inspect(reason)}")
    end
  end
end 