import Config

config :insightnest,
  ecto_repos: [Insightnest.Repo],
  generators: [timestamp_type: :utc_datetime]

# Guardian JWT config
config :insightnest, Insightnest.Auth.Guardian,
  issuer: "insightnest",
  secret_key: System.get_env("GUARDIAN_SECRET_KEY") || "dev_secret_change_in_prod",
  ttl: {7, :days}

# Platform config
config :insightnest,
  nonce_ttl_seconds: 300,
  highlight_threshold: 3,
  spark_default_timeout_days: 14,
  spark_max_timeout_days: 90,
  spark_max_extensions: 2

config :insightnest, InsightnestWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: InsightnestWeb.ErrorHTML, json: InsightnestWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Insightnest.PubSub,
  live_view: [signing_salt: "change_me_in_prod"]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :esbuild,
  version: "0.25.4",
  insightnest: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :insightnest, Insightnest.Mailer,
  adapter: Swoosh.Adapters.Local
config :swoosh, :api_client, false

import_config "#{config_env()}.exs"
