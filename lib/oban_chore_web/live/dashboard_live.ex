defmodule ObanChoreWeb.DashboardLive do
  use Phoenix.LiveView
  import ObanChoreWeb.CoreComponents

  require Logger

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
                if(@selected_chore_module == chore.module,
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
      <main class="flex-1 overflow-y-auto p-8 relative">
        <.flash_group flash={@flash} />

        <%= if @selected_chore_module do %>
          <% chore = Enum.find(@chores, &(&1.module == @selected_chore_module)) %>
          <div class="max-w-4xl mx-auto space-y-8">
            <div class="border-b border-gray-200 pb-5">
              <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:truncate sm:text-3xl sm:tracking-tight">
                <%= chore.name %>
              </h2>
              <p class="mt-2 text-sm text-gray-500">
                <%= chore.description || "Configure and execute this chore." %>
              </p>
            </div>

            <!-- Tabs -->
            <div class="border-b border-gray-200">
              <nav class="-mb-px flex space-x-8" aria-label="Tabs">
                <button
                  phx-click="select_tab"
                  phx-value-tab="new"
                  class={[
                    "whitespace-nowrap border-b-2 py-4 px-1 text-sm font-medium",
                    if(@selected_tab == :new,
                      do: "border-brand text-brand",
                      else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700"
                    )
                  ]}
                >
                  New Execution
                </button>
                <%= for job_id <- Map.get(@chore_jobs, @selected_chore_module, []), job = @jobs[job_id] do %>
                  <button
                    phx-click="select_tab"
                    phx-value-tab={"job_#{job.id}"}
                    class={[
                      "whitespace-nowrap border-b-2 py-4 px-1 text-sm font-medium flex items-center gap-2",
                      if(@selected_tab == {:job, job.id},
                        do: "border-brand text-brand",
                        else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700"
                      )
                    ]}
                  >
                    <span>Job #<%= job.id %></span>
                    <span class={[
                      "w-2 h-2 rounded-full",
                      case job.state do
                        :executing -> "bg-blue-500 animate-pulse"
                        :available -> "bg-gray-400"
                        :scheduled -> "bg-yellow-400"
                        _ -> "bg-gray-400"
                      end
                    ]}></span>
                  </button>
                <% end %>
              </nav>
            </div>

            <!-- Content Area -->
            <div class="mt-8">
              <%= for chore_item <- @chores do %>
                <.live_component
                  module={ObanChoreWeb.ChoreComponent}
                  id={chore_item.module}
                  chore={chore_item}
                  selected={@selected_chore_module == chore_item.module and @selected_tab == :new}
                />
              <% end %>

              <%= for {module, job_ids} <- @chore_jobs, job_id <- job_ids, job = @jobs[job_id] do %>
                  <%= if @selected_chore_module == module do %>
                    <.live_component
                      module={ObanChoreWeb.JobComponent}
                      id={job.id}
                      job={job}
                      selected={@selected_tab == {:job, job.id}}
                    />
                  <% end %>
              <% end %>
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
      Phoenix.PubSub.subscribe(pubsub, "oban_chore:counts")
    end

    # Fetch initial active jobs and subscribe to them
    {jobs, chore_jobs} =
      Enum.reduce(chores, {%{}, %{}}, fn chore, {jobs_acc, chore_jobs_acc} ->
        jobs = ObanChore.list_active_jobs(chore.module)

        if connected?(socket) do
          for job <- jobs do
            Phoenix.PubSub.subscribe(pubsub, "oban_chore:logs:#{job.id}")
            Phoenix.PubSub.subscribe(pubsub, "oban_chore:status:#{job.id}")
          end
        end

        new_jobs_acc = Enum.reduce(jobs, jobs_acc, fn job, acc -> Map.put(acc, job.id, job) end)
        new_chore_jobs_acc = Map.put(chore_jobs_acc, chore.module, Enum.map(jobs, & &1.id))

        {new_jobs_acc, new_chore_jobs_acc}
      end)

    {:ok,
     assign(socket,
       chores: chores,
       counts: fetch_counts(chores),
       selected_chore_module: nil,
       jobs: jobs,
       chore_jobs: chore_jobs,
       selected_tab: :new
     )}
  end

  @impl true
  def handle_event("select_chore", %{"module" => module_str}, socket) do
    module = String.to_existing_atom(module_str)
    {:noreply, assign(socket, selected_chore_module: module, selected_tab: :new)}
  end

  @impl true
  def handle_event("select_tab", %{"tab" => "new"}, socket) do
    {:noreply, assign(socket, selected_tab: :new)}
  end

  @impl true
  def handle_event("select_tab", %{"tab" => "job_" <> id_str}, socket) do
    id = String.to_integer(id_str)
    {:noreply, assign(socket, selected_tab: {:job, id})}
  end

  @impl true
  def handle_info({:oban_chore_count, worker_module, count}, socket) do
    new_counts = Map.put(socket.assigns.counts, worker_module, count)
    {:noreply, assign(socket, counts: new_counts)}
  end

  @impl true
  def handle_info({:job_enqueued, job, worker_module}, socket) do
    pubsub = ObanChore.pubsub_server()

    if connected?(socket) do
      Phoenix.PubSub.subscribe(pubsub, "oban_chore:logs:#{job.id}")
      Phoenix.PubSub.subscribe(pubsub, "oban_chore:status:#{job.id}")
    end

    new_jobs = Map.put(socket.assigns.jobs, job.id, job)

    new_chore_jobs =
      Map.update(socket.assigns.chore_jobs, worker_module, [job.id], fn job_ids ->
        if job.id in job_ids, do: job_ids, else: [job.id | job_ids]
      end)

    {:noreply,
     socket
     |> assign(jobs: new_jobs, chore_jobs: new_chore_jobs, selected_tab: {:job, job.id})}
  end

  @impl true
  def handle_info({:oban_chore_state, job_id, state}, socket) do
    # O(1) update of the flat jobs map
    new_jobs = Map.update!(socket.assigns.jobs, job_id, fn job -> %{job | state: state} end)

    # Forward to JobComponent
    send_update(ObanChoreWeb.JobComponent, id: job_id, new_state: state)

    {:noreply, assign(socket, jobs: new_jobs)}
  end

  @impl true
  def handle_info({:oban_chore_log, job_id, message}, socket) do
    send_update(ObanChoreWeb.JobComponent, id: job_id, new_log: message)
    {:noreply, socket}
  end

  defp fetch_counts(chores) do
    Map.new(chores, fn chore -> {chore.module, ObanChore.count_running(chore.module, Oban)} end)
  end
end
