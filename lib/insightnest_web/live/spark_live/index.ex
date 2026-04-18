defmodule InsightnestWeb.SparkLive.Index do
  use InsightnestWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="p-8">
      <h1 class="text-2xl font-bold">InsightNest</h1>
      <p>Week 0 — auth spike in progress.</p>
      <a href="/auth">Sign in</a>
    </div>
    """
  end
end
