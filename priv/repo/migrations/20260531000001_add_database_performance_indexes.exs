defmodule Insightnest.Repo.Migrations.AddDatabasePerformanceIndexes do
  use Ecto.Migration

  def up do
    # GIN index for JSONB @> containment queries on insights.contributors.
    # Enables Library.list_insights_for_member/1 to filter at the DB level
    # rather than loading all published insights into memory.
    execute "CREATE INDEX idx_insights_contributors_gin ON insights USING GIN (contributors jsonb_path_ops)"

    # Partial index covering only highlighted=true rows — a small minority of
    # contributions. Serves list_highlighted/1 and highlighted_author?/2.
    execute """
    CREATE INDEX contributions_spark_highlighted_partial
      ON contributions (spark_id, highlighted)
      WHERE highlighted = true
    """

    # Functional unique index so username_taken?/1 can use an index scan
    # on the lower(username) expression. Usernames are stored lowercase by
    # the changeset, so this also enforces uniqueness across any mixed-case
    # duplicates that could otherwise slip through.
    execute "CREATE UNIQUE INDEX idx_members_username_lower ON members (lower(username))"
  end

  def down do
    execute "DROP INDEX IF EXISTS idx_insights_contributors_gin"
    execute "DROP INDEX IF EXISTS contributions_spark_highlighted_partial"
    execute "DROP INDEX IF EXISTS idx_members_username_lower"
  end
end
