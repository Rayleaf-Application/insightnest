defmodule InsightnestWeb.EmailAuthTest do
  # async: false — PasscodeStore is shared ETS state
  use InsightnestWeb.ConnCase, async: false

  alias Insightnest.Accounts
  alias Insightnest.Accounts.PasscodeStore

  defp uemail, do: "user_#{System.unique_integer([:positive])}@example.com"
  defp uname, do: "user#{System.unique_integer([:positive])}"

  # ── POST /auth/email/request ─────────────────────────────────────────────────

  describe "POST /auth/email/request" do
    test "returns ok for a valid email", %{conn: conn} do
      conn = post(conn, "/auth/email/request", %{email: uemail()})
      assert %{"ok" => true} = json_response(conn, 200)
    end

    test "sends a passcode email to the address", %{conn: conn} do
      email = uemail()
      post(conn, "/auth/email/request", %{email: email})
      assert_receive {:email, sent}
      assert sent.subject =~ "sign-in code"
      assert List.first(sent.to) == {"", email}
    end

    test "normalises the address to lowercase before sending", %{conn: conn} do
      email = uemail()
      post(conn, "/auth/email/request", %{email: String.upcase(email)})
      assert_receive {:email, sent}
      assert List.first(sent.to) == {"", email}
    end

    test "always returns ok — no email enumeration", %{conn: conn} do
      # Whether the address belongs to an existing member or not, the response is identical
      {:ok, _} = Accounts.find_or_create_by_email(uemail())
      conn = post(conn, "/auth/email/request", %{email: uemail()})
      assert %{"ok" => true} = json_response(conn, 200)
    end

    test "returns 400 for an empty email string", %{conn: conn} do
      conn = post(conn, "/auth/email/request", %{email: ""})
      assert %{"error" => _} = json_response(conn, 400)
    end

    test "returns 400 when the email param is absent", %{conn: conn} do
      conn = post(conn, "/auth/email/request", %{})
      assert %{"error" => _} = json_response(conn, 400)
    end
  end

  # ── POST /auth/email/verify ──────────────────────────────────────────────────

  describe "POST /auth/email/verify — happy path" do
    test "returns token, member data, and redirect on correct code", %{conn: conn} do
      email = uemail()
      PasscodeStore.put(email, "123456")

      conn = post(conn, "/auth/email/verify", %{email: email, code: "123456"})
      data = json_response(conn, 200)

      assert data["token"] != nil
      assert data["redirect_to"] == "/onboarding"
      assert data["member"]["email"] == email
    end

    test "stores the guardian token in the session", %{conn: conn} do
      email = uemail()
      PasscodeStore.put(email, "123456")

      conn = post(conn, "/auth/email/verify", %{email: email, code: "123456"})
      assert get_session(conn, :guardian_token) != nil
    end

    test "creates a new member on first login", %{conn: conn} do
      email = uemail()
      PasscodeStore.put(email, "123456")
      assert Accounts.get_member_by_email(email) == nil

      post(conn, "/auth/email/verify", %{email: email, code: "123456"})

      assert %{email: ^email} = Accounts.get_member_by_email(email)
    end

    test "marks the member's email as verified", %{conn: conn} do
      email = uemail()
      PasscodeStore.put(email, "123456")

      post(conn, "/auth/email/verify", %{email: email, code: "123456"})

      assert Accounts.get_member_by_email(email).email_verified == true
    end

    test "redirects to / when the member already has a username", %{conn: conn} do
      email = uemail()
      {:ok, member} = Accounts.find_or_create_by_email(email)
      {:ok, _} = Accounts.set_username(member, uname())
      PasscodeStore.put(email, "654321")

      conn = post(conn, "/auth/email/verify", %{email: email, code: "654321"})
      assert json_response(conn, 200)["redirect_to"] == "/"
    end

    test "is idempotent — repeated logins for the same email work fine", %{conn: conn} do
      email = uemail()

      PasscodeStore.put(email, "111111")
      post(conn, "/auth/email/verify", %{email: email, code: "111111"})

      PasscodeStore.put(email, "222222")
      conn2 = post(build_conn(), "/auth/email/verify", %{email: email, code: "222222"})
      assert json_response(conn2, 200)["token"] != nil
    end
  end

  describe "POST /auth/email/verify — error cases" do
    test "returns 401 for a wrong code", %{conn: conn} do
      email = uemail()
      PasscodeStore.put(email, "123456")

      conn = post(conn, "/auth/email/verify", %{email: email, code: "000000"})
      assert json_response(conn, 401)["error"] =~ "Incorrect"
    end

    test "returns 401 when no code was requested for that email", %{conn: conn} do
      conn = post(conn, "/auth/email/verify", %{email: uemail(), code: "123456"})
      assert json_response(conn, 401)["error"] =~ "not found"
    end

    test "code is single-use — second attempt is rejected", %{conn: conn} do
      email = uemail()
      PasscodeStore.put(email, "123456")

      post(conn, "/auth/email/verify", %{email: email, code: "123456"})
      conn2 = post(build_conn(), "/auth/email/verify", %{email: email, code: "123456"})
      assert json_response(conn2, 401)["error"] =~ "not found"
    end

    test "returns 400 when the code param is absent", %{conn: conn} do
      conn = post(conn, "/auth/email/verify", %{email: uemail()})
      assert %{"error" => _} = json_response(conn, 400)
    end

    test "returns 400 when the email param is absent", %{conn: conn} do
      conn = post(conn, "/auth/email/verify", %{code: "123456"})
      assert %{"error" => _} = json_response(conn, 400)
    end
  end

  # ── Full round-trip ──────────────────────────────────────────────────────────

  describe "full email login round-trip" do
    test "request then verify produces a working session", %{conn: conn} do
      email = uemail()

      # Step 1 — request code
      conn1 = post(conn, "/auth/email/request", %{email: email})
      assert %{"ok" => true} = json_response(conn1, 200)
      assert_receive {:email, sent}
      [code] = Regex.run(~r/\b\d{6}\b/, sent.text_body)

      # Step 2 — verify code
      conn2 = post(build_conn(), "/auth/email/verify", %{email: email, code: code})
      data = json_response(conn2, 200)
      assert data["token"] != nil
      assert data["member"]["email"] == email
      assert get_session(conn2, :guardian_token) != nil
    end
  end
end
