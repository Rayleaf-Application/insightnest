defmodule InsightnestWeb.SparkLive.New do
  use InsightnestWeb, :live_view

  alias Insightnest.Sparks

  on_mount {InsightnestWeb.Live.AuthHooks, :require_auth}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "New Spark",
       form: to_form(%{"title" => "", "body" => "", "concepts" => [], "status" => "published"}),
       concept_input: "",
       concepts: [],
       error: nil
     )}
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
    member = socket.assigns.current_member
    attrs  = Map.put(params, "concepts", socket.assigns.concepts)

    case Sparks.create_spark(attrs, member.id) do
      {:ok, spark} ->
        {:noreply, push_navigate(socket, to: "/sparks/#{spark.id}")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(form: to_form(changeset))
         |> assign(error: "Please fix the errors below.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto px-4 py-8">
      <div class="flex items-center gap-3 mb-8">
        <a href="/" class="text-stone-500 hover:text-stone-300 transition-colors text-sm">← Feed</a>
        <h1 class="text-xl font-semibold text-stone-100">New Spark</h1>
      </div>

      <div :if={@error} class="mb-4 p-3 rounded-lg border border-red-800 bg-red-950 text-red-300 text-sm">
        {@error}
      </div>

      <.form for={@form} phx-submit="save" class="space-y-5">
        <div>
          <label class="block text-sm text-stone-400 mb-1">Title</label>
          <input
            type="text"
            name="spark[title]"
            value={@form[:title].value}
            placeholder="What's your idea?"
            class="w-full bg-stone-900 border border-stone-700 rounded-lg px-3 py-2 text-stone-100 text-sm placeholder-stone-600 focus:outline-none focus:border-violet-500"
          />
        </div>

        <div>
          <label class="block text-sm text-stone-400 mb-1">Body</label>
          <textarea
            name="spark[body]"
            rows="8"
            placeholder="Develop your idea..."
            class="w-full bg-stone-900 border border-stone-700 rounded-lg px-3 py-2 text-stone-100 text-sm placeholder-stone-600 focus:outline-none focus:border-violet-500 resize-none"
          ><%= @form[:body].value %></textarea>
        </div>

        <div>
          <label class="block text-sm text-stone-400 mb-1">
            Concepts <span class="text-stone-600">(press Enter to add)</span>
          </label>

          <div class="flex flex-wrap gap-2 mb-2">
            <span
              :for={concept <- @concepts}
              class="inline-flex items-center gap-1 px-2 py-0.5 text-xs rounded-full bg-stone-800 text-stone-300 border border-stone-700"
            >
              {concept}
              <button
                type="button"
                phx-click="remove_concept"
                phx-value-concept={concept}
                class="text-stone-500 hover:text-red-400 transition-colors"
              >×</button>
            </span>
          </div>

          <input
            type="text"
            value={@concept_input}
            placeholder="e.g. epistemology"
            phx-keyup="add_concept"
            phx-value-value={@concept_input}
            phx-change="update_concept_input"
            class="w-full bg-stone-900 border border-stone-700 rounded-lg px-3 py-2 text-stone-100 text-sm placeholder-stone-600 focus:outline-none focus:border-violet-500"
          />
        </div>

        <div>
          <label class="block text-sm text-stone-400 mb-1">Publish as</label>
          <div class="flex gap-3">
            <label class="flex items-center gap-2 cursor-pointer">
              <input
                type="radio"
                name="spark[status]"
                value="published"
                checked={@form[:status].value == "published"}
                class="accent-violet-500"
              />
              <span class="text-sm text-stone-300">Published</span>
            </label>
            <label class="flex items-center gap-2 cursor-pointer">
              <input
                type="radio"
                name="spark[status]"
                value="draft"
                checked={@form[:status].value == "draft"}
                class="accent-violet-500"
              />
              <span class="text-sm text-stone-300">Draft</span>
            </label>
          </div>
        </div>

        <button
          type="submit"
          class="w-full py-2.5 bg-violet-600 hover:bg-violet-500 text-white text-sm font-medium rounded-lg transition-colors"
        >
          Create Spark
        </button>
      </.form>
    </div>
    """
  end
end
