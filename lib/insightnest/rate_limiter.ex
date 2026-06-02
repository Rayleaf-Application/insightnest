defmodule Insightnest.RateLimiter do
  @moduledoc false

  use GenServer

  @table :insightnest_rate_limit

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Fixed-window counter. Returns :ok if within limit or {:error, :rate_limited} if exceeded.

  `key` should include the action and client identifier, e.g. "nonce:1.2.3.4".
  """
  def check(key, limit, window_seconds) do
    now = System.system_time(:second)
    window_id = div(now, window_seconds)
    ets_key = "#{key}:#{window_id}"
    expires_at = (window_id + 1) * window_seconds

    count = :ets.update_counter(@table, ets_key, {2, 1}, {ets_key, 0, expires_at})

    if count <= limit, do: :ok, else: {:error, :rate_limited}
  end

  @impl GenServer
  def init(_opts) do
    :ets.new(@table, [:set, :public, :named_table, write_concurrency: true])
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
