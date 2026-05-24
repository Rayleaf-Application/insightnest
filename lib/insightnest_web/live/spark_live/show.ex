defmodule InsightnestWeb.SparkLive.Show do
  use InsightnestWeb, :live_view

  alias Insightnest.Contributions
  alias Insightnest.Error
  alias Insightnest.Sparks
  alias Insightnest.Weaves
  alias InsightnestWeb.ContributionComponents
  alias InsightnestWeb.SparkComponents

  @max_extensions Application.compile_env(:insightnest, :spark_max_extensions, 2)

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # FIX 1: Cast the string ID to a UUID binary to prevent Postgrex EncodeError
    spark_id = Ecto.UUID.cast!(id)

    spark = Sparks.get_spark!(spark_id)
    contributions = Contributions.list_for_spark(spark_id)
    member = socket.assigns[:current_member]

    voted_set =
      if member do
        # Ensure member.id is also cast if it's a string coming from session
        Contributions.voter_highlights(spark_id, Ecto.UUID.cast!(member.id))
      else
        MapSet.new()
      end

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Insightnest.PubSub, "spark:#{spark_id}")
    end

    {:ok,
     assign(socket,
       spark: spark,
       contributions: contributions,
       voted_set: voted_set,
       page_title: spark.title,
       form: to_form(%{"body" => ""}),
       selected_stance: nil,
       active_filter: nil,
       submitting: false,
       error: nil,
       max_extensions: @max_extensions,
       can_contribute: can_contribute?(spark, member, contributions),
       can_weave: member && Weaves.eligible_to_weave?(spark_id, Ecto.UUID.cast!(member.id)),
       spark_id: spark_id,
       timer_unlocked: false
     )}
  end

  defp word_count(body) do
    body |> String.split(~r/\s+/, trim: true) |> length()
  end

  # ── PubSub handlers ───────────────────────────────────────────────────────────

  @impl true
  def handle_info({:new_contribution, contribution}, socket) do
    contributions = socket.assigns.contributions ++ [contribution]

    {:noreply,
     socket
     |> assign(contributions: contributions)
     |> update_can_contribute()}
  end

  def handle_info({:contribution_updated, updated}, socket) do
    contributions =
      Enum.map(socket.assigns.contributions, fn c ->
        if c.id == updated.id, do: updated, else: c
      end)

    {:noreply, assign(socket, contributions: contributions)}
  end

  def handle_info({:spark_updated, spark}, socket) do
    {:noreply, assign(socket, spark: spark)}
  end

  # ── Events ────────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("read_timer_unlocked", _params, socket) do
    {:noreply, assign(socket, timer_unlocked: true)}
  end

  def handle_event("select_stance", %{"stance" => stance}, socket) do
    {:noreply, assign(socket, selected_stance: if(stance == "", do: nil, else: stance))}
  end

  def handle_event("update_contribution_draft", %{"contribution" => %{"body" => body}}, socket) do
    {:noreply, assign(socket, form: to_form(%{"body" => body}))}
  end

  def handle_event("filter_stance", %{"stance" => stance}, socket) do
    {:noreply, assign(socket, active_filter: if(stance == "", do: nil, else: stance))}
  end

  def handle_event("toggle_highlight", %{"contribution_id" => cid}, socket) do
    member = socket.assigns.current_member

    if is_nil(member) do
      {:noreply, assign(socket, error: "Sign in to highlight contributions.")}
    else
      # Cast IDs for DB operations
      contribution_uuid = Ecto.UUID.cast!(cid)
      member_uuid = Ecto.UUID.cast!(member.id)

      case Contributions.toggle_highlight(contribution_uuid, member_uuid) do
        {:ok, _} ->
          # Update local voted_set optimistically
          voted_set =
            if MapSet.member?(socket.assigns.voted_set, cid) do
              MapSet.delete(socket.assigns.voted_set, cid)
            else
              MapSet.put(socket.assigns.voted_set, cid)
            end

          {:noreply, assign(socket, voted_set: voted_set)}

        {:error, _} ->
          {:noreply, assign(socket, error: Error.message(:unauthorized))}
      end
    end
  end

  def handle_event("author_override", params, socket) do
    member = socket.assigns.current_member
    cid = params["contribution_id"]
    highlighted = params["highlighted"] == "true"

    # Cast IDs
    contribution_uuid = Ecto.UUID.cast!(cid)
    member_uuid = Ecto.UUID.cast!(member.id)

    case Contributions.author_override(contribution_uuid, member_uuid, highlighted) do
      {:ok, _} ->
        {:noreply, socket}

      {:error, reason} ->
        {:noreply, assign(socket, error: Error.message(reason))}
    end
  end

  def handle_event("publish_spark", _params, socket) do
    member = socket.assigns.current_member

    if is_nil(member) do
      {:noreply, assign(socket, error: "You must be signed in.")}
    else
      member_uuid = Ecto.UUID.cast!(member.id)

      case Sparks.publish_spark(socket.assigns.spark, member_uuid) do
        {:ok, spark} ->
          {:noreply,
           socket
           |> assign(spark: spark)
           |> update_can_contribute()}

        {:error, reason} ->
          {:noreply, assign(socket, error: Error.message(reason))}
      end
    end
  end

  def handle_event("extend_spark", %{"days" => days_str}, socket) do
    member = socket.assigns.current_member
    days = String.to_integer(days_str)

    # Cast spark ID if needed in the context function, assuming get_spark! handles it or we pass binary
    _spark_id = socket.assigns.spark_id || Ecto.UUID.cast!(socket.assigns.spark.id)
    member_uuid = Ecto.UUID.cast!(member.id)

    case Sparks.extend_spark(socket.assigns.spark, member_uuid, days) do
      {:ok, spark} ->
        {:noreply, assign(socket, spark: spark)}

      {:error, reason} ->
        {:noreply, assign(socket, error: Error.message(reason))}
    end
  end

  def handle_event("submit_contribution", %{"contribution" => params}, socket) do
    member = socket.assigns.current_member

    if is_nil(member) do
      {:noreply, assign(socket, error: "You must be signed in to contribute.")}
    else
      socket = assign(socket, submitting: true, error: nil)
      attrs = Map.put(params, "stance", socket.assigns.selected_stance)

      # Cast IDs for context
      spark_id = socket.assigns.spark_id || Ecto.UUID.cast!(socket.assigns.spark.id)
      member_uuid = Ecto.UUID.cast!(member.id)

      case Contributions.create_contribution(attrs, spark_id, member_uuid) do
        {:ok, _} ->
          {:noreply,
           assign(socket,
             submitting: false,
             form: to_form(%{"body" => ""}),
             selected_stance: nil
           )}

        {:error, reason} ->
          {:noreply,
           assign(socket,
             submitting: false,
             error: Error.message(reason)
           )}
      end
    end
  end

  # ── Render ────────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto px-4 py-10 animate-fade-up">
      <a
        href="/feed"
        class="inline-flex items-center gap-1.5 text-sm text-stone-600
               hover:text-stone-300 transition-colors mb-8 group"
      >
        <span class="group-hover:-translate-x-0.5 transition-transform">←</span> Feed
      </a>

      <%!-- Spark --%>
      <article class="mb-12">
        <div class="flex items-center gap-2 mb-4 flex-wrap">
          <SparkComponents.status_chip status={@spark.status} />
          <SparkComponents.closes_in_badge
            closes_at={@spark.closes_at}
            is_closed={@spark.is_closed}
          />
          <span class="text-stone-700">·</span>
          <span
            class="text-xs text-stone-600"
            style="font-family: 'DM Mono', monospace;"
          >
            {format_author(@spark.author)}
          </span>

          <%!-- Extend button — spark author only --%>
          <ContributionComponents.extend_button
            :if={@current_member && @current_member.id == @spark.author_id}
            spark={@spark}
            max_extensions={@max_extensions}
          />
        </div>

        <h1
          class="text-2xl font-medium text-stone-100 leading-tight mb-5"
          style="font-family: 'Playfair Display', serif;"
        >
          {@spark.title}
        </h1>

        <SparkComponents.concept_tag_list concepts={@spark.concepts} />

        <%!-- Draft banner — author only --%>
        <div
          :if={@spark.status == "draft" and @current_member && @current_member.id == @spark.author_id}
          class="mb-5 flex items-center justify-between gap-4 px-4 py-3 rounded-xl
                 border border-amber-800/50 bg-amber-950/30"
        >
          <p class="text-sm text-amber-400">
            Draft — only you can see this spark.
          </p>
          <button
            phx-click="publish_spark"
            class="shrink-0 px-3 py-1.5 rounded-lg text-xs font-medium
                   bg-emerald-900/60 border border-emerald-700/50 text-emerald-300
                   hover:bg-emerald-800/60 transition-colors"
          >
            Publish
          </button>
        </div>

        <div class="mt-6 spark-body">
          <p :for={para <- paragraphs(@spark.body)} class="mb-4 last:mb-0">
            {para}
          </p>
        </div>
        <%!-- Weave trigger link — eligible members only --%>
        <div :if={@current_member && @can_weave} class="mt-6 pt-6 border-t border-stone-800">
          <a
            href={"/weave/#{@spark.id}"}
            class="inline-flex items-center gap-2 px-4 py-2 rounded-xl
                   border border-[#C9913A]/40 text-[#E8B86D] text-sm
                   hover:bg-[#1d1a14]/40 transition-colors"
          >
            <span>⟡</span>
            <span>Trigger Weave</span>
          </a>
          <p class="text-xs text-stone-600 mt-2">
            Weave highlighted contributions into a lasting Insight.
          </p>
        </div>
      </article>

      <%!-- Contributions --%>
      <section>
        <SparkComponents.section_divider label={"#{length(@contributions)} #{if length(@contributions) == 1, do: "contribution", else: "contributions"}"} />

        <%!-- Read timer hook target — invisible, wraps the spark body --%>
        <div
          :if={@can_contribute}
          id="read-timer"
          phx-hook="ReadTimer"
          data-word-count={word_count(@spark.body)}
          data-min-seconds="30"
        />

        <%!-- Stance filter --%>
        <ContributionComponents.stance_filter
          contributions={@contributions}
          active_filter={@active_filter}
        />

        <%!-- Thread --%>
        <div class="space-y-3 mb-8">
          <ContributionComponents.contribution_card
            :for={c <- filtered_contributions(@contributions, @active_filter)}
            contribution={c}
            is_author={@current_member && @current_member.id == c.author_id}
            is_spark_author={@current_member && @current_member.id == @spark.author_id}
            voted={MapSet.member?(@voted_set, c.id)}
            can_vote={not is_nil(@current_member)}
          />

          <div
            :if={@contributions == []}
            class="text-center py-10 text-stone-600 text-sm"
          >
            No contributions yet — be the first.
          </div>
        </div>

        <%!-- Form area --%>
        <div class="border-t border-stone-800 pt-6">
          <%= cond do %>
            <% @spark.status == "draft" and @current_member && @current_member.id == @spark.author_id -> %>
              <div class="text-center py-4">
                <p class="text-sm text-amber-500/80 mb-3">Publish this spark to open it for contributions.</p>
                <button
                  phx-click="publish_spark"
                  class="px-4 py-2 rounded-xl text-sm font-medium
                         bg-emerald-900/60 border border-emerald-700/50 text-emerald-300
                         hover:bg-emerald-800/60 transition-colors"
                >
                  Publish Spark
                </button>
              </div>
            <% @spark.status == "draft" -> %>
              <p class="text-sm text-stone-600 text-center py-4">
                This spark hasn't been published yet.
              </p>
            <% @spark.is_closed -> %>
              <ContributionComponents.closed_notice />
            <% is_nil(@current_member) -> %>
              <div class="text-center py-4">
                <a
                  href="/auth"
                  class="text-sm text-[#C9913A] hover:text-[#E8B86D] transition-colors"
                >
                  Sign in to contribute →
                </a>
              </div>
            <% true -> %>
              <%!-- Read lock overlay --%>
              <div
                id="contribution-lock"
                style={if @timer_unlocked, do: "display:none", else: ""}
                class="text-center py-6"
              >
                <div class="inline-flex items-center gap-3 px-5 py-3 rounded-xl
                            border border-stone-800 bg-stone-900/60">
                  <span class="text-stone-600 text-sm">Finish reading</span>
                  <span
                    id="read-timer-count"
                    class="font-mono text-sm text-[#C9913A]"
                    style="font-family: 'DM Mono', monospace; min-width: 2.5rem;"
                  >
                    …
                  </span>
                  <span class="text-stone-700 text-xs">to unlock</span>
                </div>
              </div>

              <%!-- Form — shown once timer unlocks --%>
              <div
                id="contribution-form-wrapper"
                style={if @timer_unlocked, do: "", else: "display:none"}
              >
                <ContributionComponents.contribution_form
                  form={@form}
                  selected_stance={@selected_stance}
                  submitting={@submitting}
                  error={@error}
                />
              </div>
          <% end %>
        </div>
      </section>
    </div>
    """
  end

  # ── Private ───────────────────────────────────────────────────────────────────

  defp can_contribute?(_spark, nil, _contributions), do: false

  defp can_contribute?(spark, member, _contributions) do
    not spark.is_closed and
      spark.status == "published" and
      not Sparks.author?(spark, member.id)
  end

  defp update_can_contribute(socket) do
    assign(socket,
      can_contribute:
        can_contribute?(
          socket.assigns.spark,
          socket.assigns.current_member,
          socket.assigns.contributions
        )
    )
  end

  defp filtered_contributions(contributions, nil), do: contributions

  defp filtered_contributions(contributions, stance) do
    Enum.filter(contributions, &(&1.stance == stance))
  end

  defp paragraphs(body) do
    body |> String.split("\n\n") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
  end

  defp format_author(%{username: u}) when is_binary(u) and u != "", do: "@" <> u
  defp format_author(%{wallet_address: addr}) when is_binary(addr), do: format_wallet(addr)
  defp format_author(_), do: "anon"

  defp format_wallet(nil), do: "anon"
  defp format_wallet(addr), do: String.slice(addr, 0, 6) <> "…" <> String.slice(addr, -4, 4)
end
