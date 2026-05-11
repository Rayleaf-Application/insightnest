import Config

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "DATABASE_URL environment variable is missing"

  config :insightnest, Insightnest.Repo,
    url: database_url,
    ssl: [verify: :verify_none],
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "SECRET_KEY_BASE environment variable is missing"

  guardian_secret =
    System.get_env("GUARDIAN_SECRET_KEY") ||
      raise "GUARDIAN_SECRET_KEY environment variable is missing"

  live_view_salt =
    System.get_env("LIVE_VIEW_SIGN_SALT") ||
      raise "LIVE_VIEW_SIGN_SALT environment variable is missing"

  host =
    System.get_env("PHX_HOST") ||
      raise "PHX_HOST environment variable is missing"

  config :insightnest, Insightnest.Auth.Guardian, secret_key: guardian_secret

  admin_api_key =
    System.get_env("ADMIN_API_KEY") ||
      raise "ADMIN_API_KEY environment variable is missing"

  config :insightnest, :admin_api_key, admin_api_key

  # Mailer — Mailtrap sending API
  mailtrap_token =
    System.get_env("MAILTRAP_API_TOKEN") ||
      raise "MAILTRAP_API_TOKEN environment variable is missing"

  config :insightnest, Insightnest.Mailer,
    adapter: Swoosh.Adapters.Mailtrap,
    api_key: mailtrap_token

  config :swoosh, :api_client, Swoosh.ApiClient.Finch

  config :insightnest, InsightnestWeb.Endpoint,
    server: true,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT", "4000"))],
    secret_key_base: secret_key_base,
    live_view: [signing_salt: live_view_salt]
end
