# priv/repo/migrations/20240101000005_add_username_index.exs
defmodule Insightnest.Repo.Migrations.AddUsernameIndex do
  use Ecto.Migration

  def change do
    create unique_index(:members, [:username])
  end
end
