defmodule ObanChore.LoggingTest do
  use ExUnit.Case, async: true

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
end
