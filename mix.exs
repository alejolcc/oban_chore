defmodule ObanChore.MixProject do
  use Mix.Project

  @version "0.3.4"

  def project do
    [
      app: :oban_chore,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      name: "ObanChore",
      source_url: "https://github.com/alejolcc/oban_chore",
      docs: [
        main: "README",
        extras: ["README.md"]
      ],
      aliases: aliases()
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

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
      links: %{"GitHub" => "https://github.com/alejolcc/oban_chore"},
      files: ~w(lib priv mix.exs README.md LICENSE)
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:oban, "~> 2.15"},
      {:phoenix_live_view, "~> 0.20 or ~> 1.0"},
      {:phoenix_html, "~> 3.3 or ~> 4.0"},
      {:phoenix_ecto, "~> 4.5"},
      {:jason, "~> 1.2", only: :test},
      {:ecto, "~> 3.10"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0", only: :test},
      {:ex_doc, "~> 0.31", runtime: false, only: :dev},
      {:lazy_html, ">= 0.1.0", only: :test}
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
