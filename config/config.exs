# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :job_hunt,
  ecto_repos: [JobHunt.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure LiveSvelte
config :live_svelte,
  ssr: false,
  esbuild: [
    args: ~w(
      --bundle
      --target=es2021
      --outdir=../priv/static/assets
      --external:/fonts/*
      --external:/images/*
    ),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]


config :job_hunt, Oban,
  repo: JobHunt.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    # {Oban.Plugins.Cron,
    #  crontab: [
    #    {"@daily", JobHunt.Workers.CleanupWorker},
    #    {"0 0 * * *", JobHunt.Workers.MemberUpdater}
    #  ]}
  ],
  queues: [
    seek: 1,
    gemini: 2
  ],
  peer: false,
  timezone: "Australia/Brisbane",
  shutdown_grace_period: :timer.minutes(30)


# Configures the endpoint
config :job_hunt, JobHuntWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: JobHuntWeb.ErrorHTML, json: JobHuntWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: JobHunt.PubSub,
  live_view: [signing_salt: "aj6Qv/be"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :job_hunt, JobHunt.Mailer, adapter: Swoosh.Adapters.Local

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.4",
  job_hunt: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use native JSON parsing in Phoenix
config :phoenix, :json_library, JSON

config :chromic_pdf,
  chrome_executable: "/usr/bin/chromium",
  discard_stderr: false

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
