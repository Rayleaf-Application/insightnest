defmodule Insightnest.Repo.Migrations.CreateHighlightVotes do
  use Ecto.Migration

  def change do
    create table(:highlight_votes, primary_key: false) do
      add :id,              :binary_id, primary_key: true
      add :contribution_id, references(:contributions, type: :binary_id, on_delete: :delete_all), null: false
      add :voter_id,        references(:members, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:highlight_votes, [:contribution_id, :voter_id],
      name: :highlight_votes_one_per_voter
    )
    create index(:highlight_votes, [:contribution_id])
  end
end
