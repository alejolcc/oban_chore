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
        my_select: [type: :select],
        my_email: [type: :email],
        my_url: [type: :url],
        my_pass: [type: :password],
        my_search: [type: :search],
        my_tel: [type: :tel]
      ]

    @impl Oban.Worker
    def perform(_), do: :ok
  end

  test "correctly maps UI types to Ecto types and casts them" do
    params = %{
      "my_string" => "hello",
      "my_int" => "42",
      "my_bool" => "true",
      "my_text" => "some long text",
      "my_select" => "option1",
      "my_email" => "test@example.com",
      "my_url" => "https://example.com",
      "my_pass" => "secret",
      "my_search" => "query",
      "my_tel" => "123456"
    }

    changeset = ComprehensiveWorker.changeset(params)
    assert changeset.valid?

    # Verify values and their types
    assert changeset.changes.my_string == "hello"
    assert changeset.changes.my_int == 42
    assert changeset.changes.my_bool == true
    assert changeset.changes.my_text == "some long text"
    assert changeset.changes.my_select == "option1"
    assert changeset.changes.my_email == "test@example.com"
    assert changeset.changes.my_url == "https://example.com"
    assert changeset.changes.my_pass == "secret"
    assert changeset.changes.my_search == "query"
    assert changeset.changes.my_tel == "123456"
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
