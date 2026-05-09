defmodule InsightnestWeb.HealthController do
  use InsightnestWeb, :controller

  def check(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
