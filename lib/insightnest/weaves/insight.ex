defmodule Insightnest.Weaves.Insight do
  use Ecto.Schema
  import Ecto.Changeset

  alias Insightnest.Weaves.Weave
  alias Insightnest.Sparks.Spark

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "insights" do
    field :version,      :integer, default: 1
    field :title,        :string
    field :summary,      :string, default: ""
    field :body,         :map
    field :contributors, :map
    field :content_hash, :string
    field :slug,         :string
    field :status,       :string, default: "draft"
    field :codex_cid,    :string

    belongs_to :weave, Weave
    belongs_to :spark, Spark

    timestamps(type: :utc_datetime)
  end

  def changeset(insight, attrs) do
    insight
    |> cast(attrs, [:title, :summary, :body, :contributors, :content_hash,
                    :slug, :status, :codex_cid, :weave_id, :spark_id, :version])
    |> validate_required([:title, :body, :content_hash, :weave_id, :spark_id])
    |> validate_inclusion(:status, ["draft", "published"])
    |> unique_constraint(:slug)
  end

  def update_changeset(insight, attrs) do
    insight
    |> cast(attrs, [:title, :summary, :body])
    |> validate_required([:title])
    |> validate_length(:title, min: 5, max: 200)
  end
end
