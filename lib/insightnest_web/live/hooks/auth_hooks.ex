defmodule InsightnestWeb.Live.AuthHooks do
  import Phoenix.LiveView
  import Phoenix.Component

  alias Insightnest.Auth.Guardian
  alias Insightnest.Accounts

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

  @doc """
  Requires auth AND completed onboarding (username set).
  Redirects to /onboarding if username is missing.
  """
  def on_mount(:require_onboarded, _params, session, socket) do
    socket = assign_member(socket, session)

    cond do
      is_nil(socket.assigns.current_member) ->
        {:halt, push_navigate(socket, to: "/auth")}

      not Accounts.onboarded?(socket.assigns.current_member) ->
        {:halt, push_navigate(socket, to: "/onboarding")}

      true ->
        {:cont, socket}
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
