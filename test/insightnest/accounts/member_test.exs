defmodule Insightnest.Accounts.MemberTest do
  use ExUnit.Case, async: true

  import Ecto.Changeset, only: [get_change: 2]

  alias Insightnest.Accounts.Member

  # ── wallet_changeset ──────────────────────────────────────────────────────────

  describe "wallet_changeset/2" do
    test "accepts a valid checksummed Ethereum address" do
      cs =
        Member.wallet_changeset(%Member{}, %{
          wallet_address: "0xf39Fd6e51aad88F6f4ce6aB8827279cffFb92266"
        })

      assert cs.valid?
    end

    test "normalizes address to lowercase" do
      cs =
        Member.wallet_changeset(%Member{}, %{
          wallet_address: "0xF39FD6E51AAD88F6F4CE6AB8827279CFFFB92266"
        })

      assert cs.valid?
      assert get_change(cs, :wallet_address) == "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"
    end

    test "rejects address without 0x prefix" do
      cs =
        Member.wallet_changeset(%Member{}, %{
          wallet_address: "f39fd6e51aad88f6f4ce6ab8827279cfffb92266"
        })

      refute cs.valid?
      assert "must be a valid Ethereum address" in errors_on(cs).wallet_address
    end

    test "rejects address that is only 38 hex chars" do
      cs = Member.wallet_changeset(%Member{}, %{wallet_address: "0xabcdef1234"})
      refute cs.valid?
    end

    test "rejects non-hex characters in address" do
      cs =
        Member.wallet_changeset(%Member{}, %{wallet_address: "0x" <> String.duplicate("g", 40)})

      refute cs.valid?
    end

    test "rejects missing wallet_address" do
      cs = Member.wallet_changeset(%Member{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).wallet_address
    end
  end

  # ── email_changeset ───────────────────────────────────────────────────────────

  describe "email_changeset/2" do
    test "accepts a valid email" do
      cs = Member.email_changeset(%Member{}, %{email: "user@example.com"})
      assert cs.valid?
    end

    test "rejects email without @ symbol" do
      cs = Member.email_changeset(%Member{}, %{email: "notanemail"})
      refute cs.valid?
      assert "must be a valid email address" in errors_on(cs).email
    end

    test "rejects email without domain extension" do
      cs = Member.email_changeset(%Member{}, %{email: "user@nodot"})
      refute cs.valid?
    end

    test "rejects blank email" do
      cs = Member.email_changeset(%Member{}, %{email: ""})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).email
    end

    test "rejects missing email key" do
      cs = Member.email_changeset(%Member{}, %{})
      refute cs.valid?
    end
  end

  # ── username_changeset ────────────────────────────────────────────────────────

  describe "username_changeset/2" do
    test "accepts a valid alphanumeric username" do
      cs = Member.username_changeset(%Member{}, %{username: "alice42"})
      assert cs.valid?
    end

    test "lowercases the stored username" do
      cs = Member.username_changeset(%Member{}, %{username: "Alice42"})
      assert cs.valid?
      assert get_change(cs, :username) == "alice42"
    end

    test "accepts underscores" do
      cs = Member.username_changeset(%Member{}, %{username: "alice_bob_42"})
      assert cs.valid?
    end

    test "rejects username shorter than 3 characters" do
      cs = Member.username_changeset(%Member{}, %{username: "ab"})
      refute cs.valid?
      assert :username in Map.keys(errors_on(cs))
    end

    test "rejects username longer than 20 characters" do
      cs = Member.username_changeset(%Member{}, %{username: String.duplicate("a", 21)})
      refute cs.valid?
    end

    test "accepts username exactly 20 characters" do
      cs = Member.username_changeset(%Member{}, %{username: String.duplicate("a", 20)})
      assert cs.valid?
    end

    test "rejects username with spaces" do
      cs = Member.username_changeset(%Member{}, %{username: "alice bob"})
      refute cs.valid?
      assert "can only contain letters, numbers, and underscores" in errors_on(cs).username
    end

    test "rejects username with @" do
      cs = Member.username_changeset(%Member{}, %{username: "alice@bob"})
      refute cs.valid?
    end

    test "rejects username with hyphen" do
      cs = Member.username_changeset(%Member{}, %{username: "alice-bob"})
      refute cs.valid?
    end

    test "rejects missing username" do
      cs = Member.username_changeset(%Member{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).username
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
