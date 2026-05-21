defmodule ObanChoreWeb.JobComponent do
  use Phoenix.LiveComponent

  @impl true
  def render(assigns) do
    ~H"""
    <div class={if @selected, do: "oc-block", else: "oc-hidden"}>
      <div style="display: flex; flex-direction: column; gap: 1.5rem;">
        <div class="oc-card">
          <div class="oc-job-header">
            <h3 class="oc-text-sm" style="font-weight: 600; color: var(--oc-gray-900);">Arguments</h3>
            <div class="oc-flex oc-items-center oc-gap-2">
              <span class="oc-badge" style={state_style(@job.state)}>
                <%= String.capitalize(to_string(@job.state)) %>
              </span>
              <span class="oc-text-xs oc-text-gray-500 oc-font-mono">ID: <%= @job.id %></span>
            </div>
          </div>
          <div class="oc-job-args-grid">
            <%= if map_size(@job.args) > 0 do %>
              <%= for {key, value} <- @job.args do %>
                <div>
                  <dt class="oc-job-arg-title"><%= key %></dt>
                  <dd class="oc-job-arg-value" title={inspect(value)}>
                    <%= inspect(value) %>
                  </dd>
                </div>
              <% end %>
            <% else %>
              <p class="oc-text-xs oc-text-gray-500" style="font-style: italic;">No arguments provided.</p>
            <% end %>
          </div>
        </div>

        <div style="display: flex; flex-direction: column; gap: 1rem;">
          <h3 class="oc-text-sm" style="font-weight: 600; color: var(--oc-gray-900); padding-left: 0.25rem;">Execution Logs</h3>

          <div class={[
            "oc-log-container",
            if(@logs == [], do: "oc-flex oc-items-center oc-justify-center oc-text-gray-500", else: "")
          ]} style={if(@logs == [], do: "font-style: italic;", else: "")}>
            <%= if @logs == [] do %>
              <%= if @job.state == :executing do %>
                Waiting for logs...
              <% else %>
                No logs yet.
              <% end %>
            <% else %>
              <div style="display: flex; flex-direction: column-reverse; gap: 0.25rem;">
                <%= for log <- @logs do %>
                  <div class="oc-log-line">
                    <span class="oc-log-prompt">$</span>
                    <span class="oc-log-content"><%= log %></span>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def update(%{new_log: message}, socket) do
    {:ok, assign(socket, logs: [message | socket.assigns.logs])}
  end

  @impl true
  def update(%{new_state: state}, socket) do
    {:ok, assign(socket, job: %{socket.assigns.job | state: state})}
  end

  @impl true
  def update(assigns, socket) do
    if socket.assigns[:job] == nil do
      {:ok,
       socket
       |> assign(assigns)
       |> assign(logs: [])}
    else
      {:ok, assign(socket, assigns)}
    end
  end

  defp state_style(state) do
    case state do
      :executing ->
        "background-color: var(--oc-blue-50); color: var(--oc-blue-700); box-shadow: inset 0 0 0 1px rgba(29, 78, 216, 0.1);"

      :available ->
        "background-color: var(--oc-gray-50); color: var(--oc-gray-600); box-shadow: inset 0 0 0 1px rgba(107, 114, 128, 0.1);"

      :scheduled ->
        "background-color: var(--oc-amber-50); color: var(--oc-amber-800); box-shadow: inset 0 0 0 1px rgba(180, 83, 9, 0.2);"

      :completed ->
        "background-color: var(--oc-emerald-50); color: var(--oc-emerald-800); box-shadow: inset 0 0 0 1px rgba(16, 185, 129, 0.2);"

      :discarded ->
        "background-color: var(--oc-rose-50); color: var(--oc-rose-900); box-shadow: inset 0 0 0 1px rgba(244, 63, 94, 0.1);"

      _ ->
        "background-color: var(--oc-gray-50); color: var(--oc-gray-600); box-shadow: inset 0 0 0 1px rgba(107, 114, 128, 0.1);"
    end
  end
end
