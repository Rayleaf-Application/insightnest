defmodule Insightnest.Repo.Migrations.AddFounderBadgeToMembers do
  use Ecto.Migration

  def change do
    alter table(:members) do
      add :founder, :boolean, default: false, null: false
    end
  end
end
