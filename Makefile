# insightnest/Makefile
DC      := podman compose
COMPOSE := $(DC) -f docker-compose.yml

.DEFAULT_GOAL := help

.PHONY: help dev db db-stop db-logs db-wait reset migrate rollback \
        seed test test-watch test-cover shell format lint deps clean setup

help:                             ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

# ── Docker services ───────────────────────────────────────────────────────────

db:                               ## Start Postgres in background
	$(COMPOSE) up -d db

db-stop:                          ## Stop Postgres
	$(COMPOSE) down

db-logs:                          ## Tail Postgres logs
	$(COMPOSE) logs -f db

db-wait: db                       ## Wait until Postgres is healthy
	@echo "Waiting for Postgres..."
	@until $(COMPOSE) exec db pg_isready -U postgres > /dev/null 2>&1; do \
	  sleep 1; \
	done
	@echo "✓ Postgres ready"

# ── Phoenix ───────────────────────────────────────────────────────────────────

dev: db-wait                      ## Start Postgres + Phoenix dev server
	mix phx.server

# ── Database management ───────────────────────────────────────────────────────

reset: db-wait                    ## Drop DB, recreate, migrate, seed
	mix ecto.drop --force-drop
	mix ecto.create
	mix ecto.migrate
	mix run priv/repo/seeds.exs
	@echo "✓ Reset complete"

migrate:                          ## Run pending migrations
	mix ecto.migrate

rollback:                         ## Roll back one migration
	mix ecto.rollback

seed:                             ## Run seeds (idempotent)
	mix run priv/repo/seeds.exs

# ── Testing ───────────────────────────────────────────────────────────────────

test: db-wait                     ## Run test suite
	MIX_ENV=test mix test

test-watch: db-wait               ## Run tests in watch mode
	MIX_ENV=test mix test.watch

test-cover: db-wait               ## Run tests with coverage report
	MIX_ENV=test mix test --cover

# ── Utilities ─────────────────────────────────────────────────────────────────

shell:                            ## Open IEx with project loaded
	iex -S mix

format:                           ## Format Elixir source
	mix format

lint:                             ## Run Credo linter
	mix credo --strict

deps:                             ## Fetch mix dependencies
	mix deps.get

deps-update:                      ## Update all dependencies
	mix deps.update --all

clean:                            ## Remove build artefacts
	mix clean
	rm -rf _build deps .nix-mix .nix-hex

setup: deps db-wait migrate seed  ## First-time project setup
	@echo "✓ Ready — run: make dev"
