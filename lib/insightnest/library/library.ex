defmodule Insightnest.Library do
  import Ecto.Query

  alias Insightnest.Repo
  alias Insightnest.Weaves.Insight

  @doc "Returns all published Insights, newest first."
  def list_insights do
    Insight
    |> where([i], i.status == "published")
    |> order_by([i], desc: i.inserted_at)
    |> preload(weave: :curator, spark: :author)
    |> Repo.all()
  end

  @doc "Full-text search over published Insights."
  def search(query) when is_binary(query) and byte_size(query) > 0 do
    Insight
    |> where([i], i.status == "published")
    |> where([i], fragment("search_vector @@ plainto_tsquery('english', ?)", ^query))
    |> order_by([i], desc: i.inserted_at)
    |> preload(weave: :curator, spark: :author)
    |> Repo.all()
  end

  def search(_), do: list_insights()

  @doc "Returns a published Insight by slug. Raises if not found."
  def get_insight_by_slug!(slug) do
    Insight
    |> where([i], i.slug == ^slug and i.status == "published")
    |> preload(weave: :curator, spark: :author)
    |> Repo.one!()
  end

  @doc "Returns a published Insight by ID. Raises if not found."
  def get_insight!(id) do
    Insight
    |> where([i], i.id == ^id and i.status == "published")
    |> preload(weave: :curator, spark: :author)
    |> Repo.one!()
  end

  @doc "Returns ownership data for an Insight (computed, not on-chain in Phase 0)."
  def get_ownership(insight) do
    shares = get_in(insight.contributors, ["shares"]) || []
    %{
      insight_id:       insight.id,
      token_id:         nil,
      contract_address: nil,
      on_chain:         false,
      shares:           shares
    }
  end
end