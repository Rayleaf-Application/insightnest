defmodule Insightnest.Repo.Migrations.CreateContributions do
  use Ecto.Migration

  def change do
    create table(:contributions, primary_key: false) do
      add :id,             :binary_id, primary_key: true
      add :spark_id,       references(:sparks, type: :binary_id, on_delete: :delete_all), null: false
      add :author_id,      references(:members, type: :binary_id, on_delete: :delete_all), null: false
      add :body,           :text, null: false
      add :stance,         :text
      add :status,         :text, null: false, default: "active"
      add :highlighted,    :boolean, null: false, default: false
      add :highlight_count, :integer, null: false, default: 0
      add :author_override, :boolean

      timestamps(type: :utc_datetime)
    end

    create index(:contributions, [:spark_id, :inserted_at])
    create index(:contributions, [:author_id])
    create index(:contributions, [:spark_id, :stance])

    execute """
      ALTER TABLE contributions
        ADD CONSTRAINT contributions_body_length
          CHECK (char_length(body) BETWEEN 10 AND 5000),
        ADD CONSTRAINT contributions_status_valid
          CHECK (status IN ('active', 'hidden')),
        ADD CONSTRAINT contributions_stance_valid
          CHECK (stance IN ('expands', 'challenges', 'evidence', 'question'))
    """,
    """
      ALTER TABLE contributions
        DROP CONSTRAINT IF EXISTS contributions_body_length,
        DROP CONSTRAINT IF EXISTS contributions_status_valid,
        DROP CONSTRAINT IF EXISTS contributions_stance_valid
    """

    # One contribution per member per spark
    create unique_index(:contributions, [:spark_id, :author_id],
      name: :contributions_one_per_member_per_spark
    )
  end
end
