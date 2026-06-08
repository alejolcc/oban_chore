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

  defmacro oban_chore_dashboard(path, opts \\ []) do
    quote do
      scope unquote(path), alias: false, as: false do
        import Phoenix.LiveView.Router

        live("/", ObanChoreWeb.DashboardLive, :index, metadata: %{oban_chore_opts: unquote(opts)})
      end
    end
  end
end
