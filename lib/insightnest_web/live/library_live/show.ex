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

    base_url = InsightnestWeb.Endpoint.url()
    page_url = base_url <> ~p"/insights/#{slug}"
    description = build_description(insight)

    {:ok,
     assign(socket,
       insight: insight,
       ownership: ownership,
       page_title: insight.title,
       page_description: description,
       page_url: page_url,
       page_type: "article"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    {Phoenix.HTML.raw(json_ld(@insight, @ownership, @page_url))}

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

  defp build_description(insight) do
    text =
      case insight.summary do
        s when is_binary(s) and s != "" -> s
        _ -> "An Insight from InsightNest — community-crafted collective intelligence."
      end

    if String.length(text) > 160, do: String.slice(text, 0, 157) <> "…", else: text
  end

  defp json_ld(insight, ownership, page_url) do
    authors =
      ownership.shares
      |> Enum.map(fn share ->
        name =
          case share do
            %{"handle" => h} when is_binary(h) and h != "" -> "@" <> h
            %{"wallet" => w} when is_binary(w) -> String.slice(w, 0, 10) <> "…"
            _ -> "anon"
          end

        %{"@type" => "Person", "name" => name}
      end)

    data = %{
      "@context" => "https://schema.org",
      "@type" => "Article",
      "headline" => insight.title,
      "description" => build_description(insight),
      "url" => page_url,
      "datePublished" => DateTime.to_iso8601(insight.inserted_at),
      "dateModified" => DateTime.to_iso8601(insight.updated_at),
      "author" => authors,
      "publisher" => %{
        "@type" => "Organization",
        "name" => "InsightNest",
        "url" => InsightnestWeb.Endpoint.url()
      },
      "isPartOf" => %{
        "@type" => "WebSite",
        "name" => "InsightNest",
        "url" => InsightnestWeb.Endpoint.url()
      }
    }

    ~s(<script type="application/ld+json">#{Jason.encode!(data)}</script>)
  end
end
