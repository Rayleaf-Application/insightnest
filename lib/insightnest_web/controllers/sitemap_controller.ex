defmodule InsightnestWeb.SitemapController do
  use InsightnestWeb, :controller

  import Ecto.Query
  alias Insightnest.Repo
  alias Insightnest.Weaves.Insight

  def index(conn, _params) do
    base = InsightnestWeb.Endpoint.url()

    insights =
      Insight
      |> where([i], i.status == "published")
      |> select([i], {i.slug, i.updated_at})
      |> order_by([i], desc: i.updated_at)
      |> Repo.all()

    static_pages = [
      {"/", nil},
      {"/library", nil},
      {"/roadmap", nil}
    ]

    xml = build_sitemap(base, static_pages, insights)

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, xml)
  end

  defp build_sitemap(base, static_pages, insights) do
    static_entries =
      Enum.map(static_pages, fn {path, _updated_at} ->
        "<url><loc>#{base}#{path}</loc><changefreq>weekly</changefreq><priority>0.6</priority></url>"
      end)

    insight_entries =
      Enum.map(insights, fn {slug, updated_at} ->
        lastmod = Date.to_iso8601(DateTime.to_date(updated_at))

        "<url><loc>#{base}/insights/#{slug}</loc><lastmod>#{lastmod}</lastmod><changefreq>monthly</changefreq><priority>0.8</priority></url>"
      end)

    all_entries = (static_entries ++ insight_entries) |> Enum.join("\n  ")

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      #{all_entries}
    </urlset>
    """
  end
end
