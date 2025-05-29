defmodule PhoenixScopePlayer.PlaybackEngine.Registry do
  @moduledoc """
  Registry for managing PlaybackEngine processes.
  Each session will have its own PlaybackEngine process registered here.
  """
  use Registry, keys: :unique, name: __MODULE__

  @doc """
  Returns the process name for a session's playback engine
  """
  def via_tuple(session_id) when is_binary(session_id) do
    {:via, Registry, {__MODULE__, session_id}}
  end

  @doc """
  Returns the pid of the playback engine for a session, if it exists
  """
  def whereis(session_id) when is_binary(session_id) do
    case Registry.lookup(__MODULE__, session_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end
end 