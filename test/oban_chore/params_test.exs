defmodule ObanChore.ParamsTest do
  use ExUnit.Case, async: true
  alias ObanChore.Params

  test "cast/2 converts string values to correct types" do
    fields = [
      user_id: [type: :integer, required: true],
      active: [type: :boolean],
      name: [type: :string]
    ]

    params = %{
      "user_id" => "123",
      "active" => "true",
      "name" => "Alice"
    }

    casted = Params.cast(params, fields)
    assert casted.user_id == 123
    assert casted.active == true
    assert casted.name == "Alice"
  end

  test "cast/2 handles empty/missing values" do
    fields = [
      user_id: [type: :integer, required: true]
    ]

    assert Params.cast(%{}, fields) == %{}
    assert Params.cast(%{"user_id" => ""}, fields) == %{}
  end

  test "validate/2 returns :ok when all required fields are present" do
    fields = [user_id: [type: :integer, required: true]]
    assert Params.validate(%{user_id: 123}, fields) == :ok
  end

  test "validate/2 returns error map when required fields are missing" do
    fields = [user_id: [type: :integer, required: true]]
    assert {:error, %{user_id: "is required"}} == Params.validate(%{}, fields)
  end
end
