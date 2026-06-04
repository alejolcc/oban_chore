defmodule ObanChoreWeb.DashboardLiveTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint ObanChore.TestEndpoint

  defmodule DashboardTestChore do
    use ObanChore.Worker,
      name: "Dashboard Test Chore",
      description: "A test chore for the dashboard live view",
      fields: [
        username: [type: :string, required: true],
        admin: [type: :boolean, default: false]
      ]

    @impl Oban.Worker
    def perform(_), do: :ok
  end

  defmodule DashboardUniqueChore do
    use ObanChore.Worker,
      name: "Dashboard Unique Chore",
      description: "A test chore with unique constraint",
      fields: [
        username: [type: :string, required: true]
      ],
      unique: [period: :infinity]

    @impl Oban.Worker
    def perform(_), do: :ok
  end

  setup do
    # Set the pubsub server application environment required by ObanChore
    # to the endpoint's running PubSub instance.
    Application.put_env(:oban_chore, :pubsub_server, ObanChore.EndpointPubSub)

    # Checkout connection for Ecto sandbox
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(ObanChore.TestRepo)

    # Start Oban
    start_supervised!({
      Oban,
      name: Oban,
      repo: ObanChore.TestRepo,
      queues: [default: 5],
      notifier: Oban.Notifiers.Isolated,
      peer: Oban.Peers.Isolated,
      plugins: [],
      testing: :manual
    })

    # Start the ObanChore.Plugin with our test chore
    start_supervised!({
      ObanChore.Plugin,
      chores: [DashboardTestChore, DashboardUniqueChore], pubsub_server: ObanChore.EndpointPubSub
    })

    # Synchronize with the Plugin's handle_continue
    _ = :sys.get_state(ObanChore.Plugin)

    :ok
  end

  test "renders the dashboard and displays the header" do
    conn = build_conn()
    {:ok, view, html} = live(conn, "/ops/chores")

    assert html =~ "ObanChore"
    assert html =~ "Available Chores"
    assert html =~ "No chore selected"
    assert html =~ "Dashboard Test Chore"

    # Click the chore in the sidebar
    chore_module = to_string(DashboardTestChore)

    html =
      view
      |> element("button[data-role=chore-select][data-chore-module=\"#{chore_module}\"]")
      |> render_click()

    assert html =~ "A test chore for the dashboard live view"
    assert html =~ "username"

    # Assert header title
    assert has_element?(element(view, ~s(h2[data-role="chore-title"])))

    # Assert duplicate warning banner is not shown for the initial execution
    refute has_element?(element(view, "[data-role=duplicate-warning-banner]"))

    # Fill and submit form
    view
    |> form("[id=\"form-#{chore_module}\"]", args: %{username: "john_doe", admin: "true"})
    |> render_submit()

    # Assert that the job was actually inserted in the database
    assert [job] = ObanChore.TestRepo.all(Oban.Job)
    assert job.worker == "ObanChoreWeb.DashboardLiveTest.DashboardTestChore"
    assert job.args == %{"username" => "john_doe", "admin" => true}

    # Assert tab presence
    assert has_element?(element(view, ~s(button[data-role="job-tab"][data-job-id="#{job.id}"])))

    # Assert job details
    assert has_element?(element(view, ~s(div[data-role="job-details"][data-job-id="#{job.id}"])))
  end

  test "enforces and toggles job uniqueness" do
    conn = build_conn()
    {:ok, view, _html} = live(conn, "/ops/chores")

    # Select the chore
    chore_module = to_string(DashboardTestChore)

    view
    |> element("button[data-role=chore-select][data-chore-module=\"#{chore_module}\"]")
    |> render_click()

    # Fill and submit first execution
    view
    |> form("[id=\"form-#{chore_module}\"]", args: %{username: "john_doe", admin: "true"})
    |> render_submit()

    render(view)

    # 1. Assert that the first job is inserted
    assert [job1] = ObanChore.TestRepo.all(Oban.Job)
    assert job1.worker == "ObanChoreWeb.DashboardLiveTest.DashboardTestChore"
    assert job1.args == %{"username" => "john_doe", "admin" => true}

    # Verify duplicate warning banner is not shown for initial execution
    refute has_element?(element(view, "[data-role=duplicate-warning-banner]"))

    # 2. Select New Execution tab to run a duplicate job (unique execution active by default)
    view |> element("button[phx-value-tab=new]") |> render_click()

    # Submit the form with the same arguments
    view
    |> form("[id=\"form-#{chore_module}\"]", args: %{username: "john_doe", admin: "true"})
    |> render_submit()

    # Assert duplicate warning banner is shown and job is NOT inserted yet
    assert has_element?(element(view, "[data-role=duplicate-warning-banner]"))
    assert [job_before_confirm] = ObanChore.TestRepo.all(Oban.Job)
    assert job_before_confirm.id == job1.id

    # Confirm the duplicate execution
    view
    |> element("[data-role=duplicate-warning-banner] button.oc-btn-warning")
    |> render_click()

    # Assert duplicate warning banner is gone after confirmation
    refute has_element?(element(view, "[data-role=duplicate-warning-banner]"))

    # Because unique execution was active, even after confirmation, no new job is inserted (Oban unique conflict handles it)
    assert [job_after_unique] = ObanChore.TestRepo.all(Oban.Job)
    assert job_after_unique.id == job1.id
    assert ObanChore.TestRepo.aggregate(Oban.Job, :count) == 1

    # 3. Select New Execution tab again to disable unique execution and trigger another duplicate
    view |> element("button[phx-value-tab=new]") |> render_click()

    # Uncheck the "Unique per args" checkbox
    view
    |> element("input[id=\"unique-Elixir.ObanChoreWeb.DashboardLiveTest.DashboardTestChore\"]")
    |> render_click()

    # Submit the duplicate arguments again
    view
    |> form("[id=\"form-#{chore_module}\"]", args: %{username: "john_doe", admin: "true"})
    |> render_submit()

    # Assert duplicate warning banner is shown again and job is NOT inserted yet
    assert has_element?(element(view, "[data-role=duplicate-warning-banner]"))
    assert render(view) =~ "Duplicate Execution Warning"
    assert ObanChore.TestRepo.aggregate(Oban.Job, :count) == 1

    # Confirm the duplicate execution
    view
    |> element("[data-role=duplicate-warning-banner] button.oc-btn-warning")
    |> render_click()

    # Assert duplicate warning banner is gone after confirmation
    refute has_element?(element(view, "[data-role=duplicate-warning-banner]"))

    # Because unique execution was disabled, after confirmation a new duplicate job is successfully inserted!
    assert jobs = ObanChore.TestRepo.all(Oban.Job)
    assert length(jobs) == 2
    assert Enum.all?(jobs, fn job -> job.args == %{"username" => "john_doe", "admin" => true} end)
  end

  test "respects job unique configuration and disables toggle" do
    conn = build_conn()
    {:ok, view, _html} = live(conn, "/ops/chores")

    # Select the unique chore
    chore_module = to_string(DashboardUniqueChore)

    view
    |> element("button[data-role=chore-select][data-chore-module=\"#{chore_module}\"]")
    |> render_click()

    # Verify unique toggle exists and is disabled
    toggle_selector =
      "input[id=\"unique-Elixir.ObanChoreWeb.DashboardLiveTest.DashboardUniqueChore\"]"

    assert has_element?(element(view, toggle_selector))
    assert render(view) =~ "disabled"

    # Fill and submit first execution
    view
    |> form("[id=\"form-#{chore_module}\"]", args: %{username: "jane_doe"})
    |> render_submit()

    # 1. Assert that the first job is inserted
    assert [job1] = ObanChore.TestRepo.all(Oban.Job)
    assert job1.worker == "ObanChoreWeb.DashboardLiveTest.DashboardUniqueChore"
    assert job1.args == %{"username" => "jane_doe"}

    # 2. Select New Execution tab to try to run a duplicate
    view |> element("button[phx-value-tab=new]") |> render_click()

    # Submit the form with the same arguments
    view
    |> form("[id=\"form-#{chore_module}\"]", args: %{username: "jane_doe"})
    |> render_submit()

    # Assert duplicate warning banner is shown
    assert has_element?(element(view, "[data-role=duplicate-warning-banner]"))
    assert ObanChore.TestRepo.aggregate(Oban.Job, :count) == 1

    # Confirm the duplicate execution (will fail to create a new job due to Oban's DB-level unique constraint)
    view
    |> element("[data-role=duplicate-warning-banner] button.oc-btn-warning")
    |> render_click()

    # Assert that no new job was created since it's unique
    assert ObanChore.TestRepo.aggregate(Oban.Job, :count) == 1
  end
end
