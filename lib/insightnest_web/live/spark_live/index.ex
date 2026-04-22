defmodule InsightnestWeb.SparkLive.Index do
  use InsightnestWeb, :live_view

  alias Insightnest.Sparks
  alias InsightnestWeb.SparkComponents

  @impl true
  def mount(_params, _session, socket) do
    sparks = Sparks.list_published()
    {:ok,
     assign(socket, sparks: sparks, page_title: "InsightNest"),
     layout: {InsightnestWeb.Layouts, :app}}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto px-4 py-10">
        <%!-- Hero line --%>
        <div class="mb-10 animate-fade-up">
          <h1
            class="text-3xl text-stone-100 mb-2 leading-tight"
            style="font-family: 'Playfair Display', serif;"
          >
            Slow knowledge,<br />
            <span class="italic text-violet-400">co-owned.</span>
          </h1>
          <p class="text-sm text-stone-500 leading-relaxed max-w-md">
            Ideas refined through discussion. Insights owned by the contributors who shaped them.
          </p>
        </div>

        <%!-- Empty state --%>
        <SparkComponents.empty_state
          :if={@sparks == []}
          title="No sparks yet."
          body="Be the first to post an idea."
          cta_label="Create a Spark"
          cta_href={if @current_member, do: "/sparks/new", else: "/auth"}
        />

        <%!-- Feed --%>
        <div class="space-y-3">
          <SparkComponents.spark_card
            :for={{spark, i} <- Enum.with_index(@sparks)}
            spark={spark}
            index={i}
          />
        </div>
      </div>
    """
  end
end
