# InsightNest — Architecture

## Overview

InsightNest is a four-stage knowledge pipeline built on Phoenix LiveView and PostgreSQL:

1. **Spark** — a member posts an idea or question
2. **Contribution** — community responds (minimum 50 words, stance-tagged)
3. **Weave** — a curator assembles highlighted contributions into a draft
4. **Insight** — published, versioned artifact with fractional contributor ownership

---

## Tech Stack

| Layer | Choice |
|-------|--------|
| Language / Runtime | Elixir 1.18, OTP 27 |
| Web framework | Phoenix 1.8, LiveView 1.0, Bandit |
| Database / ORM | PostgreSQL 16, Ecto 3.12 |
| Auth | Guardian 2.3 (JWT), pure-Elixir SIWE (EIP-4361), Ex_Keccak 0.7 (Rustler NIF) |
| Email | Swoosh 1.16 + Finch 0.18 |
| Frontend | Tailwind CSS 3.4 + esbuild, Heroicons |
| Testing | ExUnit, Floki, ExCoveralls |
| Linting | Credo 1.7 |

---

## Repository Layout

```
insightnest/
├── lib/
│   ├── insightnest/           # Domain — contexts, schemas, business logic
│   │   ├── accounts/          # Member identity & auth utilities
│   │   ├── auth/              # SIWE, JWT, secp256k1
│   │   ├── sparks/            # Spark lifecycle
│   │   ├── contributions/     # Community responses & highlight voting
│   │   ├── weaves/            # Weave curation & Insight publishing
│   │   ├── library/           # Read-only published Insights
│   │   ├── publisher/         # Abstract external-storage interface
│   │   ├── application.ex
│   │   ├── mailer.ex
│   │   ├── error.ex
│   │   └── repo.ex
│   └── insightnest_web/       # Phoenix web layer
│       ├── components/        # Reusable HEEx components
│       ├── controllers/       # Auth, health HTTP endpoints
│       ├── live/              # LiveView pages & hooks
│       ├── plugs/             # HTTP middleware
│       ├── emails/            # Swoosh email templates
│       ├── endpoint.ex
│       └── router.ex
├── priv/repo/migrations/      # Ecto migrations
├── assets/                    # CSS / JS sources
├── config/                    # config.exs, dev/prod/test/runtime.exs
├── test/
│   ├── bdd/                   # BDD-style integration scenarios
│   ├── insightnest/           # Context unit tests
│   └── insightnest_web/       # LiveView & controller tests
├── Dockerfile                 # Multistage build
├── render.yaml                # Render.com service definition
└── docker-compose.yml         # Local dev stack
```

---

## Contexts

### Accounts (`lib/insightnest/accounts/`)

Manages members and identity.

**Public API — `Insightnest.Accounts`**

| Function | Purpose |
|----------|---------|
| `find_or_create_by_wallet/1` | SIWE login — upsert by wallet address |
| `find_or_create_by_email/1` | Email login — upsert by email |
| `set_username/2` | Onboarding — set username for a member |
| `onboarded?/1` | Returns `true` when username is set |
| `verify_email/1` | Mark email as verified |
| `username_taken?/1` | Case-insensitive uniqueness check |
| `generate_passcode/0` | 6-digit numeric code for email auth |

**Supporting modules**

- `Accounts.Member` — Ecto schema; `wallet_changeset`, `email_changeset`, `username_changeset`
- `Accounts.Avatar` — Deterministic 5×5 SVG identicon (`generate/1`, `data_uri/1`)
- `Accounts.NonceStoreETS` — ETS-backed SIWE nonce store with TTL (swappable via `NonceStore` behaviour)
- `Accounts.PasscodeStore` — ETS-backed email passcode store (10-minute TTL)

---

### Auth (`lib/insightnest/auth/`)

Cryptographic authentication only — no Ecto calls.

- `Auth.Guardian` — JWT issue / verify / resource lookup (Guardian 2.3)
- `Auth.Siwe` — Pure-Elixir SIWE (EIP-4361) parser and verifier
- `Auth.Secp256k1` — Pure-Elixir ECDSA public-key recovery; uses `ex_keccak` NIF for Keccak-256

---

### Sparks (`lib/insightnest/sparks/`)

**Public API — `Insightnest.Sparks`**

| Function | Purpose |
|----------|---------|
| `list_published/0` | All published Sparks, newest first |
| `list_by_author/1` | Member's own Sparks |
| `get_spark!/1`, `get_spark_by_slug!/1` | Retrieval with preloads |
| `search_published/1` | PostgreSQL full-text search (`@@` operator) |
| `create_spark/2` | Creates with engagement gate validation |
| `publish_spark/2` | Transitions draft → published |
| `update_spark/3` | Updates title / body / concepts |
| `extend_spark/3` | Extends close date (max 2 extensions, 90-day ceiling) |
| `author?/2` | Authorization check |

**Schema — `Sparks.Spark`**

Fields: `title`, `body`, `concepts` (text[]), `status` (draft|published), `slug`, `content_hash`, `closes_at`, `extension_count`, `search_vector` (tsvector, GIN indexed).

