defmodule Insightnest.Weaves.WeightTest do
  use ExUnit.Case, async: true

  alias Insightnest.Weaves.Weight

  @wallet_a "0xaaaa000000000000000000000000000000000001"
  @wallet_b "0xbbbb000000000000000000000000000000000002"
  @wallet_c "0xcccc000000000000000000000000000000000003"
  @wallet_d "0xdddd000000000000000000000000000000000004"

  defp spark(author_id) do
    %{author_id: author_id, author: %{wallet_address: @wallet_a}}
  end

  defp weave(curator_id, wallet \\ @wallet_b) do
    %{curator_id: curator_id, curator: %{wallet_address: wallet}}
  end

  defp contrib(author_id, wallet) do
    %{author_id: author_id, author: %{wallet_address: wallet}}
  end

  defp find(shares, member_id) do
    Enum.find(shares, &(&1.member_id == member_id))
  end

  defp total(shares), do: Enum.sum(Enum.map(shares, & &1.bps))

  # ── Standard cases ────────────────────────────────────────────────────────────

  test "total always sums to 10_000 — 1 contributor" do
    shares = Weight.compute(spark("author"), weave("curator"), [contrib("c1", @wallet_c)])
    assert total(shares) == 10_000
  end

  test "total always sums to 10_000 — 3 contributors" do
    contribs = [contrib("c1", @wallet_c), contrib("c2", @wallet_d), contrib("c3", "0xeeee")]
    shares = Weight.compute(spark("author"), weave("curator"), contribs)
    assert total(shares) == 10_000
  end

  test "standard split: author 40%, curator 20%, contributor 40%" do
    shares = Weight.compute(spark("author"), weave("curator"), [contrib("c1", @wallet_c)])
    assert find(shares, "author").bps == 4000
    assert find(shares, "curator").bps == 2000
    assert find(shares, "c1").bps == 4000
  end

  test "3 contributors split 40% equally — remainder goes to first" do
    contribs = [contrib("c1", @wallet_c), contrib("c2", @wallet_d), contrib("c3", "0xeeee")]
    shares = Weight.compute(spark("author"), weave("curator"), contribs)

    contrib_shares = shares |> Enum.filter(&("contribution" in &1.roles)) |> Enum.map(& &1.bps)
    assert Enum.sum(contrib_shares) == 4000
    # each gets 1333, remainder 1 goes to first
    assert Enum.max(contrib_shares) == 1334
    assert Enum.min(contrib_shares) == 1333
  end

  # ── Edge cases ────────────────────────────────────────────────────────────────

  test "curator === spark author: they get 6000 bps" do
    shares =
      Weight.compute(spark("author"), weave("author", @wallet_a), [contrib("c1", @wallet_c)])

    assert total(shares) == 10_000
    author_entry = find(shares, "author")
    assert author_entry.bps == 6000
    assert "spark" in author_entry.roles
    assert "weave" in author_entry.roles
  end

  test "contributor === spark author: shares merge" do
    # author also contributed
    shares = Weight.compute(spark("author"), weave("curator"), [contrib("author", @wallet_a)])

    assert total(shares) == 10_000
    author_entry = find(shares, "author")
    assert author_entry.bps == 8000
    assert "spark" in author_entry.roles
    assert "contribution" in author_entry.roles
  end

  test "contributor === curator: shares merge" do
    # curator also contributed
    shares = Weight.compute(spark("author"), weave("curator"), [contrib("curator", @wallet_b)])

    assert total(shares) == 10_000
    curator_entry = find(shares, "curator")
    assert curator_entry.bps == 6000
    assert "weave" in curator_entry.roles
    assert "contribution" in curator_entry.roles
  end

  test "all three same person: gets 100%" do
    shares =
      Weight.compute(
        spark("solo"),
        weave("solo", @wallet_a),
        [contrib("solo", @wallet_a)]
      )

    assert total(shares) == 10_000
    assert length(shares) == 1
    entry = find(shares, "solo")
    assert entry.bps == 10_000
    assert "spark" in entry.roles
    assert "weave" in entry.roles
    assert "contribution" in entry.roles
  end

  test "no contributors: leftover 40% split proportionally" do
    shares = Weight.compute(spark("author"), weave("curator"), [])

    assert total(shares) == 10_000
    # 4000 + 2666
    assert find(shares, "author").bps == 6666
    # 2000 + 1334
    assert find(shares, "curator").bps == 3334
  end
end
