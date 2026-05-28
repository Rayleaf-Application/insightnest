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

  pipeline :admin_api do
    plug InsightnestWeb.Plugs.RequireAdminKey
  end

  # ── Waitlist — public signup ──────────────────────────────────────────────────

  scope "/api/waitlist", InsightnestWeb do
    pipe_through :api
    post "/", WaitlistController, :signup
  end

  # ── Waitlist — admin CRUD ────────────────────────────────────────────────────

  scope "/api/waitlist", InsightnestWeb do
    pipe_through [:api, :admin_api]
    get "/", WaitlistController, :index
    patch "/:id", WaitlistController, :update
    delete "/:id", WaitlistController, :delete
  end

  # ── Members — admin ───────────────────────────────────────────────────────────

  scope "/api/members", InsightnestWeb do
    pipe_through [:api, :admin_api]
    get "/", MemberAdminController, :index
    patch "/:id", MemberAdminController, :update
  end

  # ── Health check & sitemap ────────────────────────────────────────────────────

  scope "/", InsightnestWeb do
    pipe_through :api
    get "/health", HealthController, :check
    get "/sitemap.xml", SitemapController, :index
  end

  # ── Auth routes (JSON, no CSRF needed for nonce/verify) ──────────────────────

  scope "/auth", InsightnestWeb do
    pipe_through :api

    get "/nonce", AuthController, :nonce
    post "/verify", AuthController, :verify

    post "/email/request", AuthController, :request_passcode
    post "/email/verify", AuthController, :verify_passcode

    delete "/logout", AuthController, :logout
  end

  # Onboarding — auth required, no username required
  scope "/", InsightnestWeb do
    pipe_through :browser
    live "/onboarding", OnboardingLive, :index
  end

  # ── Auth page (HTML) ──────────────────────────────────────────────────────────

  scope "/auth", InsightnestWeb do
    pipe_through :browser
    get "/", AuthController, :index
  end

  # ── App routes — soft auth via on_mount hooks ─────────────────────────────────
  scope "/", InsightnestWeb do
    pipe_through :browser

    live "/", LandingLive, :index
    live "/feed", SparkLive.Index, :index
    live "/garden", GardenLive.Index, :index
    live "/garden/settings", GardenLive.Settings, :index
    live "/sparks/new", SparkLive.New, :new
    live "/sparks/:id", SparkLive.Show, :show
    live "/weave/:spark_id", WeaveLive.Editor, :edit
    live "/library", LibraryLive.Index, :index
    live "/insights/:slug", LibraryLive.Show, :show
    live "/roadmap", RoadmapLive, :index
  end

  # ── GDPR — authenticated controller routes ────────────────────────────────────
  scope "/garden", InsightnestWeb do
    pipe_through [:browser, :authenticated]
    get "/export", GardenController, :export
  end

  scope "/auth", InsightnestWeb do
    pipe_through :browser
    get "/delete_redirect", AuthController, :delete_redirect
  end

  # ── Dev routes ────────────────────────────────────────────────────────────────

  if Application.compile_env(:insightnest, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: InsightnestWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
