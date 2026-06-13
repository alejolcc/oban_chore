defmodule ObanChore do
  import Ecto.Query

  @moduledoc """
  ObanChore transforms standard Oban workers into secure, UI-driven operational tools.

  It eliminates the need for manual IEx interaction by providing a dashboard to trigger
  and monitor background jobs with a user-friendly interface.

  ## Quick Start

  Getting started with ObanChore takes just a few steps:

  1. **Install the dependency** in your `mix.exs`:
     ```elixir
     {:oban_chore, "~> 0.3"}
     ```

  2. **Configure the Plugin** in your Oban settings:
     ```elixir
     config :my_app, Oban,
       repo: MyApp.Repo,
       plugins: [
         {ObanChore.Plugin, otp_app: :my_app, pubsub_server: MyApp.PubSub}
       ]
     ```

  3. **Mount the Dashboard** in your `router.ex`:
     ```elixir
     import ObanChore.Router
     # ...
     oban_chore_dashboard "/ops/chores"
     ```

  4. **Define a Chore** by using `ObanChore.Worker`:
     ```elixir
     defmodule MyApp.Workers.MyChore do
       use ObanChore.Worker,
         name: "My Operational Task",
         fields: [user_id: [type: :integer, required: true]]

       @impl Oban.Worker
       def perform(%Oban.Job{args: %{"user_id" => id}}) do
         # logic...
         :ok
       end
     end
     ```

  ## Real-Time Logs

  You can stream logs from your worker directly to the dashboard using `log/2`.
  See the `log/2` documentation below for examples.
  """

  @doc """
  Logs a message to the ObanChore dashboard for a specific job.

  This is intended to be used inside your worker's `perform/1` function to stream
  progress updates or important information back to the UI in real-time.

  ## Examples

  ```elixir
  def perform(%Oban.Job{} = job) do
    ObanChore.log(job, "Initializing backfill...")
    # ... logic ...
    ObanChore.log(job, "Successfully processed users.")
    :ok
  end
  ```
  """
  def log(%Oban.Job{id: job_id}, message) do
    Phoenix.PubSub.broadcast(
      pubsub_server(),
      "oban_chore:logs:#{job_id}",
      {:oban_chore_log, job_id, message}
    )

    :ok
  end

  @doc """
  Counts the number of active jobs (available, scheduled, or executing) for a given worker module.
  """
  def count_running(worker_module, oban_name \\ Oban) do
    config = Oban.config(oban_name)
    repo = config.repo

    Oban.Job
    |> where([j], j.state in ~w(available scheduled executing))
    |> where([j], j.worker == ^normalize_worker(worker_module))
    |> repo.aggregate(:count, :id)
  end

  @doc """
  Checks if a job with the specified arguments is already in an active state.

  Active states include `available`, `scheduled`, and `executing`.
  """
  def running_with_args?(worker_module, args, oban_name \\ Oban) do
    config = Oban.config(oban_name)
    repo = config.repo

    string_args = Map.new(args, fn {k, v} -> {to_string(k), v} end)

    Oban.Job
    |> where([j], j.state in ~w(available scheduled executing))
    |> where([j], j.worker == ^normalize_worker(worker_module))
    |> where([j], fragment("? @> ?", j.args, ^string_args))
    |> repo.exists?()
  end

  @doc """
  Lists the active (available, scheduled, executing) jobs for a given worker module.

  Returns a list of `%Oban.Job{}` structs with the state converted to an atom.
  """
  def list_active_jobs(worker_module, oban_name \\ Oban) do
    config = Oban.config(oban_name)
    repo = config.repo

    Oban.Job
    |> where([j], j.state in ~w(available scheduled executing))
    |> where([j], j.worker == ^normalize_worker(worker_module))
    |> repo.all()
    |> Enum.map(fn job -> %{job | state: String.to_existing_atom(job.state)} end)
  end

  @doc """
  Lists the previous (completed, discarded, retryable, cancelled) jobs for a given worker module.

  Returns a list of `%Oban.Job{}` structs, ordered by `id` descending, with the state converted to an atom.
  """
  def list_previous_runs(
        worker_module,
        oban_name \\ Oban,
        limit \\ 20,
        sort_by \\ :id,
        sort_dir \\ :desc
      ) do
    config = Oban.config(oban_name)
    repo = config.repo

    query =
      Oban.Job
      |> where([j], j.state in ~w(completed discarded retryable cancelled))
      |> where([j], j.worker == ^normalize_worker(worker_module))
      |> limit(^limit)

    query =
      case sort_by do
        :id ->
          order_by(query, [j], [{^sort_dir, j.id}])

        :state ->
          order_by(query, [j], [{^sort_dir, j.state}])

        :timestamp ->
          order_by(query, [j], [
            {^sort_dir,
             fragment(
               "coalesce(?, ?, ?, ?, ?)",
               j.completed_at,
               j.discarded_at,
               j.cancelled_at,
               j.attempted_at,
               j.inserted_at
             )}
          ])

        :started_at ->
          order_by(query, [j], [{^sort_dir, j.attempted_at}])
      end

    query
    |> repo.all()
    |> Enum.map(fn job -> %{job | state: String.to_existing_atom(job.state)} end)
  end

  @doc """
  Gets a job by ID.
  """
  def get_job(job_id, oban_name \\ Oban) do
    config = Oban.config(oban_name)
    repo = config.repo

    case repo.get(Oban.Job, job_id) do
      nil -> nil
      job -> %{job | state: String.to_existing_atom(job.state)}
    end
  end

  @doc false
  def pubsub_server do
    Application.fetch_env!(:oban_chore, :pubsub_server)
  end

  defp normalize_worker(worker_module) do
    worker_module
    |> to_string()
    |> String.trim_leading("Elixir.")
  end
end
