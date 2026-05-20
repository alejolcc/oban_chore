defmodule ObanChoreWeb.JobComponent do
  use Phoenix.LiveComponent

  @impl true
  def render(assigns) do
    ~H"""
    <div class={if @selected, do: "block", else: "hidden"}>
      <div class="space-y-4">
        <div class="flex items-center justify-between">
          <h3 class="text-sm font-semibold text-gray-900">Execution Logs</h3>
          <div class="flex items-center gap-2">
            <span class={[
              "inline-flex items-center rounded-md px-2 py-1 text-xs font-medium ring-1 ring-inset",
              state_class(@job.state)
            ]}>
              <%= String.capitalize(to_string(@job.state)) %>
            </span>
            <span class="text-xs text-gray-500 font-mono">ID: <%= @job.id %></span>
          </div>
        </div>

        <div class={[
          "bg-slate-900 rounded-lg p-4 font-mono text-xs overflow-y-auto h-[500px] border border-slate-800 shadow-inner",
          if(@logs == [], do: "flex items-center justify-center text-slate-500 italic", else: "text-slate-300")
        ]}>
          <%= if @logs == [] do %>
            <%= if @job.state == :executing do %>
              Waiting for logs...
            <% else %>
              No logs yet.
            <% end %>
          <% else %>
            <div class="space-y-1">
              <%= for log <- Enum.reverse(@logs) do %>
                <div class="flex gap-2">
                  <span class="text-slate-600 select-none">$</span>
                  <span><%= log %></span>
                </div>
              <% end %>
            </div>
          <% end %>
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

  defp state_class(state) do
    case state do
      :executing -> "bg-blue-50 text-blue-700 ring-blue-700/10"
      :available -> "bg-gray-50 text-gray-600 ring-gray-500/10"
      :scheduled -> "bg-yellow-50 text-yellow-800 ring-yellow-600/20"
      :completed -> "bg-green-50 text-green-700 ring-green-600/20"
      :discarded -> "bg-red-50 text-red-700 ring-red-600/10"
      _ -> "bg-gray-50 text-gray-600 ring-gray-500/10"
    end
  end
end
