defmodule ObanChoreWeb.CoreComponents do
  @moduledoc """
  Provides UI components for the ObanChore dashboard.
  """
  use Phoenix.Component

  @doc """
  Renders an input with label and error messages.
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :type, :string, default: "text"
  attr :field, Phoenix.HTML.FormField
  attr :errors, :list, default: []
  attr :default, :any, default: nil
  attr :options, :list, default: []
  attr :prompt, :string, default: nil
  attr :rest, :global

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(field.errors, &format_error/1))
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value || assigns.default end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name} style="margin-bottom: 1rem;">
      <label style="display: flex; align-items: center; gap: 0.5rem; font-weight: bold; cursor: pointer;">
        <input type="hidden" name={@name} value="false" />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@value}
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
    <div phx-feedback-for={@name} style="margin-bottom: 1rem;">
      <.label :if={@label} for={@id}><%= @label %></.label>
      <textarea
        id={@id}
        name={@name}
        style="width: 100%; min-height: 100px; display: block;"
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
      <.error_list errors={@errors} />
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name} style="margin-bottom: 1rem;">
      <.label :if={@label} for={@id}><%= @label %></.label>
      <select id={@id} name={@name} style="width: 100%; display: block;" {@rest}>
        <option :if={@prompt} value=""><%= @prompt %></option>
        <%= Phoenix.HTML.Form.options_for_select(@options, @value) %>
      </select>
      <.error_list errors={@errors} />
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div phx-feedback-for={@name} style="margin-bottom: 1rem;">
      <.label :if={@label} for={@id}><%= @label %></.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={@value}
        style="width: 100%; display: block;"
        {@rest}
      />
      <.error_list errors={@errors} />
    </div>
    """
  end

  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} style="display: block; font-weight: bold; margin-bottom: 0.2rem;">
      <%= render_slot(@inner_block) %>
    </label>
    """
  end

  defp error_list(assigns) do
    ~H"""
    <%= for msg <- @errors do %>
      <span style="color: red; font-size: 0.8rem; display: block; margin-top: 0.2rem;"><%= msg %></span>
    <% end %>
    """
  end

  defp format_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
