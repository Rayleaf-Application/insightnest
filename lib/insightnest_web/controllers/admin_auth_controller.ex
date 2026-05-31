defmodule InsightnestWeb.AdminAuthController do
  use InsightnestWeb, :controller

  def login(conn, _params) do
    render(conn, :login, error: nil)
  end

  def do_login(conn, %{"key" => key}) do
    expected = Application.get_env(:insightnest, :admin_api_key, "")

    if expected != "" && key == expected do
      conn
      |> put_session(:admin_authenticated, true)
      |> redirect(to: "/admin")
    else
      render(conn, :login, error: "Invalid admin key.")
    end
  end

  def logout(conn, _params) do
    conn
    |> delete_session(:admin_authenticated)
    |> redirect(to: "/admin/login")
  end
end
