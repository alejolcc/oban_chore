defmodule ObanChoreWeb.Layouts do
  @moduledoc """
  Provides layouts for the ObanChore dashboard.
  """
  use Phoenix.Component

  # 1. Resolve the path relative to this file to ensure it works during compilation
  @css_path Path.expand("../../../priv/static/oban_chore.css", __DIR__)

  # 2. Tell the compiler to recompile this module if the CSS file changes
  # https://hexdocs.pm/elixir/Module.html#module-external_resource
  @external_resource @css_path

  # 3. Read the file once during compilation and store it in a module attribute
  @css File.read!(@css_path)

  @doc """
  The layout for the ObanChore dashboard.
  Injected into the host application's root layout.
  """
  def dashboard(assigns) do
    ~H"""
    <style>
      <%= Phoenix.HTML.raw(@css) %>
    </style>
    <div class="oc-wrapper">
      <%= @inner_content %>
    </div>
    """
  end
end
