defmodule ObanChore.Plugin do
  @moduledoc """
  An Oban Plugin that discovers and manages chores.

  ## Options

    * `:otp_app` - An atom or list of atoms representing the OTP application(s) to search for chores.
      If not provided, all loaded applications will be searched (less efficient).
  """
  @behaviour Oban.Plugin

  use GenServer
  require Logger

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
    {:noreply, %{state | chores: chores}, {:continue, :attach_telemetry}}
  end

  @impl GenServer
  def handle_continue(:attach_telemetry, state) do
    if pubsub_server = ObanChore.pubsub_server() do
      oban_name = if state.opts[:conf], do: state.opts[:conf].name, else: Oban
      handler_id = {:oban_chore_counts, oban_name}

      :telemetry.attach_many(
        handler_id,
        [
          [:oban, :job, :insert, :stop],
          [:oban, :job, :start],
          [:oban, :job, :stop],
          [:oban, :job, :exception]
        ],
        &__MODULE__.handle_telemetry/4,
        %{oban_name: oban_name, pubsub_server: pubsub_server, chores: state.chores}
      )
    end

    {:noreply, state}
  end

  @doc false
  def handle_telemetry(event, _measurements, metadata, %{
        oban_name: oban_name,
        pubsub_server: pubsub_server,
        chores: chores
      }) do
    if metadata.conf.name == oban_name do
      jobs =
        case metadata do
          %{job: job} -> [job]
          %{jobs: jobs} -> jobs
          _ -> []
        end

      workers = jobs |> Enum.map(& &1.worker) |> Enum.uniq()

      for worker_str <- workers do
        # Robust matching: Oban worker strings can be "Elixir.Mod" or just "Mod"
        # or even custom names. We check against the module atom string.
        chore =
          Enum.find(chores, fn c ->
            c_mod_str = to_string(c.module)
            c_mod_str == worker_str or c_mod_str == "Elixir." <> worker_str
          end)

        if chore do
          # Broadcast state changes for specific jobs if available
          for job <- jobs, job.worker == worker_str do
            state = event_to_state(event, job)

            Phoenix.PubSub.broadcast(
              pubsub_server,
              "oban_chore:status:#{job.id}",
              {:oban_chore_state, job.id, state}
            )
          end

          # Broadcast counts (requires running Oban instance)
          try do
            count = ObanChore.count_running(chore.module, oban_name)

            Logger.debug(
              "[ObanChore] Telemetry #{inspect(event)} for #{chore.module}. New count: #{count}. Broadcasting to #{pubsub_server}"
            )

            Phoenix.PubSub.broadcast(
              pubsub_server,
              "oban_chore:counts",
              {:oban_chore_count, chore.module, count}
            )
          rescue
            _ -> :ok
          end
        end
      end
    end
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

  defp event_to_state([:oban, :job, :start], _job), do: :executing
  defp event_to_state([:oban, :job, :stop], _job), do: :completed

  defp event_to_state([:oban, :job, :exception], job) do
    if job.state == "discarded", do: :discarded, else: :retryable
  end

  defp event_to_state(_event, job), do: String.to_existing_atom(job.state)

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
