import Config

config :insightnest,
  ecto_repos: [InsightNest.Repo]

config :insightnest_web,
  generators: [timestamp_type: :utc_datetime]

# Guardian JWT config
config :insightnest, InsightNest.Auth.Guardian,
  issuer: "insightnest",
  secret_key: System.get_env("GUARDIAN_SECRET_KEY") || "dev_secret_change_in_prod",
  ttl: {7, :days}

# Nonce store config
config :insightnest,
  nonce_ttl_seconds: 300,           # 5 minutes
  highlight_threshold: 3,
  spark_default_timeout_days: 14,
  spark_max_timeout_days: 90,
  spark_max_extensions: 2

config :insightnest_web, InsightNestWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: InsightNestWeb.ErrorHTML, json: InsightNestWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: InsightNest.PubSub,
  live_view: [signing_salt: "change_me_in_prod"]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
