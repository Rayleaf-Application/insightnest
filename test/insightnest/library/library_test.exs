defmodule Insightnest.LibraryTest do
  use Insightnest.DataCase, async: true

  alias Insightnest.AccountsFixtures
  alias Insightnest.Accounts
  alias Insightnest.Contributions
  alias Insightnest.Library
  alias Insightnest.SparksFixtures
  alias Insightnest.Weaves

  # ── Fixture helper ────────────────────────────────────────────────────────────

  # Creates and publishes a full insight via the production weave flow.
  # Accepts optional spark attrs (e.g., %{title: "Custom Title"}) to make
  # insights searchable by a known keyword.
  defp create_published_insight(spark_attrs \\ %{}) do
    spark = SparksFixtures.published_spark(spark_attrs)
    author = Accounts.get_member(spark.author_id)
    contributor = AccountsFixtures.onboarded_member()

    {:ok, c} =
      Contributions.create_contribution(
        %{"body" => String.duplicate("knowledge synthesis ", 60), "stance" => "expands"},
        spark.id,
        contributor.id
      )

    voter = AccountsFixtures.onboarded_member()
    {:ok, _} = Contributions.toggle_highlight(c.id, voter.id)

    {:ok, %{weave: weave}} = Weaves.trigger_weave(spark.id, author.id)
    {:ok, insight} = Weaves.publish_insight(weave.id, author.id)
    insight
  end

  # ── list_insights ─────────────────────────────────────────────────────────────

  describe "list_insights/0" do
    test "returns published insights" do
      insight = create_published_insight()
      results = Library.list_insights()
      ids = Enum.map(results, & &1.id)
      assert insight.id in ids
    end

    test "does not return draft insights" do
      spark = SparksFixtures.published_spark()
      author = Accounts.get_member(spark.author_id)
      contributor = AccountsFixtures.onboarded_member()

      {:ok, c} =
        Contributions.create_contribution(
          %{"body" => String.duplicate("draft content ", 60), "stance" => "expands"},
          spark.id,
          contributor.id
        )

      voter = AccountsFixtures.onboarded_member()
      {:ok, _} = Contributions.toggle_highlight(c.id, voter.id)

      {:ok, %{weave: _weave, insight: draft}} = Weaves.trigger_weave(spark.id, author.id)

      results = Library.list_insights()
      ids = Enum.map(results, & &1.id)
      refute draft.id in ids
    end

    test "preloads weave curator and spark author" do
      _insight = create_published_insight()
      [result | _] = Library.list_insights()
      assert %Insightnest.Weaves.Weave{} = result.weave
      assert result.weave.curator != nil
      assert result.spark.author != nil
    end

    test "orders results newest first" do
      insight1 = create_published_insight()
      insight2 = create_published_insight()
      results = Library.list_insights()
      ids = Enum.map(results, & &1.id)
      assert Enum.find_index(ids, &(&1 == insight2.id)) <
               Enum.find_index(ids, &(&1 == insight1.id))
    end
  end

  # ── search/1 ─────────────────────────────────────────────────────────────────

  describe "search/1" do
    test "returns insights whose title matches the query keyword" do
      unique_kw = "Xylophonic#{System.unique_integer()}"
      insight = create_published_insight(%{title: "#{unique_kw} Deep Analysis"})
      results = Library.search(unique_kw)
      ids = Enum.map(results, & &1.id)
      assert insight.id in ids
    end

    test "does not return insights that do not match the query" do
      insight = create_published_insight(%{title: "Completely Unrelated Topic"})
      results = Library.search("xyzzyquux")
      ids = Enum.map(results, & &1.id)
      refute insight.id in ids
    end

    test "falls back to list_insights for an empty string query" do
      insight = create_published_insight()
      results = Library.search("")
      ids = Enum.map(results, & &1.id)
      assert insight.id in ids
    end

    test "falls back to list_insights for a nil query" do
      insight = create_published_insight()
      results = Library.search(nil)
      ids = Enum.map(results, & &1.id)
      assert insight.id in ids
    end
  end

  # ── get_insight_by_slug!/1 ────────────────────────────────────────────────────

  describe "get_insight_by_slug!/1" do
    test "returns the insight for a known slug" do
      insight = create_published_insight()
      result = Library.get_insight_by_slug!(insight.slug)
      assert result.id == insight.id
    end

    test "preloads weave and spark associations" do
      insight = create_published_insight()
      result = Library.get_insight_by_slug!(insight.slug)
      assert result.weave != nil
      assert result.spark != nil
    end

    test "raises Ecto.NoResultsError for an unknown slug" do
      assert_raise Ecto.NoResultsError, fn ->
        Library.get_insight_by_slug!("no-such-slug-zzz")
      end
    end

    test "raises for a draft insight slug" do
      spark = SparksFixtures.published_spark()
      author = Accounts.get_member(spark.author_id)
      contributor = AccountsFixtures.onboarded_member()

      {:ok, c} =
        Contributions.create_contribution(
          %{"body" => String.duplicate("word ", 60), "stance" => "expands"},
          spark.id,
          contributor.id
        )

      voter = AccountsFixtures.onboarded_member()
      {:ok, _} = Contributions.toggle_highlight(c.id, voter.id)

      {:ok, %{insight: draft}} = Weaves.trigger_weave(spark.id, author.id)

      assert_raise Ecto.NoResultsError, fn ->
        Library.get_insight_by_slug!(draft.slug)
      end
    end
  end

  # ── get_insight!/1 ────────────────────────────────────────────────────────────

  describe "get_insight!/1" do
    test "returns the insight for a known id" do
      insight = create_published_insight()
      result = Library.get_insight!(insight.id)
      assert result.id == insight.id
    end

    test "raises Ecto.NoResultsError for an unknown id" do
      assert_raise Ecto.NoResultsError, fn ->
        Library.get_insight!(Ecto.UUID.generate())
      end
    end
  end

  # ── get_ownership/1 ───────────────────────────────────────────────────────────

  describe "get_ownership/1" do
    test "returns a map with on_chain: false in phase 0" do
      insight = create_published_insight()
      ownership = Library.get_ownership(insight)
      assert ownership.on_chain == false
      assert ownership.token_id == nil
      assert ownership.contract_address == nil
    end

    test "returns the shares list from the contributors map" do
      insight = create_published_insight()
      ownership = Library.get_ownership(insight)
      assert is_list(ownership.shares)
      assert length(ownership.shares) > 0
    end

    test "returns an empty shares list when the contributors field is missing shares key" do
      fake_insight = %{
        id: Ecto.UUID.generate(),
        contributors: %{}
      }

      ownership = Library.get_ownership(fake_insight)
      assert ownership.shares == []
    end

    test "includes the insight_id in the result" do
      insight = create_published_insight()
      ownership = Library.get_ownership(insight)
      assert ownership.insight_id == insight.id
    end
  end
end
