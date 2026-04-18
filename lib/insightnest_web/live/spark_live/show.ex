defmodule InsightnestWeb.SparkLive.Show do
  use InsightnestWeb, :live_view

  alias Insightnest.Sparks
  alias InsightnestWeb.SparkComponents

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    spark = Sparks.get_spark!(id)

    # Subscribe to real-time updates for this spark's thread
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Insightnest.PubSub, "spark:#{id}")
    end

    {:ok,
     assign(socket,
       spark: spark,
       page_title: spark.title
     )}
  end

  @impl true
  def handle_info({:spark_updated, spark}, socket) do
    {:noreply, assign(socket, spark: spark)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto px-4 py-8">
      <div class="flex items-center gap-3 mb-8">
        <a href="/" class="text-stone-500 hover:text-stone-300 transition-colors text-sm">← Feed</a>
      </div>

      <article>
        <div class="flex items-start justify-between gap-4 mb-3">
          <h1 class="text-xl font-semibold text-stone-100">{@spark.title}</h1>
          <SparkComponents.closes_in_badge closes_at={@spark.closes_at} is_closed={@spark.is_closed} />
        </div>

        <div class="flex items-center gap-3 mb-4">
          <SparkComponents.status_chip status={@spark.status} />
          <span class="text-xs text-stone-600">
            by {format_wallet(@spark.author.wallet_address)}
          </span>
        </div>

        <SparkComponents.concept_tag_list concepts={@spark.concepts} />

        <div class="mt-5 prose prose-invert prose-sm max-w-none">
          <p class="text-stone-300 leading-relaxed whitespace-pre-wrap">{@spark.body}</p>
        </div>
      </article>

      <div class="mt-12 border-t border-stone-800 pt-8">
        <p class="text-sm text-stone-500">
          Contributions coming in Sprint 2.
        </p>
      </div>
    </div>
    """
  end

  defp format_wallet(nil), do: "anonymous"
  defp format_wallet(address) do
    String.slice(address, 0, 6) <> "…" <> String.slice(address, -4, 4)
  end
end
