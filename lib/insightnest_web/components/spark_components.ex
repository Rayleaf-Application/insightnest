defmodule InsightnestWeb.SparkComponents do
  use Phoenix.Component

  @doc "A card for a single spark in the feed."
  attr :spark, :map, required: true

  def spark_card(assigns) do
    ~H"""
    <article class="border border-stone-800 rounded-xl p-5 bg-stone-900 hover:bg-stone-800 transition-colors">
      <a href={"/sparks/#{@spark.id}"} class="block">
        <div class="flex items-start justify-between gap-4">
          <h2 class="text-base font-semibold text-stone-100 leading-snug">
            {@spark.title}
          </h2>
          <.closes_in_badge closes_at={@spark.closes_at} is_closed={@spark.is_closed} />
        </div>

        <p class="mt-2 text-sm text-stone-400 line-clamp-3">
          {excerpt(@spark.body)}
        </p>

        <div class="mt-3 flex items-center justify-between">
          <.concept_tag_list concepts={@spark.concepts} />
          <span class="text-xs text-stone-600">
            {format_wallet(@spark.author.wallet_address)}
          </span>
        </div>
      </a>
    </article>
    """
  end

  @doc "List of concept tag chips."
  attr :concepts, :list, default: []

  def concept_tag_list(assigns) do
    ~H"""
    <div class="flex flex-wrap gap-1">
      <span
        :for={concept <- @concepts}
        class="inline-block px-2 py-0.5 text-xs rounded-full bg-stone-800 text-stone-400 border border-stone-700"
      >
        {concept}
      </span>
    </div>
    """
  end

  @doc "Badge showing time until a spark closes, or 'Closed'."
  attr :closes_at, :any, default: nil
  attr :is_closed, :boolean, default: false

  def closes_in_badge(%{closes_at: nil} = assigns), do: ~H""

  def closes_in_badge(assigns) do
    ~H"""
    <span class={[
      "shrink-0 inline-block px-2 py-0.5 text-xs rounded-full border",
      badge_class(@is_closed, @closes_at)
    ]}>
      {badge_text(@is_closed, @closes_at)}
    </span>
    """
  end

  @doc "Status chip for draft/published."
  attr :status, :string, required: true

  def status_chip(assigns) do
    ~H"""
    <span class={[
      "inline-block px-2 py-0.5 text-xs rounded-full border",
      if(@status == "published",
        do: "bg-green-950 text-green-400 border-green-800",
        else: "bg-stone-800 text-stone-500 border-stone-700"
      )
    ]}>
      {@status}
    </span>
    """
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  defp excerpt(body) when byte_size(body) > 200 do
    String.slice(body, 0, 197) <> "…"
  end
  defp excerpt(body), do: body

  defp format_wallet(nil), do: "anonymous"
  defp format_wallet(address) do
    String.slice(address, 0, 6) <> "…" <> String.slice(address, -4, 4)
  end

  defp badge_class(true, _), do: "bg-red-950 text-red-400 border-red-800"
  defp badge_class(false, closes_at) do
    hours_remaining = DateTime.diff(closes_at, DateTime.utc_now(), :hour)
    cond do
      hours_remaining < 2  -> "bg-red-950 text-red-400 border-red-800"
      hours_remaining < 48 -> "bg-amber-950 text-amber-400 border-amber-800"
      true                 -> "bg-stone-800 text-stone-400 border-stone-700"
    end
  end

  defp badge_text(true, _), do: "Closed"
  defp badge_text(false, closes_at) do
    seconds = DateTime.diff(closes_at, DateTime.utc_now(), :second)
    cond do
      seconds < 3600       -> "#{div(seconds, 60)}m"
      seconds < 86_400     -> "#{div(seconds, 3600)}h"
      true                 -> "#{div(seconds, 86_400)}d"
    end
  end
end
