defmodule Insightnest.Repo.Migrations.CreateMemberDeletionLogs do
  use Ecto.Migration

  def change do
    create table(:member_deletion_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      # SHA-256 of the wallet address — never the address itself.
      # Used only for abuse-prevention lookups.
      add :wallet_hash, :text
      add :deleted_at, :utc_datetime, null: false
    end

    create index(:member_deletion_logs, [:deleted_at])
  end
end
