defmodule ObanChoreWeb.ChoreComponent do
  @moduledoc false
  use Phoenix.LiveComponent
  import ObanChoreWeb.CoreComponents

  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <div class={if @selected, do: "oc-block", else: "oc-hidden"}>
      <div class="oc-container" style="display: flex; flex-direction: column; gap: 1.5rem;">
        <%= if @duplicate_warning do %>
          <.duplicate_warning_banner
            on_dismiss="cancel_execute"
            message="A job with these exact arguments is already running or scheduled. Please uncheck 'Unique per args' to run it anyway."
            phx-target={@myself}
            data-role="duplicate-warning-banner"
          />
        <% end %>

        <div class="oc-card">
          <div class="oc-card-body">
            <.form id={"form-#{@id}"} for={@form} phx-change="validate" phx-submit="execute" phx-target={@myself} data-role="execute-form" style="display: flex; flex-direction: column; gap: 1.5rem;">
              <%= for {field, opts} <- @chore.fields do %>
                <.input
                  id={"#{@id}-#{field}"}
                  field={@form[field]}
                  label={Keyword.get(opts, :label, field)}
                  type={type_to_input_type(Keyword.get(opts, :type))}
                  default={Keyword.get(opts, :default)}
                  options={Keyword.get(opts, :options, [])}
                  prompt={Keyword.get(opts, :prompt)}
                />
              <% end %>

              <div style="border-top: 1px solid var(--oc-gray-200); padding-top: 1.5rem; margin-top: 1.5rem; display: flex; flex-direction: column; gap: 1rem;">
                <div class="oc-form-group">
                  <label class="oc-label">Schedule Execution</label>
                  <div style="display: flex; gap: 1rem; align-items: center; flex-wrap: wrap;">
                    <select
                      name="schedule_type"
                      phx-target={@myself}
                      class="oc-input"
                      style="max-width: 15rem;"
                    >
                      <%= for {label, value} <- [
                            {"Run immediately", "immediately"},
                            {"In 5 minutes", "5_min"},
                            {"In 15 minutes", "15_min"},
                            {"In 30 minutes", "30_min"},
                            {"In 1 hour", "1_hour"},
                            {"In 2 hours", "2_hour"},
                            {"In 12 hours", "12_hour"},
                            {"In 24 hours", "24_hour"},
                            {"Custom delay...", "custom"}
                          ] do %>
                        <option value={value} selected={@schedule_type == value}><%= label %></option>
                      <% end %>
                    </select>

                    <%= if @schedule_type == "custom" do %>
                      <div style="display: flex; align-items: center; gap: 0.5rem;">
                        <input
                          type="number"
                          name="custom_delay_minutes"
                          value={@custom_delay_minutes}
                          phx-target={@myself}
                          class="oc-input"
                          style="max-width: 8rem;"
                          placeholder="Minutes"
                          min="1"
                          required
                        />
                        <span class="oc-text-sm oc-text-gray-500">minutes</span>
                      </div>
                    <% end %>
                  </div>
                </div>

                <div class="oc-flex oc-items-center oc-justify-between oc-gap-2">
                  <.unique_execution_toggle
                    id={"unique-#{@id}"}
                    unique_execution={@unique_execution}
                    worker_has_unique={@chore.unique}
                    phx_click={Phoenix.LiveView.JS.push("toggle_unique", target: @myself)}
                    phx-target={@myself}
                  />
                  <button
                    type="submit"
                    class="oc-btn oc-btn-primary"
                  >
                    <%= if @schedule_type == "immediately", do: "Execute Chore", else: "Schedule Chore" %>
                  </button>
                </div>
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
         unique_execution: chore.unique || true,
         schedule_type: "immediately",
         custom_delay_minutes: 10
       )}
    else
      {:ok, assign(socket, assigns)}
    end
  end

  @impl true
  def handle_event("toggle_unique", _params, socket) do
    {:noreply,
     socket
     |> assign(unique_execution: not socket.assigns.unique_execution)
     |> assign(duplicate_warning: nil)}
  end

  @impl true
  def handle_event("validate", %{"args" => params} = form_params, socket) do
    schedule_type = Map.get(form_params, "schedule_type", socket.assigns.schedule_type)

    custom_delay_minutes =
      Map.get(form_params, "custom_delay_minutes", socket.assigns.custom_delay_minutes)

    changeset =
      socket.assigns.chore.module.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(form: to_form(changeset, as: :args), duplicate_warning: nil)
     |> assign(schedule_type: schedule_type, custom_delay_minutes: custom_delay_minutes)}
  end

  @impl true
  def handle_event("execute", %{"args" => params} = form_params, socket) do
    chore = socket.assigns.chore
    changeset = chore.module.changeset(params)

    schedule_type = Map.get(form_params, "schedule_type", socket.assigns.schedule_type)

    custom_delay_minutes =
      Map.get(form_params, "custom_delay_minutes", socket.assigns.custom_delay_minutes)

    socket =
      socket
      |> assign(schedule_type: schedule_type, custom_delay_minutes: custom_delay_minutes)

    if changeset.valid? do
      casted_args = Ecto.Changeset.apply_changes(changeset)
      has_worker_unique? = socket.assigns.chore.unique

      if not has_worker_unique? and socket.assigns.unique_execution and
           ObanChore.running_with_args?(chore.module, casted_args) do
        {:noreply, assign(socket, duplicate_warning: params)}
      else
        case get_delay_minutes(schedule_type, custom_delay_minutes) do
          {:ok, delay} ->
            perform_execute(socket, chore, casted_args, delay)

          {:error, message} ->
            {:noreply, put_flash(socket, :error, message)}
        end
      end
    else
      {:noreply, assign(socket, form: to_form(Map.put(changeset, :action, :insert), as: :args))}
    end
  end

  @impl true
  def handle_event("cancel_execute", _params, socket) do
    {:noreply, assign(socket, duplicate_warning: nil)}
  end

  defp perform_execute(socket, chore, casted_args, delay) do
    has_worker_unique? = chore.unique

    unique_opts =
      if socket.assigns.unique_execution and not has_worker_unique?,
        do: [unique: [period: :infinity, states: [:available, :scheduled, :executing]]],
        else: []

    opts =
      if delay do
        Keyword.put(unique_opts, :schedule_in, delay * 60)
      else
        unique_opts
      end

    case Oban.insert(chore.module.new(casted_args, opts)) do
      {:ok, %{conflict?: conflict?} = job} ->
        # Notify parent to track this job and switch tab
        send(self(), {:job_enqueued, job, chore.module})

        message =
          cond do
            conflict? -> "Job already running with these arguments"
            delay -> "Successfully scheduled #{chore.name} to run in #{delay} minutes"
            true -> "Successfully enqueued #{chore.name}"
          end

        {:noreply, put_flash(socket, :info, message)}

      {:error, _reason} ->
        Logger.error("Failed to enqueue #{chore.name} with args #{inspect(casted_args)}")
        {:noreply, put_flash(socket, :error, "Failed to enqueue #{chore.name}")}
    end
  end

  defp get_delay_minutes("immediately", _), do: {:ok, nil}
  defp get_delay_minutes("5_min", _), do: {:ok, 5}
  defp get_delay_minutes("15_min", _), do: {:ok, 15}
  defp get_delay_minutes("30_min", _), do: {:ok, 30}
  defp get_delay_minutes("1_hour", _), do: {:ok, 60}
  defp get_delay_minutes("2_hour", _), do: {:ok, 120}
  defp get_delay_minutes("12_hour", _), do: {:ok, 720}
  defp get_delay_minutes("24_hour", _), do: {:ok, 1440}

  defp get_delay_minutes("custom", delay) do
    case parse_integer(delay) do
      {:ok, val} when val > 0 ->
        {:ok, val}

      _ ->
        {:error, "Please enter a valid positive number of minutes for custom delay."}
    end
  end

  defp parse_integer(val) when is_integer(val), do: {:ok, val}

  defp parse_integer(val) when is_binary(val) do
    case Integer.parse(val) do
      {num, ""} -> {:ok, num}
      _ -> :error
    end
  end

  defp parse_integer(_), do: :error

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
