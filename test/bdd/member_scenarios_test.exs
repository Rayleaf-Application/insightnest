defmodule Insightnest.BDD.MemberScenariosTest do
  use Insightnest.DataCase, async: true
  use Insightnest.BDDCase

  alias Insightnest.Accounts
  alias Insightnest.AccountsFixtures

  defp random_wallet do
    "0x" <> (:crypto.strong_rand_bytes(20) |> Base.encode16(case: :lower))
  end

  # ── New member ────────────────────────────────────────────────────────────────

  scenario "first-time wallet sign-in creates an account" do
    step "given a brand-new wallet, when find_or_create is called, a member is returned" do
      wallet = random_wallet()
      assert {:ok, member} = Accounts.find_or_create_by_wallet(wallet)
      assert member.wallet_address == wallet
      refute is_nil(member.id)
    end

    step "the new member has no username yet (not onboarded)" do
      wallet = random_wallet()
      {:ok, member} = Accounts.find_or_create_by_wallet(wallet)
      refute Accounts.onboarded?(member)
    end
  end

  scenario "returning member sign-in finds existing account" do
    setup do
      wallet = random_wallet()
      {:ok, member} = Accounts.find_or_create_by_wallet(wallet)
      {:ok, wallet: wallet, member: member}
    end

    step "given a known wallet, find_or_create returns the same member", %{wallet: w, member: m} do
      {:ok, found} = Accounts.find_or_create_by_wallet(w)
      assert found.id == m.id
    end

    step "lookup succeeds regardless of address capitalisation", %{wallet: w, member: m} do
      {:ok, found} = Accounts.find_or_create_by_wallet(String.upcase(w))
      assert found.id == m.id
    end
  end

  # ── Onboarding ────────────────────────────────────────────────────────────────

  scenario "member chooses a username during onboarding" do
    setup do
      {:ok, member: AccountsFixtures.member()}
    end

    step "given a valid username, set_username succeeds", %{member: m} do
      username = "thinker_#{System.unique_integer([:positive])}"
      assert {:ok, updated} = Accounts.set_username(m, username)
      assert updated.username == String.downcase(username)
    end

    step "after setting username, member is considered onboarded", %{member: m} do
      username = "builder_#{System.unique_integer([:positive])}"
      {:ok, updated} = Accounts.set_username(m, username)
      assert Accounts.onboarded?(updated)
    end
  end

  scenario "username uniqueness is enforced at onboarding" do
    setup do
      existing = AccountsFixtures.onboarded_member()
      newcomer = AccountsFixtures.member()
      {:ok, existing: existing, newcomer: newcomer}
    end

    step "setting a taken username returns an error changeset", %{existing: e, newcomer: n} do
      assert {:error, changeset} = Accounts.set_username(n, e.username)
      refute changeset.valid?
      assert "is already taken" in errors_on(changeset).username
    end

    step "username_taken? reports true for the existing username", %{existing: e} do
      assert Accounts.username_taken?(e.username)
    end

    step "username_taken? is case-insensitive", %{existing: e} do
      assert Accounts.username_taken?(String.upcase(e.username))
    end
  end
end
