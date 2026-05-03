# Contributing to InsightNest

Thank you for your interest in contributing to InsightNest. We are building a platform where ideas are nurtured, not diluted. As we transition from a solo-developer MVP to a community-governed ecosystem, we prioritize **clarity, architectural integrity, and alignment with our core principles** over speed.

## 🌱 How to Contribute

### 1. Reporting Issues
Before opening an issue, please search the existing tracker to see if it has already been reported.

When creating a new issue:
- **Bug Reports:** Include steps to reproduce, expected behavior, actual behavior, and your environment (OS, Elixir version, browser).
- **Feature Requests:** Explain the *problem* you are trying to solve, not just the solution. How does this align with "slow knowledge," "attention-based friction," or "sovereign identity"?
- **Security:** If you discover a security vulnerability, please do not open a public issue. Contact us directly via the support channel on our demo site.

### 2. Branch Naming
We follow a simple, descriptive convention for branch names:
- `feat/<short-description>`: New features (e.g., `feat/email-passcode-login`)
- `fix/<short-description>`: Bug fixes (e.g., `fix/weave-share-calculation`)
- `docs/<short-description>`: Documentation updates
- `chore/<short-description>`: Maintenance tasks (e.g., `chore/update-dependencies`)

### 3. Pull Request Expectations
We value small, focused changes over massive refactors.

- **Scope:** Keep PRs focused on a single logical change. If a PR touches too many unrelated areas, it may be split.
- **Tests:** All new features and bug fixes must include tests. We use `ExUnit`. Ensure `mix test` passes locally before submitting.
- **Type Safety:** If you introduce new structs, types, or protocols, update the `@typedoc` or `@type` annotations.
- **Code Style:** Follow the standard Elixir style guide. We use `mix format` and `mix credo` for linting.
- **Context:** In your PR description:
  - Link to the related issue (if any).
  - Explain *why* you made your architectural choices.
  - Mention any trade-offs considered.

## 🏗 Architectural Guardrails

InsightNest makes several deliberate engineering choices to ensure sovereignty and simplicity. Please respect these boundaries:

- **Pure Elixir SIWE:** We reject Rust NIFs (`siwe_ex`) to maintain compatibility with OTP 27 and NixOS. Any auth-related PRs must adhere to this constraint.
- **Single Repo:** There is no umbrella project. The backend and frontend are unified in Phoenix LiveView.
- **Attention Friction:** Logic enforcing read-times and word counts is core to the domain, not an afterthought. Do not remove or bypass these constraints without a compelling, community-voted reason.
- **No External Dependencies:** We prefer minimal dependencies. If you propose adding a new Hex package, justify why it cannot be implemented with standard library or existing tools.

## 🤝 Code of Conduct

We are building a space for respectful, constructive dialogue.
- **Be Inclusive:** Welcome diverse perspectives and backgrounds.
- **Focus on Ideas:** Critique the code and the concept, not the person.
- **Assume Good Faith:** We are all learning and building together.
- **Patience:** We value "slow knowledge." Reviews may take time as we ensure every change aligns with our long-term vision.

## 📬 Contact

For questions not covered here, please open a **"Discussion"** thread in the GitHub repository or reach out via the support channel on our demo site.

Let's build something that lasts.