---

### Contributions (`lib/insightnest/contributions/`)

**Public API — `Insightnest.Contributions`**

| Function | Purpose |
|----------|---------|
| `list_for_spark/1` | All active contributions, oldest first |
| `list_highlighted/1` | Highlighted contributions only |
| `create_contribution/3` | Enforces gate rules (one per member, min 50 words) |
| `delete_contribution/2` | Soft-delete (status → hidden) |
| `already_contributed?/2` | One-per-member guard |
| `toggle_highlight/2` | Add / remove highlight vote |
| `author_override/3` | Spark author forces highlight on any contribution |
| `voter_highlights/2` | Returns `MapSet` of voted contribution IDs for a voter |

All writes broadcast on `Phoenix.PubSub` topic `"spark:#{spark_id}"`.

**Schemas**

- `Contributions.Contribution` — `body` (10–5000 chars, ≥50 words), `stance` (expands|challenges|evidence|question), `status` (active|hidden), `highlighted`, `highlight_count`, `author_override`; unique on `[spark_id, author_id]`
- `Contributions.HighlightVote` — junction table; unique on `[contribution_id, voter_id]`

---

### Weaves (`lib/insightnest/weaves/`)

**Public API — `Insightnest.Weaves`**

| Function | Purpose |
|----------|---------|
| `eligible_to_weave?/2` | True for the Spark author or any highlighted contributor |
| `trigger_weave/2` | Creates Weave + draft Insight; auto-computes contributor shares |
| `in_progress_weave/1` | Fetches in-progress Weave for a Spark |
| `update_draft/4` | Curator edits title / summary |
| `publish_insight/2` | Publishes Insight, broadcasts on `"library"` PubSub topic |

**Schemas**

- `Weaves.Weave` — `status` (in_progress|published|abandoned)
- `Weaves.Insight` — `version`, `title`, `summary`, `body` (JSONB blocks), `contributors` (JSONB shares), `slug`, `status` (draft|published), `codex_cid`; GIN full-text search index

**`Weaves.Weight`** — share calculator

Computes `%{member_id, wallet, roles, bps}` per contributor using a 40 / 20 / 40 model (author / curator / contributors). Handles edge cases: no contributors, curator == author, overlapping roles.

---

### Library (`lib/insightnest/library/`)

Read-only façade over published Insights.

- `list_insights/0`, `search/1`, `get_insight_by_slug!/1`, `get_insight!/1`, `get_ownership/1`

---

### Publisher (`lib/insightnest/publisher/`)

Behaviour for external Insight storage (Codex / IPFS planned for Phase 1).

- `Publisher` behaviour — `publish(insight)` → `{:ok, cid} | {:error, reason}`
- `Publisher.NoopPublisher` — Phase 0 stub; logs and returns a mock CID

---

## Database Schema

All tables use `binary_id` (UUID) primary keys.

```
members
  wallet_address  text unique
  email           text unique
  username        text unique (case-insensitive index)
  email_verified  boolean

sparks
  author_id       FK → members (cascade)
  title           text  (5–200 chars)
  body            text  (10–10 000 chars)
  concepts        text[]
  status          text  (draft|published)
  slug            text  unique
  content_hash    text
  closes_at       utc_datetime nullable
  extension_count int   default 0
  search_vector   tsvector generated (GIN indexed)

contributions
  spark_id        FK → sparks (cascade)
  author_id       FK → members (cascade)
  body            text  (min 50 words)
  stance          text  nullable (expands|challenges|evidence|question)
  status          text  (active|hidden)
  highlighted     boolean
  highlight_count int
  author_override boolean nullable
  UNIQUE (spark_id, author_id)

highlight_votes
  contribution_id FK → contributions (cascade)
  voter_id        FK → members (cascade)
  UNIQUE (contribution_id, voter_id)

weaves
  spark_id        FK → sparks (cascade)
  curator_id      FK → members (cascade)
  status          text  (in_progress|published|abandoned)

insights
  weave_id        FK → weaves (cascade)
  spark_id        FK → sparks (cascade)
  version         int   default 1
  title           text
  summary         text
  body            jsonb (array of blocks)
  contributors    jsonb (shares map)
  content_hash    text
  slug            text  unique
  status          text  (draft|published)
  codex_cid       text  nullable
  search_vector   tsvector generated (GIN indexed)

weave_contributions  (junction)
  weave_id        FK → weaves (cascade)
  contribution_id FK → contributions (cascade)
  PRIMARY KEY (weave_id, contribution_id)
```

---

## Router

**Pipelines**

| Pipeline | Plugs |
|----------|-------|
| `:browser` | Accepts HTML, session, flash, CSRF, secure headers, `LoadMember` (soft auth) |
| `:api` | Accepts JSON, session |
| `:authenticated` | `:browser` + `RequireAuth` (halts if no valid session) |

**Routes**

