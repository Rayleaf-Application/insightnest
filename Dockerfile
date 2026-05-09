# ==========================================
# Stage 1: Build
# ==========================================
FROM hexpm/elixir:1.18.0-erlang-27.2 AS build

# Build deps: Rust for ex_keccak (Rustler NIF), curl for tailwindcss binary
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    curl \
    libssl-dev \
    libgmp-dev \
    pkg-config \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Rust toolchain — required by ex_keccak (Rustler NIF)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Standalone tailwindcss binary — project calls the binary directly, no npm needed
ARG TAILWIND_VERSION=3.4.17
RUN curl -sLo /usr/local/bin/tailwindcss \
    "https://github.com/tailwindlabs/tailwindcss/releases/download/v${TAILWIND_VERSION}/tailwindcss-linux-x64" \
    && chmod +x /usr/local/bin/tailwindcss

ENV MIX_ENV=prod \
    HEX_HOME=/root/.hex \
    MIX_HOME=/root/.mix

RUN mix local.hex --force && \
    mix local.rebar --force

WORKDIR /app

# Copy manifests first — deps layer is cached until mix.lock changes
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

COPY . .

RUN mix deps.compile
RUN mix compile
RUN mix assets.deploy
RUN mix release

# ==========================================
# Stage 2: Runtime
# ==========================================
FROM debian:bookworm-slim

# Erlang runtime libs + SSL (no build tools, no Rust, no Node)
RUN apt-get update && apt-get install -y \
    libstdc++6 \
    libncurses6 \
    libssl3 \
    libgmp10 \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -u 1000 -m -d /app -s /bin/bash app

WORKDIR /app

COPY --from=build --chown=app:app /app/_build/prod/rel/insightnest /app

ENV HOME=/app \
    PORT=4000 \
    ERL_AFLAGS="-kernel shell_history enabled"

EXPOSE 4000

USER app

CMD ["./bin/server"]
