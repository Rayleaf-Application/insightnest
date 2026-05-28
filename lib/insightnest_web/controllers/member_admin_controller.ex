defmodule InsightnestWeb.MemberAdminController do
  use InsightnestWeb, :controller

  alias Insightnest.Accounts

  def index(conn, _params) do
    members = Accounts.list_members()
    json(conn, %{members: Enum.map(members, &member_json/1)})
  end

  def update(conn, %{"id" => id} = params) do
    case Accounts.get_member(id) do
      nil ->
        conn |> put_status(404) |> json(%{ok: false, error: "not found"})

      member ->
        case Map.get(params, "founder") do
          true ->
            do_update(conn, Accounts.grant_founder_badge(member))

          false ->
            do_update(conn, Accounts.revoke_founder_badge(member))

          _ ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{ok: false, error: "founder must be true or false"})
        end
    end
  end

  defp do_update(conn, {:ok, member}), do: json(conn, %{ok: true, member: member_json(member)})

  defp do_update(conn, {:error, _changeset}) do
    conn |> put_status(:unprocessable_entity) |> json(%{ok: false, error: "update failed"})
  end

  defp member_json(m) do
    %{
      id: m.id,
      username: m.username,
      wallet_address: m.wallet_address,
      email: m.email,
      founder: m.founder,
      inserted_at: m.inserted_at
    }
  end
end
