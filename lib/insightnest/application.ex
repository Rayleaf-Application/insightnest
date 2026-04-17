defmodule InsightNest.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Database
      InsightNest.Repo,

      # Telemetry
      InsightNestWeb.Telemetry,

      # PubSub — used for real-time Spark/Contribution updates
      {Phoenix.PubSub, name: InsightNest.PubSub},

      # Nonce store — ETS-backed GenServer
      # Swap for NonceStoreRedis in production by changing this line only
      InsightNest.Accounts.NonceStoreETS,

      # Phoenix Endpoint
      InsightNestWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: InsightNest.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    InsightNestWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
