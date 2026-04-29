defmodule Insightnest.Contributions.HighlightVote do
  use Ecto.Schema

  alias Insightnest.Contributions.Contribution
  alias Insightnest.Accounts.Member

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "highlight_votes" do
    belongs_to :contribution, Contribution
    belongs_to :voter,        Member

    timestamps(type: :utc_datetime)
  end
end
