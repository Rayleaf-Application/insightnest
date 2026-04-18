defmodule Insightnest.Sparks.Spark do
  use Ecto.Schema
  import Ecto.Changeset

  alias Insightnest.Accounts.Member

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "sparks" do
    field :title,           :string
    field :body,            :string
    field :concepts,        {:array, :string}, default: []
    field :status,          :string, default: "draft"
    field :slug,            :string
    field :content_hash,    :string
    field :closes_at,       :utc_datetime
    field :extension_count, :integer, default: 0

    # Computed at read time — not stored
    field :is_closed, :boolean, virtual: true, default: false

    belongs_to :author, Member

    timestamps(type: :utc_datetime)
  end

  @required [:title, :body, :author_id, :content_hash]
  @optional [:concepts, :status, :slug, :closes_at, :extension_count]

  def changeset(spark, attrs) do
    spark
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:title, min: 5, max: 200)
    |> validate_length(:body, min: 10, max: 10_000)
    |> validate_inclusion(:status, ["draft", "published"])
    |> unique_constraint(:slug)
  end

  def publish_changeset(spark) do
    spark
    |> change(status: "published")
    |> validate_inclusion(:status, ["draft", "published"])
  end
end
