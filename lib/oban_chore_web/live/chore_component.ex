defmodule ObanChoreWeb.ChoreComponent do
  use Phoenix.LiveComponent
  import ObanChoreWeb.CoreComponents

  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <div class={if @selected, do: "block", else: "hidden"}>
      <div class="max-w-4xl mx-auto space-y-6">
        <%= if @duplicate_warning do %>
          <.duplicate_warning_banner
            on_confirm="confirm_execute"
            on_cancel="cancel_execute"
            phx-target={@myself}
          />
        <% end %>

        <div class="bg-white shadow-sm ring-1 ring-gray-900/5 sm:rounded-xl">
          <div class="px-4 py-6 sm:p-8">
            <.form for={@form} phx-change="validate" phx-submit="execute" phx-target={@myself} class="space-y-6">
              <%= for {field, opts} <- @chore.fields do %>
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
                <.unique_execution_toggle
                  id={"unique-#{@id}"}
                  unique_execution={@unique_execution}
                  worker_has_unique={@chore.unique}
                  phx_click={Phoenix.LiveView.JS.push("toggle_unique", target: @myself)}
                  phx-target={@myself}
                />
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
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    if socket.assigns[:chore] == nil do
      # Initialization
      chore = assigns.chore

      defaults =
        Enum.into(chore.fields, %{}, fn {name, opts} ->
          {to_string(name), Keyword.get(opts, :default)}
        end)

      {:ok,
       socket
       |> assign(assigns)
       |> assign(
         form: to_form(chore.module.changeset(defaults), as: :args),
         duplicate_warning: nil,
         unique_execution: chore.unique || true
       )}
    else
      {:ok, assign(socket, assigns)}
    end
  end

  @impl true
  def handle_event("toggle_unique", _params, socket) do
    {:noreply, assign(socket, unique_execution: not socket.assigns.unique_execution)}
  end

  @impl true
  def handle_event("validate", %{"args" => params}, socket) do
    changeset =
      socket.assigns.chore.module.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :args), duplicate_warning: nil)}
  end

  @impl true
  def handle_event("execute", %{"args" => params}, socket) do
    chore = socket.assigns.chore
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
    chore = socket.assigns.chore
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
    has_worker_unique? = chore.unique

    opts =
      if socket.assigns.unique_execution and not has_worker_unique?,
        do: [unique: [period: :infinity, states: [:available, :scheduled, :executing]]],
        else: []

    case Oban.insert(chore.module.new(casted_args, opts)) do
      {:ok, %{conflict?: conflict?} = job} ->
        # Notify parent to track this job and switch tab
        send(self(), {:job_enqueued, job, chore.module})

        message =
          if conflict?,
            do: "Job already running with these arguments",
            else: "Successfully enqueued #{chore.name}"

        {:noreply, put_flash(socket, :info, message)}

      {:error, _reason} ->
        Logger.error("Failed to enqueue #{chore.name} with args #{inspect(casted_args)}")
        {:noreply, put_flash(socket, :error, "Failed to enqueue #{chore.name}")}
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
end
