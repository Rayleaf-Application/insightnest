defmodule InsightnestWeb.SparkLive.New do
  use InsightnestWeb, :live_view

  on_mount {InsightnestWeb.Live.AuthHooks, :require_auth}

  alias Insightnest.Sparks
  alias Insightnest.Sparks.Spark

  @impl true
  def mount(_params, _session, socket) do
    changeset = Sparks.changeset(%Spark{}, %{})

    {:ok,
     assign(socket,
       page_title: "New Spark",
       form: to_form(changeset),
       concepts: [],
       concept_input: "",
       error: nil
     ), layout: {InsightnestWeb.Layouts, :app}}
  end

  @impl true
  def handle_event("add_concept", %{"key" => key, "value" => value}, socket)
      when key in ["Enter", ","] do
    concept = String.trim(value)

    if concept != "" and concept not in socket.assigns.concepts do
      {:noreply,
       socket
       |> assign(concepts: socket.assigns.concepts ++ [concept])
       |> assign(concept_input: "")}
    else
      {:noreply, assign(socket, concept_input: "")}
    end
  end

  def handle_event("add_concept", _, socket), do: {:noreply, socket}

  def handle_event("remove_concept", %{"concept" => concept}, socket) do
    {:noreply, assign(socket, concepts: List.delete(socket.assigns.concepts, concept))}
  end

  def handle_event("update_concept_input", %{"value" => value}, socket) do
    {:noreply, assign(socket, concept_input: value)}
  end

  def handle_event("save", %{"spark" => params}, socket) do
    IO.inspect(params, label: "======================SAVE PARAMS")
    IO.inspect(socket.assigns.current_member, label: "======================MEMBER")

    # Add concepts to params
    attrs = Map.put(params, "concepts", socket.assigns.concepts)

    # Create changeset with the attributes
    changeset = Sparks.changeset(%Spark{}, attrs)

    case Sparks.create_spark(attrs, socket.assigns.current_member.id) do
      {:ok, spark} ->
        {:noreply, push_navigate(socket, to: "/sparks/#{spark.id}")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(form: to_form(changeset))
         # Remove custom error, let changeset errors display
         |> assign(error: nil)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto px-4 py-10 animate-fade-up">
        <a
          href="/"
          class="inline-flex items-center gap-1.5 text-sm text-stone-600
               hover:text-stone-300 transition-colors mb-8 group"
        >
          <span class="group-hover:-translate-x-0.5 transition-transform">←</span> Feed
        </a>

        <h1
          class="text-2xl font-medium text-stone-100 mb-8"
          style="font-family: 'Playfair Display', serif;"
        >
          New Spark
        </h1>

        <%!-- Error --%>
        <div :if={@error} class="flash-error rounded-lg px-4 py-3 text-sm mb-6">
          {@error}
        </div>

        <.form for={@form} id="spark-form" phx-submit="save" class="space-y-6">
          <%!-- Title --%>
          <div>
            <label class="block text-xs text-stone-500 uppercase tracking-widest mb-2">
              Title
            </label>
            <input
              type="text"
              name="spark[title]"
              value={@form[:title].value}
              placeholder="What's your idea?"
              autofocus
              class="w-full bg-stone-900 border border-stone-700 rounded-lg px-4 py-3
                   text-stone-100 placeholder-stone-700 text-base
                   focus:outline-none focus:border-violet-500 focus:ring-1 focus:ring-violet-500/30
                   transition-colors"
              style="font-family: 'Playfair Display', serif;"
            />
          </div>

          <%!-- Body --%>
          <div>
            <label class="block text-xs text-stone-500 uppercase tracking-widest mb-2">
              Body
            </label>
            <textarea
              name="spark[body]"
              rows="10"
              placeholder="Develop your idea..."
              class="w-full bg-stone-900 border border-stone-700 rounded-lg px-4 py-3
                   text-stone-300 placeholder-stone-700 text-sm leading-relaxed
                   focus:outline-none focus:border-violet-500 focus:ring-1 focus:ring-violet-500/30
                   transition-colors resize-none"
            ><%= @form[:body].value %></textarea>
          </div>

          <%!-- Concepts --%>
          <div>
            <label class="block text-xs text-stone-500 uppercase tracking-widest mb-2">
              Concepts <span class="normal-case ml-1 text-stone-700">(press Enter to add)</span>
            </label>

            <div class="flex flex-wrap gap-2 mb-2 min-h-[1.5rem]">
              <span
                :for={concept <- @concepts}
                class="inline-flex items-center gap-1.5 px-2.5 py-1 text-xs rounded-md
                     bg-violet-950 text-violet-300 border border-violet-800/60"
              >
                {concept}
                <button
                  type="button"
                  phx-click="remove_concept"
                  phx-value-concept={concept}
                  class="text-violet-500 hover:text-red-400 transition-colors leading-none"
                >
                  ×
                </button>
              </span>
            </div>

            <input
              type="text"
              value={@concept_input}
              placeholder="e.g. epistemology"
              phx-keyup="add_concept"
              phx-value-value={@concept_input}
              phx-change="update_concept_input"
              class="w-full bg-stone-900 border border-stone-700 rounded-lg px-4 py-2.5
                   text-stone-300 placeholder-stone-700 text-sm
                   focus:outline-none focus:border-violet-500 focus:ring-1 focus:ring-violet-500/30
                   transition-colors"
            />
          </div>

          <%!-- Publish toggle --%>
          <div>
            <label class="block text-xs text-stone-500 uppercase tracking-widest mb-3">
              Visibility
            </label>
            <div class="flex gap-4">
              <label class="flex items-center gap-2.5 cursor-pointer group">
                <input
                  type="radio"
                  name="spark[status]"
                  value="published"
                  checked={@form[:status].value != "draft"}
                  class="w-4 h-4 accent-violet-500"
                />
                <span class="text-sm text-stone-300 group-hover:text-stone-100 transition-colors">
                  Publish now
                </span>
              </label>
              <label class="flex items-center gap-2.5 cursor-pointer group">
                <input
                  type="radio"
                  name="spark[status]"
                  value="draft"
                  checked={@form[:status].value == "draft"}
                  class="w-4 h-4 accent-violet-500"
                />
                <span class="text-sm text-stone-300 group-hover:text-stone-100 transition-colors">
                  Save as draft
                </span>
              </label>
            </div>
          </div>

          <%!-- Submit --%>
          <button
            type="submit"
            class="w-full py-3 bg-violet-600 hover:bg-violet-500 active:bg-violet-700
                 text-white text-sm font-medium rounded-lg transition-colors
                 focus:outline-none focus:ring-2 focus:ring-violet-400 focus:ring-offset-2
                 focus:ring-offset-stone-950"
          >
            Create Spark
          </button>
        </.form>
      </div>
    """
  end
end
