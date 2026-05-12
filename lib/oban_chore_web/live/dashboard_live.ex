defmodule ObanChoreWeb.DashboardLive do
  use Phoenix.LiveView

  @impl true
  def render(assigns) do
    ~H"""
    <div id="oban-chore-dashboard" style="display: flex; gap: 2rem; padding: 1rem;">
      <div style="flex: 1; border-right: 1px solid #ccc; padding-right: 1rem;">
        <h1>ObanChore</h1>
        <h2>Available Chores</h2>
        <ul style="list-style: none; padding: 0;">
          <%= for chore <- @chores do %>
            <li
              phx-click="select_chore"
              phx-value-module={chore.module}
              style={"cursor: pointer; padding: 0.5rem; background: #{if @selected_chore && @selected_chore.module == chore.module, do: "#eee", else: "transparent"}"}
            >
              <strong><%= chore.name %></strong>
            </li>
          <% end %>
        </ul>
      </div>

      <div style="flex: 2;">
        <%= if @selected_chore do %>
          <h2>Run: <%= @selected_chore.name %></h2>
          <.form for={@form} phx-change="validate" phx-submit="execute" style="max-width: 400px;">
            <%= for {field, opts} <- @selected_chore.fields do %>
              <div style="margin-bottom: 1rem;">
                <label style="display: block; font-weight: bold;"><%= Keyword.get(opts, :label, field) %></label>
                <%= render_input(field, opts, @form) %>
                <%= if error = @errors[field] do %>
                  <span style="color: red; font-size: 0.8rem;"><%= error %></span>
                <% end %>
              </div>
            <% end %>
            <button type="submit" style="padding: 0.5rem 1rem; cursor: pointer;">Execute Chore</button>
          </.form>

          <%= if @active_job_id do %>
            <div style="margin-top: 2rem;">
              <h3>Execution Logs</h3>
              <div style="background: #1e1e1e; color: #d4d4d4; padding: 1rem; font-family: monospace; height: 200px; overflow-y: auto; border-radius: 4px;">
                <%= for log <- Enum.reverse(@logs) do %>
                  <div style="margin-bottom: 0.2rem;">> <%= log %></div>
                <% end %>
              </div>
            </div>
          <% end %>
        <% else %>
          <p>Select a chore from the list to get started.</p>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_input(field, opts, form) do
    type = Keyword.get(opts, :type, :string)
    name = "args[#{field}]"
    value = form.params[to_string(field)] || Keyword.get(opts, :default)
    assigns = %{name: name, value: value}

    case type do
      :boolean ->
        ~H|<input type="checkbox" name={@name} checked={@value} />|

      :integer ->
        ~H|<input type="number" name={@name} value={@value} style="width: 100%;" />|

      _ ->
        ~H|<input type="text" name={@name} value={@value} style="width: 100%;" />|
    end
  end

  @impl true
  def mount(_params, _session, socket) do
    chores = ObanChore.Plugin.get_chores()

    {:ok,
     assign(socket,
       chores: chores,
       selected_chore: nil,
       form: to_form(%{}),
       errors: %{},
       logs: [],
       active_job_id: nil
     )}
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
       form: to_form(defaults),
       errors: %{},
       logs: [],
       active_job_id: nil
     )}
  end

  @impl true
  def handle_event("validate", %{"args" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params), errors: %{})}
  end

  @impl true
  def handle_event("execute", %{"args" => params}, socket) do
    chore = socket.assigns.selected_chore
    casted_args = ObanChore.Params.cast(params, chore.fields)

    case ObanChore.Params.validate(casted_args, chore.fields) do
      :ok ->
        case Oban.insert(chore.module.new(casted_args)) do
          {:ok, job} ->
            if pubsub = ObanChore.pubsub_server() do
              Phoenix.PubSub.subscribe(pubsub, "oban_chore:logs:#{job.id}")
            end

            {:noreply,
             socket
             |> put_flash(:info, "Successfully enqueued #{chore.name}")
             |> assign(active_job_id: job.id, logs: [])}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to enqueue #{chore.name}")}
        end

      {:error, errors} ->
        {:noreply, assign(socket, errors: errors)}
    end
  end

  @impl true
  def handle_info({:oban_chore_log, job_id, message}, socket) do
    if job_id == socket.assigns.active_job_id do
      {:noreply, assign(socket, logs: [message | socket.assigns.logs])}
    else
      {:noreply, socket}
    end
  end
end
