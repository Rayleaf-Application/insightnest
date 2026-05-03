defmodule Insightnest.SparksFixtures do
  alias Insightnest.Sparks
  alias Insightnest.AccountsFixtures

  def spark(attrs \\ %{}) do
    author = attrs[:author] || AccountsFixtures.onboarded_member()
    {:ok, spark} = Sparks.create_spark(
      %{
        "title"  => attrs[:title]  || "Test Spark #{System.unique_integer()}",
        "body"   => attrs[:body]   || String.duplicate("word ", 20),
        "status" => attrs[:status] || "draft"
      },
      author.id
    )
    spark
  end

  def published_spark(attrs \\ %{}) do
    spark = spark(Map.put(attrs, :status, "published"))
    spark
  end
end
