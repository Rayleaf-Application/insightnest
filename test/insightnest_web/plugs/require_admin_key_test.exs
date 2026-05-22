defmodule InsightnestWeb.Plugs.RequireAdminKeyTest do
  use InsightnestWeb.ConnCase, async: true

  alias InsightnestWeb.Plugs.RequireAdminKey

  @test_key "super-secret-admin-key"

  setup do
    Application.put_env(:insightnest, :admin_api_key, @test_key)
    on_exit(fn -> Application.delete_env(:insightnest, :admin_api_key) end)
    :ok
  end

  defp call(conn) do
    RequireAdminKey.call(conn, RequireAdminKey.init([]))
  end

  describe "RequireAdminKey.call/2" do
    test "passes through when the correct key is provided", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-admin-key", @test_key)
        |> call()

      refute conn.halted
    end

    test "returns 401 when no key header is provided", %{conn: conn} do
      conn = call(conn)
      assert conn.halted
      assert conn.status == 401
    end

    test "returns 401 when the key is incorrect", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-admin-key", "wrong-key")
        |> call()

      assert conn.halted
      assert conn.status == 401
    end

    test "401 response body is JSON with an error key", %{conn: conn} do
      conn = call(conn)
      assert %{"error" => "unauthorized"} = Jason.decode!(conn.resp_body)
    end

    test "returns 401 when key is close but not exact", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-admin-key", @test_key <> "x")
        |> call()

      assert conn.halted
      assert conn.status == 401
    end
  end
end
