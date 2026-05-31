defmodule InsightnestWeb.SparkLive.Index do
  use InsightnestWeb, :live_view

  alias Insightnest.Accounts
  alias Insightnest.Sparks
  alias InsightnestWeb.SparkComponents

  @impl true
  def mount(_params, _session, socket) do
    sparks = Sparks.list_published()
    members = Accounts.list_members_with_usernames()
    concepts = Sparks.list_all_concepts()

    {:ok,
     assign(socket,
       tab: "sparks",
       query: "",
       only_not_weaved: false,
       sparks: sparks,
       members: members,
       concepts: concepts,
       page_title: "Explore — InsightNest"
     ), layout: {InsightnestWeb.Layouts, :app}}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    socket = assign(socket, tab: tab, query: "")
    {:noreply, reload_data(socket)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    socket = assign(socket, query: query)
    {:noreply, reload_data(socket)}
  end

  @impl true
  def handle_event("toggle_not_weaved", _params, socket) do
    socket = assign(socket, only_not_weaved: !socket.assigns.only_not_weaved)
    {:noreply, reload_data(socket)}
  end

  defp reload_data(socket) do
    %{tab: tab, query: query, only_not_weaved: only_not_weaved} = socket.assigns

    case tab do
      "sparks" ->
        sparks =
          if only_not_weaved,
            do: Sparks.search_published_not_weaved(query),
            else: Sparks.search_published(query)

        assign(socket, sparks: sparks)

      "members" ->
        assign(socket, members: Accounts.search_members(query))

      "concepts" ->
        assign(socket, concepts: Sparks.search_concepts(query))
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto px-4 py-10">
      <%!-- Header --%>
      <div class="mb-8 animate-fade-up">
        <h1
          class="text-3xl text-stone-100 mb-2 leading-tight"
          style="font-family: 'Playfair Display', serif;"
        >
          Explore
        </h1>
        <p class="text-sm text-stone-500">
          Discover sparks, members, and concepts shaping this community.
        </p>
      </div>

      <%!-- Search bar --%>
      <div class="mb-5 animate-fade-up" style="animation-delay: 40ms">
        <form phx-change="search">
          <input
            type="text"
            value={@query}
            placeholder={search_placeholder(@tab)}
            phx-debounce="300"
            name="query"
            class="w-full bg-stone-900 border border-stone-700 rounded-lg px-4 py-2.5
                   text-stone-200 placeholder-stone-600 text-sm
                   focus:outline-none focus:border-[#C9913A] focus:ring-1
                   focus:ring-[#C9913A]/20 transition-colors"
          />
        </form>
      </div>

      <%!-- Tab switcher --%>
      <div class="flex gap-1.5 mb-7 animate-fade-up" style="animation-delay: 60ms">
        <button
          :for={tab <- ["sparks", "members", "concepts"]}
          phx-click="switch_tab"
          phx-value-tab={tab}
          class={[
            "px-4 py-1.5 rounded-lg text-sm font-medium transition-colors capitalize",
            if(@tab == tab,
              do: "bg-[#C9913A] text-[#141820]",
              else: "bg-stone-800 text-stone-400 hover:text-stone-200 hover:bg-stone-700"
            )
          ]}
        >
          {tab}
        </button>
      </div>

      <%!-- Sparks tab --%>
      <div :if={@tab == "sparks"}>
        <div class="flex items-center gap-2.5 mb-5">
          <button
            phx-click="toggle_not_weaved"
            role="switch"
            aria-checked={to_string(@only_not_weaved)}
            class="relative inline-flex h-5 w-9 shrink-0 items-center rounded-full transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-[#C9913A]/50"
            style={"background-color: #{if @only_not_weaved, do: "#C9913A", else: "#2D3142"}"}
          >
            <span
              class="inline-block h-3.5 w-3.5 rounded-full bg-white shadow transition-transform"
              style={"transform: translateX(#{if @only_not_weaved, do: "18px", else: "3px"})"}
            />
          </button>
          <span class={[
            "text-sm transition-colors",
            if(@only_not_weaved, do: "text-stone-200", else: "text-stone-500")
          ]}>
            Only not-yet-weaved
          </span>
        </div>

        <SparkComponents.empty_state
          :if={@sparks == []}
          title={if @query != "", do: "No sparks match \"#{@query}\".", else: "No sparks yet."}
          body={
            if @query != "",
              do: "Try a different search term.",
              else: "Be the first to post an idea."
          }
          cta_label={if @query == "", do: "Create a Spark", else: nil}
          cta_href={
            cond do
              @query != "" -> nil
              @current_member -> "/sparks/new"
              true -> "/auth"
            end
          }
        />

        <div class="space-y-3">
          <SparkComponents.spark_card
            :for={{spark, i} <- Enum.with_index(@sparks)}
            spark={spark}
            index={i}
          />
        </div>
      </div>

      <%!-- Members tab --%>
      <div :if={@tab == "members"}>
        <div :if={@members == []} class="text-center py-20">
          <p
            class="text-stone-500"
            style="font-family: 'Playfair Display', serif; font-size: 1.1rem;"
          >
            {if @query != "",
              do: "No members match \"#{@query}\".",
              else: "No members with a username yet."}
          </p>
        </div>

        <div class="flex flex-wrap gap-x-5 gap-y-3 py-2">
          <span
            :for={member <- @members}
            class="text-stone-400 hover:text-[#E8B86D] transition-colors cursor-default leading-snug"
            style={"font-size: #{member_font_size(member.username)}px; font-family: 'DM Sans', sans-serif;"}
          >
            @{member.username}
          </span>
        </div>
      </div>

      <%!-- Concepts tab --%>
      <div :if={@tab == "concepts"}>
        <div :if={@concepts == []} class="text-center py-20">
          <p
            class="text-stone-500"
            style="font-family: 'Playfair Display', serif; font-size: 1.1rem;"
          >
            {if @query != "",
              do: "No concepts match \"#{@query}\".",
              else: "No concepts yet."}
          </p>
        </div>

        <div class="flex flex-wrap gap-x-5 gap-y-3 py-2">
          <span
            :for={{concept, count} <- @concepts}
            class="text-stone-400 hover:text-[#E8B86D] transition-colors cursor-default leading-snug"
            style={"font-size: #{concept_font_size(count, @concepts)}px;"}
            title={"#{count} #{if count == 1, do: "spark", else: "sparks"}"}
          >
            {concept}
          </span>
        </div>
      </div>
    </div>
    """
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  defp search_placeholder("sparks"), do: "Search sparks…"
  defp search_placeholder("members"), do: "Search members…"
  defp search_placeholder("concepts"), do: "Search concepts…"

  defp member_font_size(username) do
    13 + :erlang.phash2(username, 8)
  end

  defp concept_font_size(_count, []), do: 14

  defp concept_font_size(count, concepts) do
    max_count = concepts |> Enum.map(fn {_, c} -> c end) |> Enum.max()
    min_s = 12
    max_s = 28
    round(min_s + count / max_count * (max_s - min_s))
  end
end
