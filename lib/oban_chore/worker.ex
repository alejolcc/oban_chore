defmodule ObanChore.Worker do
  @moduledoc """
  A macro that wraps `Oban.Worker` to provide the DSL for defining chore inputs.

  When you `use ObanChore.Worker`, it automatically includes `Oban.Worker` and sets up
  the metadata required for the dashboard to render forms and track execution.

  ## Options

    * `:name` - (Optional) A human-readable name for the chore. Defaults to the module name.
    * `:description` - (Optional) A brief description of what the chore does.
    * `:fields` - (Required) A keyword list defining the input fields for the chore.

  Since `ObanChore.Worker` is a wrapper around `Oban.Worker`, you can also pass any standard
  Oban option (like `:queue`, `:unique`, `:max_attempts`, etc.). These options are passed
  directly to the underlying `Oban.Worker`.

  ## Field Options

    * `:type` - (Required) The data type of the field. Supported types:
      - Ecto types: `:integer`, `:float`, `:boolean`, `:string`, `:date`, `:time`, `:utc_datetime`.
      - UI-specific types: `:textarea`, `:select` (uses `:string` in changeset), `:checkbox` (uses `:boolean`).
    * `:label` - (Optional) The label to display in the UI.
    * `:default` - (Optional) Default value for the field.
    * `:required` - (Optional) Whether the field is required.
    * `:options` - (Required for `:select`) A list of options for the select input.

  ## Example

  ```elixir
  defmodule MyApp.Chores.UserBackfill do
    use ObanChore.Worker,
      name: "User Data Backfill",
      description: "Backfills historical data for a specific user.",
      fields: [
        user_id: [type: :integer, required: true, label: "Target User ID"],
        reason: [type: :string, default: "Manual correction", label: "Reason for backfill"]
      ],
      queue: :default,
      unique: [period: :infinity]

    @impl Oban.Worker
    def perform(%Oban.Job{args: args}) do
      # Your execution logic here
      :ok
    end

    # You can optionally override custom_changeset/1 for advanced validation
    @impl true
    def custom_changeset(changeset) do
      validate_number(changeset, :user_id, greater_than: 0)
    end
  end
  ```
  """

  @doc """
  A callback to add custom validations to the chore's arguments changeset.
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
          unique: unquote(has_unique),
          tags: Keyword.get(__opts__(), :tags, [])
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
