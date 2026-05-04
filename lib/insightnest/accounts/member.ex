defmodule Insightnest.Accounts.Member do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "members" do
    field :wallet_address,  :string
    field :email,           :string
    field :username,        :string
    field :email_verified,  :boolean, default: false  # ← add this

    timestamps(type: :utc_datetime)
  end

  @doc "Changeset for wallet-based member creation."
  def wallet_changeset(member, attrs) do
    member
    |> cast(attrs, [:wallet_address, :username])
    |> validate_required([:wallet_address])
    |> validate_format(:wallet_address, ~r/^0x[0-9a-fA-F]{40}$/,
      message: "must be a valid Ethereum address"
    )
    |> update_change(:wallet_address, &normalize_address/1)
    |> unique_constraint(:wallet_address)
  end

  @doc "Changeset for email-based member creation (Phase 0 stub)."
  def email_changeset(member, attrs) do
    member
    |> cast(attrs, [:email, :username])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/,
      message: "must be a valid email address"
    )
    |> unique_constraint(:email)
  end

  @doc "Changeset for setting/updating a username."
  def username_changeset(member, attrs) do
    member
    |> cast(attrs, [:username])
    |> validate_required([:username])
    |> validate_length(:username, min: 3, max: 20)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/,
        message: "can only contain letters, numbers, and underscores"
      )
    |> update_change(:username, &String.downcase/1)
    |> unique_constraint(:username, message: "is already taken")
  end

  # Normalize to EIP-55 checksum format via downcase first, then let
  # the SIWE library handle checksum validation upstream.
  defp normalize_address(address) do
    String.downcase(address)
  end
end
