defmodule ObanChore.LoggingTest do
  use ExUnit.Case, async: false

  setup do
    pubsub = ObanChore.TestPubSub
    start_supervised!({Phoenix.PubSub, name: pubsub})
    Application.put_env(:oban_chore, :pubsub_server, pubsub)
    on_exit(fn -> Application.delete_env(:oban_chore, :pubsub_server) end)

    case :ets.info(:oban_chore_active_logs) do
      :undefined ->
        :ets.new(:oban_chore_active_logs, [
          :named_table,
          :public,
          :set,
          {:write_concurrency, true},
          {:read_concurrency, true}
        ])

      _ ->
        :ok
    end

    {:ok, pubsub: pubsub}
  end

  test "log/2 broadcasts to the correct topic", %{pubsub: pubsub} do
    job = %Oban.Job{id: 123}
    topic = "oban_chore:logs:123"

    Phoenix.PubSub.subscribe(pubsub, topic)

    ObanChore.log(job, "Hello from the worker!")

    assert_receive {:oban_chore_log, 123, "Hello from the worker!"}
  end

  test "log/2 accumulates logs in the ETS table" do
    job = %Oban.Job{id: 456}
    :ets.delete(:oban_chore_active_logs, job.id)

    ObanChore.log(job, "First log")
    ObanChore.log(job, "Second log")

    assert [{456, logs}] = :ets.lookup(:oban_chore_active_logs, job.id)
    assert logs == ["Second log", "First log"]
  end

  test "log/2 caps active logs at 500 lines using a rolling buffer in ETS" do
    job = %Oban.Job{id: 789}
    :ets.delete(:oban_chore_active_logs, job.id)

    for i <- 1..510 do
      ObanChore.log(job, "Log #{i}")
    end

    assert [{789, logs}] = :ets.lookup(:oban_chore_active_logs, job.id)
    assert length(logs) == 500
    assert hd(logs) == "Log 510"
    assert List.last(logs) == "Log 11"
  end
end
