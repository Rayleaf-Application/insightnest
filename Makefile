DC := docker compose

.PHONY: dev reset migrate rollback seed test test-watch logs shell

dev:                              ## Start dev server
	$(DC) up

dev-build:                        ## Rebuild and start
	$(DC) up --build

reset:                            ## Drop DB, recreate, migrate, seed
	$(DC) down -v db
	$(DC) up -d db
	@echo "Waiting for Postgres..."
	@sleep 4
	$(DC) run --rm app mix ecto.create
	$(DC) run --rm app mix ecto.migrate
	$(DC) run --rm app mix run priv/repo/seeds.exs
	@echo "✓ Reset complete"

migrate:                          ## Run pending migrations
	$(DC) run --rm app mix ecto.migrate

rollback:                         ## Roll back one migration
	$(DC) run --rm app mix ecto.rollback

seed:                             ## Run seeds (idempotent)
	$(DC) run --rm app mix run priv/repo/seeds.exs

test:                             ## Run test suite
	$(DC) run --rm -e MIX_ENV=test app mix test

test-watch:                       ## Run tests in watch mode
	$(DC) run --rm -e MIX_ENV=test app mix test.watch

logs:                             ## Tail app logs
	$(DC) logs -f app

shell:                            ## Open IEx in running container
	$(DC) exec app iex -S mix

deps:                             ## Fetch dependencies
	$(DC) run --rm app mix deps.get