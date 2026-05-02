defmodule InsightnestWeb.LibraryLive.Show do
  use InsightnestWeb, :live_view

  alias Insightnest.Library
  alias InsightnestWeb.InsightComponents

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    insight   = Library.get_insight_by_slug!(slug)
    ownership = Library.get_ownership(insight)

    {:ok,
     assign(socket,
       insight:    insight,
       ownership:  ownership,
       page_title: insight.title
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto px-4 py-10 animate-fade-up">

      <div class="flex items-center gap-3 mb-8">
        <a
          href="/library"
          class="inline-flex items-center gap-1.5 text-sm text-stone-600
                 hover:text-stone-300 transition-colors group"
        >
          <span class="group-hover:-translate-x-0.5 transition-transform">←</span>
          Library
        </a>
      </div>

      <InsightComponents.insight_viewer
        insight={@insight}
        ownership={@ownership}
      />

    </div>
    """
  end
end