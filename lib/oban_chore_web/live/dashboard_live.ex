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
end
