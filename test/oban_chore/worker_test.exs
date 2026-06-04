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

  defmodule UniqueChore do
    use ObanChore.Worker,
      name: "Unique Chore",
      fields: [],
      unique: [period: 60]

    @impl Oban.Worker
    def perform(_), do: :ok
  end

  defmodule ComprehensiveWorker do
    use ObanChore.Worker,
      name: "All Types Chore",
      fields: [
        # Native types
        my_string: [type: :string],
        my_int: [type: :integer],
        my_bool: [type: :boolean],
        # Mapped types
        my_text: [type: :textarea],
        my_select: [type: :select, options: ["Option 1", "Option 2"]],
        my_checkbox: [type: :checkbox]
      ]

    @impl Oban.Worker
    def perform(_), do: :ok
  end

  defmodule DescriptiveWorker do
    use ObanChore.Worker,
      name: "Descriptive Chore",
      description: "This chore has a helpful description.",
      fields: []

    @impl Oban.Worker
    def perform(_), do: :ok
  end

  test "captures description in __chore_info__" do
    info = DescriptiveWorker.__chore_info__()
    assert info.description == "This chore has a helpful description."

    # Verify fallback for workers without description
    info = MyTestChore.__chore_info__()
    assert info.description == nil
  end

  test "captures uniqueness in __chore_info__" do
    info = UniqueChore.__chore_info__()
    assert info.unique == true

    info = MyTestChore.__chore_info__()
    assert info.unique == false
  end

  test "correctly maps UI types to Ecto types and casts them" do
    params = %{
      "my_string" => "hello",
      "my_int" => "42",
      "my_bool" => "true",
      "my_text" => "some long text",
      "my_select" => "option1",
      "my_checkbox" => "true"
    }

    changeset = ComprehensiveWorker.changeset(params)
    assert changeset.valid?

    # Verify values and their types
    assert changeset.changes.my_string == "hello"
    assert changeset.changes.my_int == 42
    assert changeset.changes.my_bool == true
    assert changeset.changes.my_text == "some long text"
    assert changeset.changes.my_select == "option1"
    assert changeset.changes.my_checkbox == true
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

  test "raises on missing field type" do
    assert_raise ArgumentError, ~r/missing :type for field :bad_field/, fn ->
      defmodule MissingTypeChore do
        use ObanChore.Worker,
          name: "Missing Type",
          fields: [bad_field: []]
      end
    end
  end

  test "raises on invalid field type" do
    assert_raise ArgumentError, ~r/invalid type :invalid_type/, fn ->
      defmodule InvalidChore do
        use ObanChore.Worker,
          name: "Invalid",
          fields: [bad_field: [type: :invalid_type]]
      end
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
