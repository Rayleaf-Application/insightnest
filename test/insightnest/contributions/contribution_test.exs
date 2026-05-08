defmodule Insightnest.Contributions.ContributionTest do
  use ExUnit.Case, async: true

  alias Insightnest.Contributions.Contribution

  @spark_id  Ecto.UUID.generate()
  @author_id Ecto.UUID.generate()

  defp valid_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        body:      String.duplicate("insightful analysis here ", 60),
        stance:    "expands",
        spark_id:  @spark_id,
        author_id: @author_id
      },
      overrides
    )
  end

  # ── changeset/2 ───────────────────────────────────────────────────────────────

  describe "changeset/2" do
    test "valid attributes produce a valid changeset" do
      assert Contribution.changeset(%Contribution{}, valid_attrs()).valid?
    end

    test "body is required" do
      cs = Contribution.changeset(%Contribution{}, Map.delete(valid_attrs(), :body))
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).body
    end

    test "spark_id is required" do
      cs = Contribution.changeset(%Contribution{}, Map.delete(valid_attrs(), :spark_id))
      refute cs.valid?
    end

    test "author_id is required" do
      cs = Contribution.changeset(%Contribution{}, Map.delete(valid_attrs(), :author_id))
      refute cs.valid?
    end

    test "body shorter than 10 chars is rejected" do
      cs = Contribution.changeset(%Contribution{}, valid_attrs(%{body: "Too short"}))
      refute cs.valid?
      assert :body in Map.keys(errors_on(cs))
    end

    test "body longer than 5_000 chars is rejected" do
      cs = Contribution.changeset(%Contribution{}, valid_attrs(%{body: String.duplicate("x", 5_001)}))
      refute cs.valid?
    end

    test "body with fewer than 50 words is rejected" do
      cs = Contribution.changeset(%Contribution{}, valid_attrs(%{body: String.duplicate("word ", 49)}))
      refute cs.valid?
      assert Enum.any?(errors_on(cs).body || [], &String.starts_with?(&1, "must be at least 50 words"))
    end

    test "body with exactly 50 words is accepted" do
      cs = Contribution.changeset(%Contribution{}, valid_attrs(%{body: String.duplicate("word ", 50)}))
      assert cs.valid?
    end

    test "valid stance 'expands' is accepted" do
      cs = Contribution.changeset(%Contribution{}, valid_attrs(%{stance: "expands"}))
      assert cs.valid?
    end

    test "valid stance 'challenges' is accepted" do
      cs = Contribution.changeset(%Contribution{}, valid_attrs(%{stance: "challenges"}))
      assert cs.valid?
    end

    test "valid stance 'evidence' is accepted" do
      cs = Contribution.changeset(%Contribution{}, valid_attrs(%{stance: "evidence"}))
      assert cs.valid?
    end

    test "valid stance 'question' is accepted" do
      cs = Contribution.changeset(%Contribution{}, valid_attrs(%{stance: "question"}))
      assert cs.valid?
    end

    test "invalid stance is rejected" do
      cs = Contribution.changeset(%Contribution{}, valid_attrs(%{stance: "agree"}))
      refute cs.valid?
      assert "must be one of: expands, challenges, evidence, question" in errors_on(cs).stance
    end

    test "nil stance is allowed (stance is optional)" do
      cs = Contribution.changeset(%Contribution{}, valid_attrs(%{stance: nil}))
      assert cs.valid?
    end
  end

  describe "valid_stances/0" do
    test "returns the four allowed stance values" do
      assert Contribution.valid_stances() == ~w(expands challenges evidence question)
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
