# InsightNest
**A privacy-focused, community co-owned knowledge platform.** InsightNest is designed for people who value slow, intentional thinking—a space where ideas are nurtured rather than diluted by algorithmic noise or AI-generated filler.
Users are not passive content consumers; they are co-creators who hold real ownership stakes in the knowledge they help produce.
> "Slow knowledge requires structural incentives for slowness."
## 🚀 Quick Start (Local Development)
InsightNest runs on **Elixir 1.18**, **Phoenix 1.8**, and **PostgreSQL 16**.
The recommended development environment is **NixOS** (or any Linux/macOS with `nix-shell`).
### Prerequisites
- [Nix](https://nixos.org/download.html) (with flakes enabled)
- Docker or Podman (for the database)
- Git
### Setup & Run
1. **Clone the repository:**
   ```bash   git clone https://github.com/Rayleaf-Application/insightnest.git```
   ```cd insightnest```

2. **Start the development shell:** This loads Elixir 1.18, Erlang/OTP 27, Node 20, and system Tailwind.
   ```nix-shell```

3. **Reset the database and start the server:**
   This command drops the existing DB (if any), creates a fresh one, runs migrations, seeds initial data, and starts the Phoenix server.
   ```make reset mix phx.server```

4. **Open your browser:** Navigate to [http://localhost:4000](http://localhost:4000).
   > **Note:** The first time you visit, you will be redirected to `/onboarding` to set your username. You can log in via **Wallet (SIWE)** or **Email Passcode** (planned for Sprint 6).

### Live Demo

Try the platform before you build: 👉 **[https://insightnest.xyz](https://insightnest.xyz)**

---

## 🧠 Core Philosophy

InsightNest operates on a four-stage pipeline designed to transform ephemeral discussion into durable, owned knowledge artifacts:

1. **Spark:** An idea or question posted by a member.
2. **Contribution:** Structured responses (min. 50 words) with stance tagging (`expands`, `challenges`, `evidence`, `question`).
3. **Weave:** The crystallization step where highlighted contributions are assembled into a draft.
4. **Insight:** The published, versioned artifact stored in the Knowledge Library, with fractional ownership shares assigned to contributors.

**Attention-Based Friction:** We intentionally gate contributions with read timers and word counts. These are not bugs; they are the product.

---

## 🛠 Tech Stack

|Layer|Technology|Notes|
|---|---|---|
|**Language**|Elixir 1.18 / OTP 27|Functional, concurrent, fault-tolerant|
|**Framework**|Phoenix 1.8|Built-in LiveView, Ecto, PubSub|
|**Database**|PostgreSQL 16|Full-text search via `tsvector`|
|**Auth**|SIWE (Pure Elixir)|No Rust NIFs. Signature verification via `ex_keccak`|
|**UI**|Phoenix LiveView 1.1|Real-time updates via PubSub, no JS framework|
|**CSS**|Tailwind CSS v3|System binary via Nix|
|**Dev Env**|NixOS + Docker/Podman|Reproducible builds, rootless DB|

---

## 📚 Documentation

- **[Contributing Guide](https://lumo.proton.me/CONTRIBUTING.md)**: How to open issues, branch naming conventions, and PR expectations.
- **[Architecture & Design](https://lumo.proton.me/docs/architecture.md)**: Deep dive into the Spark → Contribution → Weave → Insight pipeline, tech stack mapping, and roadmap.

---

## 📜 License

This project is licensed under the **GNU Affero General Public License v3.0 (AGPL-3.0)**. See [LICENSE](https://lumo.proton.me/LICENSE) for details.

_By using this software, you agree that any modifications deployed as a network service must also be open-sourced._