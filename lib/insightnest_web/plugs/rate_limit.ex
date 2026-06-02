defmodule InsightnestWeb.Plugs.RateLimit do
  @moduledoc false

  import Plug.Conn

  alias Insightnest.RateLimiter

  # {max_requests, window_seconds}
  @rules %{
    nonce: {10, 60},
    email_request: {5, 600},
    email_verify: {10, 600},
    waitlist: {5, 3600}
  }

  def init(action), do: action

  def call(conn, action) do
    {limit, window} = Map.fetch!(@rules, action)
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()

    case RateLimiter.check("#{action}:#{ip}", limit, window) do
      :ok ->
        conn

      {:error, :rate_limited} ->
        conn
        |> put_resp_header("retry-after", to_string(window))
        |> put_status(429)
        |> Phoenix.Controller.json(%{error: "Too many requests. Please try again later."})
        |> halt()
    end
  end
end
