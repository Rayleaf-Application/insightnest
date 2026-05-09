defmodule Insightnest.Repo.Migrations.CreateWaitlistEntries do
  use Ecto.Migration

  def change do
    create table(:waitlist_entries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :name, :string
      add :reason, :text
      add :status, :string, null: false, default: "pending"

      timestamps()
    end

    create unique_index(:waitlist_entries, [:email])
    create index(:waitlist_entries, [:status])
  end
end
