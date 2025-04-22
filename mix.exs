defmodule JobHunt.MixProject do
  use Mix.Project

  def project do
    [
      app: :job_hunt,
      version: "0.2.0",
      elixir: "~> 1.18.0",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {JobHunt.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.7.19"},
      {:phoenix_ecto, "~> 4.4"},
      {:live_svelte, "~> 0.16.0"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:html_sanitize_ex, "~> 1.4"},
      {:earmark, "~> 1.4.0"},
      {:earmark_parser, "~> 1.4"},
      {:httpoison, "~> 2.0"},
      {:oban, "~> 2.18"},
      {:yaml_elixir, "~> 2.11.0"},
      {:phoenix_html, "~> 4.0"},
      {:chromic_pdf, "~> 1.17"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0.3"},
      {:floki, ">= 0.37.0"},
      {:tailwind, "~> 0.3.1"},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.5",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.5"},
      {:finch, "~> 0.19"},
      {:gettext, "~> 0.20"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.2"},
      {:instructor, "~> 0.1.0"},
      {:instructor_lite, "~> 0.3.0"},
      {:castore, "~> 1.0"}
    ]
  end

  defp aliases do
    [
      setup: [
        "deps.get",
        "ecto.setup",
        "assets.setup",
        "assets.build",
        "cmd --cd assets npm install"
      ],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing"],
      "assets.build": ["tailwind job_hunt"],
      "assets.deploy": [
        "tailwind job_hunt --minify",
        "cmd --cd assets node build.js --deploy",
        "phx.digest"
      ]
    ]
  end
end
