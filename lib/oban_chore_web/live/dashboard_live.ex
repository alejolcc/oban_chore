defmodule ObanChoreWeb.DashboardLive do
  use Phoenix.LiveView
  import ObanChoreWeb.CoreComponents

  require Logger

  @refresh_interval 5000

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-screen bg-gray-50 overflow-hidden">
      <!-- Sidebar -->
      <div class="w-64 bg-white border-r border-gray-200 flex flex-col">
        <div class="p-6 border-b border-gray-200 flex items-center gap-2">
          <div class="w-8 h-8 bg-brand rounded-lg flex items-center justify-center text-white font-bold">
            O
          </div>
          <h1 class="text-xl font-bold text-gray-900 tracking-tight">ObanChore</h1>
        </div>

        <nav class="flex-1 overflow-y-auto p-4 space-y-1">
          <div class="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2 px-2">
            Available Chores
          </div>
          <%= for chore <- @chores do %>
            <button
              phx-click="select_chore"
              phx-value-module={to_string(chore.module)}
              class={[
                "w-full text-left px-3 py-2 rounded-md text-sm font-medium transition-colors flex items-center justify-between",
                if(@selected_chore && @selected_chore.module == chore.module,
                  do: "bg-brand/10 text-brand",
                  else: "text-gray-600 hover:bg-gray-100 hover:text-gray-900"
                )
              ]}
            >
              <span><%= chore.name %></span>
              <.badge count={@counts[chore.module] || 0} />
            </button>
          <% end %>
        </nav>
      </div>

      <!-- Main Content -->
      <main class="flex-1 overflow-y-auto p-8">
        <%= if @selected_chore do %>
          <div class="max-w-4xl mx-auto space-y-8">
            <div class="border-b border-gray-200 pb-5">
              <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:truncate sm:text-3xl sm:tracking-tight">
                <%= @selected_chore.name %>
              </h2>
              <p class="mt-2 text-sm text-gray-500">
                <%= @selected_chore.description || "Configure and execute this chore." %>
              </p>
            </div>

            <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
              <!-- Form Section -->
              <div class="space-y-6">
                <%= if @duplicate_warning do %>
                  <.duplicate_warning_banner on_confirm="confirm_execute" on_cancel="cancel_execute" />
                <% end %>

                <div class="bg-white shadow-sm ring-1 ring-gray-900/5 sm:rounded-xl">
                  <div class="px-4 py-6 sm:p-8">
                    <.form for={@form} phx-change="validate" phx-submit="execute" class="space-y-6">
                    <%= for {field, opts} <- @selected_chore.fields do %>
                      <.input
                        field={@form[field]}
                        label={Keyword.get(opts, :label, field)}
                        type={type_to_input_type(Keyword.get(opts, :type))}
                        default={Keyword.get(opts, :default)}
                        options={Keyword.get(opts, :options, [])}
                        prompt={Keyword.get(opts, :prompt)}
                      />
                    <% end %>

                    <div class="flex items-center justify-end gap-x-6 border-t border-gray-900/10 pt-6">
                      <div class="relative flex items-center gap-2 group">
                        <input
                          type="checkbox"
                          id="unique_execution"
                          phx-click="toggle_unique"
                          checked={@unique_execution}
                          class="h-4 w-4 rounded border-gray-300 text-brand focus:ring-brand cursor-pointer"
                        />
                        <label for="unique_execution" class="text-sm font-medium text-gray-700 cursor-pointer select-none">
                          Unique per args
                        </label>
                        <div class="absolute bottom-full mb-2 left-1/2 -translate-x-1/2 px-3 py-2 bg-gray-900 text-white text-[10px] leading-tight rounded shadow-xl opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none w-48 text-center z-20">
                          Uses Oban's uniqueness engine to ensure only one job with these exact arguments can run at a time.
                          <div class="absolute top-full left-1/2 -translate-x-1/2 border-4 border-transparent border-t-gray-900"></div>
                        </div>
                      </div>
                      <button
                        type="submit"
                        class="rounded-md bg-brand px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-brand/90 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
                      >
                        Execute Chore
                      </button>
                    </div>
                  </.form>
                </div>
              </div>
            </div>

            <!-- Logs Section -->
            <div class="space-y-4">
                <h3 class="text-sm font-semibold text-gray-900">Execution Logs</h3>
                <div class={[
                  "bg-slate-900 rounded-lg p-4 font-mono text-xs overflow-y-auto h-[400px] border border-slate-800 shadow-inner",
                  if(@logs == [], do: "flex items-center justify-center text-slate-500 italic", else: "text-slate-300")
                ]}>
                  <%= if @logs == [] do %>
                    <%= if @active_job_id do %>
                      Waiting for logs...
                    <% else %>
                      No active execution.
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
        <% else %>
          <div class="h-full flex flex-col items-center justify-center text-center">
            <div class="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mb-4">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-8 h-8 text-gray-400">
                <path stroke-linecap="round" stroke-linejoin="round" d="M15.59 14.37a6 6 0 01-5.84 7.38v-4.8m5.84-2.58a14.98 14.98 0 006.16-12.12A14.98 14.98 0 009.631 8.41m5.96 5.96a14.926 14.926 0 01-5.841 2.58m-.119-8.54a6 6 0 00-7.381 5.84h4.8m2.581-5.84a14.927 14.927 0 00-2.58 5.84m2.699 2.7c-.103.021-.207.041-.311.06a15.09 15.09 0 01-2.448-2.448 14.9 14.9 0 01.06-.312m-2.24 2.39a4.493 4.493 0 00-1.757 4.306 4.493 4.493 0 004.306-1.758M16.5 9a1.5 1.5 0 11-3 0 1.5 1.5 0 013 0z" />
              </svg>
            </div>
            <h3 class="text-sm font-semibold text-gray-900">No chore selected</h3>
            <p class="mt-1 text-sm text-gray-500">Select a chore from the sidebar to get started.</p>
          </div>
        <% end %>
      </main>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    chores = ObanChore.Plugin.get_chores()
    pubsub = ObanChore.pubsub_server()

    if connected?(socket) do
      if pubsub do
        Phoenix.PubSub.subscribe(pubsub, "oban_chore:counts")
      else
        :timer.send_interval(@refresh_interval, self(), :refresh_counts)
      end
    end

    {:ok,
     assign(socket,
       chores: chores,
       counts: fetch_counts(chores),
       selected_chore: nil,
       form: to_form(%{}, as: :args),
       logs: [],
       active_job_id: nil,
       duplicate_warning: nil,
       unique_execution: true
     )}
  end

  @impl true
  def handle_event("toggle_unique", _params, socket) do
    {:noreply, assign(socket, unique_execution: not socket.assigns.unique_execution)}
  end

  @impl true
  def handle_event("select_chore", %{"module" => module_str}, socket) do
    module = String.to_existing_atom(module_str)
    chore = Enum.find(socket.assigns.chores, fn c -> c.module == module end)

    # Initialize form with defaults
    defaults =
      Enum.into(chore.fields, %{}, fn {name, opts} ->
        {to_string(name), Keyword.get(opts, :default)}
      end)

    {:noreply,
     assign(socket,
       selected_chore: chore,
       form: to_form(chore.module.changeset(defaults), as: :args),
       logs: [],
       active_job_id: nil,
       duplicate_warning: nil
     )}
  end

  @impl true
  def handle_event("validate", %{"args" => params}, socket) do
    changeset =
      socket.assigns.selected_chore.module.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :args), duplicate_warning: nil)}
  end

  @impl true
  def handle_event("execute", %{"args" => params}, socket) do
    chore = socket.assigns.selected_chore
    changeset = chore.module.changeset(params)

    if changeset.valid? do
      casted_args = Ecto.Changeset.apply_changes(changeset)

      if ObanChore.running_with_args?(chore.module, casted_args) do
        {:noreply, assign(socket, duplicate_warning: params)}
      else
        perform_execute(socket, chore, casted_args)
      end
    else
      {:noreply, assign(socket, form: to_form(Map.put(changeset, :action, :insert), as: :args))}
    end
  end

  @impl true
  def handle_event("confirm_execute", _params, socket) do
    chore = socket.assigns.selected_chore
    params = socket.assigns.duplicate_warning
    changeset = chore.module.changeset(params)
    casted_args = Ecto.Changeset.apply_changes(changeset)

    socket
    |> assign(duplicate_warning: nil)
    |> perform_execute(chore, casted_args)
  end

  @impl true
  def handle_event("cancel_execute", _params, socket) do
    {:noreply, assign(socket, duplicate_warning: nil)}
  end

  defp perform_execute(socket, chore, casted_args) do
    opts =
      if socket.assigns.unique_execution,
        do: [unique: [period: :infinity, states: [:available, :scheduled, :executing]]],
        else: []

    case Oban.insert(chore.module.new(casted_args, opts)) do
      {:ok, job} ->
        if pubsub = ObanChore.pubsub_server() do
          Phoenix.PubSub.subscribe(pubsub, "oban_chore:logs:#{job.id}")
        end

        message =
          if socket.assigns.unique_execution,
            do: "Job processed (uniqueness enforced)",
            else: "Successfully enqueued #{chore.name}"

        {:noreply,
         socket
         |> put_flash(:info, message)
         |> assign(active_job_id: job.id, logs: [])}

      {:error, _reason} ->
        Logger.error("Failed to enqueue #{chore.name} with args #{inspect(casted_args)}")
        {:noreply, put_flash(socket, :error, "Failed to enqueue #{chore.name}")}
    end
  end

  @impl true
  def handle_info(:refresh_counts, socket) do
    {:noreply, assign(socket, counts: fetch_counts(socket.assigns.chores))}
  end

  @impl true
  def handle_info({:oban_chore_count, worker_module, count}, socket) do
    Logger.debug("[ObanChore Dashboard] Received count update for #{worker_module}: #{count}")
    new_counts = Map.put(socket.assigns.counts, worker_module, count)
    {:noreply, assign(socket, counts: new_counts)}
  end

  @impl true
  def handle_info({:oban_chore_log, job_id, message}, socket) do
    if job_id == socket.assigns.active_job_id do
      {:noreply, assign(socket, logs: [message | socket.assigns.logs])}
    else
      {:noreply, socket}
    end
  end

  defp type_to_input_type(type) do
    case type do
      :utc_datetime -> "datetime-local"
      :date -> "date"
      :time -> "time"
      :boolean -> "checkbox"
      other -> to_string(other)
    end
  end

  defp fetch_counts(chores) do
    # For now we use the default Oban name.
    # In the future we can make this configurable via the dashboard mount options.
    Map.new(chores, fn chore -> {chore.module, ObanChore.count_running(chore.module, Oban)} end)
  end
end
