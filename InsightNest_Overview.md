# InsightNest — Product & Technical Overview

*Last updated: May 2026 · Stack: Elixir/Phoenix LiveView · PostgreSQL*

---

## 1. What Is InsightNest?

InsightNest is a privacy-focused, community co-owned knowledge platform. It is designed for people who value slow, intentional thinking — a space where ideas are nurtured rather than diluted by algorithmic noise or AI-generated filler. Users are not passive content consumers; they are co-creators who hold real ownership stakes in the knowledge they help produce.

The platform's core thesis is that a piece of community-shaped knowledge — refined through discussion, curated by contributors — is a *digital asset*, not just a blog post. InsightNest provides the infrastructure for that asset to be created, owned, and preserved.

**Attention-based friction is a deliberate design choice.** A minimum read time gates the contribution form. Spark creation requires your previous spark to have received at least one contribution. Contributions require a minimum of 50 words. These constraints are not bugs — they are the product. Slow knowledge requires structural incentives for slowness.

**Target audience (MVP launch):** knowledge workers, researchers, writers, indie thinkers, and Web3 builders. No single vertical is locked in; the platform is intentionally open.

---

## 2. Core Flow: Spark → Contribution → Weave → Insight

Everything on InsightNest moves through a four-stage pipeline. Each stage has a clear role, distinct actors, and defined outputs.

### 2.1 Spark

A Spark is the entry point. Any authenticated member can post a Spark — an idea, opinion, question, or piece of knowledge they want to put into the world. Sparks have a title, a body, optional concept tags, and an optional closing deadline.

A Spark is intentionally lightweight. It is the seed, not the finished product.

**Timeouts:** Sparks can have an optional closing deadline. Closed Sparks still accept Weaves on existing highlights, but no new contributions or highlight votes can be added. The author can extend the deadline up to two times.

### 2.2 Contribution

Once a Spark is published, other members can respond with Contributions. A Contribution must be at least 50 words and the contributor must have read the Spark for a minimum time (computed from word count, capped at 3 minutes) before the form unlocks.

Contributions carry an optional **stance** tag: `expands`, `challenges`, `evidence`, or `question`. Stances are displayed as colour-coded chips and used to group contributions in the Weave draft.

**Highlighting:** Any authenticated member can highlight a Contribution. At 3 votes, a Contribution is automatically highlighted. The Spark author can override highlight state regardless of vote count. Highlights are locked when a Weave enters `in_progress`.

### 2.3 Weave

The Weave is the crystallisation step — it turns an open discussion into a lasting artifact.

**Who can trigger a Weave:** The original Spark author, or any author whose Contribution has been highlighted.

**What happens during a Weave:**
- Highlighted Contributions are automatically assembled into a draft Insight, grouped by stance when multiple stances are present.
- Highlights are locked for the duration of the Weave.
- The Weave curator edits the title, summary, and prose framing of the draft.
- Fractional contributor shares are computed at trigger time (40/20/40 model).
- The curator publishes the final Insight.

**Multiple Weaves per Spark:** A Spark accepts new contributions immediately after a Weave publishes. Subsequent Weaves produce new Insight versions, each with its own content hash. The full version history is retained via the `weave_contributions` join table.

### 2.4 Insight

An Insight is the published, canonical artifact. It is versioned, assigned a deterministic content hash, and stored in the Knowledge Library. It carries a record of every contributor who shaped it and their fractional ownership share.

From Phase 2 onwards, each Insight is pinned to Codex (decentralised storage) and receives a content-addressed CID. From Phase 3, each Insight is an on-chain ERC-721 token with fractional shares recorded on-chain.

### 2.5 Knowledge Library

The Knowledge Library is the searchable repository of all published Insights. It supports full-text search (PostgreSQL `tsvector` in Phase 0; evolving toward a Codex-pinned manifest index in Phase 4). Any visitor — authenticated or guest — can browse it.

---

## 3. Identity & Authentication

InsightNest is built on sovereign identity from day one.

| Method | Mechanism | Notes |
|---|---|---|
| Wallet login (primary) | MetaMask / SIWE (Sign-In with Ethereum) | Non-custodial; no personal data collected |
| Email passcode login | Notion-style one-time code; no password | Sprint 6 — planned |
| JWT | Guardian library; stored in session cookie | Guards all authenticated LiveView routes |

