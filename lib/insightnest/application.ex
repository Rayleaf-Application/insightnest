defmodule Insightnest.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Database
      Insightnest.Repo,

      # Telemetry
      InsightnestWeb.Telemetry,

      # PubSub — used for real-time Spark/Contribution updates
      {Phoenix.PubSub, name: Insightnest.PubSub},

      # Nonce store — ETS-backed GenServer
      # Swap for NonceStoreRedis in production by changing this line only
      Insightnest.Accounts.NonceStoreETS,

      # Phoenix Endpoint
      InsightnestWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Insightnest.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    InsightnestWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  def publisher do
    # Swap to Insightnest.Publisher.CodexPublisher in Phase 2
    Insightnest.Publisher.NoopPublisher
  end
end
