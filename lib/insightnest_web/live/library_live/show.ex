defmodule InsightnestWeb.LibraryLive.Show do
  use InsightnestWeb, :live_view

  alias Insightnest.Accounts
  alias Insightnest.Library
  alias InsightnestWeb.InsightComponents

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    insight = Library.get_insight_by_slug!(slug)
    ownership = insight |> Library.get_ownership() |> enrich_ownership()
    insight = enrich_blocks(insight, ownership)

    {:ok,
     assign(socket,
       insight: insight,
       ownership: ownership,
       page_title: insight.title
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto px-4 py-10 animate-fade-up">
      <div class="flex items-center gap-3 mb-8">
        <a
          href="/library"
          class="inline-flex items-center gap-1.5 text-sm text-stone-600
                 hover:text-stone-300 transition-colors group"
        >
          <span class="group-hover:-translate-x-0.5 transition-transform">←</span> Library
        </a>
      </div>

      <InsightComponents.insight_viewer
        insight={@insight}
        ownership={@ownership}
      />
    </div>
    """
  end

  # ── Private ───────────────────────────────────────────────────────────────────

  defp enrich_ownership(%{shares: shares} = ownership) do
    ids = shares |> Enum.map(& &1["member_id"]) |> Enum.reject(&is_nil/1)
    member_map = ids |> Accounts.list_by_ids() |> Map.new(&{&1.id, &1})

    enriched =
      Enum.map(shares, fn share ->
        case Map.get(member_map, share["member_id"]) do
          nil -> share
          m -> Map.merge(share, %{"handle" => m.username, "wallet" => m.wallet_address})
        end
      end)

    %{ownership | shares: enriched}
  end

  defp enrich_blocks(insight, %{shares: shares}) do
    member_map = Map.new(shares, &{&1["member_id"], &1})

    blocks =
      case insight.body do
        %{"blocks" => blocks} ->
          Enum.map(blocks, fn
            %{"type" => "quote", "member_id" => mid} = block ->
              handle =
                case Map.get(member_map, mid) do
                  %{"handle" => h} when is_binary(h) and h != "" -> "@" <> h
                  %{"wallet" => w} when is_binary(w) -> w
                  _ -> block["author"]
                end

              Map.put(block, "author", handle)

            block ->
              block
          end)

        _ ->
          []
      end

    put_in(insight.body["blocks"], blocks)
  end
end
