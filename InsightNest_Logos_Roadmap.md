# InsightNest × Logos Ecosystem — Integration Roadmap

*Updated: May 2026 | Stack: Elixir 1.18 / Phoenix LiveView 1.1 | Auth: SIWE (pure Elixir)*

---

## Current State (Baseline)

The following is shipped and running:

- **Elixir/Phoenix LiveView** single-repo application (no frontend/backend split)
- **Pure Elixir SIWE** — signature verification without Rust NIFs (`Auth.Siwe` + `Auth.Secp256k1` + `ex_keccak`)
- **MetaMask wallet login** — full SIWE nonce/verify flow, Guardian JWT, session cookie
- **Username onboarding** — unique username + deterministic SVG identicon from wallet address
- **Sparks** — creation with timeouts, draft/publish, concept tags, full-text search index
- **Contributions** — real-time via Phoenix PubSub (no polling), stance tags, 50-word minimum, attention-based read timer
- **Highlights** — vote-based (threshold: 3) + author override, locked at Weave trigger
- **Weave** — trigger, draft editor, stance-grouped body blocks, 40/20/40 contributor weighting
- **Insight publishing** — versioned, content-hashed, slug-addressed, `NoopPublisher` stub wired
- **Knowledge Library** — full-text search via PostgreSQL `tsvector`, live PubSub updates
- **CI pipeline** — GitHub Actions on every push (`mix test`, `mix credo`, migration reversibility)
- **LiveDashboard** — Telemetry metrics at `/dev/dashboard`

**The `Publisher` behaviour is the designed seam for Codex.** `NoopPublisher` runs in Phase 0. Swapping in `CodexPublisher` in Phase 2 is a single line change in `Application.start/2` — nothing else touches it.

**The `MessageBus` behaviour is the designed seam for Waku.** `NoopMessageBus` runs in Phase 0. Phoenix PubSub handles real-time today; Waku replaces it in Phase 1 by implementing the same behaviour interface.

---

## Why Elixir/Phoenix for a Logos-aligned project

The stack choice is architecturally motivated, not incidental:

**Real-time without infrastructure overhead.** Phoenix PubSub + LiveView delivers sub-50ms real-time updates across all connected clients with zero client-side state management code. This is the correct foundation for a live discussion layer that Waku will extend — not replace — in Phase 1.

**The BEAM is built for distributed systems.** OTP supervision trees, process isolation, and fault tolerance are native. When Waku node management, Codex upload queuing, and on-chain minting calls are added in later phases, each becomes a supervised GenServer process. No thread management, no retry middleware, no service mesh.

**One language, one deploy unit.** No Go API + Next.js split. No JSON serialisation between your own services. No three-repo coordination overhead. For a solo founder this compounds significantly over a multi-phase build.

**SIWE works without Rust.** The `siwe` and `siwe_ex` hex packages both use Rustler NIFs incompatible with OTP 27. The pure Elixir implementation in `Auth.Siwe` and `Auth.Secp256k1` uses `:crypto.mod_pow` (OTP stdlib) and `ex_keccak`. No native dependencies for the auth critical path.

---

## Phase 0 — MVP Feature Completion
**Timeline: Months 0–2 (complete)**
**Goal: Shippable, demo-ready product for the Logos grant application**

### Deliverables

| Feature | Status | Notes |
|---|---|---|
| Spark creation | ✅ | Timeouts, concepts, draft/publish |
| Contributions | ✅ | Real-time PubSub, stances, word minimum |
| Attention-based friction | ✅ | Read timer, engagement gate, word min |
| Highlighting | ✅ | Vote threshold + author override + locking |
| Weave trigger | ✅ | Eligibility check, highlight lock, stance grouping |
| Draft Insight editor | ✅ | Title/summary editable, contributor shares displayed |
| Insight publishing | ✅ | Versioned, content-hashed, NoopPublisher wired |
| Knowledge Library | ✅ | Full-text search, live PubSub updates |
| SIWE auth | ✅ | Pure Elixir, no NIFs |
| Username + identicon | ✅ | Deterministic SVG, onboarding flow |
| CI pipeline | ✅ | GitHub Actions, mix test + credo |
| Email passcode login | 🔲 | Sprint 6 |
| Error handling standardisation | 🔲 | Sprint 6 |
| Demo recording | 🔲 | Sprint 7 |

