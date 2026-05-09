defmodule InsightnestWeb.WaitlistController do
  use InsightnestWeb, :controller
  alias Insightnest.Waitlist

  # ── Public ────────────────────────────────────────────────────────────────────

  def signup(conn, params) do
    attrs = Map.take(params, ["email", "name", "reason"])

    case Waitlist.create(attrs) do
      {:ok, entry} ->
        conn
        |> put_status(:created)
        |> json(%{ok: true, id: entry.id})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{ok: false, errors: format_errors(changeset)})
    end
  end

  # ── Admin ─────────────────────────────────────────────────────────────────────

  def index(conn, _params) do
    entries = Waitlist.list()
    json(conn, %{entries: Enum.map(entries, &entry_json/1)})
  end

  def update(conn, %{"id" => id} = params) do
    status = Map.get(params, "status")

    case Waitlist.update_status(id, status) do
      {:ok, entry} ->
        json(conn, %{ok: true, entry: entry_json(entry)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{ok: false, errors: format_errors(changeset)})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Waitlist.delete(id) do
      {:ok, _} -> json(conn, %{ok: true})
      {:error, _} -> conn |> put_status(404) |> json(%{ok: false})
    end
  end

  # ── Private ───────────────────────────────────────────────────────────────────

  defp entry_json(e) do
    %{
      id: e.id,
      email: e.email,
      name: e.name,
      reason: e.reason,
      status: e.status,
      inserted_at: e.inserted_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
