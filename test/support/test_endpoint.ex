defmodule ObanChore.TestEndpoint do
  use Phoenix.Endpoint, otp_app: :oban_chore

  @session_options [
    store: :cookie,
    key: "_test_key",
    signing_salt: "super_secret_salt_for_testing_purposes_only"
  ]

  socket("/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]])

  plug(Plug.Session, @session_options)

  plug(ObanChore.TestRouter)
end
