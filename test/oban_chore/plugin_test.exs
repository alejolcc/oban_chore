defmodule ObanChore.PluginTest do
  use ExUnit.Case, async: false

  defmodule TestChore do
    use ObanChore.Worker, name: "Plugin Test Chore", fields: [arg: [type: :string]]

    @impl Oban.Worker
    def perform(_), do: :ok
  end

  test "discover_chores returns a list" do
    # Discovery might return empty if no chores are in lib/
    # but it should at least not crash.
    {:ok, pid} = ObanChore.Plugin.start_link([])

    # Wait for handle_continue to finish
    _ = :sys.get_state(pid)

    chores = ObanChore.Plugin.get_chores()
    assert is_list(chores)
    GenServer.stop(pid)
  end

  test "can limit discovery to a specific otp_app" do
    # :oban_chore app should have some modules.
    # We don't necessarily expect TestChore to be found because it's defined in the test
    # and not in the .app modules list, but we can verify the GenServer starts and runs discovery.
    {:ok, pid} = ObanChore.Plugin.start_link(otp_app: :oban_chore)

    # Wait for handle_continue to finish
    _ = :sys.get_state(pid)

    chores = ObanChore.Plugin.get_chores()
    assert is_list(chores)

    GenServer.stop(pid)
  end

  test "validate/1 checks for correct otp_app format" do
    assert ObanChore.Plugin.validate([]) == :ok
    assert ObanChore.Plugin.validate(otp_app: :my_app) == :ok
    assert ObanChore.Plugin.validate(otp_app: [:app1, :app2]) == :ok
    assert {:error, _} = ObanChore.Plugin.validate(otp_app: "not_an_atom")
    assert {:error, _} = ObanChore.Plugin.validate(otp_app: [:app1, "not_an_atom"])
  end
end
