defmodule Insightnest.Weaves.Weight do
  @moduledoc """
  Computes fractional contributor shares at Weave time.

  Base model (v1):
    Spark author:   40% (4000 bps)
    Weave curator:  20% (2000 bps)
    Contributors:   40% split equally (4000 bps / n)

  Edge cases handled explicitly:
    curator == spark author → they get 60%, contributors split 40%
    contributor == spark author → their bps merged with author share
    contributor == curator → their bps merged with curator share
  """

  @spark_bps   4000
  @curator_bps 2000
  @contrib_bps 4000

  @doc """
  Returns a list of %{wallet, role, member_id, bps} maps.
  Total bps always sums to 10_000.
  """
  def compute(spark, weave, contributions) do
    spark_author_id  = spark.author_id
    curator_id       = weave.curator_id
    curator_is_author = curator_id == spark_author_id

    n = length(contributions)

    # Per-contribution share
    per_contrib_bps = if n > 0, do: div(@contrib_bps, n), else: 0
    remainder_bps   = if n > 0, do: rem(@contrib_bps, n), else: 0

    # Build share map: member_id → {wallet, roles, bps}
    shares = %{}

    # Spark author
    shares = Map.put(shares, spark_author_id, %{
      member_id: spark_author_id,
      wallet:    spark.author.wallet_address,
      roles:     ["spark"],
      bps:       @spark_bps
    })

    # Weave curator
    shares =
      if curator_is_author do
        # Merge curator bps into author entry
        update_in(shares[spark_author_id], fn entry ->
          %{entry | roles: entry.roles ++ ["weave"], bps: entry.bps + @curator_bps}
        end)
      else
        Map.put(shares, curator_id, %{
          member_id: curator_id,
          wallet:    weave.curator.wallet_address,
          roles:     ["weave"],
          bps:       @curator_bps
        })
      end

    # Contributors — add bps, merge if same as author or curator
    {shares, _} =
      contributions
      |> Enum.with_index()
      |> Enum.reduce({shares, 0}, fn {contrib, idx}, {acc, extra} ->
        cid        = contrib.author_id
        # Give remainder bps to first contributor
        this_bps   = per_contrib_bps + (if idx == 0, do: remainder_bps, else: 0)

        acc =
          if Map.has_key?(acc, cid) do
            # Merge into existing entry
            update_in(acc[cid], fn entry ->
              roles = if "contribution" in entry.roles, do: entry.roles,
                       else: entry.roles ++ ["contribution"]
              %{entry | roles: roles, bps: entry.bps + this_bps}
            end)
          else
            Map.put(acc, cid, %{
              member_id: cid,
              wallet:    contrib.author.wallet_address,
              roles:     ["contribution"],
              bps:       this_bps
            })
          end

        {acc, extra}
      end)

    shares
    |> Map.values()
    |> Enum.sort_by(& &1.bps, :desc)
  end
end
