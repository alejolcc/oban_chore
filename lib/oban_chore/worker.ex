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

  @callback custom_changeset(Ecto.Changeset.t()) :: Ecto.Changeset.t()

  defp accepted_types do
    [
      :integer,
      :float,
      :boolean,
      :string,
      :date,
      :time,
      :utc_datetime,
      :textarea,
      :select,
      :checkbox
    ]
  end

  defmacro __using__(opts) do
    # Extract ObanChore specific options
    {chore_name, opts} = Keyword.pop(opts, :name)
    {chore_description, opts} = Keyword.pop(opts, :description)
    {chore_fields, opts} = Keyword.pop(opts, :fields, [])

    # Default chore name to module name if not provided
    name_ast =
      if chore_name do
        chore_name
      else
        quote do: inspect(__MODULE__)
      end

    for {name, field_opts} <- chore_fields do
      type = Keyword.get(field_opts, :type)

      if is_nil(type) do
        raise ArgumentError,
              "missing :type for field #{inspect(name)}. " <>
                "All fields must explicitly define a type (e.g., type: :string, type: :integer)."
      end

      unless type in accepted_types() do
        raise ArgumentError,
              "invalid type #{inspect(type)} for field #{inspect(name)}. " <>
                "Supported types are :textarea, :select, :checkbox or any Ecto base type."
      end
    end

    # Determine if the worker has unique options
    has_unique = Keyword.has_key?(opts, :unique)

    quote do
      @behaviour ObanChore.Worker
      use Oban.Worker, unquote(opts)
      import Ecto.Changeset

      # Ensure the module provides the __chore_info__/0 function
      @doc false
      def __chore_info__ do
        %{
          module: __MODULE__,
          name: unquote(name_ast),
          description: unquote(chore_description),
          fields: unquote(chore_fields),
          unique: unquote(has_unique)
        }
      end

      @doc """
      Builds a changeset for the chore arguments.
      """
      def changeset(params \\ %{}) do
        fields = unquote(chore_fields)

        types =
          Enum.into(fields, %{}, fn {k, opts} ->
            type =
              case Keyword.get(opts, :type) do
                t when t in [:textarea, :select] ->
                  :string

                :checkbox ->
                  :boolean

                other ->
                  other
              end

            {k, type}
          end)

        required = for {k, opts} <- fields, Keyword.get(opts, :required), do: k

        {%{}, types}
        |> cast(params, Map.keys(types))
        |> then(fn changeset ->
          # Only validate required for fields that don't already have errors (like cast errors)
          Enum.reduce(required, changeset, fn field, acc ->
            if Keyword.has_key?(acc.errors, field) do
              acc
            else
              validate_required(acc, [field])
            end
          end)
        end)
        |> custom_changeset()
      end

      @doc """
      A hook to add custom validations to the chore changeset.
      """
      def custom_changeset(changeset), do: changeset

      defoverridable custom_changeset: 1
    end
  end
end
