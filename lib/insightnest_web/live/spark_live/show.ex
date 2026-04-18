defmodule InsightnestWeb.SparkLive.Show do
  use InsightnestWeb, :live_view
  def mount(_params, _session, socket), do: {:ok, socket}
  def render(assigns), do: ~H"<div>placeholder</div>"
end
