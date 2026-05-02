defmodule InsightnestWeb.WeaveLive.Editor do
  use InsightnestWeb, :live_view

  alias Insightnest.Weaves
  alias Insightnest.Sparks

  on_mount {InsightnestWeb.Live.AuthHooks, :require_onboarded}

  @impl true
  def mount(%{"spark_id" => spark_id}, _session, socket) do
    member = socket.assigns.current_member
    spark  = Sparks.get_spark!(spark_id)
             |> Insightnest.Repo.preload(:author)

    eligible = Weaves.eligible_to_weave?(spark_id, member.id)

    # Check for existing in-progress weave
    existing_weave = Weaves.in_progress_weave(spark_id)

    {weave, insight, triggered} =
      if existing_weave do
        insight = Weaves.get_draft!(existing_weave.id)
        {existing_weave, insight, true}
      else
        {nil, nil, false}
      end

    {:ok,
     assign(socket,
       spark:      spark,
       weave:      weave,
       insight:    insight,
       eligible:   eligible,
       triggered:  triggered,
       triggering: false,
       saving:     false,
       error:      nil,
       page_title: "Weave — #{spark.title}"
     )}
  end

  # ── Events ────────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("trigger_weave", _, socket) do
    member = socket.assigns.current_member
    spark  = socket.assigns.spark

    socket = assign(socket, triggering: true, error: nil)

    case Weaves.trigger_weave(spark.id, member.id) do
      {:ok, %{weave: weave, insight: insight}} ->
        {:noreply,
         assign(socket,
           weave:      weave,
           insight:    insight,
           triggered:  true,
           triggering: false
         )}

      {:error, :no_highlighted_contributions} ->
        {:noreply,
         assign(socket,
           triggering: false,
           error: "No highlighted contributions to weave. Highlight some contributions first."
         )}

      {:error, :weave_in_progress} ->
        {:noreply,
         assign(socket,
           triggering: false,
           error: "A Weave is already in progress for this Spark."
         )}

      {:error, :not_eligible} ->
        {:noreply,
         assign(socket,
           triggering: false,
           error: "You are not eligible to trigger a Weave on this Spark."
         )}

      {:error, reason} ->
        {:noreply, assign(socket, triggering: false, error: "Error: #{inspect(reason)}")}
    end
  end

  def handle_event("update_draft", %{"insight" => params}, socket) do
    insight = socket.assigns.insight
    weave   = socket.assigns.weave
    member  = socket.assigns.current_member

    case Weaves.update_draft(insight, weave, params, member.id) do
      {:ok, updated} ->
        {:noreply, assign(socket, insight: updated, saving: false)}

      {:error, _} ->
        {:noreply, assign(socket, saving: false, error: "Failed to save draft.")}
    end
  end

  def handle_event("publish", _, socket) do
    member = socket.assigns.current_member
    weave  = socket.assigns.weave

    case Weaves.publish_insight(weave.id, member.id) do
      {:ok, insight} ->
        {:noreply, push_navigate(socket, to: "/insights/#{insight.slug}")}

      {:error, :unauthorized} ->
        {:noreply, assign(socket, error: "Only the Weave curator can publish.")}

      {:error, :already_published} ->
        {:noreply, assign(socket, error: "This Insight has already been published.")}

      {:error, reason} ->
        {:noreply, assign(socket, error: "Publish failed: #{inspect(reason)}")}
    end
  end

  # ── Render ────────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto px-4 py-10 animate-fade-up">

      <a
        href={"/sparks/#{@spark.id}"}
        class="inline-flex items-center gap-1.5 text-sm text-stone-600
               hover:text-stone-300 transition-colors mb-8 group"
      >
        <span class="group-hover:-translate-x-0.5 transition-transform">←</span>
        Back to Spark
      </a>

      <div class="mb-8">
        <div class="flex items-center gap-2 mb-1">
          <span class="text-xs text-violet-400 uppercase tracking-widest">Weave</span>
        </div>
        <h1
          class="text-2xl font-medium text-stone-100"
          style="font-family: 'Playfair Display', serif;"
        >
          {@spark.title}
        </h1>
      </div>

      <%!-- Error --%>
      <div :if={@error} class="mb-6 px-4 py-3 rounded-lg border border-red-800/60 bg-red-950/50 text-red-300 text-sm">
        {@error}
      </div>

      <%!-- Not eligible --%>
      <div :if={not @eligible and not @triggered} class="text-center py-16">
        <p class="text-stone-500 mb-2">You are not eligible to trigger a Weave.</p>
        <p class="text-stone-600 text-sm">
          Only the Spark author or authors of highlighted contributions can start a Weave.
        </p>
      </div>

      <%!-- Trigger button --%>
      <div :if={@eligible and not @triggered} class="text-center py-16">
        <p class="text-stone-400 mb-6 text-sm leading-relaxed max-w-sm mx-auto">
          Triggering a Weave will assemble all highlighted contributions
          into a draft Insight. Highlights will be locked.
        </p>
        <button
          type="button"
          phx-click="trigger_weave"
          disabled={@triggering}
          class="px-6 py-3 bg-violet-600 hover:bg-violet-500 disabled:opacity-50
                 text-white font-medium rounded-xl transition-colors"
        >
          {if @triggering, do: "Weaving…", else: "Trigger Weave"}
        </button>
      </div>

      <%!-- Draft editor --%>
      <div :if={@triggered and @insight} class="space-y-6">

        <div class="flex items-center justify-between mb-2">
          <span class="text-xs text-stone-600 uppercase tracking-widest">Draft Insight</span>
          <span :if={@saving} class="text-xs text-stone-600">Saving…</span>
        </div>

        <%!-- Title --%>
        <div>
          <label class="block text-xs text-stone-500 uppercase tracking-widest mb-2">
            Title
          </label>
          <input
            type="text"
            value={@insight.title}
            phx-blur="update_draft"
            phx-value-insight-title={@insight.title}
            name="insight[title]"
            class="w-full bg-stone-900 border border-stone-700 rounded-lg px-4 py-3
                   text-stone-100 text-base focus:outline-none focus:border-violet-500
                   transition-colors"
            style="font-family: 'Playfair Display', serif;"
          />
        </div>

        <%!-- Summary --%>
        <div>
          <label class="block text-xs text-stone-500 uppercase tracking-widest mb-2">
            Summary
          </label>
          <textarea
            name="insight[summary]"
            rows="3"
            placeholder="Write a brief summary of this Insight…"
            phx-blur="update_draft"
            class="w-full bg-stone-900 border border-stone-700 rounded-lg px-4 py-3
                   text-stone-300 text-sm leading-relaxed focus:outline-none
                   focus:border-violet-500 transition-colors resize-none"
          ><%= @insight.summary %></textarea>
        </div>

        <%!-- Body blocks (read-only preview — curator edits prose around them) --%>
        <div>
          <label class="block text-xs text-stone-500 uppercase tracking-widest mb-3">
            Contributions
          </label>
          <div class="space-y-3">
            <.body_block :for={block <- get_blocks(@insight)} block={block} />
          </div>
        </div>

        <%!-- Contributors --%>
        <div>
          <label class="block text-xs text-stone-500 uppercase tracking-widest mb-3">
            Contributors
          </label>
          <div class="space-y-2">
            <.contributor_row :for={share <- get_shares(@insight)} share={share} />
          </div>
        </div>

        <%!-- Publish --%>
        <div class="pt-4 border-t border-stone-800">
          <button
            type="button"
            phx-click="publish"
            class="px-6 py-3 bg-emerald-700 hover:bg-emerald-600
                   text-white font-medium rounded-xl transition-colors"
          >
            Publish Insight →
          </button>
          <p class="text-xs text-stone-600 mt-2">
            Publishing is permanent. The Insight will appear in the Knowledge Library.
          </p>
        </div>

      </div>

    </div>
    """
  end

  # ── Sub-components ────────────────────────────────────────────────────────────

  defp body_block(assigns) do
    ~H"""
    <%= case @block["type"] do %>
      <% "section_header" -> %>
        <div class="pt-2 pb-1">
          <span class="text-xs text-stone-500 uppercase tracking-widest">
            {@block["content"]}
          </span>
        </div>

      <% "quote" -> %>
        <div class={[
          "rounded-xl border p-4",
          stance_border(@block["stance"])
        ]}>
          <p class="text-sm text-stone-300 leading-relaxed whitespace-pre-wrap mb-2">
            {@block["content"]}
          </p>
          <span
            class="text-xs text-stone-600"
            style="font-family: 'DM Mono', monospace;"
          >
            {format_wallet(@block["author"])}
          </span>
        </div>

      <% _ -> %>
        <p class="text-sm text-stone-400">{@block["content"]}</p>
    <% end %>
    """
  end

  defp contributor_row(assigns) do
    ~H"""
    <div class="flex items-center justify-between py-2 border-b border-stone-800 last:border-0">
      <div class="flex items-center gap-3">
        <span
          class="text-xs text-stone-400"
          style="font-family: 'DM Mono', monospace;"
        >
          {format_wallet(@share["wallet"])}
        </span>
        <div class="flex gap-1">
          <span
            :for={role <- @share["roles"]}
            class="px-1.5 py-0.5 text-xs rounded bg-stone-800 text-stone-500"
          >
            {role}
          </span>
        </div>
      </div>
      <span class="text-sm text-stone-300 font-mono">
        {format_bps(@share["bps"])}%
      </span>
    </div>
    """
  end

  # ── Private helpers ───────────────────────────────────────────────────────────

  defp get_blocks(%{body: %{"blocks" => blocks}}), do: blocks
  defp get_blocks(_), do: []

  defp get_shares(%{contributors: %{"shares" => shares}}), do: shares
  defp get_shares(_), do: []

  defp format_bps(bps) when is_integer(bps) do
    :erlang.float_to_binary(bps / 100, decimals: 1)
  end
  defp format_bps(bps) when is_binary(bps) do
    {n, _} = Integer.parse(bps)
    format_bps(n)
  end
  defp format_bps(_), do: "0.0"

  defp format_wallet(nil), do: "anon"
  defp format_wallet(addr), do: String.slice(addr, 0, 6) <> "…" <> String.slice(addr, -4, 4)

  defp stance_border("evidence"),   do: "border-emerald-800/50 bg-emerald-950/20"
  defp stance_border("expands"),    do: "border-blue-800/50 bg-blue-950/20"
  defp stance_border("challenges"), do: "border-orange-800/50 bg-orange-950/20"
  defp stance_border("question"),   do: "border-purple-800/50 bg-purple-950/20"
  defp stance_border(_),            do: "border-stone-800 bg-stone-900/40"
end
