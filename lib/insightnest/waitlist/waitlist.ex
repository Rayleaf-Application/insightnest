defmodule Insightnest.Waitlist do
  import Ecto.Query
  alias Insightnest.Repo
  alias Insightnest.Waitlist.Entry

  def create(attrs) do
    %Entry{}
    |> Entry.changeset(attrs)
    |> Repo.insert()
  end

  def list do
    Entry
    |> order_by([e], desc: e.inserted_at)
    |> Repo.all()
  end

  def get!(id), do: Repo.get!(Entry, id)

  def update_status(id, status) do
    get!(id)
    |> Entry.status_changeset(%{status: status})
    |> Repo.update()
  end

  def delete(id) do
    get!(id)
    |> Repo.delete()
  end

  @doc "Returns true if the email has an approved waitlist entry."
  def approved?(email) do
    email = String.downcase(String.trim(email))
    Repo.exists?(from e in Entry, where: e.email == ^email and e.status == "approved")
  end
end
