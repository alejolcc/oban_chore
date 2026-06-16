defmodule ObanChoreWeb.HistoryComponent do
  @moduledoc false
  use Phoenix.LiveComponent

  @impl true
  def render(assigns) do
    ~H"""
    <div class="oc-card">
      <div class="oc-card-body" style="padding: 0;">
        <div class="oc-table-responsive" style="overflow-x: auto;">
          <table class="oc-table" style="width: 100%; border-collapse: collapse; text-align: left;">
            <thead>
              <tr style="border-bottom: 1px solid var(--oc-gray-200); background-color: var(--oc-gray-50);">
                <th
                  style="padding: 1rem 1.5rem; font-size: 0.75rem; font-weight: 600; text-transform: uppercase; color: var(--oc-gray-500); letter-spacing: 0.05em; cursor: pointer; user-select: none; transition: color 0.2s;"
                  phx-click="sort"
                  phx-value-column="id"
                  phx-target={@myself}
                  class="oc-sortable-header"
                >
                  <div style="display: flex; align-items: center; gap: 0.25rem;">
                    <span>Job ID</span>
                    <%= render_sort_arrow(:id, @sort_by, @sort_dir) %>
                  </div>
                </th>
                <th
                  style="padding: 1rem 1.5rem; font-size: 0.75rem; font-weight: 600; text-transform: uppercase; color: var(--oc-gray-500); letter-spacing: 0.05em; cursor: pointer; user-select: none; transition: color 0.2s;"
                  phx-click="sort"
                  phx-value-column="state"
                  phx-target={@myself}
                  class="oc-sortable-header"
                >
                  <div style="display: flex; align-items: center; gap: 0.25rem;">
                    <span>State</span>
                    <%= render_sort_arrow(:state, @sort_by, @sort_dir) %>
                  </div>
                </th>
                <th
                  style="padding: 1rem 1.5rem; font-size: 0.75rem; font-weight: 600; text-transform: uppercase; color: var(--oc-gray-500); letter-spacing: 0.05em; cursor: pointer; user-select: none; transition: color 0.2s;"
                  phx-click="sort"
                  phx-value-column="started_at"
                  phx-target={@myself}
                  class="oc-sortable-header"
                >
                  <div style="display: flex; align-items: center; gap: 0.25rem;">
                    <span>Started At</span>
                    <%= render_sort_arrow(:started_at, @sort_by, @sort_dir) %>
                  </div>
                </th>
                <th
                  style="padding: 1rem 1.5rem; font-size: 0.75rem; font-weight: 600; text-transform: uppercase; color: var(--oc-gray-500); letter-spacing: 0.05em; cursor: pointer; user-select: none; transition: color 0.2s;"
                  phx-click="sort"
                  phx-value-column="timestamp"
                  phx-target={@myself}
                  class="oc-sortable-header"
                >
                  <div style="display: flex; align-items: center; gap: 0.25rem;">
                    <span>Finished At</span>
                    <%= render_sort_arrow(:timestamp, @sort_by, @sort_dir) %>
                  </div>
                </th>
                <th style="padding: 1rem 1.5rem; font-size: 0.75rem; font-weight: 600; text-transform: uppercase; color: var(--oc-gray-500); letter-spacing: 0.05em;">Actions</th>
              </tr>
            </thead>
            <tbody style="divide-y divide-gray-200">
              <%= if @sorted_runs == [] do %>
                <tr>
                  <td colspan="5" style="padding: 3rem 1.5rem; text-align: center; color: var(--oc-gray-500); font-style: italic;">
                    No previous runs found for this chore.
                  </td>
                </tr>
              <% else %>
                <%= for run <- @sorted_runs do %>
                  <tr style="border-bottom: 1px solid var(--oc-gray-100); transition: background-color 0.2s;" class="oc-table-row" data-job-id={run.id}>
                    <td style="padding: 1rem 1.5rem; font-size: 0.875rem; font-weight: 500; color: var(--oc-gray-900);">
                      #<%= run.id %>
                    </td>
                    <td style="padding: 1rem 1.5rem; font-size: 0.875rem;">
                      <span class="oc-badge" style={ObanChoreWeb.CoreComponents.state_style(run.state)}>
                        <%= String.capitalize(to_string(run.state)) %>
                      </span>
                    </td>
                    <td style="padding: 1rem 1.5rem; font-size: 0.875rem; color: var(--oc-gray-500);">
                      <%= format_started_time(run) %>
                    </td>
                    <td style="padding: 1rem 1.5rem; font-size: 0.875rem; color: var(--oc-gray-500);">
                      <%= format_finished_time(run) %>
                    </td>
                    <td style="padding: 1rem 1.5rem; font-size: 0.875rem;">
                      <button
                        phx-click="view_job_details"
                        phx-value-id={run.id}
                        class="oc-btn"
                        style="padding: 0.25rem 0.5rem; font-size: 0.75rem; background-color: var(--oc-gray-100); color: var(--oc-gray-700); border: 1px solid var(--oc-gray-200);"
                      >
                        Details
                      </button>
                    </td>
                  </tr>
                <% end %>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    chore_module_changed? = assigns[:chore_module] != socket.assigns[:chore_module]
    refresh? = assigns[:refresh] || false

    socket =
      socket
      |> assign_new(:sort_by, fn -> :id end)
      |> assign_new(:sort_dir, fn -> :desc end)
      |> assign(Map.drop(assigns, [:previous_runs]))

    if socket.assigns[:sorted_runs] == nil or chore_module_changed? or refresh? do
      sorted_runs =
        ObanChore.list_previous_runs(
          socket.assigns.chore_module,
          ObanChore.oban_name(),
          20,
          socket.assigns.sort_by,
          socket.assigns.sort_dir
        )

      {:ok, assign(socket, sorted_runs: sorted_runs)}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_event("sort", %{"column" => column_str}, socket) do
    column =
      case column_str do
        "id" -> :id
        "state" -> :state
        "started_at" -> :started_at
        "timestamp" -> :timestamp
        _ -> nil
      end

    if column do
      current_column = socket.assigns.sort_by
      current_dir = socket.assigns.sort_dir

      {new_column, new_dir} =
        if column == current_column do
          {column, if(current_dir == :asc, do: :desc, else: :asc)}
        else
          {column, :desc}
        end

      sorted_runs =
        ObanChore.list_previous_runs(
          socket.assigns.chore_module,
          ObanChore.oban_name(),
          20,
          new_column,
          new_dir
        )

      {:noreply,
       socket
       |> assign(sort_by: new_column, sort_dir: new_dir, sorted_runs: sorted_runs)}
    else
      {:noreply, socket}
    end
  end

  defp format_finished_time(run) do
    time =
      run.completed_at || run.discarded_at || run.cancelled_at || run.attempted_at ||
        run.inserted_at

    if time do
      Calendar.strftime(time, "%Y-%m-%d %H:%M:%S UTC")
    else
      "N/A"
    end
  end

  defp format_started_time(run) do
    if run.attempted_at do
      Calendar.strftime(run.attempted_at, "%Y-%m-%d %H:%M:%S UTC")
    else
      "N/A"
    end
  end

  defp render_sort_arrow(col, current_col, dir) do
    assigns = %{col: col, current_col: current_col, dir: dir}

    ~H"""
    <div style="display: inline-flex; align-items: center; margin-left: 0.25rem;">
      <%= if @col == @current_col do %>
        <%= if @dir == :asc do %>
          <!-- Chevron Up (Active) -->
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" style="width: 0.875rem; height: 0.875rem; color: var(--oc-brand);">
            <path fill-rule="evenodd" d="M14.77 12.79a.75.75 0 01-1.06-.02L10 8.832 6.29 12.77a.75.75 0 11-1.08-1.04l4.25-4.5a.75.75 0 011.08 0l4.25 4.5a.75.75 0 01-.02 1.06z" clip-rule="evenodd" />
          </svg>
        <% else %>
          <!-- Chevron Down (Active) -->
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" style="width: 0.875rem; height: 0.875rem; color: var(--oc-brand);">
            <path fill-rule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z" clip-rule="evenodd" />
          </svg>
        <% end %>
      <% else %>
        <!-- Neutral double chevron/arrow or light arrow -->
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" style="width: 0.875rem; height: 0.875rem; opacity: 0.25; color: var(--oc-gray-400);">
          <path fill-rule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z" clip-rule="evenodd" />
        </svg>
      <% end %>
    </div>
    """
  end
end
