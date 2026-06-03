defmodule ObanChore.TestRouter do
  use Phoenix.Router
  import ObanChore.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  scope "/" do
    pipe_through(:browser)
    oban_chore_dashboard("/ops/chores")
  end
end