```
GET  /health                     HealthController.check
GET  /auth                       AuthController.index
GET  /auth/nonce                 AuthController.nonce        (API)
POST /auth/verify                AuthController.verify       (API — SIWE)
POST /auth/email/request         AuthController.request_passcode
POST /auth/email/verify          AuthController.verify_passcode
DELETE /auth/logout              AuthController.logout

GET  /onboarding                 OnboardingLive              (auth required)
GET  /                           SparkLive.Index             (soft auth)
GET  /garden                     GardenLive.Index            (onboarded)
GET  /sparks/new                 SparkLive.New               (onboarded)
GET  /sparks/:id                 SparkLive.Show              (soft auth)
GET  /weave/:spark_id            WeaveLive.Editor            (onboarded)
GET  /library                    LibraryLive.Index           (soft auth)
GET  /insights/:slug             LibraryLive.Show            (soft auth)
GET  /roadmap                    RoadmapLive                 (soft auth)

# Dev only
GET  /dev/dashboard              Phoenix LiveDashboard
GET  /dev/mailbox                Swoosh preview
```

**LiveView Auth Hooks** (`live/hooks/auth_hooks.ex`)

- `on_mount :default` — assigns `current_member` if session exists
- `on_mount :require_auth` — redirects to `/auth` if not logged in
- `on_mount :require_onboarded` — redirects to `/onboarding` if username not set

---

## LiveView Pages

| Module | Route | Auth |
|--------|-------|------|
| `SparkLive.Index` | `/` | soft |
| `SparkLive.New` | `/sparks/new` | onboarded |
| `SparkLive.Show` | `/sparks/:id` | soft — subscribes to `"spark:#{id}"` |
| `WeaveLive.Editor` | `/weave/:spark_id` | onboarded |
| `LibraryLive.Index` | `/library` | soft — subscribes to `"library"` |
| `LibraryLive.Show` | `/insights/:slug` | soft |
| `GardenLive.Index` | `/garden` | onboarded |
| `OnboardingLive` | `/onboarding` | auth required |
| `RoadmapLive` | `/roadmap` | soft |

---

## Component Library

| Module | Purpose |
|--------|---------|
| `CoreComponents` | Buttons, forms, badges, modals, flash messages |
| `SparkComponents` | Spark cards, empty states, reader controls |
| `ContributionComponents` | Contribution display, stance badges, highlight voting UI |
| `InsightComponents` | Insight cards, contributor-share display |

---

## Key Design Decisions

**Pure-Elixir crypto** — SIWE parsing and secp256k1 recovery are implemented in pure Elixir. Only `ex_keccak` (Keccak-256) uses a Rust NIF.

**Soft auth by default** — Most pages load `current_member` via `LoadMember` plug but do not require authentication. Hard gates are applied only where required.

**ETS-backed ephemeral stores** — `NonceStoreETS` and `PasscodeStore` use ETS with TTL expiration. Both implement swappable behaviours for future Redis backing.

**PostgreSQL full-text search** — `search_vector` tsvector columns (generated, GIN indexed) on `sparks` and `insights` for `@@ plainto_tsquery()` search.

**PubSub for real-time** — Contributions, highlights, and new Insights broadcast over Phoenix.PubSub. LiveViews subscribe to per-Spark and global library topics.

**Abstract Publisher** — The `Publisher` behaviour decouples Insight publishing from any specific storage backend. Phase 0 uses `NoopPublisher`; Codex / IPFS integration slots in via config.

**Fractional ownership** — `Weaves.Weight` computes on-chain-ready share allocations (basis points): 40% author, 20% curator, 40% highlighted contributors (split equally).

---

## Deployment

### Docker (multistage)

- **Builder** — `hexpm/elixir:1.18.0-erlang-27.2`; installs Rust (for `ex_keccak`), builds release + assets
- **Runtime** — `debian:bookworm-slim`; runs as unprivileged user `app` (UID 1000); entrypoint: `./bin/server`

### Render.com (`render.yaml`)

- Service type: Docker (Oregon, free tier)
- Health check: `GET /health`
- Database: Render-managed PostgreSQL 16
- Generated secrets: `SECRET_KEY_BASE`, `GUARDIAN_SECRET_KEY`, `LIVE_VIEW_SIGN_SALT`
- Manual env var: `PHX_HOST` (set post-deploy)

### Configuration highlights

- `config.exs` — Guardian 7-day JWT TTL; nonce TTL 300 s; highlight threshold 3; asset builder paths
- `runtime.exs` — Reads `DATABASE_URL`, `POOL_SIZE`, `PORT`, secrets from environment; raises on missing required vars
- `prod.exs` — Static asset manifest caching; Swoosh API client; logger level info

---

## Tests

```
test/
├── bdd/
│   ├── spark_lifecycle_test.exs
│   ├── contribution_lifecycle_test.exs
│   ├── member_scenarios_test.exs
│   └── auth_scenarios_test.exs
├── insightnest/
│   ├── accounts/
│   ├── auth/
│   ├── contributions/
│   ├── sparks/
│   └── weaves/
└── insightnest_web/
    ├── live/
    └── controllers/
```

- ExUnit with Ecto sandbox (manual mode for async tests)
- Floki / lazy_html for HTML assertions in LiveView tests
- ExCoveralls for coverage reporting
- Credo for static analysis (`mix credo`)
