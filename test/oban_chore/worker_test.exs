defmodule ObanChore.WorkerTest do
  use ExUnit.Case, async: true

  defmodule MyTestChore do
    use ObanChore.Worker,
      name: "My Test Chore",
      queue: :default,
      fields: [
        user_id: [type: :integer, required: true, label: "User ID"],
        reason: [type: :string, default: "Testing"]
      ]

    @impl Oban.Worker
    def perform(%Oban.Job{}) do
      :ok
    end
  end

  defmodule MinimalChore do
    use ObanChore.Worker

    @impl Oban.Worker
    def perform(%Oban.Job{}) do
      :ok
    end
  end

  test "injects Oban.Worker behaviour" do
    assert Oban.Worker in behaviour_info(MyTestChore)
    assert MyTestChore.__opts__()[:queue] == :default
  end

  describe "__chore_info__/0" do
    test "returns configured name and fields" do
      info = MyTestChore.__chore_info__()
      assert info.name == "My Test Chore"
      assert info.fields[:user_id][:type] == :integer
      assert info.fields[:user_id][:required] == true
      assert info.fields[:reason][:default] == "Testing"
    end

    test "handles minimal configuration" do
      info = MinimalChore.__chore_info__()
      assert info.name == "ObanChore.WorkerTest.MinimalChore"
      assert info.fields == []
    end
  end

  defp behaviour_info(module) do
    module.module_info(:attributes)[:behaviour] || []
  end
end
