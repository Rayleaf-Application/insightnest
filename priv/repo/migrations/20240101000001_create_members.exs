defmodule Insightnest.Repo.Migrations.CreateMembers do
  use Ecto.Migration

  def change do
    create table(:members, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :wallet_address, :text
      add :email, :text
      add :username, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:members, [:wallet_address])
    create unique_index(:members, [:email])
  end
end
