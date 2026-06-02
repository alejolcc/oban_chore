defmodule ObanChore.PluginTest do
  use ExUnit.Case, async: false

  defmodule TestChore do
    use ObanChore.Worker, name: "Plugin Test Chore", fields: [arg: [type: :string]]

    @impl Oban.Worker
    def perform(_), do: :ok
  end

  test "discover_chores returns a list of manually specified chores" do
    {:ok, pid} = ObanChore.Plugin.start_link(chores: [TestChore], pubsub_server: TestPubSub)

    # Wait for handle_continue to finish
    _ = :sys.get_state(pid)

    chores = ObanChore.Plugin.get_chores()
    assert is_list(chores)
    assert Enum.any?(chores, fn chore -> chore.module == TestChore end)
    GenServer.stop(pid)
  end

  test "can limit discovery to a specific otp_app" do
    # :oban_chore app should have some modules.
    {:ok, pid} = ObanChore.Plugin.start_link(otp_app: :oban_chore, pubsub_server: TestPubSub)

    # Wait for handle_continue to finish
    _ = :sys.get_state(pid)

    chores = ObanChore.Plugin.get_chores()
    assert is_list(chores)

    GenServer.stop(pid)
  end

  test "validate/1 checks for correct format" do
    assert ObanChore.Plugin.validate(otp_app: :my_app, pubsub_server: TestPubSub) == :ok
    assert ObanChore.Plugin.validate(chores: [TestChore], pubsub_server: TestPubSub) == :ok
    assert ObanChore.Plugin.validate(otp_app: [:app1, :app2], pubsub_server: TestPubSub) == :ok

    assert {:error, "must set either :otp_app or :chores option"} =
             ObanChore.Plugin.validate(pubsub_server: TestPubSub)

    assert {:error, "cannot set both :otp_app and :chores options"} =
             ObanChore.Plugin.validate(
               otp_app: :my_app,
               chores: [TestChore],
               pubsub_server: TestPubSub
             )

    assert {:error, "missing :pubsub_server option"} = ObanChore.Plugin.validate(otp_app: :my_app)

    assert {:error, "chores must be a list of modules (atoms)"} =
             ObanChore.Plugin.validate(chores: "not_a_list", pubsub_server: TestPubSub)

    assert {:error, "all chores elements must be modules (atoms)"} =
             ObanChore.Plugin.validate(chores: [:app1, "not_an_atom"], pubsub_server: TestPubSub)

    assert {:error, "the following modules are not chores: [SomeNonExistentModule]"} =
             ObanChore.Plugin.validate(chores: [SomeNonExistentModule], pubsub_server: TestPubSub)

    assert {:error, "the following modules are not chores: [ObanChore.Plugin]"} =
             ObanChore.Plugin.validate(chores: [ObanChore.Plugin], pubsub_server: TestPubSub)

    assert {:error, "otp_app must be an atom or a list of atoms"} =
             ObanChore.Plugin.validate(otp_app: "not_an_atom", pubsub_server: TestPubSub)

    assert {:error, "all otp_app elements must be atoms"} =
             ObanChore.Plugin.validate(otp_app: [:app1, "not_an_atom"], pubsub_server: TestPubSub)
  end
end
