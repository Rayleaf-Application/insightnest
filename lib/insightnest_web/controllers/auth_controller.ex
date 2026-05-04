defmodule InsightnestWeb.AuthController do
  use InsightnestWeb, :controller

  alias Insightnest.Accounts
  alias Insightnest.Accounts.PasscodeStore
  alias Insightnest.Accounts.NonceStoreETS, as: NonceStore
  alias Insightnest.Auth.Guardian
  alias InsightnestWeb.UserEmail

  @nonce_ttl Application.compile_env(:insightnest, :nonce_ttl_seconds, 300)

  # ── GET /auth ────────────────────────────────────────────────────────────────

  def index(conn, _params) do
    # If already logged in, redirect to home
    if conn.assigns[:current_member] do
      redirect(conn, to: ~p"/")
    else
      render(conn, :index)
    end
  end

  # ── GET /auth/nonce?address=0x... ────────────────────────────────────────────

  @doc """
  Returns a fresh nonce for the given wallet address.
  The frontend must include this nonce in the SIWE message it constructs.
  """
  def nonce(conn, %{"address" => address}) when byte_size(address) > 0 do
    nonce = generate_nonce()
    :ok = NonceStore.put(address, nonce, @nonce_ttl)

    json(conn, %{nonce: nonce})
  end

  def nonce(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "address parameter is required"})
  end

  # ── POST /auth/verify ─────────────────────────────────────────────────────────

  @doc """
  Verifies a SIWE message + signature.

  Expected body:
    { "message": "<SIWE EIP-4361 plaintext>", "signature": "0x..." }

  On success:
    - Issues a Guardian JWT
    - Stores the token in the session
    - Returns { "token": "...", "member": { ... } }

  On failure:
    - Returns 401 with an error message
  """
  def verify(conn, %{"message" => raw_message, "signature" => signature}) do
    with {:ok, siwe_message} <- parse_siwe(raw_message),
          address = siwe_message.address,
          {:ok, stored_nonce} <- NonceStore.get_and_delete(address),
          :ok <- verify_nonce(siwe_message.nonce, stored_nonce),
          :ok <- verify_signature(raw_message, signature, address),
          {:ok, member} <- Accounts.find_or_create_by_wallet(address),
          {:ok, token, _claims} <- Guardian.encode_and_sign(member) do

      # Redirect to onboarding if username not set yet
      redirect_to = if Accounts.onboarded?(member), do: "/", else: "/onboarding"

      conn
      |> put_session(:guardian_token, token)
      |> json(%{
        token:       token,
        redirect_to: redirect_to,
        member: %{
          id:             member.id,
          wallet_address: member.wallet_address,
          username:       member.username
        }
      })
    else
      {:error, :not_found}  -> auth_error(conn, "Nonce not found — request a new one")
      {:error, :expired}    -> auth_error(conn, "Nonce expired — request a new one")
      {:error, :nonce_mismatch}    -> auth_error(conn, "Nonce mismatch")
      {:error, :invalid_signature} -> auth_error(conn, "Invalid signature")
      {:error, reason}      -> auth_error(conn, "Authentication failed: #{inspect(reason)}")
    end
  end

  def verify(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "message and signature are required"})
  end

  # ── DELETE /auth/logout ───────────────────────────────────────────────────────

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> json(%{ok: true})
  end

  # ── Private ───────────────────────────────────────────────────────────────────

  defp generate_nonce do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end

  # Parse the raw SIWE message string.
  defp parse_siwe(raw_message) do
    Insightnest.Auth.Siwe.parse(raw_message)
  end

  defp verify_nonce(message_nonce, stored_nonce) do
    if message_nonce == stored_nonce do
      :ok
    else
      {:error, :nonce_mismatch}
    end
  end

  # Recover the signer address from the SIWE message + signature.
  defp verify_signature(raw_message, signature, expected_address) do
    Insightnest.Auth.Siwe.verify(raw_message, signature, expected_address)
  end

  # POST /auth/email/request
  def request_passcode(conn, %{"email" => email}) when byte_size(email) > 0 do
    email = String.downcase(String.trim(email))
    code  = Accounts.generate_passcode()
    :ok   = PasscodeStore.put(email, code)

    email
    |> UserEmail.passcode_email(code)
    |> Insightnest.Mailer.deliver()

    # Always return ok — don't leak whether email exists
    json(conn, %{ok: true})
  end

  def request_passcode(conn, _) do
    conn |> put_status(:bad_request) |> json(%{error: "email is required"})
  end

  # POST /auth/email/verify
  def verify_passcode(conn, %{"email" => email, "code" => code}) do
    email = String.downcase(String.trim(email))

    with {:ok, stored} <- PasscodeStore.get_and_delete(email),
         true          <- code == stored,
         {:ok, member} <- Accounts.find_or_create_by_email(email),
         {:ok, member} <- Accounts.verify_email(member),
         {:ok, token, _claims} <- Guardian.encode_and_sign(member) do

      redirect_to = if Accounts.onboarded?(member), do: "/", else: "/onboarding"

      conn
      |> put_session(:guardian_token, token)
      |> json(%{
        token:       token,
        redirect_to: redirect_to,
        member:      %{id: member.id, email: member.email, username: member.username}
      })
    else
      {:error, :not_found} -> auth_error(conn, "Code not found — request a new one")
      {:error, :expired}   -> auth_error(conn, "Code expired — request a new one")
      false                -> auth_error(conn, "Incorrect code")
      {:error, reason}     -> auth_error(conn, "Authentication failed: #{inspect(reason)}")
    end
  end

  def verify_passcode(conn, _) do
    conn |> put_status(:bad_request) |> json(%{error: "email and code are required"})
  end

  defp auth_error(conn, message) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: message})
  end
end
