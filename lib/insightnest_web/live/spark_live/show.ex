defmodule InsightnestWeb.SparkLive.Show do
  use InsightnestWeb, :live_view

  alias Insightnest.Sparks
  alias Insightnest.Contributions
  alias InsightnestWeb.SparkComponents
  alias InsightnestWeb.ContributionComponents

  @max_extensions Application.compile_env(:insightnest, :spark_max_extensions, 2)

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    spark         = Sparks.get_spark!(id)
    contributions = Contributions.list_for_spark(id)
    member        = socket.assigns[:current_member]

    voted_set =
      if member do
        Contributions.voter_highlights(id, member.id)
      else
        MapSet.new()
      end

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Insightnest.PubSub, "spark:#{id}")
    end

    {:ok,
     assign(socket,
       spark:           spark,
       contributions:   contributions,
       voted_set:       voted_set,
       page_title:      spark.title,
       form:            to_form(%{"body" => ""}),
       selected_stance: nil,
       active_filter:   nil,
       submitting:      false,
       error:           nil,
       max_extensions:  @max_extensions,
       can_contribute:  can_contribute?(spark, member, contributions)
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
  def handle_event("select_stance", %{"stance" => stance}, socket) do
    {:noreply, assign(socket, selected_stance: if(stance == "", do: nil, else: stance))}
  end

  def handle_event("filter_stance", %{"stance" => stance}, socket) do
    {:noreply, assign(socket, active_filter: if(stance == "", do: nil, else: stance))}
  end

  def handle_event("toggle_highlight", %{"contribution_id" => cid}, socket) do
    member = socket.assigns.current_member

    if is_nil(member) do
      {:noreply, assign(socket, error: "Sign in to highlight contributions.")}
    else
      case Contributions.toggle_highlight(cid, member.id) do
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
          {:noreply, assign(socket, error: "Could not update highlight.")}
      end
    end
  end

  def handle_event("author_override", params, socket) do
    member     = socket.assigns.current_member
    cid        = params["contribution_id"]
    highlighted = params["highlighted"] == "true"

    case Contributions.author_override(cid, member.id, highlighted) do
      {:ok, _}             -> {:noreply, socket}
      {:error, :unauthorized} -> {:noreply, assign(socket, error: "Not authorized.")}
      {:error, _}          -> {:noreply, assign(socket, error: "Could not update.")}
    end
  end

  def handle_event("extend_spark", %{"days" => days_str}, socket) do
    member = socket.assigns.current_member
    days   = String.to_integer(days_str)

    case Sparks.extend_spark(socket.assigns.spark, member.id, days) do
      {:ok, spark} ->
        {:noreply, assign(socket, spark: spark)}

      {:error, :max_extensions_reached} ->
        {:noreply, assign(socket, error: "Maximum extensions reached.")}

      {:error, :unauthorized} ->
        {:noreply, assign(socket, error: "Not authorized.")}
    end
  end

  def handle_event("submit_contribution", %{"contribution" => params}, socket) do
    member = socket.assigns.current_member

    if is_nil(member) do
      {:noreply, assign(socket, error: "You must be signed in to contribute.")}
    else
      socket = assign(socket, submitting: true, error: nil)
      attrs  = Map.put(params, "stance", socket.assigns.selected_stance)

      case Contributions.create_contribution(attrs, socket.assigns.spark.id, member.id) do
        {:ok, _} ->
          {:noreply,
           assign(socket,
             submitting:      false,
             form:            to_form(%{"body" => ""}),
             selected_stance: nil
           )}

        {:error, :own_spark} ->
          {:noreply, assign(socket, submitting: false, error: "You cannot contribute to your own Spark.")}

        {:error, :already_contributed} ->
          {:noreply, assign(socket, submitting: false, error: "You have already contributed to this Spark.")}

        {:error, :spark_closed} ->
          {:noreply, assign(socket, submitting: false, error: "This Spark is closed.")}

        {:error, :spark_not_published} ->
          {:noreply, assign(socket, submitting: false, error: "This Spark is not published.")}

        {:error, changeset} ->
          {:noreply,
           assign(socket,
             submitting: false,
             form:       to_form(changeset),
             error:      "Please check your contribution."
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
        href="/"
        class="inline-flex items-center gap-1.5 text-sm text-stone-600
               hover:text-stone-300 transition-colors mb-8 group"
      >
        <span class="group-hover:-translate-x-0.5 transition-transform">←</span>
        Feed
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
            {format_wallet(@spark.author.wallet_address)}
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
          <span class="group-hover:-translate-x-0.5 transition-transform">←</span> Feed
        </a>

        <SparkComponents.concept_tag_list concepts={@spark.concepts} />

        <div class="mt-6 spark-body">
          <p :for={para <- paragraphs(@spark.body)} class="mb-4 last:mb-0">
            {para}
          </p>
        </div>
      </article>

      <%!-- Contributions --%>
      <section>
        <SparkComponents.section_divider
          label={"#{length(@contributions)} #{if length(@contributions) == 1, do: "contribution", else: "contributions"}"}
        />

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
            <% @spark.is_closed -> %>
              <ContributionComponents.closed_notice />

            <% is_nil(@current_member) -> %>
              <div class="text-center py-4">
                <a href="/auth" class="text-sm text-violet-400 hover:text-violet-300 transition-colors">
                  Sign in to contribute →
                </a>
              </div>

            <% not @can_contribute -> %>
              <p class="text-sm text-stone-600 text-center py-4">
                You have already contributed to this Spark.
              </p>

            <% true -> %>
              <%!-- Read lock overlay --%>
              <div id="contribution-lock" class="text-center py-6">
                <div class="inline-flex items-center gap-3 px-5 py-3 rounded-xl
                            border border-stone-800 bg-stone-900/60">
                  <span class="text-stone-600 text-sm">Read time</span>
                  <span
                    id="read-timer-count"
                    class="font-mono text-sm text-violet-400"
                    style="font-family: 'DM Mono', monospace; min-width: 2.5rem;"
                  >
                    …
                  </span>
                  <span class="text-stone-700 text-xs">before contributing</span>
                </div>
              </div>

              <%!-- Form — hidden until timer unlocks it --%>
              <div id="contribution-form-wrapper" style="display: none;">
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

  defp can_contribute?(spark, nil, _), do: false
  defp can_contribute?(spark, member, contributions) do
    not spark.is_closed and
    spark.status == "published" and
    not Sparks.author?(spark, member.id) and
    not Enum.any?(contributions, &(&1.author_id == member.id))
  end

  defp update_can_contribute(socket) do
    assign(socket,
      can_contribute: can_contribute?(
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

  defp format_wallet(nil), do: "anon"
  defp format_wallet(addr), do: String.slice(addr, 0, 6) <> "…" <> String.slice(addr, -4, 4)
end
