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
end
