defmodule Insightnest.Accounts.MemberDeletionLog do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "member_deletion_logs" do
    field :wallet_hash, :string
    field :deleted_at, :utc_datetime
  end
end
