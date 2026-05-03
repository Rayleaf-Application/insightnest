# Architecture & Design

This document outlines the technical and philosophical architecture of InsightNest. It describes how we transform raw ideas into owned knowledge assets.

## 🧠 The Knowledge Pipeline

InsightNest is built around a four-stage pipeline. Unlike traditional social media where content is ephemeral, our goal is **crystallization**.

### 1. Spark (The Seed)
- **Definition:** An entry point for an idea, opinion, or question.
- **Constraints:** Lightweight. Can have an optional closing deadline.
- **Mechanism:** Authenticated members post Sparks. The author can extend the deadline twice.
- **State:** `open` → `closed` (still accepts Weaves, no new contributions).

### 2. Contribution (The Growth)
- **Definition:** Structured responses to a Spark.
- **Friction:**
  - **Read Timer:** Must read the Spark for a calculated time (capped at 3 mins) before contributing.
  - **Word Count:** Minimum 50 words.
- **Stances:** Contributions are tagged with a stance: `expands`, `challenges`, `evidence`, or `question`.
- **Highlighting:** Community voting (3 votes = auto-highlight) or author override. Highlights are the raw material for the Weave.

### 3. Weave (The Crystallization)
- **Definition:** The process of turning a discussion into a canonical artifact.
- **Trigger:** Initiated by the Spark author or any contributor with a highlighted contribution.
- **Process:**
  1. Highlighted contributions are assembled into a draft, grouped by stance.
  2. The curator edits the title, summary, and framing.
  3. **Ownership Calculation:** Shares are computed (40% Author, 20% Curator, 40% Contributors split).
  4. **Publish:** The draft becomes a versioned Insight.
- **Versioning:** A Spark can have multiple Weaves, each producing a new Insight version with a unique content hash.

### 4. Insight (The Asset)
- **Definition:** The published, immutable artifact stored in the Knowledge Library.
- **Properties:**
  - Versioned and content-addressed.
  - Carries a record of all contributors and their fractional ownership.
  - **Future State:** Pinned to Codex (Phase 2) and minted as an ERC-721 token with on-chain shares (Phase 3).

## 🏗 Technical Stack Mapping

| Component | Technology | Rationale |
| :--- | :--- | :--- |
| **Backend & UI** | Phoenix LiveView | Real-time updates via PubSub without client-side JS complexity. |
| **Database** | PostgreSQL 16 | Robust relational data + `tsvector` for full-text search. |
| **Authentication** | SIWE (Pure Elixir) | Sovereign identity. No Rust NIFs, ensuring NixOS compatibility. |
| **Search** | PostgreSQL `tsvector` | Phase 0: Native DB search. Phase 4: Codex-pinned manifest. |
| **Storage** | Local FS → Codex | Phase 0: Local. Phase 2: Decentralized, immutable storage. |
| **Messaging** | Phoenix PubSub → Waku | Phase 0: Centralized real-time. Phase 1: Decentralized Waku sidecar. |

## 🗺️ Roadmap

### Phase 0: MVP Feature Completion (Current)
- **Goal:** Deliver a functional, centralized platform with attention-based friction.
- **Status:** In Progress (Sprints 1–5 complete).
- **Key Deliverables:** SIWE Auth, Spark/Contribution/Weave flows, Share computation, Knowledge Library.
- **Next Steps:** Email passcode login, CI/CD, LiveDashboard.

### Phase 1: Decentralized Messaging
- **Goal:** Replace Phoenix PubSub with a censorship-resistant layer.
- **Tech:** `nwaku` sidecar + `js-waku` client.
- **Impact:** Live discussions become ephemeral and decentralized; only finalized Insights persist in the DB.

### Phase 2: Decentralized Storage (Codex)
- **Goal:** Pin Insights to Codex for immutability.
- **Tech:** Swap `NoopPublisher` for `CodexPublisher`.
- **Impact:** Content is no longer dependent on a single server.

### Phase 3: On-Chain Ownership
- **Goal:** Mint ERC-721 tokens for Insights; distribute shares on-chain.
- **Tech:** Status Network (L2) → Nomos Mainnet.
- **Impact:** True fractional ownership and transferable assets.

### Phase 4: DAO Governance
- **Goal:** Transfer governance to token holders.
- **Tech:** Voting via Waku; Treasury managed by DAO.
- **Impact:** The community decides the future of the platform.

## 🔒 Security & Privacy

- **Zero-Knowledge Identity:** Login via wallet signature (SIWE) or email passcode. No passwords stored.
- **Data Minimization:** Only essential data (username, wallet address) is collected.
- **Encryption:** All data at rest is encrypted (PostgreSQL TDE or application-level where applicable).
- **Auditability:** All ownership calculations and state transitions are logged and verifiable.