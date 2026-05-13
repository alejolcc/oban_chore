defmodule ObanChore do
  @moduledoc """
  ObanChore transforms standard Oban workers into secure, UI-driven operational tools.

  ## Configuration

  To use ObanChore, you must add `ObanChore.Plugin` to your Oban configuration:

      config :my_app, Oban,
        repo: MyApp.Repo,
        plugins: [
          ObanChore.Plugin,
          # ...
        ],
        queues: [default: 10]

  ### Real-time Logging (Optional)

  To enable real-time execution logs in the dashboard, configure your PubSub server:

      config :oban_chore, pubsub_server: MyApp.PubSub
  """

  @doc """
  Hello world.

  ## Examples

      iex> ObanChore.hello()
      :world

  """
  def hello do
    :world
  end

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

  @doc false
  def pubsub_server do
    Application.get_env(:oban_chore, :pubsub_server)
  end
end
