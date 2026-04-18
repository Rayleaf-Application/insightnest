defmodule InsightnestWeb.Plugs.RequireAuth do
  @moduledoc """
  Plug that reads the JWT from the session and assigns current_member.
  Used in the :authenticated pipeline for all protected routes.

  On failure: redirects to /auth with a flash message.
  On success: assigns conn.assigns.current_member.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2, put_flash: 3]

  alias Insightnest.Auth.Guardian

  def init(opts), do: opts

  def call(conn, _opts) do
    token = get_session(conn, :guardian_token)

    case Guardian.decode_and_verify(token) do
      {:ok, claims} ->
        case Guardian.resource_from_claims(claims) do
          {:ok, member} ->
            conn
            |> assign(:current_member, member)

          {:error, _} ->
            unauthorized(conn)
        end

      {:error, _} ->
        unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_flash(:error, "You must be signed in to access this page.")
    |> redirect(to: "/auth")
    |> halt()
  end
end
