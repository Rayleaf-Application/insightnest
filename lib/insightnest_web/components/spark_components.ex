defmodule InsightnestWeb.SparkComponents do
  use Phoenix.Component

  @doc "A card for a single spark in the feed."
  attr :spark, :map, required: true
  attr :index, :integer, default: 0

  def spark_card(assigns) do
    ~H"""
    <article
      class="group border border-stone-800 hover:border-stone-700 rounded-xl
             bg-stone-900/50 hover:bg-stone-900 transition-all duration-200
             animate-fade-up"
      style={"animation-delay: #{@index * 60}ms"}
    >
      <a href={"/sparks/#{@spark.id}"} class="block p-5">
        <div class="flex items-start justify-between gap-4 mb-2">
          <h2
            class="text-base font-medium leading-snug text-stone-100
                   group-hover:text-violet-300 transition-colors"
            style="font-family: 'Playfair Display', serif;"
          >
            {@spark.title}
          </h2>
          <.closes_in_badge closes_at={@spark.closes_at} is_closed={@spark.is_closed} />
        </div>

        <p class="text-sm text-stone-500 leading-relaxed line-clamp-2 mb-3">
          {excerpt(@spark.body)}
        </p>

        <div class="flex items-center justify-between">
          <.concept_tag_list concepts={@spark.concepts} />
          <span
            class="text-xs shrink-0 ml-3"
            style="font-family: 'DM Mono', monospace; color: #57534e;"
          >
            {format_wallet(@spark.author.wallet_address)}
          </span>
        </div>
      </a>
    </article>
    """
  end

  @doc "Horizontal divider with label."
  attr :label, :string, default: nil

  def section_divider(assigns) do
    ~H"""
    <div class="flex items-center gap-4 my-8">
      <div class="flex-1 border-t border-stone-800"></div>
      <span :if={@label} class="text-xs text-stone-600 tracking-widest uppercase">
        {@label}
      </span>
      <div class="flex-1 border-t border-stone-800"></div>
    </div>
    """
  end

  @doc "List of concept tag chips."
  attr :concepts, :list, default: []

  def concept_tag_list(assigns) do
    ~H"""
    <div class="flex flex-wrap gap-1.5">
      <span
        :for={concept <- @concepts}
        class="inline-block px-2 py-0.5 text-xs rounded-md
               bg-stone-800 text-stone-400 border border-stone-700/60"
      >
        {concept}
      </span>
    </div>
    """
  end

  @doc "Badge showing time until a spark closes."
  attr :closes_at, :any, default: nil
  attr :is_closed, :boolean, default: false

  def closes_in_badge(%{closes_at: nil} = assigns), do: ~H""

  def closes_in_badge(assigns) do
    ~H"""
    <span class={[
      "shrink-0 inline-block px-2 py-0.5 rounded-md border text-xs",
      badge_class(@is_closed, @closes_at)
    ]}>
      {badge_text(@is_closed, @closes_at)}
    </span>
    """
  end

  @doc "Draft/published status chip."
  attr :status, :string, required: true

  def status_chip(assigns) do
    ~H"""
    <span class={[
      "inline-block px-2 py-0.5 text-xs rounded-md border",
      if(@status == "published",
        do: "bg-emerald-950 text-emerald-400 border-emerald-800/60",
        else: "bg-stone-800 text-stone-500 border-stone-700/60"
      )
    ]}>
      {@status}
    </span>
    """
  end

  @doc "Empty state block."
  attr :title, :string, required: true
  attr :body, :string, default: nil
  attr :cta_label, :string, default: nil
  attr :cta_href, :string, default: nil

  def empty_state(assigns) do
    ~H"""
    <div class="text-center py-20">
      <p class="text-stone-400" style="font-family: 'Playfair Display', serif; font-size: 1.1rem;">
        {@title}
      </p>
      <p :if={@body} class="text-sm text-stone-600 mt-2">{@body}</p>
      <a
        :if={@cta_href}
        href={@cta_href}
        class="mt-5 inline-block px-4 py-2 bg-violet-600 hover:bg-violet-500
               text-white text-sm rounded-lg transition-colors"
      >
        {@cta_label}
      </a>
    </div>
    """
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  defp excerpt(body) when byte_size(body) > 160, do: String.slice(body, 0, 157) <> "…"
  defp excerpt(body), do: body

  defp format_wallet(nil), do: "anon"
  defp format_wallet(addr), do: String.slice(addr, 0, 6) <> "…" <> String.slice(addr, -4, 4)

  defp badge_class(true, _), do: "bg-red-950 text-red-400 border-red-800/60"

  defp badge_class(false, closes_at) do
    hours = DateTime.diff(closes_at, DateTime.utc_now(), :hour)

    cond do
      hours < 2 -> "bg-red-950 text-red-400 border-red-800/60"
      hours < 48 -> "bg-amber-950 text-amber-400 border-amber-800/60"
      true -> "bg-stone-800 text-stone-500 border-stone-700/60"
    end
  end

  defp badge_text(true, _), do: "Closed"

  defp badge_text(false, closes_at) do
    secs = DateTime.diff(closes_at, DateTime.utc_now(), :second)

    cond do
      secs < 3600 -> "#{div(secs, 60)}m"
      secs < 86_400 -> "#{div(secs, 3600)}h"
      true -> "#{div(secs, 86_400)}d"
    end
  end
end
