defmodule Insightnest.BDD.ContributionLifecycleTest do
  use Insightnest.DataCase, async: true
  use Insightnest.BDDCase

  alias Insightnest.AccountsFixtures
  alias Insightnest.Contributions
  alias Insightnest.Repo
  alias Insightnest.SparksFixtures
  alias Insightnest.Sparks

  @body String.duplicate("thoughtful analysis and synthesis of ideas ", 60)

  defp contribute(spark, author) do
    Contributions.create_contribution(
      %{"body" => @body, "stance" => "expands"},
      spark.id,
      author.id
    )
  end

  # ── Happy path ────────────────────────────────────────────────────────────────

  scenario "member contributes to a published spark" do
    setup do
      spark = SparksFixtures.published_spark()
      author = AccountsFixtures.onboarded_member()
      {:ok, spark: spark, author: author}
    end

    step "create_contribution returns {:ok, contribution}", %{spark: s, author: a} do
      assert {:ok, contribution} = contribute(s, a)
      assert contribution.spark_id == s.id
      assert contribution.author_id == a.id
    end

    step "contribution has active status by default", %{spark: s, author: a} do
      {:ok, c} = contribute(s, a)
      assert c.status == "active"
    end

    step "contribution author is preloaded on the returned struct", %{spark: s, author: a} do
      {:ok, c} = contribute(s, a)
      assert c.author.id == a.id
    end

    step "list_for_spark returns the new contribution", %{spark: s, author: a} do
      {:ok, c} = contribute(s, a)
      ids = s.id |> Contributions.list_for_spark() |> Enum.map(& &1.id)
      assert c.id in ids
    end

    step "already_contributed? returns true after contributing", %{spark: s, author: a} do
      contribute(s, a)
      assert Contributions.already_contributed?(s.id, a.id)
    end
  end

  # ── Guard: own spark ──────────────────────────────────────────────────────────

  scenario "author cannot contribute to their own spark" do
    step "given the spark author tries to contribute, it is rejected" do
      spark = SparksFixtures.published_spark()
      author = Repo.preload(spark, :author).author
      assert {:error, :own_spark} = contribute(spark, author)
    end
  end

  # ── Guard: duplicate contribution ────────────────────────────────────────────

  scenario "each member may only contribute once per spark" do
    setup do
      spark = SparksFixtures.published_spark()
      author = AccountsFixtures.onboarded_member()
      {:ok, _} = contribute(spark, author)
      {:ok, spark: spark, author: author}
    end

    step "a second contribution from the same member is rejected", %{spark: s, author: a} do
      assert {:error, :already_contributed} = contribute(s, a)
    end

    step "already_contributed? returns true", %{spark: s, author: a} do
      assert Contributions.already_contributed?(s.id, a.id)
    end
  end

  # ── Guard: closed spark ───────────────────────────────────────────────────────

  scenario "contributions to a closed spark are blocked" do
    setup do
      spark = SparksFixtures.published_spark()
      past = DateTime.add(DateTime.utc_now(), -3_600, :second) |> DateTime.truncate(:second)
      Repo.update!(Ecto.Changeset.change(spark, closes_at: past))
      {:ok, spark_id: spark.id}
    end

    step "create_contribution returns {:error, :spark_closed}", %{spark_id: sid} do
      author = AccountsFixtures.onboarded_member()

      assert {:error, :spark_closed} =
               Contributions.create_contribution(
                 %{"body" => @body, "stance" => "expands"},
                 sid,
                 author.id
               )
    end
  end

  # ── Guard: unpublished spark ──────────────────────────────────────────────────

  scenario "contributions to a draft spark are blocked" do
    step "create_contribution on a draft spark returns {:error, :spark_not_published}" do
      author = AccountsFixtures.onboarded_member()

      {:ok, draft} =
        Sparks.create_spark(
          %{
            "title" => "Draft spark #{System.unique_integer()}",
            "body" => String.duplicate("word ", 10)
          },
          author.id
        )

      contributor = AccountsFixtures.onboarded_member()

      assert {:error, :spark_not_published} =
               Contributions.create_contribution(
                 %{"body" => @body, "stance" => "expands"},
                 draft.id,
                 contributor.id
               )
    end
  end

  # ── Soft delete ───────────────────────────────────────────────────────────────

  scenario "author soft-deletes their contribution" do
    setup do
      spark = SparksFixtures.published_spark()
      author = AccountsFixtures.onboarded_member()
      {:ok, c} = contribute(spark, author)
      {:ok, contribution: c, author: author}
    end

    step "delete_contribution hides the contribution", %{contribution: c, author: a} do
      assert {:ok, hidden} = Contributions.delete_contribution(c.id, a.id)
      assert hidden.status == "hidden"
    end

    step "another member cannot delete the contribution", %{contribution: c} do
      other = AccountsFixtures.onboarded_member()
      assert {:error, :unauthorized} = Contributions.delete_contribution(c.id, other.id)
    end
  end

  # ── Highlight voting ──────────────────────────────────────────────────────────

  scenario "highlight votes accumulate and auto-highlight at threshold" do
    setup do
      spark = SparksFixtures.published_spark()
      contributor = AccountsFixtures.onboarded_member()
      {:ok, c} = contribute(spark, contributor)
      {:ok, contribution: c, spark: spark}
    end

    step "toggle_highlight adds a vote", %{contribution: c} do
      voter = AccountsFixtures.onboarded_member()
      assert {:ok, updated} = Contributions.toggle_highlight(c.id, voter.id)
      assert updated.highlight_count == 1
    end

    step "toggling again removes the vote", %{contribution: c} do
      voter = AccountsFixtures.onboarded_member()
      {:ok, _} = Contributions.toggle_highlight(c.id, voter.id)
      {:ok, reverted} = Contributions.toggle_highlight(c.id, voter.id)
      assert reverted.highlight_count == 0
    end

    step "voted_highlight? reflects the voter's current vote", %{contribution: c} do
      voter = AccountsFixtures.onboarded_member()
      refute Contributions.voted_highlight?(c.id, voter.id)
      Contributions.toggle_highlight(c.id, voter.id)
      assert Contributions.voted_highlight?(c.id, voter.id)
    end
  end
end
