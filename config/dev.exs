import Config

config :insightnest, InsightNest.Repo,
  username: "postgres",
  password: "postgres",
  hostname: System.get_env("DB_HOST", "localhost"),
  database: "insightnest_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :insightnest_web, InsightNestWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev_secret_key_base_at_least_64_chars_long_replace_in_prod_aaaa",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:insightnest, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:insightnest, ~w(--watch)]}
  ]

config :insightnest_web, InsightNestWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/insightnest_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :logger, level: :debug
config :phoenix, :plug_init_mode, :runtime
config :phoenix_live_view, debug_heex_annotations: true, profile_events: true
