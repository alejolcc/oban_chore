defmodule ObanChore.LoggingTest do
  use ExUnit.Case, async: false

  setup do
    pubsub = ObanChore.TestPubSub
    start_supervised!({Phoenix.PubSub, name: pubsub})
    Application.put_env(:oban_chore, :pubsub_server, pubsub)
    on_exit(fn -> Application.delete_env(:oban_chore, :pubsub_server) end)
    {:ok, pubsub: pubsub}
  end

  test "log/2 broadcasts to the correct topic", %{pubsub: pubsub} do
    job = %Oban.Job{id: 123}
    topic = "oban_chore:logs:123"

    Phoenix.PubSub.subscribe(pubsub, topic)

    ObanChore.log(job, "Hello from the worker!")

    assert_receive {:oban_chore_log, 123, "Hello from the worker!"}
  end

  test "log/2 accumulates logs in the process dictionary" do
    Process.delete(:oban_chore_logs)
    job = %Oban.Job{id: 456}

    ObanChore.log(job, "First log")
    ObanChore.log(job, "Second log")

    assert Process.get(:oban_chore_logs) == ["Second log", "First log"]
  end

  test "log/2 caps process dictionary logs at 500 lines using a rolling buffer" do
    Process.delete(:oban_chore_logs)
    job = %Oban.Job{id: 789}

    for i <- 1..510 do
      ObanChore.log(job, "Log #{i}")
    end

    logs = Process.get(:oban_chore_logs)
    assert length(logs) == 500
    assert hd(logs) == "Log 510"
    assert List.last(logs) == "Log 11"
  end
end
