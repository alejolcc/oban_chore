defmodule ObanChore.Router do
  @moduledoc """
  Provides a macro to mount the ObanChore dashboard in your router.
  """

  defmacro oban_chore_dashboard(path, _opts \\ []) do
    quote do
      scope unquote(path), alias: false, as: false do
        import Phoenix.LiveView.Router

        live("/", ObanChoreWeb.DashboardLive, :index)
      end
    end
  end
end
