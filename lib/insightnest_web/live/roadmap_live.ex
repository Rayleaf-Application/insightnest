defmodule InsightnestWeb.RoadmapLive do
  use InsightnestWeb, :live_view

  @phases [
    %{
      number: 0,
      name: "MVP — Core Pipeline",
      logos_component: "SIWE (sovereign identity)",
      period: "Months 0–2",
      estimate: "Complete",
      status: :done,
      deliverables: [
        "Spark creation — timeouts, concepts, draft/publish",
        "Contributions — real-time PubSub, stances, 50-word minimum",
        "Read-timer friction + engagement gate",
        "Highlight voting — threshold + author override + locking",
        "Weave trigger — eligibility, highlight lock, stance grouping",
        "Draft Insight editor — title/summary, contributor shares",
        "Insight publishing — versioned, content-hashed, NoopPublisher wired",
        "Knowledge Library — full-text search, live updates",
        "Pure Elixir SIWE auth — no Rust NIFs",
        "Username + deterministic SVG identicons",
        "CI pipeline — GitHub Actions, mix test + credo"
      ],
      seam: nil
    },
    %{
      number: 1,
      name: "Logos Messaging — Waku",
      logos_component: "Waku (censorship-resistant p2p)",
      period: "Months 3–5",
      estimate: "Jul – Sep 2026",
      status: :next,
      deliverables: [
        "nwaku sidecar in Docker Compose",
        "WakuMessageBus implementing the existing MessageBus behaviour",
        "Browser subscribes to Spark threads via js-waku",
        "Contributions signed with wallet key, published direct to Waku",
        "Weave trigger pulls from Waku Store, validates, persists to PostgreSQL",
        "RLN rate limiting for spam prevention"
      ],
      seam: "MessageBus behaviour — already stubbed as NoopMessageBus"
    },
    %{
      number: 2,
      name: "Logos Storage — Codex",
      logos_component: "Codex (immutable decentralised storage)",
      period: "Months 5–7",
      estimate: "Sep – Nov 2026",
      status: :planned,
      deliverables: [
        "CodexPublisher implementing the existing Publisher behaviour",
        "Insight JSON blob uploaded to Codex on Weave publish",
        "CID stored in insights.codex_cid (column already exists)",
        "CID provenance badge in Knowledge Library",
        "\"Verify on Codex\" link for each published Insight",
        "codex-node Docker Compose service (Altruistic Mode)"
      ],
      seam: "Publisher behaviour — already stubbed as NoopPublisher"
    },
    %{
      number: 3,
      name: "Contributor Ownership — ERC-721",
      logos_component: "Status Network EVM → Nomos",
      period: "Months 7–10",
      estimate: "Nov 2026 – Feb 2027",
      status: :planned,
      deliverables: [
        "InsightNFT.sol — ERC-721, token URI → Codex CID",
        "InsightShares.sol — records contributor share bps per token",
        "Elixir mints token via JSON-RPC after Codex upload confirms",
        "Library.get_ownership/1 switches to live on-chain data",
        "Status Network block explorer links in the Library"
      ],
      seam: "JSON-RPC from Elixir (ethereumex + ex_abi)"
    },
    %{
      number: 4,
      name: "DAO Governance & Decentralisation",
      logos_component: "Nomos (Logos blockchain)",
      period: "Month 12+",
      estimate: "Mid 2027",
      status: :horizon,
      deliverables: [
        "InsightNestDAO.sol — governance, voting power from share holdings",
        "Proposal types: treasury, curation policy, weighting formula",
        "Off-chain deliberation via Waku (same MessageBus behaviour)",
        "Library index migrated from PostgreSQL to Codex-pinned manifest",
        "Direct browser Codex fetches — backend removed from read path"
      ],
      seam: "MessageBus + Publisher + Library abstraction layer"
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Roadmap — InsightNest",
       phases: @phases
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto px-4 py-10 animate-fade-up">
      <div class="mb-10">
        <h1
          class="text-2xl font-medium text-stone-100 mb-2"
          style="font-family: 'Playfair Display', serif;"
        >
          Roadmap
        </h1>
        <p class="text-sm text-stone-500 leading-relaxed max-w-md">
          InsightNest × Logos Ecosystem integration — four phases from MVP to
          full-stack decentralisation. Estimates, not commitments. Updated monthly.
        </p>
        <p class="text-xs text-stone-700 mt-3" style="font-family: 'DM Mono', monospace;">
          Last updated: May 2026
        </p>
      </div>

      <%!-- Logos stack overview --%>
      <div class="mb-10 rounded-xl border border-stone-800 bg-stone-900/40 px-5 py-4">
        <p class="text-xs text-stone-600 uppercase tracking-widest mb-3">Logos Stack</p>
        <div class="grid grid-cols-1 gap-1.5 sm:grid-cols-2">
          <.stack_row phase="0" component="SIWE" label="Sovereign identity" done />
          <.stack_row phase="1" component="Waku" label="Live discussion layer" />
          <.stack_row phase="2" component="Codex" label="Permanent Insight storage" />
          <.stack_row phase="3" component="Status Network → Nomos" label="Contributor ownership" />
        </div>
      </div>

      <%!-- Timeline --%>
      <div class="relative">
        <%!-- Vertical line --%>
        <div class="absolute left-[1.1rem] top-4 bottom-4 w-px bg-stone-800" />

        <div class="space-y-8">
          <.phase_card :for={phase <- @phases} phase={phase} />
        </div>
      </div>

      <%!-- Footer note --%>
      <p class="mt-12 text-xs text-stone-700 text-center">
        Each Logos component plugs into a pre-built seam in the codebase.
        No phase requires a rewrite — only a behaviour implementation swap.
      </p>
    </div>
    """
  end

  # ── Sub-components ────────────────────────────────────────────────────────────

  attr :phase, :string, required: true
  attr :component, :string, required: true
  attr :label, :string, required: true
  attr :done, :boolean, default: false

  defp stack_row(assigns) do
    ~H"""
    <div class="flex items-center gap-2.5">
      <span
        class="text-xs font-mono shrink-0 w-5 text-center"
        style="font-family: 'DM Mono', monospace; color: #C9913A;"
      >
        {if @done, do: "✓", else: @phase}
      </span>
      <span class={["text-xs font-medium", if(@done, do: "text-stone-400", else: "text-stone-500")]}>
        {@component}
      </span>
      <span class="text-xs text-stone-700 truncate">— {@label}</span>
    </div>
    """
  end

  attr :phase, :map, required: true

  defp phase_card(assigns) do
    ~H"""
    <div class="relative pl-10">
      <%!-- Node dot --%>
      <div class={[
        "absolute left-0 top-1 w-[1.35rem] h-[1.35rem] rounded-full border-2 flex items-center justify-center",
        phase_dot_class(@phase.status)
      ]}>
        <span class="text-[0.55rem] font-bold" style="font-family: 'DM Mono', monospace;">
          {if @phase.status == :done, do: "✓", else: @phase.number}
        </span>
      </div>

      <%!-- Card --%>
      <div class={["rounded-xl border p-5", phase_card_class(@phase.status)]}>
        <div class="flex items-start justify-between gap-4 flex-wrap mb-3">
          <div>
            <div class="flex items-center gap-2 mb-1 flex-wrap">
              <.status_chip status={@phase.status} />
              <span
                class="text-xs text-stone-600"
                style="font-family: 'DM Mono', monospace;"
              >
                {@phase.period}
              </span>
            </div>
            <h2
              class="text-base font-medium text-stone-100"
              style="font-family: 'Playfair Display', serif;"
            >
              Phase {@phase.number} — {@phase.name}
            </h2>
          </div>
          <span class={[
            "text-xs px-2.5 py-1 rounded-md border shrink-0",
            estimate_class(@phase.status)
          ]}>
            {@phase.estimate}
          </span>
        </div>

        <p class="text-xs text-stone-600 mb-3">
          <span class="text-stone-700">Logos: </span>{@phase.logos_component}
        </p>

        <ul class="space-y-1">
          <li
            :for={item <- @phase.deliverables}
            class="flex items-start gap-2 text-sm text-stone-400"
          >
            <span class={[
              "mt-[0.35rem] shrink-0 w-1 h-1 rounded-full",
              deliverable_dot_class(@phase.status)
            ]} />
            {item}
          </li>
        </ul>

        <p :if={@phase.seam} class="mt-4 pt-3 border-t border-stone-800/60 text-xs text-stone-600">
          <span class="text-stone-500">Seam: </span>{@phase.seam}
        </p>
      </div>
    </div>
    """
  end

  attr :status, :atom, required: true

  defp status_chip(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium border",
      status_chip_class(@status)
    ]}>
      {status_label(@status)}
    </span>
    """
  end

  # ── Helpers ───────────────────────────────────────────────────────────────────

  defp phase_dot_class(:done), do: "bg-emerald-900 border-emerald-600 text-emerald-400"
  defp phase_dot_class(:next), do: "bg-[#1d1a14] border-[#C9913A] text-[#E8B86D]"
  defp phase_dot_class(:planned), do: "bg-stone-900 border-stone-600 text-stone-500"
  defp phase_dot_class(:horizon), do: "bg-stone-900 border-stone-700 text-stone-600"

  defp phase_card_class(:done), do: "border-emerald-900/50 bg-emerald-950/10"
  defp phase_card_class(:next), do: "border-[#C9913A]/25 bg-[#1d1a14]/10"
  defp phase_card_class(:planned), do: "border-stone-800 bg-stone-900/30"
  defp phase_card_class(:horizon), do: "border-stone-800/60 bg-stone-900/20"

  defp status_chip_class(:done), do: "bg-emerald-950 text-emerald-400 border-emerald-800/60"
  defp status_chip_class(:next), do: "bg-[#1d1a14] text-[#E8B86D] border-[#C9913A]/40"
  defp status_chip_class(:planned), do: "bg-stone-900 text-stone-500 border-stone-700"
  defp status_chip_class(:horizon), do: "bg-stone-900 text-stone-600 border-stone-800"

  defp status_label(:done), do: "Complete"
  defp status_label(:next), do: "Next"
  defp status_label(:planned), do: "Planned"
  defp status_label(:horizon), do: "Horizon"

  defp estimate_class(:done), do: "bg-emerald-950/50 text-emerald-600 border-emerald-900/60"
  defp estimate_class(:next), do: "bg-[#1d1a14]/50 text-[#C9913A] border-[#C9913A]/30"
  defp estimate_class(_), do: "bg-stone-900 text-stone-600 border-stone-800"

  defp deliverable_dot_class(:done), do: "bg-emerald-700"
  defp deliverable_dot_class(:next), do: "bg-[#C9913A]"
  defp deliverable_dot_class(_), do: "bg-stone-700"
end
