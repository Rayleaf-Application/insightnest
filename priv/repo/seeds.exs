alias Insightnest.Repo
alias Insightnest.Accounts.Member
alias Insightnest.Sparks.Spark

# Idempotent — skip if already seeded
if Repo.aggregate(Member, :count) > 0 do
  IO.puts("Seed data already present, skipping.")
else
  # Hardhat/Anvil default wallet addresses
  members = [
    %{wallet_address: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"},
    %{wallet_address: "0x70997970c51812dc3a010c7d01b50e0d17dc79c8"},
    %{wallet_address: "0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc"}
  ]

  [alice, bob, carol] =
    Enum.map(members, fn attrs ->
      %Member{}
      |> Member.wallet_changeset(attrs)
      |> Repo.insert!(on_conflict: :nothing, conflict_target: :wallet_address)
      |> then(fn _ -> Repo.get_by!(Member, wallet_address: attrs.wallet_address) end)
    end)

  now = DateTime.utc_now() |> DateTime.truncate(:second)

  sparks = [
    %{
      author_id: alice.id,
      title: "The case for slow knowledge",
      body: """
      We live in an age of instant takes. Every platform optimises for speed — \
      the fastest response, the hottest reaction, the freshest content. \
      But what if the most valuable knowledge is the kind that takes time to form?

      Slow knowledge is knowledge that has been tested, refined, and challenged. \
      It emerges not from the first reaction but from sustained inquiry. \
      It rewards patience and penalises haste.

      The question is whether we can build infrastructure for slow knowledge \
      in a world that financially rewards speed.
      """,
      concepts: ["epistemology", "knowledge", "attention"],
      status: "published",
      slug: "the-case-for-slow-knowledge-a1b2c3",
      content_hash: :crypto.hash(:sha256, "slow-knowledge-alice") |> Base.encode16(case: :lower),
      inserted_at: now,
      updated_at: now
    },
    %{
      author_id: bob.id,
      title: "On digital commons",
      body: """
      The tragedy of the commons assumes that shared resources are inevitably depleted. \
      But digital goods are non-rival — your reading this does not prevent me from reading it.

      What would it mean to build genuinely shared digital infrastructure? \
      Not just open source software, but open knowledge — collaboratively produced, \
      collectively owned, and governed by the communities that create it.

      Wikipedia gestures at this but falls short on ownership. \
      Blockchain gestures at ownership but falls short on knowledge.
      """,
      concepts: ["commons", "governance", "ownership"],
      status: "published",
      slug: "on-digital-commons-d4e5f6",
      content_hash: :crypto.hash(:sha256, "digital-commons-bob") |> Base.encode16(case: :lower),
      inserted_at: DateTime.add(now, -3600, :second),
      updated_at: DateTime.add(now, -3600, :second)
    },
    %{
      author_id: carol.id,
      title: "Why AI writing feels flat",
      body: """
      A draft exploring why AI-generated text lacks the texture of human writing.
      Work in progress.
      """,
      concepts: ["AI", "writing", "creativity"],
      status: "draft",
      slug: "why-ai-writing-feels-flat-g7h8i9",
      content_hash: :crypto.hash(:sha256, "ai-writing-carol") |> Base.encode16(case: :lower),
      inserted_at: DateTime.add(now, -7200, :second),
      updated_at: DateTime.add(now, -7200, :second)
    }
  ]

  Enum.each(sparks, fn attrs ->
    %Spark{}
    |> Spark.changeset(attrs)
    |> Repo.insert!(on_conflict: :nothing, conflict_target: :slug)
  end)

  IO.puts("✓ Seeded 3 members, 2 published sparks, 1 draft")

  # Add contributions if not already present
  alias Insightnest.Contributions.Contribution

  slow_knowledge = Repo.get_by!(Insightnest.Sparks.Spark, slug: "the-case-for-slow-knowledge-a1b2c3")
  digital_commons = Repo.get_by!(Insightnest.Sparks.Spark, slug: "on-digital-commons-d4e5f6")

  if Repo.aggregate(Contribution, :count) == 0 do
    contributions = [
      %{
        spark_id:   slow_knowledge.id,
        author_id:  bob.id,
        body:       "There's strong empirical grounding here. Studies on deliberative democracy show that slowing down information processing significantly improves the quality of conclusions drawn. The Kahneman System 1/2 framing applies directly — fast knowledge is System 1, pattern-matched and often wrong.",
        stance:     "evidence",
        inserted_at: DateTime.add(now, 3600, :second),
        updated_at:  DateTime.add(now, 3600, :second)
      },
      %{
        spark_id:   slow_knowledge.id,
        author_id:  carol.id,
        body:       "I'd push back on the implicit assumption that speed is purely a platform incentive problem. Sometimes urgency is epistemically valid — breaking news, emergency coordination, time-sensitive decisions. The question isn't slow vs. fast but appropriate speed for context.",
        stance:     "challenges",
        inserted_at: DateTime.add(now, 7200, :second),
        updated_at:  DateTime.add(now, 7200, :second)
      },
      %{
        spark_id:   digital_commons.id,
        author_id:  alice.id,
        body:       "This connects directly to Yochai Benkler's work on commons-based peer production. The Wealth of Networks argues that non-rival goods enable new production models that weren't economically viable before. InsightNest is essentially testing whether knowledge crystallisation is one of them.",
        stance:     "expands",
        inserted_at: DateTime.add(now, 1800, :second),
        updated_at:  DateTime.add(now, 1800, :second)
      },
      %{
        spark_id:   digital_commons.id,
        author_id:  carol.id,
        body:       "What's the governance model when contributors disagree about what counts as a valid contribution? Wikipedia's edit wars suggest this is harder than it looks at the protocol level.",
        stance:     "question",
        inserted_at: DateTime.add(now, 5400, :second),
        updated_at:  DateTime.add(now, 5400, :second)
      }
    ]

    Enum.each(contributions, fn attrs ->
      %Contribution{}
      |> Contribution.changeset(attrs)
      |> Repo.insert!(on_conflict: :nothing)
    end)

    IO.puts("✓ Seeded 4 contributions")
  end
  
  # Seeds are contributed sparks/contributions only in Phase 0.
  # Published Insights are created through the Weave flow, not seeded directly.
  # Run the demo flow manually to populate the Library:
  #   1. Log in → open a spark → highlight contributions → /weave/:id → Publish
  IO.puts("✓ To populate the Library, complete a Weave via the UI.")
end
