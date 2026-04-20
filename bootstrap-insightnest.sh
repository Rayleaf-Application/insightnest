#!/usr/bin/env bash
set -euo pipefail

echo "→ Updating apt..."
sudo apt-get update -qq

echo "→ Installing system dependencies..."
sudo apt-get install -y --no-install-recommends \
  build-essential \
  git \
  curl \
  unzip \
  libssl-dev \
  libncurses-dev \
  libffi-dev \
  libreadline-dev \
  zlib1g-dev \
  inotify-tools \
  automake \
  autoconf \
  libxml2-utils \
  m4 \
  ca-certificates \
  gnupg

# ── asdf ────────────────────────────────────────────────────────────────────
echo "→ Installing asdf..."
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.1
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.zshrc
. "$HOME/.asdf/asdf.sh"

# ── Erlang ──────────────────────────────────────────────────────────────────
echo "→ Installing Erlang/OTP 27..."
asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git
KERL_BUILD_DOCS=yes asdf install erlang 27.0
asdf global erlang 27.0

# ── Elixir ──────────────────────────────────────────────────────────────────
echo "→ Installing Elixir 1.17..."
asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git
asdf install elixir 1.17.3-otp-27
asdf global elixir 1.17.3-otp-27

# ── Node.js ─────────────────────────────────────────────────────────────────
echo "→ Installing Node.js 20..."
asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
asdf install nodejs 20.15.0
asdf global nodejs 20.15.0

# ── Hex + Rebar ─────────────────────────────────────────────────────────────
echo "→ Installing Hex and Rebar..."
mix local.hex --force
mix local.rebar --force

echo ""
echo "✓ Bootstrap complete. Run: source ~/.bashrc"
echo "  Then verify with: elixir --version && mix --version"
