defmodule Insightnest.AccountsFixtures do
  alias Insightnest.Accounts
  alias Insightnest.Repo
  alias Insightnest.Accounts.Member

  def member(attrs \\ %{}) do
    wallet = attrs[:wallet_address] || unique_wallet()
    {:ok, member} = Accounts.find_or_create_by_wallet(wallet)
    member
  end

  def onboarded_member(attrs \\ %{}) do
    m = member(attrs)
    {:ok, m} = Accounts.set_username(m, unique_username())
    m
  end

  defp unique_wallet do
    "0x" <> (:crypto.strong_rand_bytes(20) |> Base.encode16(case: :lower))
  end

  defp unique_username do
    "user_" <> (:crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower))
  end
end
