defmodule InsightnestWeb.InsightComponents do
  use Phoenix.Component

  @doc "Card for an Insight in the Library feed."
  attr :insight, :map, required: true
  attr :index,   :integer, default: 0

  def insight_card(assigns) do
    ~H"""
    <article
      class="group border border-stone-800 hover:border-stone-700 rounded-xl
             bg-stone-900/50 hover:bg-stone-900 transition-all duration-200
             animate-fade-up"
      style={"animation-delay: #{@index * 60}ms"}
    >
      <a href={"/insights/#{@insight.slug}"} class="block p-5">
        <div class="flex items-start justify-between gap-4 mb-2">
          <h2
            class="text-base font-medium leading-snug text-stone-100
                   group-hover:text-violet-300 transition-colors"
            style="font-family: 'Playfair Display', serif;"
          >
            {@insight.title}
          </h2>
          <span class="shrink-0 text-xs text-stone-700 font-mono mt-0.5">
            v{@insight.version}
          </span>
        </div>

        <p :if={@insight.summary != ""} class="text-sm text-stone-500 leading-relaxed line-clamp-2 mb-3">
          {@insight.summary}
        </p>

        <div class="flex items-center justify-between gap-3">
          <div class="flex items-center gap-2">
            <span class="text-xs text-stone-600">
              {contributor_count(@insight)} contributors
            </span>
            <span class="text-stone-800">·</span>
            <span class="text-xs text-stone-600">
              from <span class="text-stone-500">{@insight.spark.title |> excerpt(40)}</span>
            </span>
          </div>
          <.cid_badge cid={@insight.codex_cid} />
        </div>
      </a>
    </article>
    """
  end

  @doc "Small CID provenance badge."
  attr :cid, :string, default: nil

  def cid_badge(%{cid: nil} = assigns), do: ~H""

  def cid_badge(assigns) do
    ~H"""
    <span
      class="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-xs
             border border-stone-700/60 bg-stone-800 text-stone-600"
      title={@cid}
    >
      <span>⬡</span>
      <span style="font-family: 'DM Mono', monospace;">
        {String.slice(@cid || "", 0, 12)}…
      </span>
    </span>
    """
  end

  @doc "Full Insight viewer — title, summary, body blocks, contributors."
  attr :insight,   :map, required: true
  attr :ownership, :map, required: true

  def insight_viewer(assigns) do
    ~H"""
    <div>
      <%!-- Header --%>
      <div class="mb-8">
        <div class="flex items-center gap-3 mb-4 flex-wrap">
          <span class="px-2 py-0.5 text-xs rounded-md border border-emerald-800/60 bg-emerald-950 text-emerald-400">
            Insight
          </span>
          <span class="text-xs text-stone-600">v{@insight.version}</span>
          <span class="text-stone-800">·</span>
          <a
            href={"/sparks/#{@insight.spark_id}"}
            class="text-xs text-stone-600 hover:text-stone-400 transition-colors"
          >
            ↗ Original Spark
          </a>
          <.cid_badge cid={@insight.codex_cid} />
        </div>

        <h1
          class="text-3xl font-medium text-stone-100 leading-tight mb-4"
          style="font-family: 'Playfair Display', serif;"
        >
          {@insight.title}
        </h1>

        <p :if={@insight.summary != ""} class="text-base text-stone-400 leading-relaxed">
          {@insight.summary}
        </p>
      </div>

      <%!-- Body blocks --%>
      <div class="space-y-4 mb-12">
        <.body_block :for={block <- get_blocks(@insight)} block={block} />
      </div>

      <%!-- Contributors --%>
      <div class="border-t border-stone-800 pt-8">
        <h2
          class="text-lg text-stone-300 mb-5"
          style="font-family: 'Playfair Display', serif;"
        >
          Contributors
        </h2>

        <div class="space-y-3 mb-6">
          <.ownership_row :for={share <- @ownership.shares} share={share} />
        </div>

        <div :if={not @ownership.on_chain} class="flex items-center gap-2 text-xs text-stone-700">
          <span>⏳</span>
          <span>On-chain ownership pending — Phase 3</span>
        </div>
      </div>
    </div>
    """
  end

  @doc "A single contributor ownership row."
  attr :share, :map, required: true

  def ownership_row(assigns) do
    ~H"""
    <div class="flex items-center gap-3 py-2.5 border-b border-stone-800/60 last:border-0">
      <div class="flex-1 min-w-0">
        <div class="flex items-center gap-2 flex-wrap">
          <span
            class="text-sm text-stone-400 font-mono truncate"
            style="font-family: 'DM Mono', monospace;"
          >
            {format_wallet(@share["wallet"])}
          </span>
          <div class="flex gap-1">
            <span
              :for={role <- List.wrap(@share["roles"])}
              class="px-1.5 py-0.5 text-xs rounded bg-stone-800 text-stone-500"
            >
              {role}
            </span>
          </div>
        </div>
      </div>

      <%!-- Share bar --%>
      <div class="flex items-center gap-2 shrink-0">
        <div class="w-24 h-1.5 bg-stone-800 rounded-full overflow-hidden">
          <div
            class="h-full bg-violet-500 rounded-full"
            style={"width: #{share_percent(@share["bps"])}%"}
          />
        </div>
        <span class="text-sm text-stone-300 font-mono w-12 text-right"
              style="font-family: 'DM Mono', monospace;">
          {format_bps(@share["bps"])}%
        </span>
      </div>
    </div>
    """
  end

  # ── Private sub-components ────────────────────────────────────────────────────

  defp body_block(assigns) do
    ~H"""
    <%= case @block["type"] do %>
      <% "section_header" -> %>
        <div class="pt-4 pb-1 flex items-center gap-3">
          <span class="text-xs text-stone-600 uppercase tracking-widest">
            {@block["content"]}
          </span>
          <div class="flex-1 border-t border-stone-800"></div>
        </div>

      <% "quote" -> %>
        <blockquote class={[
          "rounded-xl border-l-2 pl-4 pr-4 py-3",
          stance_style(@block["stance"])
        ]}>
          <p class="text-sm text-stone-300 leading-relaxed whitespace-pre-wrap mb-2">
            {@block["content"]}
          </p>
          <cite
            class="text-xs not-italic"
            style={"font-family: 'DM Mono', monospace; #{stance_cite_color(@block["stance"])}"}
          >
            {format_wallet(@block["author"])}
            <span :if={@block["stance"]} class="ml-2 opacity-60">
              · {@block["stance"]}
            </span>
          </cite>
        </blockquote>

      <% "paragraph" -> %>
        <p class="text-stone-300 leading-relaxed">{@block["content"]}</p>

      <% _ -> %>
        <p class="text-stone-400 text-sm">{@block["content"]}</p>
    <% end %>
    """
  end

  # ── Helpers ───────────────────────────────────────────────────────────────────

  defp get_blocks(%{body: %{"blocks" => blocks}}), do: blocks
  defp get_blocks(_), do: []

  defp contributor_count(insight) do
    (get_in(insight.contributors, ["shares"]) || []) |> length()
  end

  defp excerpt(str, max) when byte_size(str) > max, do: String.slice(str, 0, max - 1) <> "…"
  defp excerpt(str, _), do: str

  defp format_wallet(nil), do: "anon"
  defp format_wallet(addr), do: String.slice(addr, 0, 6) <> "…" <> String.slice(addr, -4, 4)

  defp format_bps(nil), do: "0.0"
  defp format_bps(bps) when is_integer(bps) do
    :erlang.float_to_binary(bps / 100, decimals: 1)
  end
  defp format_bps(bps) when is_binary(bps) do
    {n, _} = Integer.parse(bps)
    format_bps(n)
  end

  defp share_percent(nil), do: 0
  defp share_percent(bps) when is_integer(bps), do: bps / 100
  defp share_percent(bps) when is_binary(bps) do
    {n, _} = Integer.parse(bps)
    n / 100
  end

  defp stance_style("evidence"),   do: "border-emerald-700 bg-emerald-950/20"
  defp stance_style("expands"),    do: "border-blue-700 bg-blue-950/20"
  defp stance_style("challenges"), do: "border-orange-700 bg-orange-950/20"
  defp stance_style("question"),   do: "border-purple-700 bg-purple-950/20"
  defp stance_style(_),            do: "border-stone-700 bg-stone-900/40"

  defp stance_cite_color("evidence"),   do: "color: #6ee7b7;"
  defp stance_cite_color("expands"),    do: "color: #93c5fd;"
  defp stance_cite_color("challenges"), do: "color: #fdba74;"
  defp stance_cite_color("question"),   do: "color: #c4b5fd;"
  defp stance_cite_color(_),            do: "color: #57534e;"
end