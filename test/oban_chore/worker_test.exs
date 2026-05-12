defmodule ObanChore.WorkerTest do
  use ExUnit.Case, async: true
  import Ecto.Changeset

  defmodule MyTestChore do
    use ObanChore.Worker,
      name: "My Test Chore",
      queue: :default,
      fields: [
        user_id: [type: :integer, required: true],
        age: [type: :integer]
      ]

    @impl ObanChore.Worker
    def custom_changeset(changeset) do
      validate_number(changeset, :age, greater_than: 18)
    end

    @impl Oban.Worker
    def perform(%Oban.Job{}), do: :ok
  end

  test "injects changeset/1 and custom_changeset/1" do
    # Valid data
    changeset = MyTestChore.changeset(%{"user_id" => "1", "age" => "25"})
    assert changeset.valid?
    assert changeset.changes.user_id == 1
    assert changeset.changes.age == 25

    # Missing required field
    changeset = MyTestChore.changeset(%{"age" => "25"})
    refute changeset.valid?
    assert "can't be blank" in errors_on(changeset).user_id

    # Custom validation failure
    changeset = MyTestChore.changeset(%{"user_id" => "1", "age" => "15"})
    refute changeset.valid?
    assert "must be greater than 18" in errors_on(changeset).age
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
