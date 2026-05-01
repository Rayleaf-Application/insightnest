defmodule Insightnest.Weaves.Weave do
  use Ecto.Schema

  alias Insightnest.Sparks.Spark
  alias Insightnest.Accounts.Member

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "weaves" do
    field :status, :string, default: "in_progress"

    belongs_to :spark,   Spark
    belongs_to :curator, Member

    timestamps(type: :utc_datetime)
  end
end
