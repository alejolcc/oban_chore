defmodule ObanChore.MixProject do
  use Mix.Project

  @version "0.2.2"

  def project do
    [
      app: :oban_chore,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      name: "ObanChore",
      source_url: "https://github.com/alejolcc/oban_chore",
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
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
      {:oban, "~> 2.15"},
      {:phoenix_live_view, "~> 0.20 or ~> 1.0"},
      {:phoenix_html, "~> 3.3 or ~> 4.0"},
      {:ecto, "~> 3.0"},
      {:ex_doc, "~> 0.31", runtime: false, only: :dev}
    ]
  end

  defp aliases do
    [publish: ["hex.publish", &git_tag/1]]
  end

  defp git_tag(_args) do
    System.cmd("git", ["tag", "v" <> Mix.Project.config()[:version]])
    System.cmd("git", ["push", "--tags"])
  end
end
