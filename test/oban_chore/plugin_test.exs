defmodule ObanChore.PluginTest do
  use ExUnit.Case, async: false

  defmodule TestChore do
    use ObanChore.Worker, name: "Plugin Test Chore", fields: [arg: [type: :string]]

    @impl Oban.Worker
    def perform(_), do: :ok
  end

  test "can be manually initialized with chores for testing" do
    chore_info = TestChore.__chore_info__()
    {:ok, pid} = ObanChore.Plugin.start_link(chores: [chore_info])

    chores = ObanChore.Plugin.get_chores()

    assert is_list(chores)
    assert Enum.any?(chores, fn c -> c.name == "Plugin Test Chore" end)
    assert Enum.any?(chores, fn c -> c.module == TestChore end)

    GenServer.stop(pid)
  end

  test "discover_chores returns a list" do
    # Discovery might return empty if no chores are in lib/
    # but it should at least not crash.
    {:ok, pid} = ObanChore.Plugin.start_link([])
    chores = ObanChore.Plugin.get_chores()
    assert is_list(chores)
    GenServer.stop(pid)
  end
end