### Technical principles honoured

- All data in PostgreSQL at this stage — Codex integration in Phase 2
- Insight JSON body structured as typed blocks (`quote`, `paragraph`, `section_header`) — serialises cleanly to Codex without schema migration
- Deterministic content hash assigned at Weave time — becomes the CID anchor in Phase 2
- `Publisher` behaviour stubbed — CodexPublisher is a drop-in replacement
- `MessageBus` behaviour stubbed — WakuMessageBus is a drop-in replacement

---

## Phase 1 — Logos Messaging Integration (Waku)
**Timeline: Month 3–5**
**Goal: Replace Phoenix PubSub for live Spark/Contribution threads with Waku p2p messaging**

### Why Waku here

Waku is censorship-resistant, privacy-preserving, and ephemeral by design — the right fit for the live discussion layer (Spark → Contribution), not for persisted Insights. Phoenix PubSub is centralised infrastructure; Waku removes that centralisation from the discussion layer while keeping PostgreSQL as the authoritative store at Weave time.

### Architecture

```
Member Browser  ──js-waku──►  Waku Network (p2p)
                                      │
Elixir Backend  ──REST──►  nwaku node (sidecar)
       │                         │
       └─► PostgreSQL  ◄── confirmed at Weave time
```

The Elixir backend talks to a `nwaku` node via its REST API — no Rust NIFs, no Go subprocess. The browser subscribes to Spark threads directly via `js-waku`. Contributions are signed with the member's wallet key and published to Waku by the browser; the backend validates and persists only at Weave time.

### Implementation approach

**Backend (`lib/insightnest/messaging/`)**

The `MessageBus` behaviour is already defined and stubbed:

```elixir
# Swap one line in Application.start/2:
# NoopMessageBus → WakuMessageBus

defmodule Insightnest.Messaging.WakuMessageBus do
  @behaviour Insightnest.Messaging.MessageBus

  # Talks to nwaku REST API
  # POST /api/v1/relay/v1/messages/{topic}
  # GET  /api/v1/store/v1/messages?contentTopic=...
end
```

- `WakuMessageBus` calls the `nwaku` REST API for publish and subscribe
- On Weave trigger: pull accumulated messages from Waku Store protocol, validate signatures, write confirmed contributions to PostgreSQL
- RLN (Rate Limiting Nullifier) integration for spam prevention — wallet addresses registered as RLN membership credentials, rate-limited per epoch

**Frontend**

- Add `@waku/sdk` to `assets/js/`
- LiveView JS hooks bridge the Waku subscription into LiveView socket events
- Contributions published directly to Waku from the browser (signed with wallet key)
- The read timer and word minimum friction mechanics apply before publishing to Waku — enforced client-side and re-validated at Weave time

**Infrastructure**

- Add `nwaku` as a Docker Compose service for local dev (Nim Waku reference node)
- Configure bootstrap peer pointing to the Waku fleet for staging

### Key decisions

- **Content topics:** hierarchical namespacing — `/insightnest/1/spark/{sparkId}/proto`
- **Message format:** Protobuf envelope — `{authorWalletAddress, content, sparkId, timestamp, signature}`
- **Waku Store protocol:** enables late-joiners to fetch thread history without a centralised backend
- **nwaku sidecar over native Elixir Waku:** no mature Elixir Waku client exists; the REST API approach is stable and decouples the Waku version lifecycle from the Elixir app

---

## Phase 2 — Logos Storage Integration (Codex)
**Timeline: Month 5–7**
**Goal: Publish finalised Insights to Codex for censorship-resistant, immutable, durable storage**

### Why Codex here

Codex is the Logos storage module — a decentralised durability engine with cryptographic proofs of storage, erasure coding, and a storage marketplace. Once an Insight is Woven, it should be immutable and permanent. Codex provides exactly that guarantee.

