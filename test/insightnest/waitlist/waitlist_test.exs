defmodule Insightnest.WaitlistTest do
  use Insightnest.DataCase, async: true

  alias Insightnest.Waitlist

  defp unique_email, do: "user_#{System.unique_integer()}@example.com"

  # ── create/1 ─────────────────────────────────────────────────────────────────

  describe "create/1" do
    test "creates an entry with valid attrs" do
      assert {:ok, entry} = Waitlist.create(%{email: unique_email(), name: "Alice"})
      assert entry.id != nil
      assert entry.status == "pending"
    end

    test "requires an email address" do
      assert {:error, cs} = Waitlist.create(%{name: "No Email"})
      assert %{email: [_ | _]} = errors_on(cs)
    end

    test "rejects an invalid email format" do
      assert {:error, cs} = Waitlist.create(%{email: "not-an-email"})
      assert %{email: [_ | _]} = errors_on(cs)
    end

    test "rejects a duplicate email" do
      email = unique_email()
      {:ok, _} = Waitlist.create(%{email: email})
      assert {:error, cs} = Waitlist.create(%{email: email})
      assert %{email: [_ | _]} = errors_on(cs)
    end

    test "persists optional fields when provided" do
      assert {:ok, entry} =
               Waitlist.create(%{
                 email: unique_email(),
                 name: "Bob",
                 reason: "I want to learn."
               })

      assert entry.name == "Bob"
      assert entry.reason == "I want to learn."
    end
  end

  # ── list/0 ────────────────────────────────────────────────────────────────────

  describe "list/0" do
    test "returns all waitlist entries" do
      {:ok, e1} = Waitlist.create(%{email: unique_email()})
      {:ok, e2} = Waitlist.create(%{email: unique_email()})
      ids = Enum.map(Waitlist.list(), & &1.id)
      assert e1.id in ids
      assert e2.id in ids
    end

    test "returns entries ordered newest first" do
      {:ok, first} = Waitlist.create(%{email: unique_email()})
      {:ok, second} = Waitlist.create(%{email: unique_email()})
      entries = Waitlist.list()
      ids = Enum.map(entries, & &1.id)

      assert Enum.find_index(ids, &(&1 == second.id)) <
               Enum.find_index(ids, &(&1 == first.id))
    end
  end

  # ── get!/1 ────────────────────────────────────────────────────────────────────

  describe "get!/1" do
    test "returns the entry by id" do
      {:ok, entry} = Waitlist.create(%{email: unique_email()})
      fetched = Waitlist.get!(entry.id)
      assert fetched.id == entry.id
    end

    test "raises Ecto.NoResultsError for an unknown id" do
      assert_raise Ecto.NoResultsError, fn ->
        Waitlist.get!(Ecto.UUID.generate())
      end
    end
  end

  # ── update_status/2 ───────────────────────────────────────────────────────────

  describe "update_status/2" do
    test "transitions a pending entry to approved" do
      {:ok, entry} = Waitlist.create(%{email: unique_email()})
      assert {:ok, updated} = Waitlist.update_status(entry.id, "approved")
      assert updated.status == "approved"
    end

    test "transitions a pending entry to rejected" do
      {:ok, entry} = Waitlist.create(%{email: unique_email()})
      assert {:ok, updated} = Waitlist.update_status(entry.id, "rejected")
      assert updated.status == "rejected"
    end

    test "rejects an invalid status value" do
      {:ok, entry} = Waitlist.create(%{email: unique_email()})
      assert {:error, cs} = Waitlist.update_status(entry.id, "banned")
      assert %{status: [_ | _]} = errors_on(cs)
    end
  end

  # ── delete/1 ─────────────────────────────────────────────────────────────────

  describe "delete/1" do
    test "removes the entry from the database" do
      {:ok, entry} = Waitlist.create(%{email: unique_email()})
      assert {:ok, _} = Waitlist.delete(entry.id)

      assert_raise Ecto.NoResultsError, fn ->
        Waitlist.get!(entry.id)
      end
    end
  end

  # ── approved?/1 ──────────────────────────────────────────────────────────────

  describe "approved?/1" do
    test "returns true for an approved email" do
      email = unique_email()
      {:ok, entry} = Waitlist.create(%{email: email})
      {:ok, _} = Waitlist.update_status(entry.id, "approved")
      assert Waitlist.approved?(email)
    end

    test "returns false for a pending email" do
      email = unique_email()
      {:ok, _} = Waitlist.create(%{email: email})
      refute Waitlist.approved?(email)
    end

    test "returns false for a rejected email" do
      email = unique_email()
      {:ok, entry} = Waitlist.create(%{email: email})
      {:ok, _} = Waitlist.update_status(entry.id, "rejected")
      refute Waitlist.approved?(email)
    end

    test "returns false for an email not on the waitlist" do
      refute Waitlist.approved?("notregistered@example.com")
    end

    test "normalises email before lookup (uppercase + whitespace)" do
      email = unique_email()
      {:ok, entry} = Waitlist.create(%{email: email})
      {:ok, _} = Waitlist.update_status(entry.id, "approved")

      assert Waitlist.approved?(String.upcase("  #{email}  "))
    end
  end
end
