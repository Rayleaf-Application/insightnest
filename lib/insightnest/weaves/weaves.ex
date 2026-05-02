defmodule Insightnest.Weaves do
  import Ecto.Query

  alias Insightnest.Repo
  alias Insightnest.Weaves.{Weave, Insight, Weight}
  alias Insightnest.Sparks
  alias Insightnest.Contributions
  alias Insightnest.Application, as: App

  # ── Eligibility ──────────────────────────────────────────────────────────────

  @doc """
  Returns true if the member is eligible to trigger a Weave on this spark.
  Eligible: spark author OR author of a highlighted contribution.
  """
  def eligible_to_weave?(spark_id, member_id) do
    Sparks.author?(spark_id, member_id) or
    Contributions.highlighted_author?(spark_id, member_id)
  end

  # ── Trigger ───────────────────────────────────────────────────────────────────

  @doc """
  Triggers a Weave for the given spark.

  Returns {:ok, %{weave: weave, insight: insight}} or {:error, reason}.
  """
  def trigger_weave(spark_id, curator_id) do
    spark = Sparks.get_spark!(spark_id)
            |> Repo.preload(:author)

    cond do
      not eligible_to_weave?(spark_id, curator_id) ->
        {:error, :not_eligible}

      in_progress_weave_exists?(spark_id) ->
        {:error, :weave_in_progress}

      true ->
        highlighted = Contributions.list_highlighted(spark_id)
                      |> Repo.preload(author: [])

        if highlighted == [] do
          {:error, :no_highlighted_contributions}
        else
          do_trigger(spark, curator_id, highlighted)
        end
    end
  end

  defp do_trigger(spark, curator_id, highlighted) do
    Repo.transaction(fn ->
      # 1. Create weave record
      {:ok, weave} =
        %Weave{}
        |> Ecto.Changeset.change(%{
          spark_id:   spark.id,
          curator_id: curator_id,
          status:     "in_progress"
        })
        |> Repo.insert()

      weave = Repo.preload(weave, :curator)

      # 2. Lock highlights on this spark
      lock_highlights!(spark.id)

      # 3. Build draft insight
      contributors = Weight.compute(spark, weave, highlighted)
      body         = build_draft_body(highlighted)
      content_hash = compute_hash(spark.title, body, spark.id, weave.id)
      slug         = generate_slug(spark.title)

      {:ok, insight} =
        %Insight{}
        |> Insight.changeset(%{
          weave_id:     weave.id,
          spark_id:     spark.id,
          title:        spark.title,
          summary:      "",
          body:         %{"blocks" => body},
          contributors: %{"shares" => contributors},
          content_hash: content_hash,
          slug:         slug,
          status:       "draft"
        })
        |> Repo.insert()

      # 4. Record which contributions are in this weave
      Enum.each(highlighted, fn c ->
        Repo.insert_all("weave_contributions", [
          %{weave_id: weave.id, contribution_id: c.id}
        ])
      end)

      %{weave: weave, insight: insight}
    end)
  end

  # ── Draft editing ─────────────────────────────────────────────────────────────

  @doc "Returns the in-progress insight for a weave, raising if not found."
  def get_draft!(weave_id) do
    Repo.get_by!(Insight, weave_id: weave_id, status: "draft")
  end

  @doc "Updates the draft insight. Curator only."
  def update_draft(%Insight{} = insight, weave, attrs, curator_id) do
    if weave.curator_id != curator_id do
      {:error, :unauthorized}
    else
      insight
      |> Insight.update_changeset(attrs)
      |> Repo.update()
    end
  end

  @doc "Returns the weave by ID with curator preloaded."
  def get_weave!(id) do
    Repo.get!(Weave, id) |> Repo.preload(:curator)
  end

  # ── Queries ───────────────────────────────────────────────────────────────────

  @doc "Returns the in-progress weave for a spark, or nil."
  def in_progress_weave(spark_id) do
    Repo.get_by(Weave, spark_id: spark_id, status: "in_progress")
  end

  defp in_progress_weave_exists?(spark_id) do
    Repo.exists?(
      from w in Weave,
        where: w.spark_id == ^spark_id and w.status == "in_progress"
    )
  end

  # ── Publishing ────────────────────────────────────────────────────────────────

  @doc """
  Publishes a draft Insight. Curator only.

  Steps:
    1. Validate caller is curator
    2. Validate weave is in_progress
    3. Recompute content_hash on final body
    4. Set insight.status = published, weave.status = published
    5. Call Publisher.publish/1 → store CID
    6. Broadcast to library PubSub topic
  """
  def publish_insight(weave_id, curator_id) do
    weave   = get_weave!(weave_id)
    insight = get_draft!(weave_id)

    cond do
      weave.curator_id != curator_id ->
        {:error, :unauthorized}

      weave.status != "in_progress" ->
        {:error, :already_published}

      true ->
        do_publish(weave, insight)
    end
  end

  defp do_publish(weave, insight) do
    Repo.transaction(fn ->
      # Recompute hash on final content
      content_hash = compute_hash(insight.title, insight.body, insight.spark_id, weave.id)

      # Generate final slug from title
      slug = generate_slug(insight.title)

      # Call publisher (NoopPublisher in Phase 0)
      {:ok, cid} = Insightnest.Application.publisher().publish(%{
        id:           insight.id,
        title:        insight.title,
        summary:      insight.summary,
        body:         insight.body,
        contributors: insight.contributors,
        content_hash: content_hash
      })

      # Update insight
      {:ok, published_insight} =
        insight
        |> Insight.changeset(%{
          status:       "published",
          content_hash: content_hash,
          slug:         slug,
          codex_cid:    cid
        })
        |> Repo.update()

      # Update weave
      weave
      |> Ecto.Changeset.change(status: "published")
      |> Repo.update!()

      # Broadcast to library
      Phoenix.PubSub.broadcast(
        Insightnest.PubSub,
        "library",
        {:insight_published, published_insight}
      )

      published_insight
    end)
  end

  # ── Private helpers ───────────────────────────────────────────────────────────

  # Lock highlights: set a flag by checking if a weave is in_progress
  # We don't add a DB column — the check is done in Contributions context.
  # SparkLive.Show hides highlight buttons when weave is in_progress.
  defp lock_highlights!(_spark_id), do: :ok

  defp build_draft_body(contributions) do
    stances_used =
      contributions
      |> Enum.map(& &1.stance)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    if length(stances_used) <= 1 do
      # Flat ordering
      Enum.map(contributions, fn c ->
        %{
          "type"    => "quote",
          "content" => c.body,
          "author"  => c.author.wallet_address,
          "stance"  => c.stance
        }
      end)
    else
      # Grouped by stance with section headers
      section_order  = ["evidence", "expands", "challenges", "question", nil]
      section_labels = %{
        "evidence"   => "Evidence",
        "expands"    => "Expansions",
        "challenges" => "Challenges",
        "question"   => "Open Questions",
        nil          => "Other contributions"
      }

      grouped = Enum.group_by(contributions, & &1.stance)

      section_order
      |> Enum.flat_map(fn stance ->
        cs = Map.get(grouped, stance, [])
        if cs == [] do
          []
        else
          header = %{
            "type"    => "section_header",
            "content" => section_labels[stance]
          }
          quotes = Enum.map(cs, fn c ->
            %{
              "type"    => "quote",
              "content" => c.body,
              "author"  => c.author.wallet_address,
              "stance"  => c.stance
            }
          end)
          [header | quotes]
        end
      end)
    end
  end

  defp compute_hash(title, body, spark_id, weave_id) do
    content = "#{title}|#{inspect(body)}|#{spark_id}|#{weave_id}"
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end

  defp generate_slug(title) do
    base   = Slug.slugify(title) || "insight"
    suffix = :crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower)
    "#{base}-#{suffix}"
  end
end
