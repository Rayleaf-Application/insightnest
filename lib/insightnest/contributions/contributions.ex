defmodule Insightnest.Contributions do
  import Ecto.Query

  alias Insightnest.Repo
  alias Insightnest.Contributions.Contribution
  alias Insightnest.Sparks
  alias Insightnest.Sparks.Spark

  # ── Queries ──────────────────────────────────────────────────────────────────

  @doc "Returns all active contributions for a spark, oldest first."
  def list_for_spark(spark_id) do
    Contribution
    |> where([c], c.spark_id == ^spark_id and c.status == "active")
    |> order_by([c], asc: c.inserted_at)
    |> preload(:author)
    |> Repo.all()
  end

  @doc "Returns highlighted contributions for a spark."
  def list_highlighted(spark_id) do
    Contribution
    |> where([c], c.spark_id == ^spark_id and c.highlighted == true and c.status == "active")
    |> order_by([c], asc: c.inserted_at)
    |> preload(:author)
    |> Repo.all()
  end

  @doc "Returns true if the member has already contributed to this spark."
  def already_contributed?(spark_id, author_id) do
    Repo.exists?(
      from c in Contribution,
        where: c.spark_id == ^spark_id and c.author_id == ^author_id
    )
  end

  @doc "Returns true if the member has a highlighted contribution on this spark."
  def highlighted_author?(spark_id, member_id) do
    Repo.exists?(
      from c in Contribution,
        where: c.spark_id == ^spark_id
          and c.author_id == ^member_id
          and c.highlighted == true
    )
  end

  # ── Commands ─────────────────────────────────────────────────────────────────

  @doc """
  Creates a contribution.
  Enforces:
    - Spark must be published and open
    - Author cannot contribute to their own spark
    - One contribution per member per spark
  """
  def create_contribution(attrs, spark_id, author_id) do
    spark = Sparks.get_spark!(spark_id)

    cond do
      spark.status != "published" ->
        {:error, :spark_not_published}

      spark.is_closed ->
        {:error, :spark_closed}

      Sparks.author?(spark, author_id) ->
        {:error, :own_spark}

      already_contributed?(spark_id, author_id) ->
        {:error, :already_contributed}

      true ->
        %Contribution{}
        |> Contribution.changeset(
          attrs
          |> Map.put("spark_id", spark_id)
          |> Map.put("author_id", author_id)
        )
        |> Repo.insert()
        |> case do
          {:ok, contribution} ->
            contribution = Repo.preload(contribution, :author)
            # Broadcast to all subscribers of this spark's thread
            Phoenix.PubSub.broadcast(
              Insightnest.PubSub,
              "spark:#{spark_id}",
              {:new_contribution, contribution}
            )
            {:ok, contribution}

          {:error, _} = error ->
            error
        end
    end
  end

  @doc "Soft-deletes a contribution (sets status to hidden). Author only."
  def delete_contribution(contribution_id, author_id) do
    case Repo.get(Contribution, contribution_id) do
      nil ->
        {:error, :not_found}

      %Contribution{author_id: ^author_id} = contribution ->
        contribution
        |> Ecto.Changeset.change(status: "hidden")
        |> Repo.update()

      _ ->
        {:error, :unauthorized}
    end
  end
end
