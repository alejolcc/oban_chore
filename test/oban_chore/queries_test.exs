defmodule ObanChore.QueriesTest do
  use ExUnit.Case, async: false

  # Define a mock Repo to capture and inspect Ecto queries
  defmodule MockRepo do
    def aggregate(query, :count, :id) do
      send(self(), {:repo_aggregate, query})
      0
    end

    def exists?(query) do
      send(self(), {:repo_exists, query})
      false
    end

    def all(query) do
      send(self(), {:repo_all, query})
      []
    end

    # Minimal callbacks for Oban start_link / validation
    def __adapter__ do
      Ecto.Adapters.Postgres
    end

    def config do
      [priv: "priv", otp_app: :oban_chore]
    end
  end

  setup do
    # Start a minimal Oban instance using our MockRepo
    # We use a unique name to avoid conflicts with other tests
    oban_name = ObanChore.TestOban

    start_supervised!(
      {Oban,
       name: oban_name,
       repo: MockRepo,
       queues: [],
       notifier: Oban.Notifiers.Isolated,
       peer: Oban.Peers.Isolated}
    )

    {:ok, oban_name: oban_name}
  end

  test "count_running/2 generates the correct Ecto query", %{oban_name: oban_name} do
    ObanChore.count_running(SomeWorker, oban_name)

    assert_receive {:repo_aggregate, query}
    assert query.from.source == {"oban_jobs", Oban.Job}

    query_str = inspect(query)
    assert query_str =~ "j0.state in [\"available\", \"scheduled\", \"executing\"]"
    assert query_str =~ "j0.worker == ^\"SomeWorker\""
  end

  test "running_with_args?/3 generates the correct Ecto query", %{oban_name: oban_name} do
    ObanChore.running_with_args?(SomeWorker, %{user_id: 123}, oban_name)

    assert_receive {:repo_exists, query}
    assert query.from.source == {"oban_jobs", Oban.Job}

    query_str = inspect(query)
    assert query_str =~ "j0.state in [\"available\", \"scheduled\", \"executing\"]"
    assert query_str =~ "j0.worker == ^\"SomeWorker\""
    assert query_str =~ "fragment(\"? @> ?\", j0.args, ^"
  end

  test "list_active_jobs/2 generates the correct Ecto query", %{oban_name: oban_name} do
    ObanChore.list_active_jobs(SomeWorker, oban_name)

    assert_receive {:repo_all, query}
    assert query.from.source == {"oban_jobs", Oban.Job}

    query_str = inspect(query)
    assert query_str =~ "j0.state in [\"available\", \"scheduled\", \"executing\"]"
    assert query_str =~ "j0.worker == ^\"SomeWorker\""
  end
end
