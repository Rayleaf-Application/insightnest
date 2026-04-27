defmodule Insightnest.Contributions.Contribution do
  use Ecto.Schema
  import Ecto.Changeset

  alias Insightnest.Accounts.Member
  alias Insightnest.Sparks.Spark

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_stances ~w(expands challenges evidence question)

  schema "contributions" do
    field :body,            :string
    field :stance,          :string
    field :status,          :string, default: "active"
    field :highlighted,     :boolean, default: false
    field :highlight_count, :integer, default: 0
    field :author_override, :boolean

    belongs_to :spark,  Spark
    belongs_to :author, Member

    timestamps(type: :utc_datetime)
  end

  def changeset(contribution, attrs) do
    contribution
    |> cast(attrs, [:body, :stance, :status, :spark_id, :author_id])
    |> validate_required([:body, :spark_id, :author_id])
    |> validate_length(:body, min: 10, max: 5000)
    |> validate_inclusion(:stance, @valid_stances, message: "must be one of: expands, challenges, evidence, question")
    |> unique_constraint([:spark_id, :author_id],
        name: :contributions_one_per_member_per_spark,
        message: "you have already contributed to this spark"
      )
    |> foreign_key_constraint(:spark_id)
    |> foreign_key_constraint(:author_id)
  end

  def valid_stances, do: @valid_stances
end
