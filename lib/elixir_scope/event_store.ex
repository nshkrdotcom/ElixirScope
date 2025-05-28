defmodule ElixirScope.EventStore do
  @moduledoc """
  EventStore API wrapper that provides the expected interface for components.
  
  This module wraps ElixirScope.Storage.EventStore and provides a simplified
  3-argument API that components expect: store_event(component, event_type, data)
  """
  
  alias ElixirScope.Storage.EventStore, as: StorageEventStore
  
  @doc """
  Stores an event with the expected 3-argument API.
  
  Converts the component/event_type/data format into the proper event struct
  and stores it in the global EventStore instance.
  """
  def store_event(component, event_type, data) when is_atom(component) and is_atom(event_type) do
    case get_or_create_event_store() do
      {:ok, store} ->
        event = %{
          component: component,
          event_type: event_type,
          timestamp: DateTime.utc_now(),
          pid: self(),
          data: data
        }
        
        StorageEventStore.store_event(store, event)
      
      {:error, reason} ->
        # In test mode or if EventStore is not available, just log and continue
        require Logger
        Logger.debug("EventStore not available: #{inspect(reason)}, skipping event storage")
        :ok
    end
  end
  
  @doc """
  Gets the global EventStore instance or creates one if needed.
  """
  def get_or_create_event_store do
    case Process.whereis(__MODULE__) do
      nil ->
        # Try to start a global EventStore
        case StorageEventStore.start_link(name: __MODULE__) do
          {:ok, pid} -> {:ok, pid}
          {:error, {:already_started, pid}} -> {:ok, pid}
          {:error, reason} -> {:error, reason}
        end
      
      pid when is_pid(pid) ->
        {:ok, pid}
    end
  end
  
  @doc """
  Queries events using the Storage EventStore API.
  """
  def query_events(filters) do
    case get_or_create_event_store() do
      {:ok, store} ->
        StorageEventStore.query_events(store, filters)
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Gets EventStore statistics.
  """
  def get_stats do
    case get_or_create_event_store() do
      {:ok, store} ->
        StorageEventStore.get_index_stats(store)
      
      {:error, reason} ->
        {:error, reason}
    end
  end
end 