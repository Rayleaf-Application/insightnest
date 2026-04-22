defmodule InsightnestWeb.LibraryLive.Index do
  use InsightnestWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, page_title: "Library"),
     layout: {InsightnestWeb.Layouts, :app}}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto px-4 py-10">
      <p class="text-stone-400">Library placeholder</p>
    </div>
    """
  end
end
