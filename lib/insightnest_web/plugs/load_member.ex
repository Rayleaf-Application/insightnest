defmodule InsightnestWeb.Plugs.LoadMember do
  @moduledoc """
  Soft auth plug — loads current_member if a valid session exists,
  but does NOT halt on failure. Used in the :browser pipeline so
  all pages (including public ones) know whether a member is logged in.
  """

  import Plug.Conn

  alias Insightnest.Auth.Guardian

  def init(opts), do: opts

  def call(conn, _opts) do
    token = get_session(conn, :guardian_token)

    case Guardian.decode_and_verify(token) do
      {:ok, claims} ->
        case Guardian.resource_from_claims(claims) do
          {:ok, member} -> assign(conn, :current_member, member)
          _ -> assign(conn, :current_member, nil)
        end

      _ ->
        assign(conn, :current_member, nil)
    end
  end
end
