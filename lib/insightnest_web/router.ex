defmodule InsightnestWeb.Router do
  use InsightnestWeb, :router

  # ── Pipelines ─────────────────────────────────────────────────────────────────

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {InsightnestWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    # soft auth — sets current_member or nil
    plug InsightnestWeb.Plugs.LoadMember
  end

  pipeline :api do
    plug :accepts, ["json"]
    # needed so auth/verify can write session
    plug :fetch_session
  end

  pipeline :authenticated do
    # hard auth — halts if no valid session
    plug InsightnestWeb.Plugs.RequireAuth
  end

  # ── Auth routes (JSON, no CSRF needed for nonce/verify) ──────────────────────

  scope "/auth", InsightnestWeb do
    pipe_through :api
    get "/nonce", AuthController, :nonce
    post "/verify", AuthController, :verify
    delete "/logout", AuthController, :logout
  end

  # ── Auth page (HTML) ──────────────────────────────────────────────────────────

  scope "/auth", InsightnestWeb do
    pipe_through :browser
    get "/", AuthController, :index
  end

  # ── Authenticated routes ───────────────────────────────────────────────────────

  scope "/", InsightnestWeb do
    pipe_through [:browser, :authenticated]

    live "/sparks/new", SparkLive.New, :new
    live "/weave/:spark_id", WeaveLive.Editor, :edit
    live "/garden", GardenLive.Index, :index
  end

  # ── Public routes ─────────────────────────────────────────────────────────────

  # Public routes — soft auth via hook
  scope "/", InsightnestWeb do
    pipe_through :browser

    live "/", SparkLive.Index, :index
    live "/sparks/:id", SparkLive.Show, :show
    live "/library", LibraryLive.Index, :index
    live "/insights/:slug", LibraryLive.Show, :show
  end

  # ── Dev routes ────────────────────────────────────────────────────────────────

  if Application.compile_env(:insightnest, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: InsightnestWeb.Telemetry
    end
  end
end
