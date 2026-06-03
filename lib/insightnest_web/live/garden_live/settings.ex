defmodule InsightnestWeb.GardenLive.Settings do
  use InsightnestWeb, :live_view

  on_mount {InsightnestWeb.Live.AuthHooks, :require_onboarded}

  alias Insightnest.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Settings",
       confirm_delete: false,
       deleting: false,
       error: nil
     )}
  end

  @impl true
  def handle_event("confirm_delete", _, socket) do
    {:noreply, assign(socket, confirm_delete: true, error: nil)}
  end

  def handle_event("cancel_delete", _, socket) do
    {:noreply, assign(socket, confirm_delete: false)}
  end

  def handle_event("delete_account", _, socket) do
    member = socket.assigns.current_member
    socket = assign(socket, deleting: true)

    result =
      try do
        Accounts.delete_member(member)
      rescue
        e -> {:error, Exception.message(e)}
      end

    case result do
      {:ok, :ok} ->
        {:noreply, redirect(socket, to: "/auth/delete_redirect")}

      {:error, _} ->
        {:noreply, assign(socket, deleting: false, error: "Deletion failed. Please try again.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto px-4 py-10 animate-fade-up">
      <div class="flex items-center gap-3 mb-8">
        <a
          href="/garden"
          class="inline-flex items-center gap-1.5 text-sm text-stone-600
                 hover:text-stone-300 transition-colors group"
        >
          <span class="group-hover:-translate-x-0.5 transition-transform">←</span> Garden
        </a>
      </div>

      <h1
        class="text-2xl font-medium text-stone-100 mb-8"
        style="font-family: 'Playfair Display', serif;"
      >
        Settings
      </h1>

      <div
        :if={@error}
        class="mb-6 px-4 py-3 rounded-lg border border-red-800/60 bg-red-950/50 text-red-300 text-sm"
      >
        {@error}
      </div>

      <%!-- Data & Privacy --%>
      <section class="space-y-6">
        <div class="border-b border-stone-800 pb-2">
          <h2 class="text-xs text-stone-600 uppercase tracking-widest">Data & Privacy</h2>
        </div>

        <%!-- Export --%>
        <div class="flex items-start justify-between gap-6 py-2">
          <div class="flex-1">
            <p class="text-sm text-stone-300 font-medium mb-1">Export my data</p>
            <p class="text-xs text-stone-600 leading-relaxed">
              Download a JSON file containing all data InsightNest holds about you —
              your profile, Sparks, and contributions. Satisfies GDPR Articles 15 and 20.
            </p>
          </div>
          <a
            href="/garden/export"
            class="shrink-0 px-4 py-2 text-sm rounded-lg border border-stone-700
                   text-stone-300 hover:border-stone-500 hover:text-stone-100
                   transition-colors"
          >
            Download JSON
          </a>
        </div>

        <%!-- Delete account --%>
        <div class="flex items-start justify-between gap-6 py-2 border-t border-stone-800/60 pt-6">
          <div class="flex-1">
            <p class="text-sm text-stone-300 font-medium mb-1">Delete my account</p>
            <p class="text-xs text-stone-600 leading-relaxed">
              Permanently removes your profile, Sparks, and contributions from InsightNest.
              This cannot be undone. Any published Insights you contributed to will remain
              on the platform, attributed only to a pseudonymous wallet address.
            </p>
          </div>
          <button
            :if={not @confirm_delete}
            type="button"
            phx-click="confirm_delete"
            class="shrink-0 px-4 py-2 text-sm rounded-lg border border-red-900/60
                   text-red-400 hover:border-red-700 hover:text-red-300
                   transition-colors"
          >
            Delete account
          </button>
        </div>

        <%!-- Confirmation panel --%>
        <div
          :if={@confirm_delete}
          class="rounded-xl border border-red-800/60 bg-red-950/30 p-5 space-y-4"
        >
          <p class="text-sm text-red-300 font-medium">
            Are you sure? This action is permanent and cannot be reversed.
          </p>
          <p class="text-xs text-stone-500 leading-relaxed">
            Your account, Sparks, and contributions will be deleted. A one-way hash
            of your wallet address is retained solely to prevent abuse.
          </p>
          <div class="flex gap-3">
            <button
              type="button"
              phx-click="delete_account"
              phx-disable-with="Deleting…"
              disabled={@deleting}
              class="px-4 py-2 text-sm rounded-lg bg-red-900/60 border border-red-700/60
                     text-red-300 hover:bg-red-800/60 transition-colors
                     disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Yes, delete my account
            </button>
            <button
              type="button"
              phx-click="cancel_delete"
              class="px-4 py-2 text-sm rounded-lg border border-stone-700
                     text-stone-400 hover:border-stone-500 transition-colors"
            >
              Cancel
            </button>
          </div>
        </div>
      </section>
    </div>
    """
  end
end
