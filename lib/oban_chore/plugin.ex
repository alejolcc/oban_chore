defmodule ObanChore.Plugin do
  @moduledoc """
  An Oban Plugin that automatically discovers and manages chores.

  The plugin is responsible for:
  - Scanning specified OTP applications for modules using `ObanChore.Worker`.
  - Attaching telemetry handlers to track chore status and counts.
  - Broadcasting real-time updates via Phoenix PubSub.

  ## Options

    * `:otp_app` - An atom or list of atoms representing the OTP application(s) to search for chores.
      If not provided, all loaded applications will be searched.
    * `:pubsub_server` - (Required) The name of your application's Phoenix PubSub server.

  ## Examples

  ```elixir
  # In your Oban configuration:
  config :my_app, Oban,
    repo: MyApp.Repo,
    plugins: [
      {ObanChore.Plugin, otp_app: :my_app, pubsub_server: MyApp.PubSub}
    ]
  ```
  """
  @behaviour Oban.Plugin

  use GenServer
  require Logger
  import Ecto.Query

  @impl Oban.Plugin
  def validate(opts) do
    with :ok <- validate_exclusive_and_required_opts(opts),
         :ok <- validate_chores(opts),
         :ok <- validate_otp_app(opts),
         :ok <- validate_pubsub_server(opts) do
      :ok
    end
  end

  defp validate_exclusive_and_required_opts(opts) do
    case {opts[:otp_app], opts[:chores]} do
      {otp, chores} when not is_nil(otp) and not is_nil(chores) ->
        {:error, "cannot set both :otp_app and :chores options"}

      {nil, nil} ->
        {:error, "must set either :otp_app or :chores option"}

      _ ->
        :ok
    end
  end

  defp validate_chores(opts) do
    case Keyword.get(opts, :chores) do
      nil ->
        :ok

      chores when is_list(chores) ->
        cond do
          not Enum.all?(chores, &is_atom/1) ->
            {:error, "all chores elements must be modules (atoms)"}

          true ->
            invalid =
              Enum.filter(chores, fn module ->
                not (match?({:module, _}, Code.ensure_compiled(module)) and
                       function_exported?(module, :__chore_info__, 0))
              end)

            if invalid == [] do
              :ok
            else
              {:error, "the following modules are not chores: #{inspect(invalid)}"}
            end
        end

      _ ->
        {:error, "chores must be a list of modules (atoms)"}
    end
  end

  defp validate_otp_app(opts) do
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

  defp validate_pubsub_server(opts) do
    case Keyword.get(opts, :pubsub_server) do
      nil -> {:error, "missing :pubsub_server option"}
      server when is_atom(server) -> :ok
      _ -> {:error, "pubsub_server must be an atom"}
    end
  end

  @impl true
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Retrieves the list of discovered chores from the plugin's state.

  Returns a list of maps containing chore metadata.
  """
  def get_chores(oban_name \\ ObanChore.oban_name()) do
    case Oban.Registry.whereis(oban_name, {:plugin, __MODULE__}) do
      nil ->
        case GenServer.whereis(__MODULE__) do
          nil -> []
          pid -> GenServer.call(pid, :get_chores)
        end

      pid ->
        GenServer.call(pid, :get_chores)
    end
  end

  @doc false
  def handle_telemetry(event, _measurements, metadata, %{
        oban_name: oban_name,
        pubsub_server: pubsub_server,
        chores: chores
      }) do
    if event in [[:oban, :job, :stop], [:oban, :job, :exception]] and Map.has_key?(metadata, :job) do
      persist_logs_to_meta(metadata.job, oban_name)
    end

    if metadata.conf.name == oban_name do
      jobs = extract_jobs(metadata)
      workers = jobs |> Enum.map(& &1.worker) |> Enum.uniq()

      for worker_str <- workers, chore = find_chore(chores, worker_str) do
        broadcast_job_status(pubsub_server, event, jobs, worker_str)
        broadcast_chore_count(pubsub_server, oban_name, chore.module, event)
      end
    end
  end

  # --- GenServer Callbacks ---

  @impl GenServer
  def init(opts) do
    # Guaranteed to exist by validate/1
    pubsub = Keyword.fetch!(opts, :pubsub_server)
    Application.put_env(:oban_chore, :pubsub_server, pubsub)

    oban_name = if opts[:conf], do: opts[:conf].name, else: Oban
    Application.put_env(:oban_chore, :oban_name, oban_name)

    # Initialize the ETS table for active logs
    table = ObanChore.logs_table()

    case :ets.info(table) do
      :undefined ->
        :ets.new(table, [
          :named_table,
          :public,
          :set,
          {:write_concurrency, true},
          {:read_concurrency, true}
        ])

      _ ->
        :ok
    end

    {:ok, %{opts: opts, chores: []}, {:continue, :discover_chores}}
  end

  @impl GenServer
  def handle_continue(:discover_chores, state) do
    chores = discover_chores(state.opts)
    {:noreply, %{state | chores: chores}, {:continue, :attach_telemetry}}
  end

  @impl GenServer
  def handle_continue(:attach_telemetry, state) do
    pubsub_server = Application.fetch_env!(:oban_chore, :pubsub_server)
    oban_name = if state.opts[:conf], do: state.opts[:conf].name, else: Oban
    handler_id = {:oban_chore_counts, oban_name}

    case :telemetry.attach_many(
           handler_id,
           [
             [:oban, :job, :insert, :stop],
             [:oban, :job, :start],
             [:oban, :job, :stop],
             [:oban, :job, :exception]
           ],
           &__MODULE__.handle_telemetry/4,
           %{oban_name: oban_name, pubsub_server: pubsub_server, chores: state.chores}
         ) do
      :ok -> :ok
      {:error, :already_exists} -> :ok
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:get_chores, _from, state) do
    {:reply, state.chores, state}
  end

  # --- Private Helpers ---

  defp extract_jobs(%{job: job}), do: [job]
  defp extract_jobs(%{jobs: jobs}), do: jobs
  defp extract_jobs(_), do: []

  defp find_chore(chores, worker_str) do
    Enum.find(chores, fn c ->
      c_mod_str = to_string(c.module)
      c_mod_str == worker_str or c_mod_str == "Elixir." <> worker_str
    end)
  end

  defp broadcast_job_status(pubsub_server, event, jobs, worker_str) do
    for job <- jobs, job.worker == worker_str do
      state = event_to_state(event, job)

      Phoenix.PubSub.broadcast(
        pubsub_server,
        "oban_chore:status:#{job.id}",
        {:oban_chore_state, job.id, state}
      )
    end
  end

  defp broadcast_chore_count(pubsub_server, oban_name, chore_module, event) do
    try do
      count = ObanChore.count_running(chore_module, oban_name)

      Logger.debug(
        "[ObanChore] Telemetry #{inspect(event)} for #{chore_module}. New count: #{count}. Broadcasting to #{pubsub_server}"
      )

      Phoenix.PubSub.broadcast(
        pubsub_server,
        "oban_chore:counts",
        {:oban_chore_count, chore_module, count}
      )
    rescue
      e ->
        Logger.error(
          "[ObanChore] Failed to broadcast chore count for #{chore_module}: #{inspect(e)}"
        )

        :ok
    end
  end

  # TODO: This is actually needed? I think we can just rely on the job state for this, but let's keep it for now in case we want to do something more specific with the events in the future.
  defp event_to_state([:oban, :job, :start], _job), do: :executing
  defp event_to_state([:oban, :job, :stop], _job), do: :completed

  defp event_to_state([:oban, :job, :exception], job) do
    if job.state == "discarded", do: :discarded, else: :retryable
  end

  # Because Oban Job state have a finite set of values, we can safely convert them to atoms
  defp event_to_state(_event, job), do: String.to_existing_atom(job.state)

  defp persist_logs_to_meta(job, oban_name) do
    table = ObanChore.logs_table()

    case :ets.info(table) do
      :undefined ->
        :ok

      _ ->
        case :ets.lookup(table, job.id) do
          [] ->
            :ok

          [{_, logs}] ->
            ordered_logs = Enum.reverse(logs)
            new_meta = Map.put(job.meta || %{}, "oban_chore_logs", ordered_logs)
            repo = Oban.config(oban_name).repo

            repo.update_all(
              from(j in Oban.Job, where: j.id == ^job.id),
              set: [meta: new_meta]
            )

            :ets.delete(table, job.id)
            :ok
        end
    end
  rescue
    error ->
      Logger.error("[ObanChore] Failed to persist job logs to metadata: #{inspect(error)}")
      :ok
  end

  # TODO: Improve the discovery
  defp discover_chores(opts) do
    case Keyword.get(opts, :chores) do
      chores when is_list(chores) ->
        chores
        |> Enum.map(fn module -> module.__chore_info__() end)

      nil ->
        apps =
          case Keyword.get(opts, :otp_app) do
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
          match?({:module, _}, Code.ensure_compiled(module)) and
            function_exported?(module, :__chore_info__, 0)
        end)
        |> Enum.map(fn module -> module.__chore_info__() end)
    end
  end
end