**Auth flow:** SIWE signature is verified by a pure Elixir implementation (`Auth.Siwe` + `Auth.Secp256k1`) — no Rust NIFs, no external packages. The `siwe` and `siwe_ex` hex packages were both evaluated and rejected due to Rustler/OTP 27 incompatibility.

**On_mount hooks:** `AuthHooks.on_mount/4` handles three variants — `:default` (soft load), `:require_auth` (redirect to /auth), `:require_onboarded` (redirect to /onboarding).

**Onboarding:** First login redirects to `/onboarding` where the member sets a unique username. A deterministic SVG identicon is generated from the wallet address (GitHub-style 5×5 grid, pure Elixir, no external service).

**Email-only members and Phase 3 ownership:** When fractional shares are assigned at Weave time, members without a wallet have their share held in escrow until they connect one. No ownership is forfeited.

---

## 4. Contribution Weighting & Ownership

At Weave time, fractional ownership shares are computed by `Weaves.Weight.compute/3`:

| Role | Share |
|---|---|
| Spark author | 40% (4000 bps) |
| Weave curator | 20% (2000 bps) |
| Accepted contributors | 40% split equally (4000 bps / n) |

**Edge cases handled explicitly:**
- Curator === Spark author → they receive 60%; contributors split 40%
- Contributor === Spark author → their contribution share merges with the author share
- Contributor === Curator → their contribution share merges with the curator share

This model is v1 and deliberately simple. In Phase 4, the DAO will govern and adjust these weights via on-chain proposal.

---

## 5. Technical Architecture

### 5.1 Repository

Single repo — `insightnest` (GitHub: `github.com/Rayleaf-Application/insightnest`).

No three-repo split. Phoenix LiveView collapses the Go API + Next.js frontend into one language, one deploy unit, one codebase.

### 5.2 Stack

| Layer | Choice | Notes |
|---|---|---|
| Language | Elixir 1.18 / OTP 27 | |
| Framework | Phoenix 1.8 | Ships with LiveView, Ecto |
| Real-time UI | Phoenix LiveView 1.1 | No client-side state management |
| Database | PostgreSQL 16 | Full-text search via `tsvector` |
| HTTP server | Bandit | Default in Phoenix 1.8 |
| Auth | SIWE (pure Elixir) + Guardian JWT | Session cookie; `on_mount` hooks |
| Real-time | Phoenix PubSub | Contributions, highlights, library updates |
| CSS | Tailwind CSS v3 | System binary via Nix shell |
| Fonts | Playfair Display / DM Sans / DM Mono | Google Fonts via `<link>` in root layout |
| Dev environment | NixOS + `nix-shell` + Docker Compose (Postgres only) | |

### 5.3 Key modules

```
lib/insightnest/
  accounts/         # Members, auth, nonce store (ETS), avatar (SVG identicon)
  sparks/           # Spark schema + context
  contributions/    # Contribution schema + context, highlight votes
  weaves/           # Weave + Insight schemas, Weight computation, publish flow
  library/          # Read-only query context for published Insights
  publisher/        # Publisher behaviour + NoopPublisher (Phase 0 stub)
  auth/             # Guardian config, pure Elixir SIWE + secp256k1

lib/insightnest_web/
  live/             # All LiveViews (SparkLive, WeaveLive, LibraryLive, etc.)
  components/       # HEEx function components (spark, contribution, insight, core)
  controllers/      # AuthController (SIWE nonce + verify JSON endpoints)
  plugs/            # LoadMember (soft), RequireAuth (hard)
```

### 5.4 Development environment

- **Host OS:** NixOS (also tested on Bazzite/Fedora Silverblue via `nix-shell`)
- **Shell:** `nix-shell` with `shell.nix` — Elixir 1.18, Erlang/OTP 27, Node 20, system Tailwind
- **Postgres:** Docker Compose (rootless Podman on Bazzite; Docker on NixOS)
- **No Distrobox:** dropped in favour of `nix-shell` after Podman storage corruption issues on Bluefin

### 5.5 Key engineering decisions

