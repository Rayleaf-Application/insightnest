defmodule InsightnestWeb.GardenController do
  use InsightnestWeb, :controller

  plug InsightnestWeb.Plugs.RequireAuth

  alias Insightnest.Accounts

  @doc "GET /garden/export — GDPR Article 20 data portability download."
  def export(conn, _params) do
    member = conn.assigns.current_member
    data = Accounts.export_member_data(member)
    json_bytes = Jason.encode!(data, pretty: true)

    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header(
      "content-disposition",
      "attachment; filename=\"insightnest-data-#{member.username}.json\""
    )
    |> send_resp(200, json_bytes)
  end
end