A Codex node exposes a REST API. The Elixir backend calls it directly via HTTP.

### Architecture

```
Weave published
      │
Elixir Backend ──HTTP──► Codex Node (REST API)
      │                        │
      │                  Upload JSON blob
      │                  Returns CID
      │
PostgreSQL  ◄── stores insights.codex_cid
      │
LiveView ──► fetches Insight content from Codex by CID
```

### Implementation approach

**Backend (`lib/insightnest/publisher/`)**

The `Publisher` behaviour and `NoopPublisher` are already in place:

```elixir
# Swap one line in Application.start/2:
# NoopPublisher → CodexPublisher

defmodule Insightnest.Publisher.CodexPublisher do
  @behaviour Insightnest.Publisher

  # POST /api/codex/v1/data       → upload Insight JSON blob
  # GET  /api/codex/v1/data/{cid} → retrieve by CID
  # POST /api/codex/v1/storage/request/{cid} → durability contract
end
```

- On Weave publish: serialise Insight to JSON, upload to Codex, store returned CID in `insights.codex_cid`
- Content integrity check on retrieval: re-hash fetched blob, compare against stored CID
- `codex_cid` column already exists on the `insights` table — no migration needed

**Frontend**

- Knowledge Library fetches Insight content from Codex via CID (proxied through the Elixir backend initially; direct browser fetch in Phase 4)
- CID provenance badge already rendered in `InsightComponents.cid_badge/1` — switches from `noop:` prefix to real CID
- "Verify on Codex" link resolves CID on the public Codex gateway

**Infrastructure**

- Add `codex-node` as a Docker Compose service (Altruistic Mode, testnet bootstrap peers)
- Persist Codex node data in a named Docker volume

### Insight JSON schema (Codex payload)

```json
{
  "version": "1",
  "id": "<uuid>",
  "title": "string",
  "summary": "string",
  "body": [
    { "type": "section_header", "content": "Evidence" },
    { "type": "quote", "content": "...", "author": "0x...", "stance": "evidence" }
  ],
  "contributors": [
    { "wallet": "0x...", "roles": ["spark"], "bps": 4000 }
  ],
  "spark_id": "<uuid>",
  "created_at": "ISO8601",
  "content_hash": "sha256:..."
}
```

### Key decisions

- The Elixir backend is the trusted Codex uploader — validates content before pinning
- CIDs are content-addressed — Insight is immutable once published; new Weave version creates new CID, old retained
- For the grant demo: run a Codex Altruistic Mode node to demonstrate live testnet integration

---

## Phase 3 — Fractional Contributor Ownership (ERC-721)
**Timeline: Month 7–10**
**Goal: Mint an ERC-721 token per Insight; distribute fractional shares to contributors on-chain**

### Chain selection

**Status Network** (gasless EVM-compatible L2, IFT ecosystem) until Nomos mainnet (targeting 2027), then migrate. Status Network keeps InsightNest inside the Logos ecosystem without blocking on Nomos.

### Architecture

```
Weave published + Codex CID confirmed
             │
Elixir Backend ──JSON-RPC──► Smart Contract (Status Network)
                                    │
                          Mint ERC-721 for Insight CID
                          Record contributor shares on-chain
                                    │
                       Contributor wallets receive fractional tokens
```

### Implementation approach

**Smart contracts (`insightnest_contracts` — new repo)**

- `InsightNFT.sol` — ERC-721 with lazy minting; token URI → Codex CID
- `InsightShares.sol` — records `(wallet → share bps)` per token; emits `SharesAssigned(tokenId, wallet, bps)`

**Backend**

- Call minting contract via JSON-RPC from Elixir after Codex upload succeeds
- Elixir has mature Ethereum JSON-RPC libraries (`ethereumex`, `ex_abi`) — no Go dependency
- Store `token_id` and `contract_address` in PostgreSQL alongside the Insight record
- `Library.get_ownership/1` already returns the share structure — switches from `on_chain: false` to live contract data

**Frontend (LiveView)**

- `InsightComponents.ownership_row/1` already renders share percentages and role badges
- Switch from computed shares to on-chain data when `on_chain: true`
- Link to Status Network block explorer

