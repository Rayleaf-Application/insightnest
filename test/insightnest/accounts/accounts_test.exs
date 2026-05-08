defmodule Insightnest.AccountsTest do
  use Insightnest.DataCase, async: true

  alias Insightnest.Accounts
  alias Insightnest.AccountsFixtures

  # ── find_or_create_by_wallet ──────────────────────────────────────────────────

  describe "find_or_create_by_wallet/1" do
    test "creates a new member for an unknown wallet" do
      wallet = random_wallet()
      assert {:ok, member} = Accounts.find_or_create_by_wallet(wallet)
      assert member.wallet_address == wallet
      refute is_nil(member.id)
    end

    test "is idempotent — returns same member on repeated calls" do
      wallet = random_wallet()
      {:ok, first}  = Accounts.find_or_create_by_wallet(wallet)
      {:ok, second} = Accounts.find_or_create_by_wallet(wallet)
      assert first.id == second.id
    end

    test "normalizes wallet address to lowercase before storage" do
      wallet_lower = random_wallet()
      wallet_upper = String.upcase(wallet_lower)
      {:ok, m1} = Accounts.find_or_create_by_wallet(wallet_lower)
      {:ok, m2} = Accounts.find_or_create_by_wallet(wallet_upper)
      assert m1.id == m2.id
      assert m2.wallet_address == wallet_lower
    end
  end

  # ── get_member / get_member! ──────────────────────────────────────────────────

  describe "get_member/1" do
    test "returns nil for an unknown id" do
      assert Accounts.get_member(Ecto.UUID.generate()) == nil
    end

    test "returns the member for a known id" do
      member = AccountsFixtures.member()
      assert Accounts.get_member(member.id).id == member.id
    end
  end

  describe "get_member!/1" do
    test "raises Ecto.NoResultsError for an unknown id" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_member!(Ecto.UUID.generate())
      end
    end

    test "returns the member for a known id" do
      member = AccountsFixtures.member()
      assert Accounts.get_member!(member.id).id == member.id
    end
  end

  # ── get_member_by_wallet ──────────────────────────────────────────────────────

  describe "get_member_by_wallet/1" do
    test "returns nil when no member has that wallet" do
      assert Accounts.get_member_by_wallet(random_wallet()) == nil
    end

    test "returns the member for a known wallet" do
      member = AccountsFixtures.member()
      found  = Accounts.get_member_by_wallet(member.wallet_address)
      assert found.id == member.id
    end

    test "is case-insensitive" do
      member = AccountsFixtures.member()
      found  = Accounts.get_member_by_wallet(String.upcase(member.wallet_address))
      assert found.id == member.id
    end
  end

  # ── username_taken? ───────────────────────────────────────────────────────────

  describe "username_taken?/1" do
    test "returns false for an unused username" do
      refute Accounts.username_taken?("definitely_not_taken_#{System.unique_integer([:positive])}")
    end

    test "returns true for a taken username" do
      member = AccountsFixtures.onboarded_member()
      assert Accounts.username_taken?(member.username)
    end

    test "is case-insensitive — uppercased taken username returns true" do
      member = AccountsFixtures.onboarded_member()
      assert Accounts.username_taken?(String.upcase(member.username))
    end
  end

  # ── set_username ──────────────────────────────────────────────────────────────

  describe "set_username/2" do
    test "stores a valid username lowercased" do
      member   = AccountsFixtures.member()
      username = "User_#{System.unique_integer([:positive])}"
      assert {:ok, updated} = Accounts.set_username(member, username)
      assert updated.username == String.downcase(username)
    end

    test "returns an error changeset for a too-short username" do
      member = AccountsFixtures.member()
      assert {:error, changeset} = Accounts.set_username(member, "ab")
      refute changeset.valid?
    end

    test "returns an error changeset for a duplicate username" do
      existing = AccountsFixtures.onboarded_member()
      member   = AccountsFixtures.member()
      assert {:error, changeset} = Accounts.set_username(member, existing.username)
      assert "is already taken" in errors_on(changeset).username
    end
  end

  # ── find_or_create_by_email ───────────────────────────────────────────────────

  describe "find_or_create_by_email/1" do
    test "creates a new member for a new email" do
      email = "new_#{System.unique_integer([:positive])}@example.com"
      assert {:ok, member} = Accounts.find_or_create_by_email(email)
      assert member.email == email
    end

    test "is idempotent — returns same member on repeated calls" do
      email = "repeat_#{System.unique_integer([:positive])}@example.com"
      {:ok, first}  = Accounts.find_or_create_by_email(email)
      {:ok, second} = Accounts.find_or_create_by_email(email)
      assert first.id == second.id
    end

    test "normalizes email to lowercase" do
      {:ok, member} = Accounts.find_or_create_by_email("Test#{System.unique_integer([:positive])}@EXAMPLE.COM")
      assert member.email == String.downcase(member.email)
    end
  end

  # ── generate_passcode ─────────────────────────────────────────────────────────

  describe "generate_passcode/0" do
    test "returns a 6-character string" do
      assert String.length(Accounts.generate_passcode()) == 6
    end

    test "contains only digits" do
      assert Accounts.generate_passcode() =~ ~r/^\d{6}$/
    end

    test "is not always the same value" do
      codes = for _ <- 1..10, do: Accounts.generate_passcode()
      assert Enum.uniq(codes) |> length() > 1
    end
  end

  # ── onboarded? ────────────────────────────────────────────────────────────────

  describe "onboarded?/1" do
    test "returns false when member has no username" do
      refute Accounts.onboarded?(AccountsFixtures.member())
    end

    test "returns true when member has a username" do
      assert Accounts.onboarded?(AccountsFixtures.onboarded_member())
    end

    test "returns false for nil" do
      refute Accounts.onboarded?(nil)
    end
  end

  # ── helpers ───────────────────────────────────────────────────────────────────

  defp random_wallet do
    "0x" <> (:crypto.strong_rand_bytes(20) |> Base.encode16(case: :lower))
  end
end
