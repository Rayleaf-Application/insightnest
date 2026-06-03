defmodule Insightnest.BDD.WeaveLifecycleTest do
  use Insightnest.DataCase, async: true
  use Insightnest.BDDCase

  alias Insightnest.AccountsFixtures
  alias Insightnest.Accounts
  alias Insightnest.Contributions
  alias Insightnest.SparksFixtures
  alias Insightnest.Weaves

  # ── Setup helper ──────────────────────────────────────────────────────────────

  # Creates a published spark with one highlighted contribution.
  # Returns %{spark: spark, spark_author: member, contributor: member}
  defp weave_ready_spark(stances \\ ["expands"]) do
    spark = SparksFixtures.published_spark()
    spark_author = Accounts.get_member(spark.author_id)

    highlighted =
      Enum.map(stances, fn stance ->
        contributor = AccountsFixtures.onboarded_member()
        body = String.duplicate("in-depth analysis ", 60)

        {:ok, c} =
          Contributions.create_contribution(
            %{"body" => body, "stance" => stance},
            spark.id,
            contributor.id
          )

        # Highlight threshold is 1 in test env; one vote auto-highlights.
        voter = AccountsFixtures.onboarded_member()
        {:ok, _} = Contributions.toggle_highlight(c.id, voter.id)

        {contributor, c}
      end)

    [{first_contributor, _} | _] = highlighted

    %{
      spark: spark,
      spark_author: spark_author,
      contributor: first_contributor
    }
  end

  # ── Eligibility ───────────────────────────────────────────────────────────────

  scenario "eligibility to trigger a weave" do
    setup do
      ctx = weave_ready_spark()
      {:ok, Map.put(ctx, :outsider, AccountsFixtures.onboarded_member())}
    end

    step "spark author is eligible", %{spark: s, spark_author: a} do
      assert Weaves.eligible_to_weave?(s.id, a.id)
    end

    step "highlighted contributor is eligible", %{spark: s, contributor: c} do
      assert Weaves.eligible_to_weave?(s.id, c.id)
    end

    step "a random member is not eligible", %{spark: s, outsider: o} do
      refute Weaves.eligible_to_weave?(s.id, o.id)
    end
  end

  # ── trigger_weave happy paths ─────────────────────────────────────────────────

  scenario "spark author triggers a weave" do
    setup do
      {:ok, weave_ready_spark()}
    end

    step "returns {:ok, %{weave, insight}}", %{spark: s, spark_author: a} do
      assert {:ok, %{weave: weave, insight: insight}} = Weaves.trigger_weave(s.id, a.id)
      assert weave.spark_id == s.id
      assert weave.curator_id == a.id
      assert insight.spark_id == s.id
    end

    step "weave status is in_progress", %{spark: s, spark_author: a} do
      {:ok, %{weave: weave}} = Weaves.trigger_weave(s.id, a.id)
      assert weave.status == "in_progress"
    end

    step "insight status is draft", %{spark: s, spark_author: a} do
      {:ok, %{insight: insight}} = Weaves.trigger_weave(s.id, a.id)
      assert insight.status == "draft"
    end

    step "draft body contains quote blocks for each contribution", %{spark: s, spark_author: a} do
      {:ok, %{insight: insight}} = Weaves.trigger_weave(s.id, a.id)
      blocks = get_in(insight.body, ["blocks"])
      assert is_list(blocks)
      assert Enum.any?(blocks, &(&1["type"] == "quote"))
    end

    step "insight contributors map is populated", %{spark: s, spark_author: a} do
      {:ok, %{insight: insight}} = Weaves.trigger_weave(s.id, a.id)
      shares = get_in(insight.contributors, ["shares"])
      assert is_list(shares)
      assert length(shares) > 0
    end
  end

  scenario "highlighted contributor triggers a weave as curator" do
    setup do
      {:ok, weave_ready_spark()}
    end

    step "contributor can serve as curator", %{spark: s, contributor: c} do
      assert {:ok, %{weave: weave}} = Weaves.trigger_weave(s.id, c.id)
      assert weave.curator_id == c.id
    end
  end

  # ── trigger_weave error paths ─────────────────────────────────────────────────

  scenario "ineligible member cannot trigger a weave" do
    step "returns {:error, :not_eligible}" do
      spark = SparksFixtures.published_spark()
      outsider = AccountsFixtures.onboarded_member()
      assert {:error, :not_eligible} = Weaves.trigger_weave(spark.id, outsider.id)
    end
  end

  scenario "duplicate weave on the same spark is blocked" do
    setup do
      ctx = weave_ready_spark()
      {:ok, _} = Weaves.trigger_weave(ctx.spark.id, ctx.spark_author.id)
      {:ok, ctx}
    end

    step "returns {:error, :weave_in_progress}", %{spark: s, spark_author: a} do
      assert {:error, :weave_in_progress} = Weaves.trigger_weave(s.id, a.id)
    end
  end

  scenario "no highlighted contributions blocks the weave" do
    step "returns {:error, :no_highlighted_contributions}" do
      spark = SparksFixtures.published_spark()
      author = Accounts.get_member(spark.author_id)
      contributor = AccountsFixtures.onboarded_member()

      # Contribute but do NOT highlight
      Contributions.create_contribution(
        %{"body" => String.duplicate("word ", 60), "stance" => "expands"},
        spark.id,
        contributor.id
      )

      assert {:error, :no_highlighted_contributions} = Weaves.trigger_weave(spark.id, author.id)
    end
  end

  # ── build_draft_body grouping ─────────────────────────────────────────────────

  scenario "single-stance contributions produce no section headers" do
    setup do
      {:ok, weave_ready_spark(["evidence", "evidence", "evidence"])}
    end

    step "all blocks are quotes", %{spark: s, spark_author: a} do
      {:ok, %{insight: insight}} = Weaves.trigger_weave(s.id, a.id)
      blocks = get_in(insight.body, ["blocks"])
      assert Enum.all?(blocks, &(&1["type"] == "quote"))
    end
  end

  scenario "multi-stance contributions produce section headers" do
    setup do
      {:ok, weave_ready_spark(["evidence", "challenges"])}
    end

    step "blocks include section_header separators", %{spark: s, spark_author: a} do
      {:ok, %{insight: insight}} = Weaves.trigger_weave(s.id, a.id)
      blocks = get_in(insight.body, ["blocks"])
      types = Enum.map(blocks, & &1["type"])
      assert "section_header" in types
      assert "quote" in types
    end

    step "section headers appear before their quote groups", %{spark: s, spark_author: a} do
      {:ok, %{insight: insight}} = Weaves.trigger_weave(s.id, a.id)
      blocks = get_in(insight.body, ["blocks"])
      first = hd(blocks)
      assert first["type"] == "section_header"
    end
  end

  # ── in_progress_weave ─────────────────────────────────────────────────────────

  scenario "in_progress_weave query" do
    step "returns nil before any weave is triggered" do
      spark = SparksFixtures.published_spark()
      assert Weaves.in_progress_weave(spark.id) == nil
    end

    step "returns the weave after it is triggered" do
      ctx = weave_ready_spark()
      {:ok, %{weave: weave}} = Weaves.trigger_weave(ctx.spark.id, ctx.spark_author.id)
      result = Weaves.in_progress_weave(ctx.spark.id)
      assert result.id == weave.id
    end
  end

  # ── update_draft ──────────────────────────────────────────────────────────────

  scenario "curator updates the draft insight" do
    setup do
      ctx = weave_ready_spark()

      {:ok, %{weave: weave, insight: insight}} =
        Weaves.trigger_weave(ctx.spark.id, ctx.spark_author.id)

      {:ok, Map.merge(ctx, %{weave: weave, insight: insight})}
    end

    step "curator can update the summary", %{weave: w, insight: i, spark_author: a} do
      assert {:ok, updated} =
               Weaves.update_draft(
                 i,
                 w,
                 %{"title" => i.title, "summary" => "A refined synthesis."},
                 a.id
               )

      assert updated.summary == "A refined synthesis."
    end

    step "curator can update the title", %{weave: w, insight: i, spark_author: a} do
      assert {:ok, updated} =
               Weaves.update_draft(i, w, %{"title" => "Updated Insight Title"}, a.id)

      assert updated.title == "Updated Insight Title"
    end

    step "non-curator gets :unauthorized", %{weave: w, insight: i} do
      outsider = AccountsFixtures.onboarded_member()

      assert {:error, :unauthorized} =
               Weaves.update_draft(i, w, %{"title" => i.title, "summary" => "hack"}, outsider.id)
    end
  end

  # ── publish_insight ───────────────────────────────────────────────────────────

  scenario "curator publishes the draft insight" do
    setup do
      ctx = weave_ready_spark()

      {:ok, %{weave: weave}} =
        Weaves.trigger_weave(ctx.spark.id, ctx.spark_author.id)

      {:ok, Map.put(ctx, :weave, weave)}
    end

    step "curator can publish and receives a published insight", %{weave: w, spark_author: a} do
      assert {:ok, insight} = Weaves.publish_insight(w.id, a.id)
      assert insight.status == "published"
      assert is_binary(insight.codex_cid)
    end

    step "weave status becomes published after the insight is published",
         %{weave: w, spark_author: a} do
      {:ok, _} = Weaves.publish_insight(w.id, a.id)
      weave = Weaves.get_weave!(w.id)
      assert weave.status == "published"
    end

    step "non-curator gets :unauthorized", %{weave: w} do
      outsider = AccountsFixtures.onboarded_member()
      assert {:error, :unauthorized} = Weaves.publish_insight(w.id, outsider.id)
    end
  end
end
