defmodule ObanChore.Plugin do
  @moduledoc """
  An Oban Plugin that discovers and manages chores.
  """
  @behaviour Oban.Plugin

  use GenServer

  @impl Oban.Plugin
  def validate(_opts), do: :ok

  @impl true
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    chores = Keyword.get(opts, :chores) || discover_chores()
    {:ok, %{opts: opts, chores: chores}}
  end

  @doc """
  Retrieves the list of discovered chores.
  """
  def get_chores do
    # During testing or if not started within Oban, handle missing process
    case GenServer.whereis(__MODULE__) do
      nil -> []
      pid -> GenServer.call(pid, :get_chores)
    end
  end

  @impl GenServer
  def handle_call(:get_chores, _from, state) do
    {:reply, state.chores, state}
  end

  defp discover_chores do
    Application.loaded_applications()
    |> Enum.flat_map(fn {app, _desc, _vsn} ->
      case :application.get_key(app, :modules) do
        {:ok, modules} -> modules
        _ -> []
      end
    end)
    |> Enum.filter(fn module ->
      Code.ensure_loaded?(module) and function_exported?(module, :__chore_info__, 0)
    end)
    |> Enum.map(fn module -> module.__chore_info__() end)
  end
end
