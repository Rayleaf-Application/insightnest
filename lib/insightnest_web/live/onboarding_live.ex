defmodule InsightnestWeb.OnboardingLive do
  use InsightnestWeb, :live_view

  alias Insightnest.Accounts
  alias Insightnest.Accounts.Avatar

  # Only accessible when logged in but NOT yet onboarded
  on_mount {InsightnestWeb.Live.AuthHooks, :require_auth}

  @impl true
  def mount(_params, _session, socket) do
    member = socket.assigns.current_member

    # Already onboarded — send home
    if Accounts.onboarded?(member) do
      {:ok, push_navigate(socket, to: "/")}
    else
      {:ok,
       assign(socket,
         page_title:    "Welcome to InsightNest",
         form:          to_form(%{"username" => ""}),
         username:      "",
         checking:      false,
         available:     nil,   # nil = not checked, true/false = result
         error:         nil,
         avatar_svg:    Avatar.generate(member.wallet_address)
       )}
    end
  end

  @impl true
  def handle_event("validate_username", %{"username" => username}, socket) do
    username = String.downcase(String.trim(username))

    cond do
      byte_size(username) < 3 ->
        {:noreply, assign(socket, username: username, available: nil, checking: false)}

      not String.match?(username, ~r/^[a-zA-Z0-9_]+$/) ->
        {:noreply, assign(socket, username: username, available: false,
          error: "Only letters, numbers, and underscores allowed", checking: false)}

      true ->
        available = not Accounts.username_taken?(username)
        {:noreply, assign(socket,
          username:  username,
          available: available,
          checking:  false,
          error:     nil
        )}
    end
  end

  def handle_event("save", %{"username" => username}, socket) do
    member   = socket.assigns.current_member
    username = String.downcase(String.trim(username))

    case Accounts.set_username(member, username) do
      {:ok, _member} ->
        {:noreply, push_navigate(socket, to: "/")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(form: to_form(changeset))
         |> assign(error: "Username is already taken — try another.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center px-4">
      <div class="w-full max-w-sm animate-fade-up">

        <%!-- Avatar preview --%>
        <div class="flex flex-col items-center mb-8">
          <div class="w-20 h-20 rounded-2xl overflow-hidden border border-stone-700 mb-4 shadow-lg">
            {Phoenix.HTML.raw(@avatar_svg)}
          </div>
          <p class="text-xs text-stone-600 font-mono">
            {format_wallet(@current_member.wallet_address)}
          </p>
        </div>

        <%!-- Heading --%>
        <h1
          class="text-2xl text-stone-100 text-center mb-2"
          style="font-family: 'Playfair Display', serif;"
        >
          Choose your username
        </h1>
        <p class="text-sm text-stone-500 text-center mb-8">
          This is how other contributors will recognise you.
        </p>

        <%!-- Error --%>
        <div :if={@error} class="mb-4 px-4 py-3 rounded-lg border border-red-800/60 bg-red-950/50 text-red-300 text-sm">
          {@error}
        </div>

        <%!-- Form --%>
        <.form for={@form} phx-submit="save" class="space-y-4">

          <div class="relative">
            <span class="absolute left-3.5 top-1/2 -translate-y-1/2 text-stone-600 text-sm select-none">
              @
            </span>
            <input
              type="text"
              name="username"
              value={@username}
              placeholder="your_username"
              autofocus
              autocomplete="off"
              phx-change="validate_username"
              phx-debounce="400"
              maxlength="20"
              class="w-full bg-stone-900 border rounded-lg pl-8 pr-10 py-3
                     text-stone-100 placeholder-stone-700 text-sm
                     focus:outline-none focus:ring-1 transition-colors
                     font-mono"
              style={[
                "font-family: 'DM Mono', monospace;",
                input_border_style(@available)
              ]}
            />
            <%!-- Availability indicator --%>
            <span class="absolute right-3.5 top-1/2 -translate-y-1/2 text-sm">
              <%= cond do %>
                <% @available == true  -> %><span class="text-emerald-400">✓</span>
                <% @available == false -> %><span class="text-red-400">✗</span>
                <% true -> %><span></span>
              <% end %>
            </span>
          </div>

          <p class="text-xs text-stone-600">
            3–20 characters · letters, numbers, underscores
          </p>

          <button
            type="submit"
            disabled={@available != true or byte_size(@username) < 3}
            class="w-full py-3 bg-violet-600 hover:bg-violet-500
                   disabled:opacity-40 disabled:cursor-not-allowed
                   text-white text-sm font-medium rounded-lg transition-colors"
          >
            Continue →
          </button>

        </.form>

      </div>
    </div>
    """
  end

  defp format_wallet(nil), do: "anonymous"
  defp format_wallet(addr), do: String.slice(addr, 0, 6) <> "…" <> String.slice(addr, -4, 4)

  defp input_border_style(nil),   do: "border-color: #292524;"
  defp input_border_style(true),  do: "border-color: #166534; box-shadow: 0 0 0 1px rgba(22,101,52,0.3);"
  defp input_border_style(false), do: "border-color: #991b1b; box-shadow: 0 0 0 1px rgba(153,27,27,0.3);"
end
