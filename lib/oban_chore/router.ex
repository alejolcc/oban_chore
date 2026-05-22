defmodule ObanChore.Router do
  @moduledoc """
  Provides a macro to mount the ObanChore dashboard in your application's router.

  ## Example

  ```elixir
  defmodule MyAppWeb.Router do
    use MyAppWeb, :router
    import ObanChore.Router

    scope "/" do
      pipe_through :browser
      oban_chore_dashboard "/ops/chores"
    end
  end
  ```
  """

  defmacro oban_chore_dashboard(path, _opts \\ []) do
    quote do
      scope unquote(path), alias: false, as: false do
        import Phoenix.LiveView.Router

        live_session :oban_chore_dashboard,
          layout: {ObanChoreWeb.Layouts, :dashboard} do
          live("/", ObanChoreWeb.DashboardLive, :index)
        end
      end
    end
  end
end
