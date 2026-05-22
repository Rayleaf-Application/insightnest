defmodule InsightnestWeb.Plugs.RequireAuthTest do
  use InsightnestWeb.ConnCase, async: true

  alias InsightnestWeb.Plugs.RequireAuth

  defp call(conn) do
    RequireAuth.call(conn, RequireAuth.init([]))
  end

  describe "RequireAuth.call/2" do
    test "assigns current_member and does not halt when token is valid", %{conn: conn} do
      member = Insightnest.AccountsFixtures.onboarded_member()

      conn =
        conn
        |> log_in(member)
        |> call()

      refute conn.halted
      assert conn.assigns[:current_member].id == member.id
    end

    test "halts the connection when no token is present", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> call()

      assert conn.halted
    end

    test "redirects to /auth when no token is present", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> call()

      assert redirected_to(conn) == "/auth"
    end

    test "halts the connection when the token is invalid", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{guardian_token: "invalid.token.here"})
        |> call()

      assert conn.halted
    end

    test "redirects to /auth when the token is invalid", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{guardian_token: "invalid.token.here"})
        |> call()

      assert redirected_to(conn) == "/auth"
    end

    test "halts when the member no longer exists in the database", %{conn: conn} do
      member = Insightnest.AccountsFixtures.onboarded_member()
      authed_conn = log_in(conn, member)

      Insightnest.Accounts.delete_member(member)

      conn = authed_conn |> call()
      assert conn.halted
    end
  end
end
