defmodule InsightnestWeb.LibraryLive.Index do
  use InsightnestWeb, :live_view

  alias Insightnest.Library
  alias InsightnestWeb.InsightComponents

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Insightnest.PubSub, "library")
    end

    insights = Library.list_insights()

    {:ok,
     assign(socket,
       insights:    insights,
       query:       "",
       page_title:  "Knowledge Library"
     )}
  end

  @impl true
  def handle_info({:insight_published, insight}, socket) do
    # Preload associations for the new insight
    insight = Insightnest.Repo.preload(insight, weave: :curator, spark: :author)
    {:noreply, update(socket, :insights, &[insight | &1])}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    insights = Library.search(query)
    {:noreply, assign(socket, insights: insights, query: query)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto px-4 py-10 animate-fade-up">

      <%!-- Header --%>
      <div class="mb-8">
        <h1
          class="text-2xl text-stone-100 mb-1"
          style="font-family: 'Playfair Display', serif;"
        >
          Knowledge Library
        </h1>
        <p class="text-sm text-stone-600">
          Community-crafted Insights, permanently preserved.
        </p>
      </div>

      <%!-- Search --%>
      <div class="mb-6">
        <input
          type="text"
          value={@query}
          placeholder="Search Insights…"
          phx-change="search"
          phx-debounce="300"
          name="query"
          class="w-full bg-stone-900 border border-stone-700 rounded-lg px-4 py-2.5
                 text-stone-200 placeholder-stone-700 text-sm
                 focus:outline-none focus:border-violet-500 focus:ring-1
                 focus:ring-violet-500/20 transition-colors"
        />
      </div>

      <%!-- Empty state --%>
      <div :if={@insights == []} class="text-center py-20">
        <p
          class="text-stone-500 mb-2"
          style="font-family: 'Playfair Display', serif; font-size: 1.1rem;"
        >
          {if @query != "", do: "No Insights match \"#{@query}\"", else: "No Insights yet."}
        </p>
        <p class="text-sm text-stone-700">
          {if @query != "",
            do: "Try a different search term.",
            else: "Complete a Weave to publish the first one."}
        </p>
      </div>

      <%!-- Feed --%>
      <div class="space-y-3">
        <InsightComponents.insight_card
          :for={{insight, i} <- Enum.with_index(@insights)}
          insight={insight}
          index={i}
        />
      </div>

    </div>
    """
  end
end