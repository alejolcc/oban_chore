defmodule ObanChore.StatusTest do
  use ExUnit.Case, async: false

  setup do
    # Ensure PubSub is configured for the test
    Application.put_env(:oban_chore, :pubsub_server, ObanChore.TestPubSub)

    # Start a dummy PubSub for testing if not already started
    # In a real project, this would be in test_helper.exs or supervised
    start_supervised!({Phoenix.PubSub, name: ObanChore.TestPubSub})

    :ok
  end

  test "telemetry broadcasts job state changes" do
    job_id = 456
    # Use the same worker string format as in the plugin matching
    worker_str = "ObanChore.StatusTest.TestWorker"
    job = %Oban.Job{id: job_id, worker: worker_str, state: "executing"}

    Phoenix.PubSub.subscribe(ObanChore.TestPubSub, "oban_chore:status:#{job_id}")

    # Simulate Oban telemetry event
    # The plugin expects chores in its state to match against.
    chores = [%{module: ObanChore.StatusTest.TestWorker, name: "Test Worker"}]

    metadata = %{
      conf: %{name: Oban},
      job: job
    }

    # Manually call the telemetry handler
    ObanChore.Plugin.handle_telemetry(
      [:oban, :job, :start],
      %{},
      metadata,
      %{
        oban_name: Oban,
        pubsub_server: ObanChore.TestPubSub,
        chores: chores
      }
    )

    assert_receive {:oban_chore_state, ^job_id, :executing}
  end
end
