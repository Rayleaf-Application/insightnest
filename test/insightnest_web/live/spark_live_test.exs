defmodule InsightnestWeb.SparkLiveTest do
  use InsightnestWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Insightnest.AccountsFixtures
  alias Insightnest.SparksFixtures

  describe "SparkLive.Index" do
    test "renders empty feed for guest", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ "InsightNest"
    end

    test "renders sparks in feed", %{conn: conn} do
      spark = SparksFixtures.published_spark()
      {:ok, _view, html} = live(conn, "/")
      assert html =~ spark.title
    end

    test "shows New Spark button for authenticated member", %{conn: conn} do
      member = AccountsFixtures.member()
      conn   = log_in(conn, member)
      {:ok, _view, html} = live(conn, "/")
      assert html =~ "New Spark"
    end
  end

  describe "SparkLive.New" do
    test "redirects unauthenticated to /auth", %{conn: conn} do
      {:error, {:redirect, %{to: "/auth"}}} = live(conn, "/sparks/new")
    end

    test "authenticated member can create a spark", %{conn: conn} do
      member = AccountsFixtures.onboarded_member()
      conn   = log_in(conn, member)
      {:ok, view, _html} = live(conn, "/sparks/new")

      view
      |> form("#spark-form", spark: %{
        title: "Test spark about epistemology",
        body:  String.duplicate("word ", 20)  # 20 words — enough for validation
      })
      |> render_submit()

      assert_redirected(view, ~r|/sparks/|)
    end
  end
end
