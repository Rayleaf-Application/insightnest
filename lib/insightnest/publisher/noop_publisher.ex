defmodule Insightnest.Publisher.NoopPublisher do
  @behaviour Insightnest.Publisher

  require Logger

  @impl true
  def publish(insight) do
    cid = "noop:" <> (insight.content_hash |> String.slice(0, 16))
    Logger.info("[noop-publisher] would publish insight #{insight.id} → #{cid}")
    {:ok, cid}
  end
end
