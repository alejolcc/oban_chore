defmodule ObanChore.RouterTest do
  use ExUnit.Case, async: true

  defmodule Router do
    use Phoenix.Router
    import ObanChore.Router

    scope "/" do
      oban_chore_dashboard "/chores"
    end
  end

  test "oban_chore_dashboard/2 generates routes" do
    # Filter for the route we expect
    route =
      Enum.find(Router.__routes__(), fn route ->
        route.path == "/chores"
      end)

    assert route
    assert route.plug == Phoenix.LiveView.Plug
    {live_view, _action, _opts, _metadata} = route.metadata.phoenix_live_view
    assert live_view == ObanChoreWeb.DashboardLive
  end
end
