defmodule InsightnestWeb.Plugs.LoadMemberTest do
  use InsightnestWeb.ConnCase, async: true

  alias InsightnestWeb.Plugs.LoadMember

  defp call(conn) do
    LoadMember.call(conn, LoadMember.init([]))
  end

  describe "LoadMember.call/2" do
    test "assigns current_member to nil when no session token is present", %{conn: conn} do
      conn = conn |> init_test_session(%{}) |> call()
      assert conn.assigns[:current_member] == nil
    end

    test "assigns current_member to nil when the token is invalid", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{guardian_token: "not.a.real.jwt"})
        |> call()

      assert conn.assigns[:current_member] == nil
    end

    test "assigns current_member to nil when the token is nil", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{guardian_token: nil})
        |> call()

      assert conn.assigns[:current_member] == nil
    end

    test "assigns current_member when a valid token is in the session", %{conn: conn} do
      member = Insightnest.AccountsFixtures.onboarded_member()

      conn =
        conn
        |> log_in(member)
        |> call()

      assert conn.assigns[:current_member].id == member.id
    end

    test "assigns current_member to nil when the member no longer exists", %{conn: conn} do
      member = Insightnest.AccountsFixtures.onboarded_member()
      authed_conn = log_in(conn, member)

      # Delete the member after issuing the token
      Insightnest.Accounts.delete_member(member)

      conn = authed_conn |> call()
      assert conn.assigns[:current_member] == nil
    end

    test "does not halt the connection regardless of auth state", %{conn: conn} do
      conn = conn |> init_test_session(%{}) |> call()
      refute conn.halted
    end
  end
end
