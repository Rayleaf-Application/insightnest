defmodule InsightNest.Accounts do
  @moduledoc """
  Accounts context. Handles member lookup and creation.
  Auth verification logic lives in AuthController — this context
  only deals with persistence.
  """

  import Ecto.Query
  alias InsightNest.Repo
  alias InsightNest.Accounts.Member

  @doc """
  Returns the member with the given wallet address,
  creating one if they don't exist yet.
  Wallet address is normalized to lowercase before lookup/insert.
  """
  def find_or_create_by_wallet(wallet_address) do
    address = String.downcase(wallet_address)

    case Repo.get_by(Member, wallet_address: address) do
      %Member{} = member ->
        {:ok, member}

      nil ->
        %Member{}
        |> Member.wallet_changeset(%{wallet_address: address})
        |> Repo.insert()
    end
  end

  @doc "Returns a member by ID, or nil."
  def get_member(id) do
    Repo.get(Member, id)
  end

  @doc "Returns a member by ID, raises if not found."
  def get_member!(id) do
    Repo.get!(Member, id)
  end

  @doc "Returns a member by wallet address, or nil."
  def get_member_by_wallet(address) do
    Repo.get_by(Member, wallet_address: String.downcase(address))
  end
end
