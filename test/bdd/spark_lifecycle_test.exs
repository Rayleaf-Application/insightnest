defmodule Insightnest.BDD.SparkLifecycleTest do
  use Insightnest.DataCase, async: true
  use Insightnest.BDDCase

  alias Insightnest.AccountsFixtures
  alias Insightnest.ContributionsFixtures
  alias Insightnest.Sparks

  defp valid_spark_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        "title" => "A thought-provoking spark about knowledge #{System.unique_integer()}",
        "body"  => String.duplicate("meaning is constructed through dialogue. ", 5)
      },
      overrides
    )
  end

  # ── First spark ───────────────────────────────────────────────────────────────

  scenario "author publishes their first spark" do
    setup do
      {:ok, member: AccountsFixtures.onboarded_member()}
    end

    step "given an onboarded member with no prior sparks, create_spark succeeds", %{member: m} do
      assert {:ok, spark} = Sparks.create_spark(valid_spark_attrs(), m.id)
      assert spark.author_id == m.id
    end

    step "the spark starts in draft status", %{member: m} do
      {:ok, spark} = Sparks.create_spark(valid_spark_attrs(), m.id)
      assert spark.status == "draft"
    end

    step "the author can publish their draft spark", %{member: m} do
      {:ok, draft} = Sparks.create_spark(valid_spark_attrs(), m.id)
      assert {:ok, published} = Sparks.publish_spark(draft, m.id)
      assert published.status == "published"
    end

    step "publishing is author-only — another member cannot publish it", %{member: m} do
      {:ok, draft}   = Sparks.create_spark(valid_spark_attrs(), m.id)
      other_member   = AccountsFixtures.onboarded_member()
      assert {:error, :unauthorized} = Sparks.publish_spark(draft, other_member.id)
    end
  end

  # ── Engagement gate ───────────────────────────────────────────────────────────

  scenario "second spark requires prior engagement" do
    setup do
      author = AccountsFixtures.onboarded_member()
      {:ok, first} = Sparks.create_spark(valid_spark_attrs(), author.id)
      {:ok, published_first} = Sparks.publish_spark(first, author.id)
      {:ok, author: author, first_spark: published_first}
    end

    step "without any contributions, creating a second spark is blocked", %{author: a} do
      result = Sparks.create_spark(valid_spark_attrs(), a.id)
      assert {:error, {:no_engagement, _last_spark}} = result
    end

    step "the error references the unengaged spark", %{author: a, first_spark: fs} do
      {:error, {:no_engagement, referenced_spark}} = Sparks.create_spark(valid_spark_attrs(), a.id)
      assert referenced_spark.id == fs.id
    end

    step "after receiving a contribution, a second spark is allowed", %{author: a, first_spark: fs} do
      ContributionsFixtures.contribution(%{spark: fs})
      assert {:ok, _second} = Sparks.create_spark(valid_spark_attrs(), a.id)
    end
  end

  # ── Retrieval ─────────────────────────────────────────────────────────────────

  scenario "fetching sparks" do
    setup do
      author = AccountsFixtures.onboarded_member()
      {:ok, draft}  = Sparks.create_spark(valid_spark_attrs(), author.id)
      {:ok, published} = Sparks.publish_spark(draft, author.id)
      {:ok, author: author, spark: published}
    end

    step "get_spark! returns the spark with author preloaded", %{spark: s} do
      fetched = Sparks.get_spark!(s.id)
      assert fetched.id == s.id
      assert fetched.author != nil
    end

    step "get_spark! raises for an unknown id" do
      assert_raise Ecto.NoResultsError, fn ->
        Sparks.get_spark!(Ecto.UUID.generate())
      end
    end

    step "list_published includes the published spark", %{spark: s} do
      sparks = Sparks.list_published()
      ids    = Enum.map(sparks, & &1.id)
      assert s.id in ids
    end

    step "list_by_author returns the author's own sparks", %{author: a, spark: s} do
      sparks = Sparks.list_by_author(a.id)
      ids    = Enum.map(sparks, & &1.id)
      assert s.id in ids
    end

    step "author?/2 returns true for the spark author", %{spark: s, author: a} do
      assert Sparks.author?(s, a.id)
    end

    step "author?/2 returns false for another member", %{spark: s} do
      other = AccountsFixtures.onboarded_member()
      refute Sparks.author?(s, other.id)
    end
  end

  # ── Extension ─────────────────────────────────────────────────────────────────

  scenario "spark deadline extension" do
    setup do
      author = AccountsFixtures.onboarded_member()
      {:ok, draft} = Sparks.create_spark(valid_spark_attrs(%{"timeout_days" => "14"}), author.id)
      {:ok, author: author, spark: draft}
    end

    step "author can extend the closing deadline", %{author: a, spark: s} do
      assert {:ok, extended} = Sparks.extend_spark(s, a.id, 7)
      assert extended.extension_count == 1
    end

    step "another member cannot extend the spark", %{spark: s} do
      other = AccountsFixtures.onboarded_member()
      assert {:error, :unauthorized} = Sparks.extend_spark(s, other.id)
    end
  end
end
