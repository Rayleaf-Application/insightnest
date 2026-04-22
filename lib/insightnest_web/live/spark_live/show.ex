defmodule InsightnestWeb.SparkLive.Show do
  use InsightnestWeb, :live_view

  alias Insightnest.Sparks
  alias InsightnestWeb.SparkComponents

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    spark = Sparks.get_spark!(id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Insightnest.PubSub, "spark:#{id}")
    end

    {:ok,
     assign(socket, spark: spark, page_title: spark.title),
     layout: {InsightnestWeb.Layouts, :app}}
  end

  @impl true
  def handle_info({:spark_updated, spark}, socket) do
    {:noreply, assign(socket, spark: spark)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto px-4 py-10 animate-fade-up">
        <%!-- Breadcrumb --%>
        <a
          href="/"
          class="inline-flex items-center gap-1.5 text-sm text-stone-600
               hover:text-stone-300 transition-colors mb-8 group"
        >
          <span class="group-hover:-translate-x-0.5 transition-transform">←</span> Feed
        </a>

        <%!-- Spark --%>
        <article>
          <%!-- Meta row --%>
          <div class="flex items-center gap-2 mb-4">
            <SparkComponents.status_chip status={@spark.status} />
            <SparkComponents.closes_in_badge
              closes_at={@spark.closes_at}
              is_closed={@spark.is_closed}
            />
            <span class="text-stone-700">·</span>
            <span
              class="text-xs text-stone-600"
              style="font-family: 'DM Mono', monospace;"
            >
              {format_wallet(@spark.author.wallet_address)}
            </span>
          </div>

          <%!-- Title --%>
          <h1
            class="text-2xl font-medium text-stone-100 leading-tight mb-5"
            style="font-family: 'Playfair Display', serif;"
          >
            {@spark.title}
          </h1>

          <%!-- Concepts --%>
          <SparkComponents.concept_tag_list concepts={@spark.concepts} />

          <%!-- Body --%>
          <div class="mt-6 spark-body">
            <p :for={para <- paragraphs(@spark.body)} class="mb-4 last:mb-0">
              {para}
            </p>
          </div>
        </article>

        <%!-- Contributions placeholder --%>
        <SparkComponents.section_divider label="Contributions" />

        <div class="text-center py-8 text-stone-600 text-sm">
          Contributions coming in Sprint 2.
        </div>
      </div>
    """
  end

  defp paragraphs(body) do
    body
    |> String.split("\n\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp format_wallet(nil), do: "anon"
  defp format_wallet(addr), do: String.slice(addr, 0, 6) <> "…" <> String.slice(addr, -4, 4)
end
