defmodule Insightnest.Waitlist.Entry do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "waitlist_entries" do
    field :email, :string
    field :name, :string
    field :reason, :string
    field :status, :string, default: "pending"

    timestamps()
  end

  @valid_statuses ~w(pending approved rejected)

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:email, :name, :reason])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/,
      message: "must be a valid email"
    )
    |> validate_length(:email, max: 200)
    |> validate_length(:name, max: 100)
    |> validate_length(:reason, max: 1000)
    |> unique_constraint(:email)
  end

  def status_changeset(entry, attrs) do
    entry
    |> cast(attrs, [:status])
    |> validate_inclusion(:status, @valid_statuses)
  end
end
