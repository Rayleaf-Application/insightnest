defmodule InsightnestWeb.WeaveLive.Editor do
  use InsightnestWeb, :live_view

  def mount(%{"spark_id" => spark_id}, _session, socket) do
    {:ok,
     assign(socket, page_title: "Weave - Spark #{spark_id}"),
     layout: {InsightnestWeb.Layouts, :app}}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto px-4 py-10">
      <p class="text-stone-400">Weave editor placeholder</p>
    </div>
    """
  end
end
