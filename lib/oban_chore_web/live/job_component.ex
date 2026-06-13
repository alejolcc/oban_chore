defmodule ObanChoreWeb.JobComponent do
  @moduledoc false
  use Phoenix.LiveComponent

  @impl true
  def render(assigns) do
    ~H"""
    <div class={if @selected, do: "oc-block", else: "oc-hidden"} data-role="job-details" data-job-id={@job.id}>
      <div style="display: flex; flex-direction: column; gap: 1.5rem;">
        <div class="oc-card">
          <div class="oc-job-header">
            <h3 class="oc-text-sm" style="font-weight: 600; color: var(--oc-gray-900);">Arguments</h3>
            <div class="oc-flex oc-items-center oc-gap-2">
              <span class="oc-badge" style={ObanChoreWeb.CoreComponents.state_style(@job.state)}>
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

        <%= if @job.errors && @job.errors != [] do %>
          <div style="display: flex; flex-direction: column; gap: 1rem;">
            <h3 class="oc-text-sm" style="font-weight: 600; color: var(--oc-red-600); padding-left: 0.25rem;">Error Details</h3>
            <div style="background-color: var(--oc-rose-50); border: 1px solid rgba(244, 63, 94, 0.2); border-radius: 0.5rem; padding: 1rem; font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; font-size: 0.875rem; color: var(--oc-rose-900); overflow-x: auto; max-height: 20rem;">
              <%= for {error, idx} <- Enum.with_index(@job.errors) do %>
                <div style={"margin-bottom: #{if idx == length(@job.errors) - 1, do: "0", else: "1rem"}; border-bottom: #{if idx == length(@job.errors) - 1, do: "none", else: "1px dashed rgba(244, 63, 94, 0.15)"}; padding-bottom: #{if idx == length(@job.errors) - 1, do: "0", else: "1rem"};"}>
                  <div style="font-weight: 600; display: flex; justify-content: space-between; margin-bottom: 0.25rem;">
                    <span>Attempt #<%= Map.get(error, "attempt") || "?" %></span>
                    <span style="font-size: 0.75rem; opacity: 0.8;"><%= Map.get(error, "at") || "unknown time" %></span>
                  </div>
                  <pre style="margin: 0; white-space: pre-wrap; word-break: break-all; font-family: inherit;"><%= Map.get(error, "error") || "No error message" %></pre>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

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
      persisted_logs = Map.get(assigns.job.meta || %{}, "oban_chore_logs", []) |> Enum.reverse()

      {:ok,
       socket
       |> assign(assigns)
       |> assign(logs: persisted_logs)}
    else
      {:ok, assign(socket, assigns)}
    end
  end
end
