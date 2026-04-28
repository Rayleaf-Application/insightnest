# ==========================================
# Stage 1: Build
# ==========================================
FROM hexpm/elixir:1.18.0-erlang-27.2 AS build

# Install system dependencies
# - build-essential: For compiling Rustler crates (SIWE)
# - nodejs/npm: For Tailwind and asset compilation
# - git: Required by mix
# - libssl-dev, libgmp-dev: Common dependencies for Rustler/Erlang
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    curl \
    nodejs \
    npm \
    libssl-dev \
    libgmp-dev \
    pkg-config \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Rust toolchain (Required for Rustler/SIWE)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Set environment variables
ENV MIX_ENV=prod \
    HEX_HOME=/root/.hex \
    MIX_HOME=/root/.mix

# Install Hex and Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

WORKDIR /app

# 1. Copy dependency files first (Optimizes Docker layer caching)
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

# 2. Copy assets configuration and install Node dependencies
# This installs Tailwind, PostCSS, and other JS deps
# Assumes package.json is in the 'assets' folder (Standard Phoenix)
COPY package.json package-lock.json* ./assets/
RUN cd assets && npm install

# 3. Copy the rest of the application source
COPY . .

# 4. Compile dependencies
RUN mix deps.compile

# 5. Compile the application (Triggers asset compilation if configured)
# This runs `mix compile` which compiles Elixir and calls `npm run deploy` if configured
RUN mix compile

# 6. Generate the release
# Creates a self-contained OTP release in _build/prod/rel/
RUN mix release

# ==========================================
# Stage 2: Runtime
# ==========================================
FROM debian:bookworm-slim

# Install runtime dependencies only
# No build tools, no git, no npm needed here
RUN apt-get update && apt-get install -y \
    libstdc++6 \
    libncurses5 \
    libssl3 \
    libgmp10 \
    libmariadb3 \
    libsqlite3-0 \
    ca-certificates \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for security
RUN useradd -u 1000 -m -d /app -s /bin/bash app

WORKDIR /app

# Copy the release from the build stage
COPY --from=build --chown=app:app /app/_build/prod/rel/insightnest /app

# Set environment variables
ENV HOME=/app \
    PORT=8080 \
    ERL_AFLAGS="-kernel shell_history enabled"

# Expose the port
EXPOSE 8080

# Switch to non-root user
USER app

# Start the server
# Render will override this CMD if you set a start command in the dashboard
CMD ["./bin/server"]
