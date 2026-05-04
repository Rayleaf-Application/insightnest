defmodule Insightnest.Accounts.PasscodeStore do
  @moduledoc """
  ETS-backed passcode store for email login.
  Same supervision pattern as NonceStoreETS.
  Codes expire after 10 minutes.
  """

  use GenServer

  @table :insightnest_passcode_store
  @ttl   600  # 10 minutes in seconds

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def put(email, code) do
    expires_at = System.system_time(:second) + @ttl
    :ets.insert(@table, {normalize(email), code, expires_at})
    :ok
  end

  def get_and_delete(email) do
    key = normalize(email)

    case :ets.lookup(@table, key) do
      [{^key, code, expires_at}] ->
        :ets.delete(@table, key)

        if System.system_time(:second) < expires_at do
          {:ok, code}
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

  defp normalize(email), do: String.downcase(String.trim(email))
  defp schedule_cleanup, do: Process.send_after(self(), :cleanup, :timer.minutes(5))
end
