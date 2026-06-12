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
      ],
      tags: ["backfill"]

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
    assert ObanChore.TestRepo.aggregate(Oban.Job, :count) == 1

    # 3. Uncheck the "Unique per args" checkbox
    view
    |> element("input[id=\"unique-Elixir.ObanChoreWeb.DashboardLiveTest.DashboardTestChore\"]")
    |> render_click()

    # Assert warning banner is cleared automatically upon unchecking uniqueness
    refute has_element?(element(view, "[data-role=duplicate-warning-banner]"))

    # 4. Submit the duplicate arguments again (unique execution is now false)
    view
    |> form("[id=\"form-#{chore_module}\"]", args: %{username: "john_doe", admin: "true"})
    |> render_submit()

    # Assert duplicate warning banner is not shown and a new duplicate job is successfully inserted!
    refute has_element?(element(view, "[data-role=duplicate-warning-banner]"))
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

    # Assert duplicate warning banner is NOT shown (natively unique jobs don't show the banner)
    refute has_element?(element(view, "[data-role=duplicate-warning-banner]"))

    # Assert that no new job was created since it's unique
    assert ObanChore.TestRepo.aggregate(Oban.Job, :count) == 1
  end

  describe "relative scheduling" do
    test "schedules a chore using presets" do
      conn = build_conn()
      {:ok, view, _html} = live(conn, "/ops/chores")

      # Select the chore
      chore_module = to_string(DashboardTestChore)

      view
      |> element("button[data-role=chore-select][data-chore-module=\"#{chore_module}\"]")
      |> render_click()

      # Schedule with a preset: 5 minutes
      view
      |> form("[id=\"form-#{chore_module}\"]", %{
        "args" => %{username: "john_preset", admin: "false"},
        "schedule_type" => "5_min"
      })
      |> render_submit()

      # Verify job is scheduled in the database
      assert [job_preset] = ObanChore.TestRepo.all(Oban.Job)
      assert job_preset.state == "scheduled"
      assert job_preset.args == %{"username" => "john_preset", "admin" => false}
      # Check that scheduled_at is roughly 5 minutes from now
      diff = DateTime.diff(job_preset.scheduled_at, DateTime.utc_now())
      # within 10 seconds
      assert_in_delta diff, 300, 10
    end

    test "schedules a chore using custom input" do
      conn = build_conn()
      {:ok, view, _html} = live(conn, "/ops/chores")

      # Select the chore
      chore_module = to_string(DashboardTestChore)

      view
      |> element("button[data-role=chore-select][data-chore-module=\"#{chore_module}\"]")
      |> render_click()

      # Change schedule_type to custom
      html =
        view
        |> form("[id=\"form-#{chore_module}\"]", %{
          "args" => %{username: "john_custom", admin: "false"},
          "schedule_type" => "custom"
        })
        |> render_change()

      assert html =~ "custom_delay_minutes"

      # Schedule with custom delay (90 minutes)
      view
      |> form("[id=\"form-#{chore_module}\"]", %{
        "args" => %{username: "john_custom", admin: "false"},
        "schedule_type" => "custom",
        "custom_delay_minutes" => "90"
      })
      |> render_submit()

      # Verify custom job is scheduled correctly
      assert [job_custom] = ObanChore.TestRepo.all(Oban.Job)
      assert job_custom.state == "scheduled"
      assert job_custom.args == %{"username" => "john_custom", "admin" => false}

      diff_custom = DateTime.diff(job_custom.scheduled_at, DateTime.utc_now())
      # within 10 seconds
      assert_in_delta diff_custom, 5400, 10
    end
  end

  describe "auth" do
    test "filters chores by module whitelist" do
      conn = build_conn()
      {:ok, view, _html} = live(conn, "/filtered/chores")

      assert has_element?(view, "button[data-chore-module=\"#{to_string(DashboardTestChore)}\"]")

      refute has_element?(
               view,
               "button[data-chore-module=\"#{to_string(DashboardUniqueChore)}\"]"
             )

      # Verify websocket selection of filtered-out chore is blocked (HTML remains showing no chore selected)
      assert render_click(view, "select_chore", %{"module" => to_string(DashboardUniqueChore)}) =~
               "No chore selected"
    end

    test "filters chores by tags" do
      conn = build_conn()
      {:ok, view, _html} = live(conn, "/tagged/chores")

      assert has_element?(view, "button[data-chore-module=\"#{to_string(DashboardTestChore)}\"]")

      refute has_element?(
               view,
               "button[data-chore-module=\"#{to_string(DashboardUniqueChore)}\"]"
             )

      # Verify websocket selection of filtered-out chore is blocked
      assert render_click(view, "select_chore", %{"module" => to_string(DashboardUniqueChore)}) =~
               "No chore selected"
    end
  end

  describe "runs history" do
    test "displays previous runs in history tab and allows viewing details" do
      # Share the database transaction with the LiveView process
      Ecto.Adapters.SQL.Sandbox.mode(ObanChore.TestRepo, {:shared, self()})

      {:ok, job1} =
        ObanChore.TestRepo.insert(%Oban.Job{
          state: "completed",
          queue: "default",
          worker: "ObanChoreWeb.DashboardLiveTest.DashboardTestChore",
          args: %{"username" => "history_user_1", "admin" => true},
          completed_at: DateTime.utc_now()
        })

      {:ok, job2} =
        ObanChore.TestRepo.insert(%Oban.Job{
          state: "discarded",
          queue: "default",
          worker: "ObanChoreWeb.DashboardLiveTest.DashboardTestChore",
          args: %{"username" => "history_user_2", "admin" => false},
          errors: [
            %{
              "error" => "Chore failed with a mock exception",
              "attempt" => 1,
              "at" => DateTime.to_string(DateTime.utc_now())
            }
          ],
          discarded_at: DateTime.utc_now()
        })

      conn = build_conn()
      {:ok, view, _html} = live(conn, "/ops/chores")

      chore_module = to_string(DashboardTestChore)

      view
      |> element("button[data-role=chore-select][data-chore-module=\"#{chore_module}\"]")
      |> render_click()

      assert has_element?(view, "button[phx-click=select_tab][phx-value-tab=history]")

      html =
        view
        |> element("button[phx-click=select_tab][phx-value-tab=history]")
        |> render_click()

      assert html =~ "#" <> to_string(job1.id)
      assert html =~ "Completed"

      assert html =~ "#" <> to_string(job2.id)
      assert html =~ "Discarded"

      detail_html =
        view
        |> element("button[phx-click=\"view_job_details\"][phx-value-id=\"#{job2.id}\"]")
        |> render_click()

      assert detail_html =~ "Job ##{job2.id}"
      assert detail_html =~ "history_user_2"
      assert detail_html =~ "Error Details"
      assert detail_html =~ "Chore failed with a mock exception"

      close_html =
        view
        |> element("button[phx-click=\"close_tab\"][phx-value-id=\"#{job2.id}\"]")
        |> render_click()

      refute close_html =~ "Job ##{job2.id}"
      assert close_html =~ "username"
    end
  end

  describe "runs history sorting" do
    test "allows sorting previous runs by id, state, started_at, and timestamp" do
      Ecto.Adapters.SQL.Sandbox.mode(ObanChore.TestRepo, {:shared, self()})

      {:ok, job_a} =
        ObanChore.TestRepo.insert(%Oban.Job{
          state: "completed",
          queue: "default",
          worker: "ObanChoreWeb.DashboardLiveTest.DashboardTestChore",
          args: %{"username" => "user_a"},
          completed_at: DateTime.from_naive!(~N[2026-06-12 10:00:00.000000], "Etc/UTC"),
          attempted_at: DateTime.from_naive!(~N[2026-06-12 09:30:00.000000], "Etc/UTC")
        })

      {:ok, job_b} =
        ObanChore.TestRepo.insert(%Oban.Job{
          state: "discarded",
          queue: "default",
          worker: "ObanChoreWeb.DashboardLiveTest.DashboardTestChore",
          args: %{"username" => "user_b"},
          discarded_at: DateTime.from_naive!(~N[2026-06-12 12:00:00.000000], "Etc/UTC"),
          attempted_at: DateTime.from_naive!(~N[2026-06-12 11:30:00.000000], "Etc/UTC")
        })

      {:ok, job_c} =
        ObanChore.TestRepo.insert(%Oban.Job{
          state: "cancelled",
          queue: "default",
          worker: "ObanChoreWeb.DashboardLiveTest.DashboardTestChore",
          args: %{"username" => "user_c"},
          cancelled_at: DateTime.from_naive!(~N[2026-06-12 11:00:00.000000], "Etc/UTC"),
          attempted_at: DateTime.from_naive!(~N[2026-06-12 10:30:00.000000], "Etc/UTC")
        })

      conn = build_conn()
      {:ok, view, _html} = live(conn, "/ops/chores")

      chore_module = to_string(DashboardTestChore)

      view
      |> element("button[data-role=chore-select][data-chore-module=\"#{chore_module}\"]")
      |> render_click()

      html =
        view
        |> element("button[phx-click=select_tab][phx-value-tab=history]")
        |> render_click()

      assert extract_job_ids(html) == [job_c.id, job_b.id, job_a.id]

      html = view |> element("th[phx-value-column=id]") |> render_click()
      assert extract_job_ids(html) == [job_a.id, job_b.id, job_c.id]

      html = view |> element("th[phx-value-column=state]") |> render_click()
      assert extract_job_ids(html) == [job_b.id, job_a.id, job_c.id]

      html = view |> element("th[phx-value-column=state]") |> render_click()
      assert extract_job_ids(html) == [job_c.id, job_a.id, job_b.id]

      html = view |> element("th[phx-value-column=started_at]") |> render_click()
      assert extract_job_ids(html) == [job_b.id, job_c.id, job_a.id]

      html = view |> element("th[phx-value-column=started_at]") |> render_click()
      assert extract_job_ids(html) == [job_a.id, job_c.id, job_b.id]

      html = view |> element("th[phx-value-column=timestamp]") |> render_click()
      assert extract_job_ids(html) == [job_b.id, job_c.id, job_a.id]

      html = view |> element("th[phx-value-column=timestamp]") |> render_click()
      assert extract_job_ids(html) == [job_a.id, job_c.id, job_b.id]
    end
  end

  defp extract_job_ids(html) do
    Regex.scan(~r/data-job-id="(\d+)"/, html)
    |> Enum.map(fn [_, id] -> String.to_integer(id) end)
  end
end
