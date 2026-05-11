defmodule ObanChore.Worker do
  @moduledoc """
  A macro that wraps `Oban.Worker` to provide metadata for UI generation.

  ## Example

      defmodule MyApp.Chores.UserBackfill do
        use ObanChore.Worker,
          name: "User Data Backfill",
          fields: [
            user_id: [type: :integer, required: true],
            reason: [type: :string, default: "Manual Update"]
          ]

        @impl Oban.Worker
        def perform(%Oban.Job{args: args}) do
          # ...
        end
      end
  """

  defmacro __using__(opts) do
    # Extract ObanChore specific options
    {chore_name, opts} = Keyword.pop(opts, :name)
    {chore_fields, opts} = Keyword.pop(opts, :fields, [])

    quote do
      use Oban.Worker, unquote(opts)

      # Ensure the module provides the __chore_info__/0 function
      @doc false
      def __chore_info__ do
        %{
          name: unquote(chore_name) || inspect(__MODULE__),
          fields: unquote(chore_fields)
        }
      end
    end
  end
end
