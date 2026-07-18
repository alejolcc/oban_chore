defmodule ObanChore.QueriesTest do
  use ExUnit.Case, async: false

  # Define a mock Repo to capture and inspect Ecto queries
  defmodule MockRepo do
    def aggregate(query, :count, :id, opts \\ []) do
      send(self(), {:repo_aggregate, query, opts})
      0
    end

    def exists?(query, opts \\ []) do
      send(self(), {:repo_exists, query, opts})
      false
    end

    def all(query, opts \\ []) do
      send(self(), {:repo_all, query, opts})
      []
    end

    def get(query, id, opts \\ []) do
      send(self(), {:repo_get, query, id, opts})
      nil
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

    assert_receive {:repo_aggregate, query, _opts}
    assert query.from.source == {"oban_jobs", Oban.Job}

    query_str = inspect(query)
    assert query_str =~ "j0.state in [\"available\", \"scheduled\", \"executing\", \"retryable\"]"
    assert query_str =~ "j0.worker == ^\"SomeWorker\""
  end

  test "running_with_args?/3 generates the correct Ecto query", %{oban_name: oban_name} do
    ObanChore.running_with_args?(SomeWorker, %{user_id: 123}, oban_name)

    assert_receive {:repo_exists, query, _opts}
    assert query.from.source == {"oban_jobs", Oban.Job}

    query_str = inspect(query)
    assert query_str =~ "j0.state in [\"available\", \"scheduled\", \"executing\", \"retryable\"]"
    assert query_str =~ "j0.worker == ^\"SomeWorker\""
    assert query_str =~ "fragment(\"? @> ?\", j0.args, ^"
  end

  test "list_active_jobs/2 generates the correct Ecto query", %{oban_name: oban_name} do
    ObanChore.list_active_jobs(SomeWorker, oban_name)

    assert_receive {:repo_all, query, _opts}
    assert query.from.source == {"oban_jobs", Oban.Job}

    query_str = inspect(query)
    assert query_str =~ "j0.state in [\"available\", \"scheduled\", \"executing\", \"retryable\"]"
    assert query_str =~ "j0.worker == ^\"SomeWorker\""
  end

  test "list_previous_runs/3 generates the correct Ecto query", %{oban_name: oban_name} do
    ObanChore.list_previous_runs(SomeWorker, oban_name)

    assert_receive {:repo_all, query, _opts}
    assert query.from.source == {"oban_jobs", Oban.Job}

    query_str = inspect(query)
    assert query_str =~ "j0.state in [\"completed\", \"discarded\", \"retryable\", \"cancelled\"]"
    assert query_str =~ "j0.worker == ^\"SomeWorker\""
    assert query_str =~ "order_by: [desc: j0.id]"
    assert query_str =~ "limit: ^20"
  end

  test "get_job/2 generates the correct Ecto query", %{oban_name: oban_name} do
    ObanChore.get_job(123, oban_name)

    assert_receive {:repo_get, query, 123, _opts}
    assert query == Oban.Job
  end

  test "passes prefix option to all query operations when configured" do
    oban_name = ObanChore.TestObanPrefix

    start_supervised!(
      {Oban,
       name: oban_name,
       repo: MockRepo,
       prefix: "custom_prefix",
       queues: [],
       notifier: Oban.Notifiers.Isolated,
       peer: Oban.Peers.Isolated}
    )

    # 1. count_running
    ObanChore.count_running(SomeWorker, oban_name)
    assert_receive {:repo_aggregate, _query, opts1}
    assert Keyword.get(opts1, :prefix) == "custom_prefix"

    # 2. running_with_args?
    ObanChore.running_with_args?(SomeWorker, %{user_id: 123}, oban_name)
    assert_receive {:repo_exists, _query, opts2}
    assert Keyword.get(opts2, :prefix) == "custom_prefix"

    # 3. list_active_jobs
    ObanChore.list_active_jobs(SomeWorker, oban_name)
    assert_receive {:repo_all, _query, opts3}
    assert Keyword.get(opts3, :prefix) == "custom_prefix"

    # 4. list_previous_runs
    ObanChore.list_previous_runs(SomeWorker, oban_name)
    assert_receive {:repo_all, _query, opts4}
    assert Keyword.get(opts4, :prefix) == "custom_prefix"

    # 5. get_job
    ObanChore.get_job(123, oban_name)
    assert_receive {:repo_get, _query, 123, opts5}
    assert Keyword.get(opts5, :prefix) == "custom_prefix"
  end
end
