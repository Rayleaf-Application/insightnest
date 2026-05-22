defmodule InsightnestWeb.AuthControllerTest do
  # async: false — tests share the ETS-backed NonceStore and PasscodeStore.
  use InsightnestWeb.ConnCase, async: false

  alias Insightnest.Accounts
  alias Insightnest.Accounts.NonceStoreETS, as: NonceStore
  alias Insightnest.Accounts.PasscodeStore

  @address "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  defp siwe_message(address, nonce) do
    """
    localhost wants you to sign in with your Ethereum account:
    #{address}

    Sign in to InsightNest

    URI: http://localhost:4000
    Version: 1
    Chain ID: 1
    Nonce: #{nonce}
    Issued At: 2026-01-01T00:00:00.000Z
    """
    |> String.trim()
  end

  defp random_valid_sig do
    # A correctly-encoded 65-byte signature that is cryptographically invalid.
    "0x" <> Base.encode16(:crypto.strong_rand_bytes(65), case: :lower)
  end

  # ── GET /auth/nonce ───────────────────────────────────────────────────────────

  describe "GET /auth/nonce" do
    test "returns a nonce for a valid address", %{conn: conn} do
      conn = get(conn, ~p"/auth/nonce", %{"address" => @address})
      assert %{"nonce" => nonce} = json_response(conn, 200)
      assert is_binary(nonce) and byte_size(nonce) > 0
    end

    test "returns 400 when address parameter is missing", %{conn: conn} do
      conn = get(conn, ~p"/auth/nonce")
      assert %{"error" => _} = json_response(conn, 400)
    end

    test "returns 400 when address is an empty string", %{conn: conn} do
      conn = get(conn, ~p"/auth/nonce", %{"address" => ""})
      assert %{"error" => _} = json_response(conn, 400)
    end
  end

  # ── POST /auth/verify ─────────────────────────────────────────────────────────

  describe "POST /auth/verify" do
    test "returns 400 when params are missing", %{conn: conn} do
      conn = post(conn, ~p"/auth/verify", %{})
      assert %{"error" => _} = json_response(conn, 400)
    end

    test "returns 401 when nonce has not been requested for the address", %{conn: conn} do
      conn =
        post(conn, ~p"/auth/verify", %{
          "message" => siwe_message(@address, "nosuchnonce"),
          "signature" => random_valid_sig()
        })

      assert %{"error" => msg} = json_response(conn, 401)
      assert msg =~ "Nonce not found"
    end

    test "returns 401 when the nonce in the message does not match the stored nonce", %{
      conn: conn
    } do
      :ok = NonceStore.put(@address, "stored_nonce", 300)

      conn =
        post(conn, ~p"/auth/verify", %{
          "message" => siwe_message(@address, "different_nonce"),
          "signature" => random_valid_sig()
        })

      assert %{"error" => msg} = json_response(conn, 401)
      assert msg =~ "Nonce"
    end

    test "returns 401 when the signature is invalid for the message", %{conn: conn} do
      nonce = "test_nonce_#{System.unique_integer()}"
      :ok = NonceStore.put(@address, nonce, 300)

      conn =
        post(conn, ~p"/auth/verify", %{
          "message" => siwe_message(@address, nonce),
          "signature" => random_valid_sig()
        })

      assert %{"error" => _} = json_response(conn, 401)
    end
  end

  # ── DELETE /auth/logout ───────────────────────────────────────────────────────

  describe "DELETE /auth/logout" do
    test "returns ok and clears the session", %{conn: conn} do
      member = Insightnest.AccountsFixtures.onboarded_member()
      conn = log_in(conn, member)
      conn = delete(conn, ~p"/auth/logout")
      assert %{"ok" => true} = json_response(conn, 200)
    end

    test "also succeeds when not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/auth/logout")
      assert %{"ok" => true} = json_response(conn, 200)
    end
  end

  # ── GET /auth/delete_redirect ────────────────────────────────────────────────

  describe "GET /auth/delete_redirect" do
    test "redirects to / and clears the session", %{conn: conn} do
      member = Insightnest.AccountsFixtures.onboarded_member()
      conn = log_in(conn, member)

      # delete_redirect goes through the :browser pipeline (has session + flash)
      conn = get(conn, ~p"/auth/delete_redirect")
      assert redirected_to(conn) == "/"
    end
  end

  # ── POST /auth/email/request ──────────────────────────────────────────────────

  describe "POST /auth/email/request" do
    test "returns 400 when email parameter is missing", %{conn: conn} do
      conn = post(conn, ~p"/auth/email/request", %{})
      assert %{"error" => _} = json_response(conn, 400)
    end

    test "returns 400 when email is an empty string", %{conn: conn} do
      conn = post(conn, ~p"/auth/email/request", %{"email" => ""})
      assert %{"error" => _} = json_response(conn, 400)
    end

    test "returns ok:true for a valid email (does not reveal delivery status)", %{conn: conn} do
      conn = post(conn, ~p"/auth/email/request", %{"email" => "user@example.com"})
      assert %{"ok" => true} = json_response(conn, 200)
    end
  end

  # ── POST /auth/email/verify ───────────────────────────────────────────────────

  describe "POST /auth/email/verify" do
    test "returns 400 when params are missing", %{conn: conn} do
      conn = post(conn, ~p"/auth/email/verify", %{})
      assert %{"error" => _} = json_response(conn, 400)
    end

    test "returns 401 when no code has been requested for the email", %{conn: conn} do
      conn =
        post(conn, ~p"/auth/email/verify", %{
          "email" => "nobody@example.com",
          "code" => "123456"
        })

      assert %{"error" => msg} = json_response(conn, 401)
      assert msg =~ "Code not found"
    end

    test "returns 401 when the code is incorrect", %{conn: conn} do
      email = "test_#{System.unique_integer()}@example.com"
      :ok = PasscodeStore.put(email, "correct_code")

      conn =
        post(conn, ~p"/auth/email/verify", %{
          "email" => email,
          "code" => "wrong_code"
        })

      assert %{"error" => _} = json_response(conn, 401)
    end

    test "returns a JWT token when the correct code is submitted", %{conn: conn} do
      email = "test_#{System.unique_integer()}@example.com"
      code = Accounts.generate_passcode()
      :ok = PasscodeStore.put(email, code)

      conn =
        post(conn, ~p"/auth/email/verify", %{
          "email" => email,
          "code" => code
        })

      assert %{"token" => token, "redirect_to" => _} = json_response(conn, 200)
      assert is_binary(token)
    end

    test "email is normalised before lookup (case + whitespace)", %{conn: conn} do
      email = "  User_#{System.unique_integer()}@Example.COM  "
      normalised = String.downcase(String.trim(email))
      code = Accounts.generate_passcode()
      :ok = PasscodeStore.put(normalised, code)

      conn =
        post(conn, ~p"/auth/email/verify", %{
          "email" => email,
          "code" => code
        })

      assert %{"token" => _} = json_response(conn, 200)
    end

    test "new member is redirected to onboarding", %{conn: conn} do
      email = "newbie_#{System.unique_integer()}@example.com"
      code = Accounts.generate_passcode()
      :ok = PasscodeStore.put(email, code)

      conn = post(conn, ~p"/auth/email/verify", %{"email" => email, "code" => code})
      assert %{"redirect_to" => "/onboarding"} = json_response(conn, 200)
    end

    test "returning member with username is redirected to library", %{conn: conn} do
      email = "returner_#{System.unique_integer()}@example.com"

      # Pre-create and onboard the member
      {:ok, member} = Accounts.find_or_create_by_email(email)
      {:ok, _} = Accounts.set_username(member, "user_#{System.unique_integer()}")

      code = Accounts.generate_passcode()
      :ok = PasscodeStore.put(email, code)

      conn = post(conn, ~p"/auth/email/verify", %{"email" => email, "code" => code})
      assert %{"redirect_to" => "/library"} = json_response(conn, 200)
    end
  end
end
