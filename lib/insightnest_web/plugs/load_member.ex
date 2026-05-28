defmodule InsightnestWeb.Plugs.LoadMember do
  @moduledoc """
  Soft auth plug — loads current_member if a valid session exists,
  but does NOT halt on failure. Used in the :browser pipeline so
  all pages (including public ones) know whether a member is logged in.

  Also handles token prolongation: when fewer than @refresh_threshold_seconds
  remain on the current token a fresh token is issued, the old JTI is revoked,
  and the session is updated transparently.
  """

  import Plug.Conn

  alias Insightnest.Auth.Guardian
  alias Insightnest.Auth.RevokedTokenStore

  # Refresh when less than 3 days remain of the 7-day TTL
  @refresh_threshold_seconds 3 * 24 * 3600

  def init(opts), do: opts

  def call(conn, _opts) do
    token = get_session(conn, :guardian_token)

    case Guardian.decode_and_verify(token) do
      {:ok, claims} ->
        case Guardian.resource_from_claims(claims) do
          {:ok, member} ->
            conn
            |> maybe_prolong_token(member, claims)
            |> assign(:current_member, member)

          _ ->
            assign(conn, :current_member, nil)
        end

      _ ->
        assign(conn, :current_member, nil)
    end
  end

  defp maybe_prolong_token(conn, member, claims) do
    now = System.system_time(:second)
    exp = claims["exp"]

    if is_integer(exp) and exp - now < @refresh_threshold_seconds do
      case Guardian.encode_and_sign(member) do
        {:ok, new_token, _new_claims} ->
          RevokedTokenStore.revoke(claims["jti"], claims["exp"])
          put_session(conn, :guardian_token, new_token)

        _ ->
          conn
      end
    else
      conn
    end
  end
end
