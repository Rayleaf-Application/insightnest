defmodule InsightNest.Accounts.NonceStore do
  @moduledoc """
  Behaviour for nonce storage.
  Swap ETS implementation for Redis in production by changing
  one line in Application.start/2.
  """

  @callback put(address :: String.t(), nonce :: String.t(), ttl_seconds :: integer()) :: :ok
  @callback get_and_delete(address :: String.t()) :: {:ok, String.t()} | {:error, :not_found | :expired}
end
