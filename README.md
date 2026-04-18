# Insightnest

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix

## Daily dev workflow
# 1. cd into project — direnv auto-loads the nix shell
cd ~/projects/insightnest
# "Insightnest dev shell" message appears automatically

# 2. Start everything
make dev
# → pulls Postgres image if missing, starts container
# → runs mix phx.server on :4000

# 3. Second terminal — IEx session
cd ~/projects/insightnest   # direnv re-enters shell
make shell

# 4. Run tests
make test
