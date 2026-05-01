defmodule Insightnest.Repo.Migrations.CreateWeavesAndInsights do
  use Ecto.Migration

  def change do
    create table(:weaves, primary_key: false) do
      add :id,         :binary_id, primary_key: true
      add :spark_id,   references(:sparks,  type: :binary_id, on_delete: :delete_all), null: false
      add :curator_id, references(:members, type: :binary_id, on_delete: :delete_all), null: false
      add :status,     :text, null: false, default: "in_progress"

      timestamps(type: :utc_datetime)
    end

    create index(:weaves, [:spark_id])
    create index(:weaves, [:curator_id])

    execute """
      ALTER TABLE weaves
        ADD CONSTRAINT weaves_status_valid
          CHECK (status IN ('in_progress', 'published', 'abandoned'))
    """,
    "ALTER TABLE weaves DROP CONSTRAINT IF EXISTS weaves_status_valid"

    create table(:insights, primary_key: false) do
      add :id,           :binary_id, primary_key: true
      add :weave_id,     references(:weaves, type: :binary_id, on_delete: :delete_all), null: false
      add :spark_id,     references(:sparks, type: :binary_id, on_delete: :delete_all), null: false
      add :version,      :integer, null: false, default: 1
      add :title,        :text, null: false
      add :summary,      :text, null: false, default: ""
      add :body,         :map, null: false     # JSONB array of body blocks
      add :contributors, :map, null: false     # JSONB contributor shares
      add :content_hash, :text, null: false
      add :slug,         :text
      add :status,       :text, null: false, default: "draft"
      add :codex_cid,    :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:insights, [:slug])
    create index(:insights, [:spark_id])
    create index(:insights, [:status])
    create index(:insights, [:weave_id])

    execute """
      ALTER TABLE insights
        ADD COLUMN search_vector tsvector
          GENERATED ALWAYS AS (
            to_tsvector('english',
              coalesce(title, '') || ' ' || coalesce(summary, ''))
          ) STORED
    """,
    "ALTER TABLE insights DROP COLUMN IF EXISTS search_vector"

    execute "CREATE INDEX idx_insights_search ON insights USING GIN(search_vector)",
            "DROP INDEX IF EXISTS idx_insights_search"

    execute """
      ALTER TABLE insights
        ADD CONSTRAINT insights_status_valid
          CHECK (status IN ('draft', 'published'))
    """,
    "ALTER TABLE insights DROP CONSTRAINT IF EXISTS insights_status_valid"

    create table(:weave_contributions, primary_key: false) do
      add :weave_id,        references(:weaves,        type: :binary_id, on_delete: :delete_all), null: false
      add :contribution_id, references(:contributions,  type: :binary_id, on_delete: :delete_all), null: false
    end

    create unique_index(:weave_contributions, [:weave_id, :contribution_id],
      name: :weave_contributions_pkey
    )
  end
end
