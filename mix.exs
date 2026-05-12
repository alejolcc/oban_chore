defmodule ObanChore.MixProject do
  use Mix.Project

  def project do
    [
      app: :oban_chore,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ObanChore.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:oban, "~> 2.18"},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_html, "~> 4.3"},
      {:ecto, "~> 3.10"}
    ]
  end
end
