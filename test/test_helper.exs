ExUnit.start()

# Define a mock error view to handle error rendering in tests
defmodule ObanChore.TestErrorView do
  def render(template, _assigns) do
    "Error: #{template}"
  end
end

# Ensure database exists and is migrated
_ = Ecto.Adapters.Postgres.storage_up(ObanChore.TestRepo.config())
{:ok, _} = ObanChore.TestRepo.start_link()
Ecto.Migrator.up(ObanChore.TestRepo, 1, Oban.Migration)
Ecto.Adapters.SQL.Sandbox.mode(ObanChore.TestRepo, :manual)

# Start the dedicated PubSub and Endpoint
{:ok, _} = Supervisor.start_link([
  {Phoenix.PubSub, name: ObanChore.EndpointPubSub},
  ObanChore.TestEndpoint
], strategy: :one_for_one)
