defmodule ObanChoreWeb.Layouts do
  @moduledoc """
  Provides layouts for the ObanChore dashboard.
  """
  use Phoenix.Component

  @doc """
  The layout for the ObanChore dashboard.
  Injected into the host application's root layout.
  """
  def dashboard(assigns) do
    ~H"""
    <style>
      <%= Phoenix.HTML.raw(File.read!(Path.join(:code.priv_dir(:oban_chore), "static/oban_chore.css"))) %>
    </style>
    <div class="oc-wrapper">
      <%= @inner_content %>
    </div>
    """
  end
end
