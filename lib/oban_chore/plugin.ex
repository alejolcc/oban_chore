defmodule ObanChore.Plugin do
  @moduledoc """
  An Oban Plugin that discovers and manages chores.

  ## Options

    * `:otp_app` - An atom or list of atoms representing the OTP application(s) to search for chores.
      If not provided, all loaded applications will be searched (less efficient).
  """
  @behaviour Oban.Plugin

  use GenServer

  @impl Oban.Plugin
  def validate(opts) do
    case Keyword.get(opts, :otp_app) do
      nil ->
        :ok

      app when is_atom(app) ->
        :ok

      apps when is_list(apps) ->
        if Enum.all?(apps, &is_atom/1),
          do: :ok,
          else: {:error, "all otp_app elements must be atoms"}

      _ ->
        {:error, "otp_app must be an atom or a list of atoms"}
    end
  end

  @impl true
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    {:ok, %{opts: opts, chores: []}, {:continue, :discover_chores}}
  end

  @impl GenServer
  def handle_continue(:discover_chores, state) do
    chores = discover_chores(state.opts)
    {:noreply, %{state | chores: chores}}
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

  defp discover_chores(opts) do
    apps =
      case Keyword.get(opts, :otp_app) do
        nil ->
          Application.loaded_applications()
          |> Enum.map(fn {app, _desc, _vsn} -> app end)

        app when is_atom(app) ->
          [app]

        apps when is_list(apps) ->
          apps
      end

    apps
    |> Enum.flat_map(fn app ->
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
