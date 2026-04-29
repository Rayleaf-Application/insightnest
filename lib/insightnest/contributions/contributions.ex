defmodule Insightnest.Contributions do
  import Ecto.Query

  alias Insightnest.Repo
  alias Insightnest.Contributions.Contribution
  alias Insightnest.Contributions.HighlightVote
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

  # ── Highlights ────────────────────────────────────────────────────────────────

  @highlight_threshold Application.compile_env(:insightnest, :highlight_threshold, 3)

  @doc "Toggles a highlight vote. Returns {:ok, contribution} or {:error, reason}."
  def toggle_highlight(contribution_id, voter_id) do
    contribution = Repo.get!(Contribution, contribution_id)

    existing = Repo.get_by(HighlightVote,
      contribution_id: contribution_id,
      voter_id: voter_id
    )

    if existing do
      remove_highlight_vote(contribution, existing)
    else
      add_highlight_vote(contribution, voter_id)
    end
  end

  @doc "Author override — force highlight on or off regardless of vote count."
  def author_override(contribution_id, spark_author_id, highlighted) do
    contribution = Repo.get!(Contribution, contribution_id) |> Repo.preload(:spark)

    if contribution.spark.author_id != spark_author_id do
      {:error, :unauthorized}
    else
      contribution
      |> Ecto.Changeset.change(highlighted: highlighted, author_override: highlighted)
      |> Repo.update()
      |> broadcast_highlight_update()
    end
  end

  defp add_highlight_vote(contribution, voter_id) do
    Repo.transaction(fn ->
      %HighlightVote{}
      |> Ecto.Changeset.change(contribution_id: contribution.id, voter_id: voter_id)
      |> Repo.insert!(
        on_conflict: :nothing,
        conflict_target: [:contribution_id, :voter_id]
      )

      new_count = contribution.highlight_count + 1
      highlighted =
        if is_nil(contribution.author_override) do
          new_count >= @highlight_threshold
        else
          contribution.highlighted
        end

      contribution
      |> Ecto.Changeset.change(highlight_count: new_count, highlighted: highlighted)
      |> Repo.update!()
    end)
    |> case do
      {:ok, contribution} ->
        broadcast_highlight_update({:ok, contribution})
      {:error, _} = err -> err
    end
  end

  defp remove_highlight_vote(contribution, vote) do
    Repo.transaction(fn ->
      Repo.delete!(vote)

      new_count = max(0, contribution.highlight_count - 1)
      highlighted =
        if is_nil(contribution.author_override) do
          new_count >= @highlight_threshold
        else
          contribution.highlighted
        end

      contribution
      |> Ecto.Changeset.change(highlight_count: new_count, highlighted: highlighted)
      |> Repo.update!()
    end)
    |> case do
      {:ok, contribution} ->
        broadcast_highlight_update({:ok, contribution})
      {:error, _} = err -> err
    end
  end

  defp broadcast_highlight_update({:ok, contribution} = result) do
    contribution = Repo.preload(contribution, :author)
    Phoenix.PubSub.broadcast(
      Insightnest.PubSub,
      "spark:#{contribution.spark_id}",
      {:contribution_updated, contribution}
    )
    result
  end

  defp broadcast_highlight_update(error), do: error

  @doc "Returns true if the voter has voted to highlight this contribution."
  def voted_highlight?(contribution_id, voter_id) do
    Repo.exists?(
      from v in HighlightVote,
        where: v.contribution_id == ^contribution_id and v.voter_id == ^voter_id
    )
  end

  @doc "Returns a map of %{contribution_id => true} for all votes by this voter on this spark."
  def voter_highlights(spark_id, voter_id) do
    from(v in HighlightVote,
      join: c in Contribution,
        on: c.id == v.contribution_id,
      where: c.spark_id == ^spark_id and v.voter_id == ^voter_id,
      select: v.contribution_id
    )
    |> Repo.all()
    |> MapSet.new()
  end
end
