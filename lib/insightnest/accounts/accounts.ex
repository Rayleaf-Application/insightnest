defmodule Insightnest.Accounts do
  @moduledoc """
  Accounts context. Handles member lookup and creation.
  Auth verification logic lives in AuthController — this context
  only deals with persistence.
  """

  import Ecto.Query

  alias Insightnest.Repo
  alias Insightnest.Accounts.Member

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

  @doc "Returns true if the username is already taken (case-insensitive)."
  def username_taken?(username) do
    Repo.exists?(
      from m in Member,
        where: fragment("lower(?)", m.username) == ^String.downcase(username)
    )
  end

  @doc "Sets the username for a member. Returns {:ok, member} or {:error, changeset}."
  def set_username(%Member{} = member, username) do
    member
    |> Member.username_changeset(%{username: username})
    |> Repo.update()
  end

  @doc "Finds or creates a member by email."
  def find_or_create_by_email(email) do
    email = String.downcase(String.trim(email))

    case Repo.get_by(Member, email: email) do
      %Member{} = member -> {:ok, member}
      nil ->
        %Member{}
        |> Member.email_changeset(%{email: email})
        |> Repo.insert()
    end
  end

  @doc "Marks the member's email as verified."
  def verify_email(%Member{} = member) do
    member
    |> Ecto.Changeset.change(email_verified: true)
    |> Repo.update()
  end

  @doc "Generates a 6-digit passcode string."
  def generate_passcode do
    :rand.uniform(999_999)
    |> Integer.to_string()
    |> String.pad_leading(6, "0")
  end

  @doc "Returns true if the member has completed onboarding (has a username)."
  def onboarded?(%Member{username: nil}), do: false
  def onboarded?(%Member{username: ""}),  do: false
  def onboarded?(%Member{}),              do: true
  def onboarded?(nil),                    do: false
end
