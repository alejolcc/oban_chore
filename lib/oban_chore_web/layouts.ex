defmodule ObanChoreWeb.Layouts do
  @moduledoc """
  Provides layouts for the ObanChore dashboard.
  """
  use Phoenix.Component

  @doc """
  The layout for the ObanChore dashboard.
  Injected into the host application's root layout.
  Includes Tailwind CSS via CDN.
  """
  def dashboard(assigns) do
    ~H"""
    <script src="https://cdn.tailwindcss.com"></script>
    <script>
      tailwind.config = {
        theme: {
          extend: {
            colors: {
              brand: "#FD4F00",
            }
          }
        }
      }
    </script>
    <div class="oban-chore-wrapper antialiased text-gray-900">
      <%= @inner_content %>
    </div>
    """
  end
end