| Decision | Rationale |
|---|---|
| Phoenix LiveView over Go + Next.js | One language, one deploy unit, real-time as a primitive via PubSub |
| Pure Elixir SIWE over `siwe`/`siwe_ex` packages | Both packages use Rustler NIFs incompatible with OTP 27 |
| Pure Elixir secp256k1 | No NIF dependency; `ex_keccak` used only for keccak-256 hashing |
| Single repo, no umbrella | Solo dev; umbrella overhead not justified |
| ETS nonce store | In-memory, supervised GenServer; Redis swap-in is one line change in `Application.start/2` |
| `Publisher` behaviour stubbed from day one | `NoopPublisher` in Phase 0; `CodexPublisher` swapped in Phase 2 without refactoring |
| Attention-based friction over time-based | Read timer, word minimum, and engagement gate produce better discourse than arbitrary cooldowns |
| System Tailwind binary via Nix | Downloaded Tailwind binaries are dynamically linked ELF — cannot run on NixOS |
| PostgreSQL `tsvector` for search | Full-text search built into the DB; no Elasticsearch dependency at Phase 0 |

---

## 6. Roadmap

### Phase 0 — MVP Feature Completion *(Weeks 0–8)*

**Status: In progress (Sprints 1–5 complete)**

Deliverables shipped:
- SIWE auth (pure Elixir, no NIFs)
- Username onboarding + SVG identicon avatars
- Spark creation with timeouts + extension
- Real-time Contributions via PubSub (no polling)
- Contribution stances (expands / challenges / evidence / question)
- Attention-based friction (read timer, word minimum, engagement gate)
- Highlight voting + author override
- Weave trigger + draft Insight editor
- Contributor share computation (40/20/40, edge cases explicit)
- Insight publishing + Knowledge Library with full-text search

Remaining Phase 0:
- Email passcode login (Sprint 6)
- Error handling standardisation
- CI/CD pipeline
- LiveDashboard observability
- Demo recording

### Phase 1 — Decentralised Messaging *(Month 3–5)*

**Goal:** Replace Phoenix PubSub for live Spark/Contribution threads with a censorship-resistant messaging layer.

**Approach:** Run a `nwaku` node as a sidecar and bridge to it via its REST API from the Elixir backend. Browser-side contributions are published directly to Waku (signed with wallet key) via `js-waku`. The backend validates and persists to PostgreSQL at Weave time only.

Waku is ephemeral by design — the right fit for live discussion, not for persisted Insights. Content topics use hierarchical namespacing: `/insightnest/1/spark/{sparkId}/proto`.

### Phase 2 — Decentralised Storage / Codex *(Month 5–7)*

**Goal:** Pin finalised Insights to Codex for censorship-resistant, immutable, durable storage.

The `Publisher` behaviour is already stubbed with `NoopPublisher`. Swapping in `CodexPublisher` is a one-line change in `Application.start/2`. The Insight JSON schema is designed for portability from day one — content hash assigned at creation becomes the CID anchor.

### Phase 3 — Fractional Contributor Ownership / ERC-721 *(Month 7–10)*

**Goal:** Mint an ERC-721 token per Insight; distribute fractional shares to contributors on-chain.

**Chain:** Status Network (gasless EVM-compatible L2) until Nomos mainnet (targeting 2027), then migrate. `InsightNFT.sol` token URI points to the Codex CID. `InsightShares.sol` records `(wallet → share bps)` per token. Email-only contributors receive shares in escrow until they connect a wallet.

### Phase 4 — DAO Governance *(Month 12+)*

**Goal:** Transfer platform governance to token holders; migrate to Nomos mainnet.

Voting power proportional to Insight share holdings. Off-chain deliberation runs over Waku (same messaging layer as Sparks). Knowledge Library index migrates from PostgreSQL to a Codex-pinned JSON manifest.

---

## 7. Differentiators

No single existing platform does all three of the following:

1. **Community co-creation** — structured discussion that crystallises into a canonical artifact.
2. **Knowledge crystallisation** — the Weave mechanism transforms ephemeral discussion into durable, versioned, searchable knowledge.
3. **Contributor ownership** — contributors hold a verifiable, on-chain fractional stake in the artifacts they helped create.

| Platform | What it does | What it lacks |
|---|---|---|
| Are.na | Thoughtful, curated collections | No co-creation pipeline; no ownership |
| Mirror.xyz | Web3 publishing with NFT monetisation | Individual authorship only; no collaborative pipeline |
| Roam / Obsidian | Personal knowledge graphs | Private by default; no community layer |
| Farcaster | Decentralised social discussion | Ephemeral; no knowledge crystallisation |
| Wikipedia | Community-edited knowledge base | No contributor ownership; centralised governance |
