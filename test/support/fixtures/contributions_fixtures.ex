defmodule Insightnest.ContributionsFixtures do
  @moduledoc false

  alias Insightnest.AccountsFixtures
  alias Insightnest.Contributions
  alias Insightnest.SparksFixtures

  # 60 words — well above the 50-word minimum.
  @default_body String.duplicate("insightful analysis here ", 60)

  @doc """
  Creates a contribution on a published spark.

  Accepted keys in `attrs`:
    - `:spark`  — defaults to a freshly created published spark
    - `:author` — defaults to a freshly created onboarded member
    - `:body`   — defaults to a 60-word body
    - `:stance` — defaults to "expands"
  """
  def contribution(attrs \\ %{}) do
    spark  = attrs[:spark]  || SparksFixtures.published_spark()
    author = attrs[:author] || AccountsFixtures.onboarded_member()
    body   = attrs[:body]   || @default_body
    stance = attrs[:stance] || "expands"

    {:ok, contribution} =
      Contributions.create_contribution(
        %{"body" => body, "stance" => stance},
        spark.id,
        author.id
      )

    contribution
  end
end
