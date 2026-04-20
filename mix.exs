defmodule Insightnest.MixProject do
  use Mix.Project

  def project do
    [
      app: :insightnest,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader]  # ← add this
    ]
  end

  def application do
    [
      mod: {Insightnest.Application, []},
      extra_applications: [:logger, :runtime_tools, :crypto]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Phoenix
      {:phoenix, "~> 1.8"},
      {:phoenix_ecto, "~> 4.6"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_live_dashboard, "~> 0.8"},

      # Database
      {:ecto_sql, "~> 3.12"},
      {:postgrex, ">= 0.0.0"},

      # Auth
      {:ex_keccak, "~> 0.7"},     # keccak-256, also a NIF but maintained and OTP-27 compatible
      {:guardian, "~> 2.3"},      # JWT
      {:bcrypt_elixir, "~> 3.0"}, # not used for wallet auth, but handy for email passcodes later

      # HTTP
      {:plug_cowboy, "~> 2.7"},
      {:cors_plug, "~> 3.0"},      # for local dev when frontend is separate

      # Utilities
      {:jason, "~> 1.4"},
      {:slugify, "~> 1.3"},        # Slug.slugify/1
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:hackney, "~> 1.9"},
      {:gettext, "~> 0.26"},
      {:swoosh, "~> 1.16"},
      {:finch, "~> 0.18"},   # swoosh needs this for HTTP delivery
      {:bandit, "~> 1.5"},

      # Assets
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:heroicons, "~> 0.5"},

      # Test
      {:floki, ">= 0.30.0", only: :test}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "assets.setup": ["esbuild.install --if-missing"],
      "assets.build": ["cmd tailwindcss --input=assets/css/app.css --output=priv/static/assets/app.css", "esbuild project"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.deploy": [
        "cmd tailwindcss --input=assets/css/app.css --output=priv/static/assets/app.css --minify",
        "esbuild project --minify",
        "phx.digest"
      ],
    ]
  end
end
