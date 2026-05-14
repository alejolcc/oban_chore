defmodule ObanChore.MixProject do
  use Mix.Project

  @version "0.1.1-beta"

  def project do
    [
      app: :oban_chore,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      name: "ObanChore",
      source_url: "https://github.com/alejolcc/oban_chore"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ObanChore.Application, []}
    ]
  end

  defp description do
    "UI-driven operational tools for Oban workers."
  end

  defp package do
    [
      maintainers: ["Alejo <alejo.lcc@gmail.com>"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/alejolcc/oban_chore"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:oban, "~> 2.18"},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_html, "~> 4.3"},
      {:ecto, "~> 3.10"},
      {:ex_doc, "~> 0.31", runtime: false, only: :dev}
    ]
  end
end
