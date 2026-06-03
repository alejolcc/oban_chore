defmodule ObanChore.TestRepo do
  use Ecto.Repo,
    otp_app: :oban_chore,
    adapter: Ecto.Adapters.Postgres
end
