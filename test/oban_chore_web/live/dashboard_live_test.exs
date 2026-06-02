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
      chores: [DashboardTestChore], pubsub_server: ObanChore.EndpointPubSub
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
    html = view |> element("button", "Dashboard Test Chore") |> render_click()
    assert html =~ "A test chore for the dashboard live view"
    assert html =~ "username"

    # Fill and submit form
    view |> form("form", args: %{username: "john_doe", admin: "true"}) |> render_submit()
    html = render(view)
    assert html =~ "Job #"

    # Assert that the job was actually inserted in the database
    assert [job] = ObanChore.TestRepo.all(Oban.Job)
    assert job.worker == "ObanChoreWeb.DashboardLiveTest.DashboardTestChore"
    assert job.args == %{"username" => "john_doe", "admin" => true}
  end
end
