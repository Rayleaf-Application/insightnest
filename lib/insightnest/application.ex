# InsightNest - A privacy-focused, community co-owned knowledge platform.
# Copyright (C) 2026 Dzmitry Litmanovich
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

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

      Insightnest.Accounts.PasscodeStore,
      {Finch, name: Insightnest.Finch},

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