**Contributor weighting (already implemented)**

The 40/20/40 model with all edge cases is live in `Weaves.Weight.compute/3`:
- Spark author: 40% (4000 bps)
- Weave curator: 20% (2000 bps)
- Contributors: 40% split equally
- Curator === author → 60%
- Contributor === author or curator → shares merge

This is governed by DAO in Phase 4.

---

## Phase 4 — DAO Governance & Progressive Decentralisation
**Timeline: Month 12+**
**Goal: Transfer platform governance to token holders; migrate to Nomos mainnet**

This phase is a long-term architectural target, not a grant deliverable. It demonstrates to Logos that InsightNest is building toward the full stack — not using one component and stopping.

**DAO Governance (on Nomos / Status Network)**

- `InsightNestDAO.sol` — governance contract
- Voting power: proportional to Insight share holdings
- Proposal types: treasury allocation, Library curation policy, contribution weighting formula, platform fees
- Off-chain deliberation via Waku (same messaging layer as Sparks) — same `MessageBus` behaviour

**Knowledge Library decentralisation**

- Migrate Library index from PostgreSQL to a Codex-pinned JSON manifest `{cid, title, contributors, timestamp}`
- Any node reconstructs the full Library from a single manifest CID
- `Library` context already abstracts the query layer — manifest-backed implementation is a drop-in

**Client-side Codex retrieval**

- Direct browser fetches via Codex JS SDK — backend removed from the read path entirely
- LiveView JS hooks bridge Codex responses into the socket

**Identity**

- SIWE-based login remains valid — Ethereum addresses are Logos-compatible identifiers
- Explore Logos identity primitives when available

---

## Logos Stack Mapping

| InsightNest Layer | Logos Component | Phase | Seam |
|---|---|---|---|
| Sovereign identity | SIWE (pure Elixir, live) | Phase 0 | `Auth.Siwe` |
| Live discussion (Spark/Contribution) | Logos Messaging (Waku) | Phase 1 | `MessageBus` behaviour |
| Permanent Insight storage | Logos Storage (Codex) | Phase 2 | `Publisher` behaviour |
| Contributor ownership (NFT shares) | Status Network EVM → Nomos | Phase 3 | JSON-RPC from Elixir |
| Platform governance (DAO voting) | Logos Blockchain (Nomos) | Phase 4 | Same `MessageBus` |

The "Seam" column shows the exact code interface each Logos component plugs into. These are not aspirational — they are already in the codebase as stubs, tested, and wired into the supervision tree.

---

## Timeline

```
Months 0–2   [Phase 0]  MVP complete — Spark, Contribute, Weave, Library, auth, CI ✅
Months 3–5   [Phase 1]  Waku integration — nwaku sidecar, js-waku browser, RLN
Months 5–7   [Phase 2]  Codex integration — Insight pinning, CID provenance, storage contracts
Months 7–10  [Phase 3]  ERC-721 minting, fractional shares, Status Network deploy
Month 12+    [Phase 4]  DAO governance, Nomos migration, Library decentralisation
```

---

## Grant Proposal Scope (Phases 0–2)

For the Logos RFP grant, the deliverable scope is **Phases 0 through 2**:

- A working MVP demonstrating the full Spark → Contribution → Weave → Insight pipeline, live and demoable
- Phoenix PubSub real-time in production today; **Waku integration replacing it in Phase 1**, with the `MessageBus` seam already designed and stubbed
- **Codex integration for Insight persistence in Phase 2**, with the `Publisher` seam already designed, stubbed, and the `codex_cid` column already on the insights table
- SIWE-based sovereign identity live in production, implemented in pure Elixir without Rust dependencies

Phases 3–4 demonstrate architectural intent — InsightNest is building toward the full Logos stack progressively, with each phase adding a new component at a pre-designed integration seam.

**The framing:** InsightNest is not a project that plans to use Logos. It is a project that has shipped on Logos (SIWE), designed explicit seams for the next two Logos components (Waku, Codex), and has a credible path to the full stack. The grant funds the next two phases of integration work, not the product itself.
