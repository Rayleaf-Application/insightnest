defmodule InsightnestWeb.PageController do
  use InsightnestWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
