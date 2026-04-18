defmodule InsightnestWeb.Live.AuthHooks do
  import Phoenix.LiveView
  import Phoenix.Component

  alias Insightnest.Auth.Guardian

  # Called when registered as: on_mount InsightnestWeb.Live.AuthHooks
  def on_mount(:default, _params, session, socket) do
    {:cont, assign_member(socket, session)}
  end

  def on_mount(:load_member, _params, session, socket) do
    {:cont, assign_member(socket, session)}
  end

  def on_mount(:require_auth, _params, session, socket) do
    socket = assign_member(socket, session)

    if socket.assigns.current_member do
      {:cont, socket}
    else
      {:halt, push_navigate(socket, to: "/auth")}
    end
  end

  defp assign_member(socket, session) do
    case Guardian.decode_and_verify(session["guardian_token"]) do
      {:ok, claims} ->
        case Guardian.resource_from_claims(claims) do
          {:ok, member} -> assign(socket, :current_member, member)
          _ -> assign(socket, :current_member, nil)
        end

      _ ->
        assign(socket, :current_member, nil)
    end
  end
end
