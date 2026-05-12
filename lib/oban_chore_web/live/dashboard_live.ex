defmodule ObanChoreWeb.DashboardLive do
  use Phoenix.LiveView

  @impl true
  def render(assigns) do
    ~H"""
    <div id="oban-chore-dashboard">
      <h1>ObanChore Dashboard</h1>
      <p>Welcome to the chore runner!</p>

      <h2>Available Chores</h2>
      <ul>
        <%= for chore <- @chores do %>
          <li>
            <strong><%= chore.name %></strong> (<%= inspect(chore.module) %>)
            <button
              phx-click="trigger"
              phx-value-module={chore.module}
              data-confirm={"Are you sure you want to run #{chore.name}?"}
            >
              Run
            </button>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    chores = ObanChore.Plugin.get_chores()
    {:ok, assign(socket, chores: chores)}
  end

  @impl true
  def handle_event("trigger", %{"module" => module_str}, socket) do
    module = String.to_existing_atom(module_str)

    case Oban.insert(module.new(%{})) do
      {:ok, _job} ->
        {:noreply, put_flash(socket, :info, "Successfully enqueued #{chore_name(socket, module)}")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to enqueue #{chore_name(socket, module)}")}
    end
  end

  defp chore_name(socket, module) do
    Enum.find_value(socket.assigns.chores, inspect(module), fn
      %{module: ^module, name: name} -> name
      _ -> nil
    end)
  end
end
