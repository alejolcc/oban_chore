defmodule ObanChoreWeb.DashboardLive do
  @moduledoc false
  use Phoenix.LiveView, layout: {ObanChoreWeb.Layouts, :dashboard}
  import ObanChoreWeb.CoreComponents

  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <div class="oc-dashboard">
      <!-- Sidebar -->
      <div class="oc-sidebar">
        <div class="oc-sidebar-header">
          <div class="oc-logo-icon">
            O
          </div>
          <h1 class="oc-sidebar-title">ObanChore</h1>
        </div>

        <nav class="oc-sidebar-nav">
          <div class="oc-nav-section-title">
            Available Chores
          </div>
          <%= for chore <- @chores do %>
            <button
              phx-click="select_chore"
              phx-value-module={to_string(chore.module)}
              data-role="chore-select"
              data-chore-module={to_string(chore.module)}
              class={[
                "oc-nav-item",
                if(@selected_chore_module == chore.module,
                  do: "oc-nav-item--active",
                  else: ""
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
      <main class="oc-main">
        <.flash_group flash={@flash} />

        <%= if @selected_chore_module do %>
          <% chore = Enum.find(@chores, &(&1.module == @selected_chore_module)) %>
          <div class="oc-container">
            <div class="oc-header">
              <h2 class="oc-title" data-role="chore-title">
                <%= chore.name %>
              </h2>
              <p class="oc-subtitle">
                <%= chore.description || "Configure and execute this chore." %>
              </p>
            </div>

            <!-- Tabs -->
            <div class="oc-tabs-nav">
              <button
                phx-click="select_tab"
                phx-value-tab="new"
                class={[
                  "oc-tab-item",
                  if(@selected_tab == :new, do: "oc-tab-item--active", else: "")
                ]}
              >
                New Execution
              </button>
              <%= for job_id <- Map.get(@chore_jobs, @selected_chore_module, []), job = @jobs[job_id] do %>
                <button
                  phx-click="select_tab"
                  phx-value-tab={"job_#{job.id}"}
                  data-role="job-tab"
                  data-job-id={job.id}
                  class={[
                    "oc-tab-item",
                    if(@selected_tab == {:job, job.id}, do: "oc-tab-item--active", else: "")
                  ]}
                >
                  <span>Job #<%= job.id %></span>
                  <span class={[
                    "oc-status-dot",
                    case job.state do
                      :executing -> "oc-status-dot--pulse"
                      _ -> ""
                    end
                  ]} style={
                    case job.state do
                      :executing -> "background-color: var(--oc-blue-500);"
                      :available -> "background-color: var(--oc-gray-400);"
                      :scheduled -> "background-color: var(--oc-amber-400);"
                      _ -> "background-color: var(--oc-gray-400);"
                    end
                  }></span>
                </button>
              <% end %>
            </div>

            <!-- Content Area -->
            <div class="oc-mt-8">
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
          <div style="height: 100%; display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center;">
            <div style="width: 4rem; height: 4rem; background-color: var(--oc-gray-100); border-radius: 9999px; display: flex; align-items: center; justify-content: center; margin-bottom: 1rem;">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" style="width: 2rem; height: 2rem; color: var(--oc-gray-400);">
                <path stroke-linecap="round" stroke-linejoin="round" d="M15.59 14.37a6 6 0 01-5.84 7.38v-4.8m5.84-2.58a14.98 14.98 0 006.16-12.12A14.98 14.98 0 009.631 8.41m5.96 5.96a14.926 14.926 0 01-5.841 2.58m-.119-8.54a6 6 0 00-7.381 5.84h4.8m2.581-5.84a14.927 14.927 0 00-2.58 5.84m2.699 2.7c-.103.021-.207.041-.311.06a15.09 15.09 0 01-2.448-2.448 14.9 14.9 0 01.06-.312m-2.24 2.39a4.493 4.493 0 00-1.757 4.306 4.493 4.493 0 004.306-1.758M16.5 9a1.5 1.5 0 11-3 0 1.5 1.5 0 013 0z" />
              </svg>
            </div>
            <h3 class="oc-text-sm" style="font-weight: 600; color: var(--oc-gray-900);">No chore selected</h3>
            <p class="oc-mt-2 oc-text-sm oc-text-gray-500">Select a chore from the sidebar to get started.</p>
          </div>
        <% end %>
      </main>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       chores: [],
       counts: %{},
       selected_chore_module: nil,
       jobs: %{},
       chore_jobs: %{},
       selected_tab: :new
     )}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    router_opts =
      if router = socket.router do
        match_route_opts(router, uri)
      else
        []
      end

    chores =
      ObanChore.Plugin.get_chores()
      |> filter_chores(router_opts)

    pubsub = ObanChore.pubsub_server()

    if connected?(socket) do
      Phoenix.PubSub.subscribe(pubsub, "oban_chore:counts")
    end

    # Fetch initial active jobs and subscribe to them
    # TODO: Avoid N+1 by fetching all active jobs in a single query and grouping them by chore.module
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

    {:noreply,
     assign(socket,
       chores: chores,
       counts: fetch_counts(chores),
       jobs: jobs,
       chore_jobs: chore_jobs
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
    allowed_modules = Enum.map(socket.assigns.chores, & &1.module)

    if worker_module in allowed_modules do
      new_counts = Map.put(socket.assigns.counts, worker_module, count)
      {:noreply, assign(socket, counts: new_counts)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:job_enqueued, job, worker_module}, socket) do
    allowed_modules = Enum.map(socket.assigns.chores, & &1.module)

    if worker_module in allowed_modules do
      pubsub = ObanChore.pubsub_server()

      if connected?(socket) do
        Phoenix.PubSub.subscribe(pubsub, "oban_chore:logs:#{job.id}")
        Phoenix.PubSub.subscribe(pubsub, "oban_chore:status:#{job.id}")
      end

      job = %{
        job
        | state: if(is_binary(job.state), do: String.to_existing_atom(job.state), else: job.state)
      }

      new_jobs = Map.put(socket.assigns.jobs, job.id, job)

      new_chore_jobs =
        Map.update(socket.assigns.chore_jobs, worker_module, [job.id], fn job_ids ->
          if job.id in job_ids, do: job_ids, else: [job.id | job_ids]
        end)

      {:noreply,
       socket
       |> assign(jobs: new_jobs, chore_jobs: new_chore_jobs, selected_tab: {:job, job.id})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:oban_chore_state, job_id, state}, socket) do
    # O(1) update of the flat jobs map, check if job exists in this filtered view
    if Map.has_key?(socket.assigns.jobs, job_id) do
      new_jobs = Map.update!(socket.assigns.jobs, job_id, fn job -> %{job | state: state} end)

      # Forward to JobComponent
      send_update(ObanChoreWeb.JobComponent, id: job_id, new_state: state)

      {:noreply, assign(socket, jobs: new_jobs)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:oban_chore_log, job_id, message}, socket) do
    send_update(ObanChoreWeb.JobComponent, id: job_id, new_log: message)
    {:noreply, socket}
  end

  defp fetch_counts(chores) do
    Map.new(chores, fn chore -> {chore.module, ObanChore.count_running(chore.module, Oban)} end)
  end

  defp match_route_opts(router, uri) do
    parsed_uri = URI.parse(uri)

    case Phoenix.Router.route_info(router, "GET", parsed_uri.path, parsed_uri.host) do
      %{oban_chore_opts: opts} ->
        opts

      _ ->
        []
    end
  end

  defp filter_chores(all_chores, opts) do
    has_chores_opt = Keyword.has_key?(opts, :chores)
    has_tags_opt = Keyword.has_key?(opts, :tags)

    cond do
      has_chores_opt ->
        allowed_modules =
          opts
          |> Keyword.get(:chores, [])
          |> List.wrap()

        Enum.filter(all_chores, fn chore -> chore.module in allowed_modules end)

      has_tags_opt ->
        allowed_tags =
          opts
          |> Keyword.get(:tags, [])
          |> List.wrap()
          |> Enum.map(&to_string/1)

        Enum.filter(all_chores, fn chore ->
          chore_tags =
            Map.get(chore, :tags, [])
            |> Enum.map(&to_string/1)

          Enum.any?(chore_tags, &(&1 in allowed_tags))
        end)

      true ->
        all_chores
    end
  end
end
