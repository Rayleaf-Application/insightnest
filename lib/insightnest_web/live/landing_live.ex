defmodule InsightnestWeb.LandingLive do
  use InsightnestWeb, :live_view

  alias Insightnest.Waitlist
  alias Insightnest.Waitlist.Entry

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns[:current_member] do
      {:ok, push_navigate(socket, to: "/feed")}
    else
      {:ok,
       socket
       |> assign(page_title: "InsightNest", submitted: false)
       |> fresh_form(),
       layout: {InsightnestWeb.Layouts, :root}}
    end
  end

  @impl true
  def handle_event("submit", %{"waitlist" => params}, socket) do
    case Waitlist.create(params) do
      {:ok, _} ->
        {:noreply, assign(socket, submitted: true)}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :waitlist))}
    end
  end

  defp fresh_form(socket) do
    assign(socket, form: to_form(Entry.changeset(%Entry{}, %{}), as: :waitlist))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col items-center justify-center px-4 py-16 animate-fade-up">

      <%!-- Logo --%>
      <div class="flex items-center gap-3 mb-16">
        <svg width="28" height="28" viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <rect width="200" height="200" rx="44" fill="#0C0929"></rect>
          <path d="M 18 120 Q 100 158 182 120" stroke="#7C3AED" stroke-width="11" fill="none" stroke-linecap="round"></path>
          <path d="M 36 105 Q 100 138 164 105" stroke="#7C3AED" stroke-width="9.5" fill="none" stroke-linecap="round" opacity="0.7"></path>
          <path d="M 55 93  Q 100 122 145 93" stroke="#8B5CF6" stroke-width="8.5" fill="none" stroke-linecap="round" opacity="0.5"></path>
          <polygon points="100,35 107,50 122,56 107,62 100,77 93,62 78,56 93,50" fill="#F59E0B"></polygon>
        </svg>
        <span
          class="text-xs text-stone-500 tracking-widest uppercase"
          style="font-family: 'DM Mono', monospace;"
        >
          InsightNest
        </span>
      </div>

      <%!-- Hero --%>
      <div class="text-center max-w-lg mb-8">
        <h1
          class="text-5xl text-stone-100 leading-tight mb-5"
          style="font-family: 'Playfair Display', serif;"
        >
          Slow knowledge,<br />
          <span class="italic text-violet-400">co-owned.</span>
        </h1>
        <p class="text-stone-500 text-base leading-relaxed max-w-sm mx-auto">
          Ideas refined through collective discussion.
          Insights that belong to the contributors who shaped them.
        </p>
      </div>

      <%!-- Alpha badge --%>
      <div class="mb-10">
        <span class="inline-flex items-center gap-2 px-3 py-1 rounded-full text-xs
                     border border-amber-800/40 bg-amber-950/30 text-amber-500">
          <span class="w-1.5 h-1.5 rounded-full bg-amber-400 animate-pulse inline-block"></span>
          Closed alpha — request early access
        </span>
      </div>

      <%!-- Form / success --%>
      <div class="w-full max-w-xs">
        <%= if @submitted do %>
          <div class="text-center py-8">
            <div
              class="inline-flex items-center justify-center w-10 h-10 rounded-full
                     border border-emerald-700/50 bg-emerald-950/40 text-emerald-400
                     text-lg mb-4"
            >
              ✓
            </div>
            <p class="text-stone-200 font-medium mb-1">You're on the list.</p>
            <p class="text-stone-600 text-sm">We'll reach out when your spot opens.</p>
          </div>
        <% else %>
          <.form for={@form} phx-submit="submit" class="space-y-2.5">

            <%!-- Email --%>
            <div>
              <input
                type="email"
                name="waitlist[email]"
                value={@form[:email].value}
                placeholder="your@email.com"
                autocomplete="email"
                required
                class="w-full bg-stone-900 border border-stone-800 rounded-xl px-4 py-3
                       text-sm text-stone-100 placeholder-stone-600
                       focus:outline-none focus:border-stone-600 transition-colors"
              />
              <p
                :for={{msg, _} <- @form[:email].errors}
                class="mt-1 text-xs text-red-400 px-1"
              >
                {msg}
              </p>
            </div>

            <%!-- Name (optional) --%>
            <div>
              <input
                type="text"
                name="waitlist[name]"
                value={@form[:name].value}
                placeholder="Name (optional)"
                autocomplete="name"
                class="w-full bg-stone-900 border border-stone-800 rounded-xl px-4 py-3
                       text-sm text-stone-100 placeholder-stone-600
                       focus:outline-none focus:border-stone-600 transition-colors"
              />
            </div>

            <%!-- Reason (optional) --%>
            <div>
              <textarea
                name="waitlist[reason]"
                placeholder="Why do you want early access? (optional)"
                rows="3"
                class="w-full bg-stone-900 border border-stone-800 rounded-xl px-4 py-3
                       text-sm text-stone-100 placeholder-stone-600
                       focus:outline-none focus:border-stone-600 transition-colors resize-none"
              ><%= @form[:reason].value %></textarea>
            </div>

            <button
              type="submit"
              class="w-full py-3 rounded-xl bg-violet-600 hover:bg-violet-500 text-white
                     text-sm font-medium transition-colors mt-1"
            >
              Request early access
            </button>
          </.form>

          <p class="text-center mt-6">
            <a
              href="/auth"
              class="text-xs text-stone-600 hover:text-stone-400 transition-colors"
            >
              Already have access? Sign in →
            </a>
          </p>
        <% end %>
      </div>

    </div>
    """
  end
end
