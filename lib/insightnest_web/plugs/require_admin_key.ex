defmodule InsightnestWeb.Plugs.RequireAdminKey do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    expected = Application.get_env(:insightnest, :admin_api_key, "")
    provided = conn |> get_req_header("x-admin-key") |> List.first("")

    if expected != "" && Plug.Crypto.secure_compare(provided, expected) do
      conn
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(401, Jason.encode!(%{error: "unauthorized"}))
      |> halt()
    end
  end
end
