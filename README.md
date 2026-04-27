<br>
<div align="center">
  <h1>InsightNest</h1>
</div>
---

## 🚀 Key Features

  * **Workflow Logic:** Handles the "Spark" $\rightarrow$ "Contribution" $\rightarrow$ "Weave" workflow state transitions.
  * **Decentralized Integration:** Manages the pipeline for committing final "Insight" artifacts to **IPFS/Filecoin**.
  * **Sovereign Identity:** Core services for non-custodial login and user profile management (built for DID integration).
  * **Monetization Hooks:** Infrastructure for future fractional ownership tokenization.

---

## 🛠️ Getting Started (Local Development)
### Daily dev workflow
  1. `cd` into project — `direnv` auto-loads the nix shell.
	  * `cd ~/projects/insightnest`
	    → "Insightnest dev shell" message appears automatically

  2. Start everything
	  * `make dev`
	    → pulls Postgres image if missing, starts container
	    → runs mix phx.server on :4000

  3. Second terminal — `IEx` session
	  * `cd ~/projects/insightnest`
	    → `direnv` re-enters shell
	  * `make shell`

  4. Run tests
  * `make test`

## 📝 WIP - Contributing
