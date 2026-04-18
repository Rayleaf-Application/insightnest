{ pkgs ? import <nixpkgs> {} }:

let
  # Pin Erlang 27 + matching Elixir 1.17
  beamPkgs = pkgs.beam.packages.erlang_27;
  elixir   = beamPkgs.elixir_1_18;
  erlang   = beamPkgs.erlang;

in pkgs.mkShell {
  name = "insightnest-dev";

  buildInputs = [
    # BEAM
    erlang
    elixir

    # Node (for Phoenix assets)
    pkgs.nodejs_20

    # Rust for siwe pkg
    pkgs.rustup

    # Build tools
    pkgs.gcc
    pkgs.gnumake
    pkgs.git

    # Postgres client (for psql CLI, migrations debugging)
    pkgs.postgresql_16

    # File watching (Phoenix live reload)
    pkgs.inotify-tools

    # Utilities
    pkgs.curl
    pkgs.jq
    pkgs.tailwindcss
    pkgs.nodePackages.postcss
  ];

  # Environment variables for the dev shell
  shellHook = ''    
    # Rust toolchain (rustler needs cargo in PATH)
    export RUSTUP_HOME="$PWD/.nix-rustup"
    export CARGO_HOME="$PWD/.nix-cargo"
    export PATH="$CARGO_HOME/bin:$PATH"

    # Install stable toolchain if not present
    rustup toolchain install stable --no-self-update > /dev/null 2>&1
    rustup default stable > /dev/null 2>&1

    # Hex + Rebar local installs go here, not to $HOME globally
    export MIX_HOME="$PWD/.nix-mix"
    export HEX_HOME="$PWD/.nix-hex"
    export PATH="$MIX_HOME/bin:$HEX_HOME/bin:$PATH"

    # Tailwind
    export TAILWIND_PATH="$(which tailwindcss)"

    # Erlang/Elixir history
    export ERL_AFLAGS="-kernel shell_history enabled"

    # Phoenix dev defaults
    export MIX_ENV="dev"
    export PHX_HOST="localhost"
    export PHX_PORT="4000"
    export SIWE_CHAIN_ID="31337"

    # Database (Docker Compose Postgres)
    export DATABASE_URL="postgres://postgres:postgres@localhost:5432/insightnest_dev"
    export SECRET_KEY_BASE="dev_secret_key_base_at_least_64_chars_long_replace_in_prod_aaaa"
    export GUARDIAN_SECRET_KEY="dev_guardian_secret_change_in_prod"

    # Install Hex + Rebar if not already present
    mix local.hex --force --if-missing > /dev/null 2>&1
    mix local.rebar --force --if-missing > /dev/null 2>&1

    echo ""
    echo "  Insightnest dev shell"
    echo "  Elixir $(elixir --version | head -2 | tail -1)"
    echo "  Node   $(node --version)"
    echo ""
    echo "  make dev     → start Postgres + Phoenix"
    echo "  make reset   → drop DB, migrate, seed"
    echo "  make test    → run test suite"
    echo ""
  '';
}