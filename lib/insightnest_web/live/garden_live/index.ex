defmodule InsightnestWeb.GardenLive.Index do
  use InsightnestWeb, :live_view

  on_mount {InsightnestWeb.Live.AuthHooks, :require_onboarded}

  import Ecto.Query
  alias Insightnest.{Repo, Sparks}
  alias Insightnest.Weaves.Insight
  alias InsightnestWeb.SparkComponents

  @impl true
  def mount(_params, _session, socket) do
    member  = socket.assigns.current_member
    sparks  = Sparks.list_by_author(member.id)
    insights = member_insights(member.id)

    {:ok,
     assign(socket,
       page_title: "Garden — #{member.username}",
       sparks:     sparks,
       insights:   insights
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto px-4 py-10 animate-fade-up">

      <!-- Header -->
      <div class="flex items-center gap-4 mb-10">
        <div class="w-14 h-14 rounded-2xl overflow-hidden border border-stone-700/60 shrink-0">
          {Phoenix.HTML.raw(
            Insightnest.Accounts.Avatar.generate(
              @current_member.wallet_address || @current_member.email || "anon"
            )
          )}
        </div>
        <div>
          <h1
            class="text-xl font-medium text-stone-100"
            style="font-family: 'Playfair Display', serif;"
          >
            @{@current_member.username}
          </h1>
          <p class="text-xs text-stone-600 mt-0.5" style="font-family: 'DM Mono', monospace;">
            {identity(@current_member)}
          </p>
        </div>
      </div>

      <!-- Stats -->
      <div class="grid grid-cols-3 gap-3 mb-10">
        <.stat label="Sparks"     value={length(@sparks)} />
        <.stat label="Insights"   value={length(@insights)} />
        <.stat label="Published"  value={Enum.count(@sparks, &(&1.status == "published"))} />
      </div>

      <!-- Sparks -->
      <section class="mb-10">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-xs text-stone-600 uppercase tracking-widest">Your Sparks</h2>
          <a href="/sparks/new"
             class="text-xs text-violet-400 hover:text-violet-300 transition-colors">
            + New Spark
          </a>
        </div>

        <div :if={@sparks == []} class="text-center py-10 text-stone-700 text-sm">
          No Sparks yet.
          <a href="/sparks/new" class="text-violet-500 hover:text-violet-400 ml-1">
            Create one →
          </a>
        </div>

        <div class="space-y-2">
          <.spark_row :for={spark <- @sparks} spark={spark} />
        </div>
      </section>

      <!-- Insights -->
      <section>
        <h2 class="text-xs text-stone-600 uppercase tracking-widest mb-4">
          Insights Contributed
        </h2>

        <div :if={@insights == []} class="text-center py-10 text-stone-700 text-sm">
          Contribute to Sparks to appear in published Insights.
        </div>

        <div class="space-y-2">
          <.insight_row :for={insight <- @insights} insight={insight} />
        </div>
      </section>

    </div>
    """
  end

  # ── Sub-components ────────────────────────────────────────────────────────────

  defp stat(assigns) do
    ~H"""
    <div class="rounded-xl border border-stone-800 bg-stone-900/50 p-4 text-center">
      <p class="text-2xl font-medium text-stone-100">{@value}</p>
      <p class="text-xs text-stone-600 mt-1">{@label}</p>
    </div>
    """
  end

  defp spark_row(assigns) do
    ~H"""
    <a
      href={"/sparks/#{@spark.id}"}
      class="flex items-center justify-between py-3 px-4 rounded-xl
             border border-stone-800 hover:border-stone-700
             bg-stone-900/40 hover:bg-stone-900 transition-all group"
    >
      <div class="flex items-center gap-3 min-w-0">
        <SparkComponents.status_chip status={@spark.status} />
        <span class="text-sm text-stone-300 truncate
                     group-hover:text-stone-100 transition-colors">
          {@spark.title}
        </span>
      </div>
      <div class="flex items-center gap-2 shrink-0 ml-3">
        <SparkComponents.closes_in_badge
          closes_at={@spark.closes_at}
          is_closed={@spark.is_closed}
        />
        <span class="text-xs text-stone-700">{format_date(@spark.inserted_at)}</span>
      </div>
    </a>
    """
  end

  defp insight_row(assigns) do
    ~H"""
    <a
      href={"/insights/#{@insight.slug}"}
      class="flex items-center justify-between py-3 px-4 rounded-xl
             border border-stone-800 hover:border-stone-700
             bg-stone-900/40 hover:bg-stone-900 transition-all group"
    >
      <span class="text-sm text-stone-300 truncate
                   group-hover:text-stone-100 transition-colors">
        {@insight.title}
      </span>
      <span class="text-xs text-stone-700 shrink-0 ml-3">
        {format_date(@insight.inserted_at)}
      </span>
    </a>
    """
  end

  # ── Helpers ───────────────────────────────────────────────────────────────────

  defp member_insights(member_id) do
    Insight
    |> where([i], i.status == "published")
    |> Repo.all()
    |> Enum.filter(fn insight ->
      shares = get_in(insight.contributors, ["shares"]) || []
      Enum.any?(shares, &(&1["member_id"] == member_id))
    end)
    |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
  end

  defp identity(%{wallet_address: w}) when not is_nil(w) do
    String.slice(w, 0, 6) <> "…" <> String.slice(w, -4, 4)
  end
  defp identity(%{email: e}) when not is_nil(e), do: e
  defp identity(_), do: "anonymous"

  defp format_date(%DateTime{} = dt) do
    "#{dt.day}/#{dt.month}/#{dt.year}"
  end
  defp format_date(_), do: ""
end
