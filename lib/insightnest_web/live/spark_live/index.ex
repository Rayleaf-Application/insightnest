defmodule InsightnestWeb.SparkLive.Index do
  use InsightnestWeb, :live_view

  alias Insightnest.Sparks
  alias InsightnestWeb.SparkComponents

  @impl true
  def mount(_params, _session, socket) do
    sparks = Sparks.list_published()
    {:ok, assign(socket, sparks: sparks, page_title: "InsightNest")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto px-4 py-8">
      <div class="flex items-center justify-between mb-8">
        <h1 class="text-xl font-semibold text-stone-100">InsightNest</h1>
        <div class="flex items-center gap-3">
          <%= if @current_member do %>
            <a
              href="/sparks/new"
              class="px-3 py-1.5 text-sm bg-violet-600 hover:bg-violet-500 text-white rounded-lg transition-colors"
            >
              New Spark
            </a>
            <a href="/garden" class="text-sm text-stone-400 hover:text-stone-200 transition-colors">
              Garden
            </a>
          <% else %>
            <a href="/auth" class="text-sm text-stone-400 hover:text-stone-200 transition-colors">
              Sign in
            </a>
          <% end %>
        </div>
      </div>

      <div :if={@sparks == []} class="text-center py-16 text-stone-500">
        <p class="text-lg">No sparks yet.</p>
        <p class="text-sm mt-1">Be the first to create one.</p>
        <a
          href="/auth"
          class="mt-4 inline-block px-4 py-2 bg-violet-600 hover:bg-violet-500 text-white text-sm rounded-lg transition-colors"
        >
          Get started
        </a>
      </div>

      <div class="space-y-3">
        <SparkComponents.spark_card :for={spark <- @sparks} spark={spark} />
      </div>
    </div>
    """
  end
end
