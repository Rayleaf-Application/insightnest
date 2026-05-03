defmodule Insightnest.Weaves.WeightTest do
  use ExUnit.Case, async: true

  alias Insightnest.Weaves.Weight

  @wallet_a "0xaaaa"
  @wallet_b "0xbbbb"
  @wallet_c "0xcccc"

  def spark(author_id), do: %{author_id: author_id, author: %{wallet_address: @wallet_a}}
  def weave(curator_id), do: %{curator_id: curator_id, curator: %{wallet_address: @wallet_b}}
  def contrib(author_id, wallet), do: %{author_id: author_id, author: %{wallet_address: wallet}}

  test "standard case: 1 contributor" do
    spark   = spark("author")
    weave   = weave("curator")
    contribs = [contrib("contrib1", @wallet_c)]

    shares = Weight.compute(spark, weave, contribs)
    total  = Enum.sum(Enum.map(shares, & &1.bps))

    assert total == 10_000
    assert find(shares, "author").bps  == 4000
    assert find(shares, "curator").bps == 2000
    assert find(shares, "contrib1").bps == 4000
  end

  test "curator === spark author: they get 6000 bps" do
    spark   = spark("author")
    weave   = weave("author")   # same person
    contribs = [contrib("contrib1", @wallet_c)]

    shares = Weight.compute(spark, weave, contribs)
    total  = Enum.sum(Enum.map(shares, & &1.bps))

    assert total == 10_000
    author_entry = find(shares, "author")
    assert author_entry.bps == 6000
    assert "spark" in author_entry.roles
    assert "weave" in author_entry.roles
  end

  test "contributor === spark author: shares merge" do
    spark   = spark("author")
    weave   = weave("curator")
    contribs = [contrib("author", @wallet_a)]  # author also contributed

    shares = Weight.compute(spark, weave, contribs)
    total  = Enum.sum(Enum.map(shares, & &1.bps))

    assert total == 10_000
    author_entry = find(shares, "author")
    assert author_entry.bps == 8000   # 4000 + 4000
    assert "spark" in author_entry.roles
    assert "contribution" in author_entry.roles
  end

  test "contributor === curator: shares merge" do
    spark   = spark("author")
    weave   = weave("curator")
    contribs = [contrib("curator", @wallet_b)]  # curator also contributed

    shares = Weight.compute(spark, weave, contribs)
    total  = Enum.sum(Enum.map(shares, & &1.bps))

    assert total == 10_000
    curator_entry = find(shares, "curator")
    assert curator_entry.bps == 6000   # 2000 + 4000
  end

  test "multiple contributors: 40% split equally" do
    spark   = spark("author")
    weave   = weave("curator")
    contribs = [
      contrib("c1", @wallet_c),
      contrib("c2", "0xdddd"),
      contrib("c3", "0xeeee")
    ]

    shares = Weight.compute(spark, weave, contribs)
    total  = Enum.sum(Enum.map(shares, & &1.bps))

    assert total == 10_000
    # 4000 / 3 = 1333 each, remainder 1 goes to first
    contrib_bps = shares |> Enum.filter(&("contribution" in &1.roles)) |> Enum.map(& &1.bps)
    assert Enum.sum(contrib_bps) == 4000
  end

  defp find(shares, member_id) do
    Enum.find(shares, &(&1.member_id == member_id))
  end
end
