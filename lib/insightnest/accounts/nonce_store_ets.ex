defmodule Insightnest.Accounts.NonceStoreETS do
  use GenServer

  @table :insightnest_nonce_store

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def put(address, nonce, ttl_seconds \\ 300) do
    expires_at = System.system_time(:second) + ttl_seconds
    :ets.insert(@table, {String.downcase(address), nonce, expires_at})
    :ok
  end

  def get_and_delete(address) do
    key = String.downcase(address)
    case :ets.lookup(@table, key) do
      [{^key, nonce, expires_at}] ->
        :ets.delete(@table, key)
        if System.system_time(:second) < expires_at do
          {:ok, nonce}
        else
          {:error, :expired}
        end
      [] ->
        {:error, :not_found}
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
    :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])
    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup, do: Process.send_after(self(), :cleanup, :timer.minutes(5))
end
