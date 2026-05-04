defmodule Insightnest.Repo.Migrations.AddEmailVerifiedToMembers do
  use Ecto.Migration

  def change do
    alter table(:members) do
      add :email_verified, :boolean, default: false, null: false
    end
  end
end
