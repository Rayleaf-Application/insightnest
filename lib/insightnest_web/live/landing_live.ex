defmodule InsightnestWeb.LandingLive do
  use InsightnestWeb, :live_view

  alias Insightnest.Waitlist
  alias Insightnest.Waitlist.Entry

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns[:current_member] do
      {:ok, push_navigate(socket, to: "/library")}
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
    <div class="min-h-screen flex flex-col">

      <%!-- Main content --%>
      <div class="flex-1 flex flex-col items-center justify-center px-4 py-16 animate-fade-up">

      <%!-- Logo --%>
      <div class="flex items-center gap-3 mb-16">
        <svg width="32" height="32" viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <rect width="200" height="200" rx="44" fill="#141820"/>
          <path d="M 36 132 C 36 68 164 68 164 132" stroke="#E8B86D" stroke-width="8.4" fill="none" stroke-linecap="round"/>
          <path d="M 54 148 C 54 92 146 92 146 148" stroke="#E8B86D" stroke-width="8.4" fill="none" stroke-linecap="round"/>
          <path d="M 76 160 C 76 116 124 116 124 160" stroke="#E8B86D" stroke-width="8.4" fill="none" stroke-linecap="round"/>
          <line x1="100" y1="56" x2="100" y2="28" stroke="#FDFAF5" stroke-width="6" stroke-linecap="round"/>
          <path d="M 100 14 L 109 27 L 100 40 L 91 27 Z" fill="#FDFAF5"/>
          <line x1="72" y1="42" x2="84" y2="53" stroke="#FDFAF5" stroke-width="5" stroke-linecap="round" opacity="0.4"/>
          <line x1="128" y1="42" x2="116" y2="53" stroke="#FDFAF5" stroke-width="5" stroke-linecap="round" opacity="0.4"/>
        </svg>
        <span style="font-family: 'Playfair Display', serif; font-size: 18px; font-weight: 400; line-height: 1; letter-spacing: -0.01em;">
          <span style="font-style: italic; color: #FDFAF5;">Insight</span><span style="color: #C9913A;">Nest</span>
        </span>
      </div>

      <%!-- Hero --%>
      <div class="text-center max-w-lg mb-8">
        <h1
          class="text-5xl text-[#FDFAF5] leading-tight mb-5"
          style="font-family: 'Playfair Display', serif;"
        >
          Slow knowledge,<br />
          <span class="italic" style="color:#C9913A;">co-owned.</span>
        </h1>
        <p class="text-[#7A7468] text-base leading-relaxed max-w-sm mx-auto">
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
            <p class="text-[#F5F0E8] font-medium mb-1">You're on the list.</p>
            <p class="text-[#7A7468] text-sm">We'll reach out when your spot opens.</p>
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
                class="w-full bg-[#2D3142] border border-[#2D3142]/60 rounded-xl px-4 py-3
                       text-sm text-[#FDFAF5] placeholder-[#7A7468]
                       focus:outline-none focus:border-[#C9913A] transition-colors"
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
                class="w-full bg-[#2D3142] border border-[#2D3142]/60 rounded-xl px-4 py-3
                       text-sm text-[#FDFAF5] placeholder-[#7A7468]
                       focus:outline-none focus:border-[#C9913A] transition-colors"
              />
            </div>

            <%!-- Reason (optional) --%>
            <div>
              <textarea
                name="waitlist[reason]"
                placeholder="Why do you want early access? (optional)"
                rows="3"
                class="w-full bg-[#2D3142] border border-[#2D3142]/60 rounded-xl px-4 py-3
                       text-sm text-[#FDFAF5] placeholder-[#7A7468]
                       focus:outline-none focus:border-[#C9913A] transition-colors resize-none"
              ><%= @form[:reason].value %></textarea>
            </div>

            <button
              type="submit"
              class="w-full py-3 rounded-xl bg-[#C9913A] hover:bg-[#E8B86D] text-[#141820]
                     text-sm font-medium transition-colors mt-1"
            >
              Request early access
            </button>
          </.form>

          <p class="text-center mt-6">
            <a
              href="/auth"
              class="text-xs text-[#7A7468] hover:text-[#F5F0E8] transition-colors"
            >
              Already have access? Sign in →
            </a>
          </p>
        <% end %>
      </div>

      </div><%!-- end main content --%>

      <%!-- Footer --%>
      <footer class="border-t border-[#2D3142]/60">
        <div class="max-w-lg mx-auto px-4 py-5 flex flex-col items-center gap-3">
          <div class="flex items-center gap-6">
            <a href="https://infosec.exchange/@insightnest" title="Mastodon" class="text-[#7A7468] hover:text-[#F5F0E8] transition-colors" aria-label="Mastodon" target="_blank" rel="noopener noreferrer">
              <svg width="16" height="16" viewBox="0 0 74 79" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
                <path d="M73.7 17.4C72.6 9.1 65.2 2.4 56.4 1.2 54.9 1 49.4 0.2 36.4 0.2h-.1C23.3 0.2 20.5 1 19.1 1.2 10.6 2.4 2.8 8.3.9 16.8c-.9 4.2-.9 8.8-.8 13 .2 6.1.2 12.2.9 18.2.4 4 1.1 7.9 2.2 11.7 2 7.5 9.4 13.7 16.6 16.3 7.7 2.8 16.1 3.2 24.1 1.5.8-.2 1.6-.4 2.4-.7 2.4-.7 5-1.5 7.1-2.9V68c-4.4 1.1-8.9 1.7-13.4 1.7-7.6 0-9.7-3.5-10.3-4.9-.5-1.2-.8-2.4-.9-3.7 4.4 1.1 8.9 1.6 13.4 1.6 1.1 0 2.2 0 3.3 0 4.5-.1 9.2-.4 13.6-1.2.1 0 .2 0 .3-.1 6.9-1.4 13.5-5.5 14.2-16.1.1-.4.1-4.9.1-5.3 0-1.5.2-12.1-.1-22.6zM61.4 45.2h-8V25.3c0-4.1-1.7-6.2-5.1-6.2-3.7 0-5.6 2.5-5.6 7.4v10.1h-8V26.4c0-4.9-1.9-7.4-5.6-7.4-3.4 0-5.1 2.1-5.1 6.2v19.9h-8V24.7c0-4.2 1.1-7.5 3.2-10 2.2-2.5 5.2-3.7 8.9-3.7 4.3 0 7.5 1.6 9.7 4.8l2 3.2 2-3.2c2.2-3.2 5.5-4.8 9.7-4.8 3.7 0 6.7 1.3 8.9 3.7 2.2 2.5 3.2 5.8 3.2 10l-2.5 20.5z"/>
              </svg>
            </a>
            <a href="https://matrix.to/#/#kradle:matrix.org" title="Matrix" class="text-[#7A7468] hover:text-[#F5F0E8] transition-colors" aria-label="Matrix" target="_blank" rel="noopener noreferrer">
              <svg width="16" height="16" viewBox="0 0 32 32" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
                <path d="M1 1v30h2.5V3.5h25V1zm28.5 1.5H4v27.5h25.5V31H31V1h-1.5z"/>
              </svg>
            </a>
            <a href="https://github.com/Rayleaf-Application/insightnest" title="GitHub" class="text-[#7A7468] hover:text-[#F5F0E8] transition-colors" aria-label="GitHub" target="_blank" rel="noopener noreferrer">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
                <path d="M12 0C5.37 0 0 5.37 0 12c0 5.3 3.44 9.8 8.21 11.39.6.11.79-.26.79-.58v-2.23c-3.34.73-4.03-1.42-4.03-1.42-.55-1.39-1.34-1.76-1.34-1.76-1.09-.74.08-.73.08-.73 1.2.08 1.84 1.24 1.84 1.24 1.07 1.83 2.81 1.3 3.49 1 .11-.78.42-1.31.76-1.61-2.67-.3-5.47-1.33-5.47-5.93 0-1.31.47-2.38 1.24-3.22-.12-.3-.54-1.52.12-3.18 0 0 1.01-.32 3.3 1.23a11.5 11.5 0 0 1 3-.4c1.02.01 2.05.14 3 .4 2.29-1.55 3.3-1.23 3.3-1.23.66 1.66.24 2.88.12 3.18.77.84 1.24 1.91 1.24 3.22 0 4.61-2.81 5.63-5.48 5.92.43.37.82 1.1.82 2.22v3.29c0 .32.19.69.8.58C20.56 21.8 24 17.3 24 12c0-6.63-5.37-12-12-12z"/>
              </svg>
            </a>
            <a href="https://discord.gg/QR3HTgDRY" title="Discord" class="text-[#7A7468] hover:text-[#F5F0E8] transition-colors" aria-label="Discord" target="_blank" rel="noopener noreferrer">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
                <path d="M20.32 4.37a19.79 19.79 0 0 0-4.89-1.52.07.07 0 0 0-.08.04c-.21.37-.44.86-.61 1.25a18.27 18.27 0 0 0-5.49 0 12.64 12.64 0 0 0-.62-1.25.08.08 0 0 0-.08-.04 19.74 19.74 0 0 0-4.88 1.52.07.07 0 0 0-.03.03C.53 9.05-.32 13.58.1 18.06a.08.08 0 0 0 .03.05 19.9 19.9 0 0 0 5.99 3.03.08.08 0 0 0 .08-.03c.46-.63.87-1.3 1.23-2a.08.08 0 0 0-.04-.1 13.1 13.1 0 0 1-1.87-.9.08.08 0 0 1 0-.13c.13-.1.25-.2.37-.29a.07.07 0 0 1 .08-.01c3.93 1.79 8.18 1.79 12.06 0a.07.07 0 0 1 .08.01c.12.1.25.19.37.29a.08.08 0 0 1-.01.13 12.3 12.3 0 0 1-1.87.89.08.08 0 0 0-.04.11c.36.7.77 1.36 1.23 1.99a.08.08 0 0 0 .08.03 19.84 19.84 0 0 0 6-3.03.08.08 0 0 0 .03-.05c.5-5.18-.84-9.67-3.55-13.66a.06.06 0 0 0-.03-.03zM8.02 15.33c-1.18 0-2.16-1.08-2.16-2.42 0-1.33.96-2.42 2.16-2.42 1.21 0 2.18 1.1 2.16 2.42 0 1.34-.96 2.42-2.16 2.42zm7.97 0c-1.18 0-2.16-1.08-2.16-2.42 0-1.33.95-2.42 2.16-2.42 1.21 0 2.18 1.1 2.16 2.42 0 1.34-.94 2.42-2.16 2.42z"/>
              </svg>
            </a>
          </div>
          <a href="/manifesto.html" class="text-xs text-[#7A7468] hover:text-[#C9913A] transition-colors tracking-wide">
            Manifesto
          </a>
        </div>
      </footer>

    </div>
    """
  end
end
