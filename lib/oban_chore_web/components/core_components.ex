defmodule ObanChoreWeb.CoreComponents do
  @moduledoc """
  Provides UI components for the ObanChore dashboard.
  """
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
    <div phx-feedback-for={@name} class="mb-4">
      <label class="flex items-center gap-2 font-semibold cursor-pointer text-sm text-gray-700">
        <input type="hidden" name={@name} value="false" />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@value}
          class="h-4 w-4 rounded border-gray-300 text-brand focus:ring-brand"
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
    <div phx-feedback-for={@name} class="mb-4">
      <.label :if={@label} for={@id}><%= @label %></.label>
      <textarea
        id={@id}
        name={@name}
        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-brand focus:ring-brand sm:text-sm min-h-[100px]"
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
      <.error_list errors={@errors} />
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name} class="mb-4">
      <.label :if={@label} for={@id}><%= @label %></.label>
      <select
        id={@id}
        name={@name}
        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-brand focus:ring-brand sm:text-sm"
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
    <div phx-feedback-for={@name} class="mb-4">
      <.label :if={@label} for={@id}><%= @label %></.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={@value}
        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-brand focus:ring-brand sm:text-sm"
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
    <label for={@for} class="block text-sm font-semibold leading-6 text-gray-900 mb-1">
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
        "inline-flex items-center rounded-full bg-blue-50 px-2 py-0.5 text-xs font-medium text-blue-700 ring-1 ring-inset ring-blue-700/10",
        @class
      ]}
    >
      <%= @count %>
    </span>
    """
  end

  defp error_list(assigns) do
    ~H"""
    <%= for msg <- @errors do %>
      <p class="mt-2 text-sm text-red-600 flex gap-1 items-center">
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="w-4 h-4">
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
