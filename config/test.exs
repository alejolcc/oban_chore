import Config

config :oban_chore, ObanChore.TestRepo,
  database: System.get_env("DB_DATABASE") || "oban_chore_test",
  username: System.get_env("DB_USERNAME") || "postgres",
  password: System.get_env("DB_PASSWORD") || "postgres",
  hostname: System.get_env("DB_HOSTNAME") || "localhost",
  port: String.to_integer(System.get_env("DB_PORT") || "5432"),
  pool: Ecto.Adapters.SQL.Sandbox,
  json_library: JSON,
  show_sensitive_data_on_connection_error: true

config :oban_chore, ObanChore.TestEndpoint,
  secret_key_base: String.duplicate("a", 64),
  pubsub_server: ObanChore.EndpointPubSub,
  render_errors: [view: ObanChore.TestErrorView, accepts: ~w(html json)],
  live_view: [signing_salt: "super_secret_signing_salt_for_liveview_must_be_long"]
