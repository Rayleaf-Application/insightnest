defmodule InsightnestWeb.ContributionComponents do
  use Phoenix.Component

  alias Insightnest.Contributions.Contribution

  # ── Stance chip ──────────────────────────────────────────────────────────────

  @doc "Colour-coded stance chip."
  attr :stance, :string, default: nil

  def stance_chip(%{stance: nil} = assigns), do: ~H""

  def stance_chip(assigns) do
    ~H"""
    <span class={["inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-xs border", stance_class(@stance)]}>
      <span>{stance_icon(@stance)}</span>
      <span>{stance_label(@stance)}</span>
    </span>
    """
  end

  # ── Stance selector ───────────────────────────────────────────────────────────

  @doc "Four toggle pills for selecting a contribution stance."
  attr :selected, :string, default: nil

  def stance_selector(assigns) do
    ~H"""
    <div class="flex flex-wrap gap-2">
      <span class="text-xs text-stone-600 self-center mr-1">Stance</span>
      <button
        :for={stance <- Contribution.valid_stances()}
        type="button"
        phx-click="select_stance"
        phx-value-stance={if @selected == stance, do: "", else: stance}
        class={[
          "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md text-xs border transition-colors",
          if(@selected == stance,
            do: stance_class(stance) <> " opacity-100",
            else: "bg-stone-900 text-stone-500 border-stone-700 hover:border-stone-500"
          )
        ]}
      >
        <span>{stance_icon(stance)}</span>
        <span>{stance_label(stance)}</span>
      </button>
    </div>
    """
  end

  # ── Stance filter ─────────────────────────────────────────────────────────────

  @doc "Filter pills shown above the thread when ≥2 stances are present."
  attr :contributions, :list, required: true
  attr :active_filter, :string, default: nil

  def stance_filter(assigns) do
    stances_present =
      assigns.contributions
      |> Enum.map(& &1.stance)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    assigns = assign(assigns, stances_present: stances_present)

    if length(stances_present) < 2 do
      ~H""
    else
      ~H"""
      <div class="flex flex-wrap gap-2 mb-4">
        <button
          type="button"
          phx-click="filter_stance"
          phx-value-stance=""
          class={[
            "px-2.5 py-1 rounded-md text-xs border transition-colors",
            if(is_nil(@active_filter),
              do: "bg-stone-700 text-stone-200 border-stone-600",
              else: "bg-stone-900 text-stone-500 border-stone-700 hover:border-stone-500"
            )
          ]}
        >
          All
        </button>
        <button
          :for={stance <- @stances_present}
          type="button"
          phx-click="filter_stance"
          phx-value-stance={stance}
          class={[
            "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md text-xs border transition-colors",
            if(@active_filter == stance,
              do: stance_class(stance),
              else: "bg-stone-900 text-stone-500 border-stone-700 hover:border-stone-500"
            )
          ]}
        >
          <span>{stance_icon(stance)}</span>
          <span>
            {stance_label(stance)}
            · {Enum.count(@contributions, &(&1.stance == stance))}
          </span>
        </button>
      </div>
      """
    end
  end

  # ── Contribution card ─────────────────────────────────────────────────────────

  @doc "A single contribution card."
  attr :contribution, :map, required: true
  attr :is_author,    :boolean, default: false

  def contribution_card(assigns) do
    ~H"""
    <div class={[
      "rounded-xl border p-4 transition-all duration-200",
      if(@contribution.highlighted,
        do: "border-violet-700/50 bg-violet-950/20",
        else: "border-stone-800 bg-stone-900/40"
      )
    ]}>
      <%!-- Header row --%>
      <div class="flex items-center justify-between gap-3 mb-3">
        <div class="flex items-center gap-2">
          <span
            class="text-xs text-stone-600"
            style="font-family: 'DM Mono', monospace;"
          >
            {format_wallet(@contribution.author.wallet_address)}
          </span>
          <span :if={@contribution.highlighted} class="text-violet-400 text-xs">✦</span>
        </div>
        <div class="flex items-center gap-2">
          <.stance_chip stance={@contribution.stance} />
          <span class="text-xs text-stone-700">
            {format_time(@contribution.inserted_at)}
          </span>
        </div>
      </div>

      <%!-- Body --%>
      <p class="text-sm text-stone-300 leading-relaxed whitespace-pre-wrap">
        {@contribution.body}
      </p>
    </div>
    """
  end

  # ── Contribution form ─────────────────────────────────────────────────────────

  @doc "Inline contribution form embedded in SparkLive.Show."
  attr :form,          :map, required: true
  attr :selected_stance, :string, default: nil
  attr :submitting,    :boolean, default: false
  attr :error,         :string, default: nil

  def contribution_form(assigns) do
    ~H"""
    <div class="mt-2">
      <div :if={@error} class="mb-3 px-3 py-2 rounded-lg border border-red-800/60 bg-red-950/50 text-red-300 text-xs">
        {@error}
      </div>

      <.form for={@form} phx-submit="submit_contribution" class="space-y-3">
        <textarea
          name="contribution[body]"
          rows="4"
          placeholder="Add your contribution…"
          class="w-full bg-stone-900 border border-stone-700 rounded-lg px-3 py-2.5
                 text-stone-200 placeholder-stone-700 text-sm leading-relaxed
                 focus:outline-none focus:border-violet-500 focus:ring-1 focus:ring-violet-500/20
                 transition-colors resize-none"
        ><%= @form[:body].value %></textarea>

        <div class="flex items-center justify-between gap-3 flex-wrap">
          <.stance_selector selected={@selected_stance} />

          <button
            type="submit"
            disabled={@submitting}
            class="px-4 py-2 bg-violet-600 hover:bg-violet-500 disabled:opacity-50
                   text-white text-sm font-medium rounded-lg transition-colors shrink-0"
          >
            {if @submitting, do: "Posting…", else: "Contribute"}
          </button>
        </div>
      </.form>
    </div>
    """
  end

  # ── Closed notice ─────────────────────────────────────────────────────────────

  @doc "Shown instead of the form when the spark is closed."
  attr :closed_at, :any, default: nil

  def closed_notice(assigns) do
    ~H"""
    <div class="px-4 py-3 rounded-lg border border-stone-800 bg-stone-900/40 text-sm text-stone-500">
      This Spark is closed. A Weave can still be triggered from existing highlights.
    </div>
    """
  end

  # ── Private helpers ───────────────────────────────────────────────────────────

  defp stance_class("expands"),    do: "bg-blue-950 text-blue-300 border-blue-800/60"
  defp stance_class("challenges"), do: "bg-orange-950 text-orange-300 border-orange-800/60"
  defp stance_class("evidence"),   do: "bg-emerald-950 text-emerald-300 border-emerald-800/60"
  defp stance_class("question"),   do: "bg-purple-950 text-purple-300 border-purple-800/60"
  defp stance_class(_),            do: "bg-stone-800 text-stone-400 border-stone-700"

  defp stance_icon("expands"),    do: "↗"
  defp stance_icon("challenges"), do: "⚡"
  defp stance_icon("evidence"),   do: "◆"
  defp stance_icon("question"),   do: "?"
  defp stance_icon(_),            do: ""

  defp stance_label("expands"),    do: "Expands"
  defp stance_label("challenges"), do: "Challenges"
  defp stance_label("evidence"),   do: "Evidence"
  defp stance_label("question"),   do: "Question"
  defp stance_label(_),            do: ""

  defp format_wallet(nil), do: "anon"
  defp format_wallet(addr), do: String.slice(addr, 0, 6) <> "…" <> String.slice(addr, -4, 4)

  defp format_time(dt) do
    diff = DateTime.diff(DateTime.utc_now(), dt, :second)
    cond do
      diff < 60    -> "just now"
      diff < 3600  -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      true         -> "#{div(diff, 86400)}d ago"
    end
  end
end
