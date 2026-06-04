defmodule ObanChoreWeb.CoreComponents do
  @moduledoc false

  use Phoenix.Component

  @doc """
  Renders an input with label and error messages.
  """
  attr(:id, :any, default: nil)
  attr(:name, :any)
  attr(:label, :string, default: nil)
  attr(:value, :any)
  attr(:type, :string, default: "text")
  attr(:field, Phoenix.HTML.FormField)
  attr(:errors, :list, default: [])
  attr(:default, :any, default: nil)
  attr(:options, :list, default: [])
  attr(:prompt, :string, default: nil)
  attr(:rest, :global)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(field.errors, &format_error/1))
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value || assigns.default end)
    |> normalize_value()
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name} class="oc-mb-4">
      <label class="oc-checkbox-wrapper">
        <input type="hidden" name={@name} value="false" />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@value}
          class="oc-checkbox"
          {@rest}
        />
        <%= @label %>
      </label>
      <.error_list errors={@errors} />
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name} class="oc-mb-4">
      <.label :if={@label} for={@id}><%= @label %></.label>
      <textarea
        id={@id}
        name={@name}
        class="oc-input"
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
      <.error_list errors={@errors} />
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name} class="oc-mb-4">
      <.label :if={@label} for={@id}><%= @label %></.label>
      <select
        id={@id}
        name={@name}
        class="oc-input"
        {@rest}
      >
        <option :if={@prompt} value=""><%= @prompt %></option>
        <%= Phoenix.HTML.Form.options_for_select(@options, @value) %>
      </select>
      <.error_list errors={@errors} />
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div phx-feedback-for={@name} class="oc-mb-4">
      <.label :if={@label} for={@id}><%= @label %></.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={@value}
        class="oc-input"
        {@rest}
      />
      <.error_list errors={@errors} />
    </div>
    """
  end

  attr(:for, :string, default: nil)
  slot(:inner_block, required: true)

  def label(assigns) do
    ~H"""
    <label for={@for} class="oc-label">
      <%= render_slot(@inner_block) %>
    </label>
    """
  end

  @doc """
  Renders a numeric badge.
  """
  attr(:count, :integer, required: true)
  attr(:class, :string, default: nil)

  def badge(assigns) do
    ~H"""
    <span
      :if={@count > 0}
      class={[
        "oc-badge oc-badge-blue",
        @class
      ]}
    >
      <%= @count %>
    </span>
    """
  end

  @doc """
  Renders a warning banner for duplicate chore execution.
  """
  attr(:on_dismiss, :string, required: true)
  attr(:message, :string, required: true)
  attr(:rest, :global)

  def duplicate_warning_banner(assigns) do
    ~H"""
    <div class="oc-alert-warning" {@rest}>
      <div class="oc-flex">
        <div style="flex-shrink: 0;">
          <svg style="height: 1.25rem; width: 1.25rem; color: var(--oc-amber-400);" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <path
              fill-rule="evenodd"
              d="M8.485 2.495c.673-1.167 2.357-1.167 3.03 0l6.28 10.875c.673 1.167-.17 2.625-1.516 2.625H3.72c-1.347 0-2.189-1.458-1.515-2.625L8.485 2.495zM10 5a.75.75 0 01.75.75v3.5a.75.75 0 01-1.5 0v-3.5A.75.75 0 0110 5zm0 9a1 1 0 100-2 1 1 0 000 2z"
              clip-rule="evenodd"
            />
          </svg>
        </div>
        <div style="margin-left: 0.75rem;">
          <h3 class="oc-alert-warning-title">Duplicate Execution Warning</h3>
          <div class="oc-alert-warning-text">
            <p>
              <%= @message %>
            </p>
          </div>
          <div class="oc-alert-warning-actions">
            <button
              type="button"
              phx-click={@on_dismiss}
              phx-target={Map.get(@rest, :"phx-target")}
              class="oc-btn oc-btn-warning"
            >
              Dismiss
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a toggle for unique execution.
  """
  attr(:id, :string, default: "unique_execution")
  attr(:unique_execution, :boolean, required: true)
  attr(:worker_has_unique, :boolean, required: true)
  attr(:phx_click, :any, default: "toggle_unique")
  attr(:rest, :global)

  def unique_execution_toggle(assigns) do
    ~H"""
    <div class="oc-tooltip-wrapper" {@rest}>
      <input
        type="checkbox"
        id={@id}
        phx-click={if not @worker_has_unique, do: @phx_click}
        phx-target={Map.get(@rest, :"phx-target")}
        checked={@unique_execution}
        disabled={@worker_has_unique}
        class="oc-checkbox"
        style={if(@worker_has_unique, do: "opacity: 0.5; cursor: not-allowed;", else: "cursor: pointer;")}
      />
      <label
        for={@id}
        class="oc-label"
        style={"margin-bottom: 0; select: none; " <> if(@worker_has_unique, do: "opacity: 0.5; cursor: not-allowed;", else: "cursor: pointer;")}
      >
        Unique per args
      </label>
      <div class="oc-tooltip">
        <%= if @worker_has_unique do %>
          Uniqueness is enforced by the worker definition.
        <% else %>
          Uses Oban's uniqueness engine to ensure only one job with these exact arguments can run at a time.
        <% end %>
        <div class="oc-tooltip-arrow"></div>
      </div>
    </div>
    """
  end

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr(:id, :string, doc: "the optional id of flash container")
  attr(:flash, :map, default: %{}, doc: "the map of flash messages to display")
  attr(:title, :string, default: nil)
  attr(:kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup")
  attr(:rest, :global, doc: "the arbitrary HTML attributes to add to the flash container")

  slot(:inner_block, doc: "the optional inner block that renders the flash message")

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={Phoenix.LiveView.JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class={[
        "oc-flash",
        @kind == :info && "oc-flash-info",
        @kind == :error && "oc-flash-error"
      ]}
      {@rest}
    >
      <p :if={@title} class="oc-flex oc-items-center oc-gap-2 oc-text-sm" style="font-weight: 600; line-height: 1.5rem;">
        <svg :if={@kind == :info} style="height: 1rem; width: 1rem;" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a.75.75 0 000 1.5h.253a.25.25 0 01.244.304l-.459 2.066A1.75 1.75 0 0010.747 15H11a.75.75 0 000-1.5h-.253a.25.25 0 01-.244-.304l.459-2.066A1.75 1.75 0 009.253 9H9z" clip-rule="evenodd" /></svg>
        <svg :if={@kind == :error} style="height: 1rem; width: 1rem;" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-5a.75.75 0 01.75.75v4.5a.75.75 0 01-1.5 0v-4.5A.75.75 0 0110 5zm0 10a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd" /></svg>
        <%= @title %>
      </p>
      <p class="oc-mt-2 oc-text-sm" style="line-height: 1.25rem;"><%= msg %></p>
      <button type="button" style="position: absolute; top: 0.25rem; right: 0.25rem; padding: 0.5rem; border: none; background: transparent; cursor: pointer;" aria-label="close">
        <svg style="height: 1.25rem; width: 1.25rem; opacity: 0.4;" viewBox="0 0 20 20" fill="currentColor"><path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" /></svg>
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr(:flash, :map, required: true, doc: "the map of flash messages")
  attr(:id, :string, default: "flash-group", doc: "the optional id of flash container")

  def flash_group(assigns) do
    ~H"""
    <div id={@id}>
      <.flash kind={:info} title="Success!" flash={@flash} />
      <.flash kind={:error} title="Error!" flash={@flash} />
    </div>
    """
  end

  ## JS Commands

  def show(js \\ %Phoenix.LiveView.JS{}, selector) do
    Phoenix.LiveView.JS.show(js,
      to: selector,
      time: 300,
      transition: {"oc-transition-show", "oc-transition-show-start", "oc-transition-show-end"}
    )
  end

  def hide(js \\ %Phoenix.LiveView.JS{}, selector) do
    Phoenix.LiveView.JS.hide(js,
      to: selector,
      time: 200,
      transition: {"oc-transition-hide", "oc-transition-hide-start", "oc-transition-hide-end"}
    )
  end

  defp error_list(assigns) do
    ~H"""
    <%= for msg <- @errors do %>
      <p class="oc-mt-2 oc-text-sm oc-text-red-600 oc-flex oc-gap-2 oc-items-center">
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" style="width: 1rem; height: 1rem;">
          <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-5a.75.75 0 01.75.75v4.5a.75.75 0 01-1.5 0v-4.5A.75.75 0 0110 5zm0 10a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd" />
        </svg>
        <%= msg %>
      </p>
    <% end %>
    """
  end

  defp format_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  defp normalize_value(%{type: "datetime-local", value: %DateTime{} = dt} = assigns) do
    # Format: YYYY-MM-DDTHH:MM
    formatted = dt |> DateTime.to_naive() |> NaiveDateTime.to_iso8601() |> String.slice(0..15)
    assign(assigns, value: formatted)
  end

  defp normalize_value(%{type: "date", value: %Date{} = d} = assigns) do
    assign(assigns, value: Date.to_iso8601(d))
  end

  defp normalize_value(%{type: "time", value: %Time{} = t} = assigns) do
    # Format: HH:MM
    formatted = t |> Time.to_iso8601() |> String.slice(0..4)
    assign(assigns, value: formatted)
  end

  defp normalize_value(assigns), do: assigns
end
