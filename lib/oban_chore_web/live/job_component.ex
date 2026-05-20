defmodule ObanChoreWeb.JobComponent do
  use Phoenix.LiveComponent

  @impl true
  def render(assigns) do
    ~H"""
    <div class={if @selected, do: "block", else: "hidden"}>
      <div class="space-y-6">
        <div class="bg-white shadow-sm ring-1 ring-gray-900/5 sm:rounded-xl">
          <div class="px-4 py-4 sm:px-6 border-b border-gray-100 flex justify-between items-center">
            <h3 class="text-sm font-semibold leading-6 text-gray-900">Arguments</h3>
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
          <div class="px-4 py-4 sm:p-6 bg-gray-50/50">
            <%= if map_size(@job.args) > 0 do %>
              <dl class="grid grid-cols-1 gap-x-4 gap-y-4 sm:grid-cols-2 lg:grid-cols-3">
                <%= for {key, value} <- @job.args do %>
                  <div class="sm:col-span-1">
                    <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider"><%= key %></dt>
                    <dd class="mt-1 text-sm text-gray-900 font-mono bg-white border border-gray-200 rounded px-2 py-1 truncate" title={inspect(value)}>
                      <%= inspect(value) %>
                    </dd>
                  </div>
                <% end %>
              </dl>
            <% else %>
              <p class="text-xs text-gray-500 italic">No arguments provided.</p>
            <% end %>
          </div>
        </div>

        <div class="space-y-4">
          <h3 class="text-sm font-semibold text-gray-900 px-1">Execution Logs</h3>

          <div class={[
            "bg-slate-900 rounded-lg p-4 font-mono text-xs overflow-y-auto h-[400px] border border-slate-800 shadow-inner",
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
