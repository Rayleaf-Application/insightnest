defmodule Insightnest.Repo.Migrations.CreateSparks do
  use Ecto.Migration

  def change do
    create table(:sparks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :author_id, references(:members, type: :binary_id, on_delete: :delete_all), null: false
      add :title, :text, null: false
      add :body, :text, null: false
      add :concepts, {:array, :text}, null: false, default: []
      add :status, :text, null: false, default: "draft"
      add :slug, :text
      add :content_hash, :text, null: false
      add :closes_at, :utc_datetime
      add :extension_count, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    # Full-text search
    execute """
              ALTER TABLE sparks
                ADD COLUMN search_vector tsvector
                  GENERATED ALWAYS AS (
                    to_tsvector('english', coalesce(title, '') || ' ' || coalesce(body, ''))
                  ) STORED
            """,
            "ALTER TABLE sparks DROP COLUMN search_vector"

    create unique_index(:sparks, [:slug])
    create index(:sparks, [:author_id])
    create index(:sparks, [:status])
    create index(:sparks, [:inserted_at])

    execute "CREATE INDEX idx_sparks_search ON sparks USING GIN(search_vector)",
            "DROP INDEX IF EXISTS idx_sparks_search"

    # Check constraints
    execute """
              ALTER TABLE sparks
                ADD CONSTRAINT sparks_title_length CHECK (char_length(title) BETWEEN 5 AND 200),
                ADD CONSTRAINT sparks_body_length CHECK (char_length(body) BETWEEN 10 AND 10000),
                ADD CONSTRAINT sparks_status_valid CHECK (status IN ('draft', 'published'))
            """,
            """
              ALTER TABLE sparks
                DROP CONSTRAINT IF EXISTS sparks_title_length,
                DROP CONSTRAINT IF EXISTS sparks_body_length,
                DROP CONSTRAINT IF EXISTS sparks_status_valid
            """
  end
end
