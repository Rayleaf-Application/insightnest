defmodule Insightnest.Auth.RevokedTokenStore do
  @moduledoc false

  use GenServer

  @table :insightnest_revoked_tokens

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Marks a JWT JTI as revoked until its original expiry (Unix timestamp)."
  def revoke(jti, exp) when is_binary(jti) and is_integer(exp) do
    :ets.insert(@table, {jti, exp})
    :ok
  end

  def revoke(_, _), do: :ok

  @doc "Returns true if the JTI is in the revocation list and the original token hasn't expired."
  def revoked?(nil), do: false

  def revoked?(jti) when is_binary(jti) do
    now = System.system_time(:second)

    case :ets.lookup(@table, jti) do
      [{^jti, exp}] when exp > now -> true
      _ -> false
    end
  end

  @impl GenServer
  def init(_opts) do
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    schedule_cleanup()
    {:ok, %{}}
  end

  @impl GenServer
  def handle_info(:cleanup, state) do
    now = System.system_time(:second)
    :ets.select_delete(@table, [{{:_, :"$1"}, [{:=<, :"$1", now}], [true]}])
    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup, do: Process.send_after(self(), :cleanup, :timer.minutes(30))
end
