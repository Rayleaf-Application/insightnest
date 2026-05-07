defmodule Insightnest.Weaves.Weight do
  @moduledoc false

  @moduledoc """
  Computes fractional contributor shares at Weave time.

  Base model (v1):
    Spark author:   40% (4000 bps)
    Weave curator:  20% (2000 bps)
    Contributors:   40% split equally (4000 bps / n)

  Edge cases:
    No contributors          → author gets 60%, curator gets 40%
    curator == spark author  → they get 60%, contributors split 40%
    contributor == author    → their bps merge with author share
    contributor == curator   → their bps merge with curator share
  """

  @spark_bps 4000
  @curator_bps 2000
  @contrib_bps 4000

  @doc """
  Returns a list of maps: %{member_id, wallet, roles, bps}.
  Total bps always sums to 10_000.
  """
  def compute(spark, weave, contributions) do
    spark_author_id = spark.author_id
    curator_id = weave.curator_id
    curator_is_author = curator_id == spark_author_id
    n = length(contributions)

    # Base shares before merging contributor edge cases
    base_author_bps = if curator_is_author, do: @spark_bps + @curator_bps, else: @spark_bps
    base_curator_bps = if curator_is_author, do: 0, else: @curator_bps

    # When no contributors, redistribute their 40% to author and curator
    # proportionally to existing shares (author 2/3, curator 1/3 of the 4000)
    {base_author_bps, base_curator_bps} =
      if n == 0 do
        if curator_is_author do
          {10_000, 0}
        else
          # author gets 2666, curator gets 1334 of the leftover 4000
          {base_author_bps + 2666, base_curator_bps + 1334}
        end
      else
        {base_author_bps, base_curator_bps}
      end

    # Per-contribution share
    per_contrib_bps = if n > 0, do: div(@contrib_bps, n), else: 0
    remainder_bps = if n > 0, do: rem(@contrib_bps, n), else: 0

    # Build share map: member_id → entry
    shares =
      %{}
      |> put_author(spark, base_author_bps)
      |> put_curator(weave, curator_id, spark_author_id, base_curator_bps)
      |> put_contributors(contributions, per_contrib_bps, remainder_bps)

    shares
    |> Map.values()
    |> Enum.filter(&(&1.bps > 0))
    |> Enum.sort_by(& &1.bps, :desc)
  end

  # ── Private builders ──────────────────────────────────────────────────────────

  defp put_author(shares, spark, bps) do
    Map.put(shares, spark.author_id, %{
      member_id: spark.author_id,
      wallet: spark.author.wallet_address,
      roles: ["spark"],
      bps: bps
    })
  end

  defp put_curator(shares, _weave, curator_id, spark_author_id, 0)
       when curator_id == spark_author_id do
    # Curator is author and already handled — just add "weave" role
    update_in(shares[spark_author_id], fn entry ->
      %{entry | roles: entry.roles ++ ["weave"]}
    end)
  end

  defp put_curator(shares, weave, curator_id, spark_author_id, bps)
       when curator_id == spark_author_id do
    update_in(shares[spark_author_id], fn entry ->
      %{entry | roles: entry.roles ++ ["weave"], bps: entry.bps + bps}
    end)
  end

  defp put_curator(shares, weave, curator_id, _spark_author_id, bps) do
    Map.put(shares, curator_id, %{
      member_id: curator_id,
      wallet: weave.curator.wallet_address,
      roles: ["weave"],
      bps: bps
    })
  end

  defp put_contributors(shares, [], _per, _remainder), do: shares

  defp put_contributors(shares, contributions, per_bps, remainder_bps) do
    contributions
    |> Enum.with_index()
    |> Enum.reduce(shares, fn {contrib, idx}, acc ->
      cid = contrib.author_id
      this_bps = per_bps + if(idx == 0, do: remainder_bps, else: 0)

      if Map.has_key?(acc, cid) do
        update_in(acc[cid], fn entry ->
          roles =
            if "contribution" in entry.roles,
              do: entry.roles,
              else: entry.roles ++ ["contribution"]

          %{entry | roles: roles, bps: entry.bps + this_bps}
        end)
      else
        Map.put(acc, cid, %{
          member_id: cid,
          wallet: contrib.author.wallet_address,
          roles: ["contribution"],
          bps: this_bps
        })
      end
    end)
  end
end
