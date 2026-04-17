defmodule InsightNestWeb.AuthController do
  use InsightNestWeb, :controller

  alias InsightNest.Accounts
  alias InsightNest.Accounts.NonceStoreETS, as: NonceStore
  alias InsightNest.Auth.Guardian

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
      conn
      |> put_session(:guardian_token, token)
      |> json(%{
        token: token,
        member: %{
          id: member.id,
          wallet_address: member.wallet_address,
          username: member.username
        }
      })
    else
      {:error, :not_found} ->
        auth_error(conn, "Nonce not found — request a new one")

      {:error, :expired} ->
        auth_error(conn, "Nonce expired — request a new one")

      {:error, :nonce_mismatch} ->
        auth_error(conn, "Nonce mismatch")

      {:error, :invalid_signature} ->
        auth_error(conn, "Invalid signature")

      {:error, reason} ->
        auth_error(conn, "Authentication failed: #{inspect(reason)}")
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

  # Parse the raw SIWE message string using ex_siwe.
  # ExSiwe.parse/1 returns {:ok, %ExSiwe.Message{}} or {:error, reason}
  defp parse_siwe(raw_message) do
    case ExSiwe.parse(raw_message) do
      {:ok, _message} = ok -> ok
      {:error, reason} -> {:error, "Invalid SIWE message: #{reason}"}
    end
  end

  defp verify_nonce(message_nonce, stored_nonce) do
    if message_nonce == stored_nonce do
      :ok
    else
      {:error, :nonce_mismatch}
    end
  end

  # Recover the signer address from the SIWE message + signature.
  # ex_siwe handles this via ExSiwe.verify/2.
  defp verify_signature(raw_message, signature, expected_address) do
    case ExSiwe.verify(raw_message, signature) do
      {:ok, recovered_address} ->
        if String.downcase(recovered_address) == String.downcase(expected_address) do
          :ok
        else
          {:error, :invalid_signature}
        end

      {:error, _} ->
        {:error, :invalid_signature}
    end
  end

  defp auth_error(conn, message) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: message})
  end
end
