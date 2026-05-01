defmodule Insightnest.Publisher do
  @moduledoc """
  Behaviour for publishing Insights to external storage.
  NoopPublisher used in Phase 0.
  CodexPublisher wired in Phase 2.
  """

  @callback publish(insight :: map()) :: {:ok, cid :: String.t()} | {:error, term()}
end
