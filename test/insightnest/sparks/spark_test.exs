defmodule Insightnest.Sparks.SparkTest do
  use ExUnit.Case, async: true

  import Ecto.Changeset, only: [get_change: 2]

  alias Insightnest.Sparks.Spark

  defp valid_attrs do
    %{
      title: "A thoughtful title about epistemology",
      body: String.duplicate("meaningful word here ", 20),
      author_id: Ecto.UUID.generate(),
      content_hash: "abc123def456"
    }
  end

  # ── changeset ─────────────────────────────────────────────────────────────────

  describe "changeset/2" do
    test "valid attributes produce a valid changeset" do
      assert Spark.changeset(%Spark{}, valid_attrs()).valid?
    end

    test "title shorter than 5 chars is rejected" do
      cs = Spark.changeset(%Spark{}, Map.put(valid_attrs(), :title, "Hi"))
      refute cs.valid?
      assert :title in Map.keys(errors_on(cs))
    end

    test "title longer than 200 chars is rejected" do
      cs = Spark.changeset(%Spark{}, Map.put(valid_attrs(), :title, String.duplicate("a", 201)))
      refute cs.valid?
    end

    test "title exactly 5 chars is accepted" do
      cs = Spark.changeset(%Spark{}, Map.put(valid_attrs(), :title, "Hello"))
      assert cs.valid?
    end

    test "title exactly 200 chars is accepted" do
      cs = Spark.changeset(%Spark{}, Map.put(valid_attrs(), :title, String.duplicate("a", 200)))
      assert cs.valid?
    end

    test "body shorter than 10 chars is rejected" do
      cs = Spark.changeset(%Spark{}, Map.put(valid_attrs(), :body, "Short"))
      refute cs.valid?
    end

    test "body longer than 10_000 chars is rejected" do
      cs = Spark.changeset(%Spark{}, Map.put(valid_attrs(), :body, String.duplicate("x", 10_001)))
      refute cs.valid?
    end

    test "status outside draft/published is rejected" do
      cs = Spark.changeset(%Spark{}, Map.put(valid_attrs(), :status, "archived"))
      refute cs.valid?
    end

    test "status 'draft' is accepted" do
      cs = Spark.changeset(%Spark{}, Map.put(valid_attrs(), :status, "draft"))
      assert cs.valid?
    end

    test "status 'published' is accepted" do
      cs = Spark.changeset(%Spark{}, Map.put(valid_attrs(), :status, "published"))
      assert cs.valid?
    end

    test "author_id is required" do
      cs = Spark.changeset(%Spark{}, Map.delete(valid_attrs(), :author_id))
      refute cs.valid?
      assert :author_id in Map.keys(errors_on(cs))
    end

    test "content_hash is required" do
      cs = Spark.changeset(%Spark{}, Map.delete(valid_attrs(), :content_hash))
      refute cs.valid?
    end

    test "default status is draft" do
      assert %Spark{}.status == "draft"
    end
  end

  # ── publish_changeset ─────────────────────────────────────────────────────────

  describe "publish_changeset/1" do
    test "changes status to published" do
      spark = %Spark{status: "draft"}
      cs = Spark.publish_changeset(spark)
      assert get_change(cs, :status) == "published"
    end
  end

  # ── helpers ───────────────────────────────────────────────────────────────────

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
