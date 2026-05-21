defmodule ObanChore do
  @moduledoc """
  ObanChore transforms standard Oban workers into secure, UI-driven operational tools.

  ## Configuration

  To use ObanChore, you must add `ObanChore.Plugin` to your Oban configuration:

      config :my_app, Oban,
        repo: MyApp.Repo,
        plugins: [
          {ObanChore.Plugin, otp_app: :my_app},
          # ...
        ],
        queues: [default: 10]

  ### Real-time Logging (Optional)

  To enable real-time execution logs in the dashboard, configure your PubSub server:

      config :oban_chore, pubsub_server: MyApp.PubSub
  """

  @doc """
  Logs a message to the ObanChore dashboard for the given job.
  """
  def log(%Oban.Job{id: job_id}, message) do
    if pubsub = pubsub_server() do
      Phoenix.PubSub.broadcast(
        pubsub,
        "oban_chore:logs:#{job_id}",
        {:oban_chore_log, job_id, message}
      )
    end

    :ok
  end

  @doc """
  Counts the number of running (available, scheduled, executing) jobs for a given worker module.
  """
  def count_running(worker_module, oban_name \\ Oban) do
    config = Oban.config(oban_name)
    repo = config.repo

    [state: ~w(available scheduled executing), worker: worker_module]
    |> Oban.Job.query()
    |> repo.aggregate(:count, :id)
  end

  @doc """
  Checks if a job for the given worker and arguments is already running (available, scheduled, executing).
  """
  def running_with_args?(worker_module, args, oban_name \\ Oban) do
    config = Oban.config(oban_name)
    repo = config.repo

    [state: ~w(available scheduled executing), worker: worker_module, args: args]
    |> Oban.Job.query()
    |> repo.exists?()
  end

  @doc """
  Lists the active (available, scheduled, executing) jobs for a given worker module.
  """
  def list_active_jobs(worker_module, oban_name \\ Oban) do
    config = Oban.config(oban_name)
    repo = config.repo

    [state: ~w(available scheduled executing), worker: worker_module]
    |> Oban.Job.query()
    |> repo.all()
    |> Enum.map(fn job -> %{job | state: String.to_existing_atom(job.state)} end)
  end

  @doc false
  def pubsub_server do
    Application.get_env(:oban_chore, :pubsub_server)
  end
end
