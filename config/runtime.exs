import Config

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "DATABASE_URL environment variable is missing"

  config :insightnest, InsightNest.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "SECRET_KEY_BASE environment variable is missing"

  guardian_secret =
    System.get_env("GUARDIAN_SECRET_KEY") ||
      raise "GUARDIAN_SECRET_KEY environment variable is missing"

  config :insightnest, InsightNest.Auth.Guardian,
    secret_key: guardian_secret

  config :insightnest_web, InsightNestWeb.Endpoint,
    url: [host: System.get_env("PHX_HOST", "example.com"), port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT", "4000"))],
    secret_key_base: secret_key_base
end
