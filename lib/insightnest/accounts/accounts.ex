defmodule Insightnest.Accounts do
  @moduledoc """
  Accounts context. Handles member lookup and creation.
  Auth verification logic lives in AuthController — this context
  only deals with persistence.
  """

  import Ecto.Query

  alias Insightnest.Accounts.Member
  alias Insightnest.Accounts.MemberDeletionLog
  alias Insightnest.Contributions.Contribution
  alias Insightnest.Repo
  alias Insightnest.Sparks.Spark

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

  @doc "Returns all members ordered by join date."
  def list_members do
    Repo.all(from m in Member, order_by: [asc: m.inserted_at])
  end

  @doc "Grants the founder badge to a member."
  def grant_founder_badge(%Member{} = member) do
    member
    |> Member.founder_changeset(%{founder: true})
    |> Repo.update()
  end

  @doc "Revokes the founder badge from a member."
  def revoke_founder_badge(%Member{} = member) do
    member
    |> Member.founder_changeset(%{founder: false})
    |> Repo.update()
  end

  @doc "Returns all members whose IDs are in the given list."
  def list_by_ids(ids) do
    Repo.all(from m in Member, where: m.id in ^ids)
  end

  @doc "Returns a member by wallet address, or nil."
  def get_member_by_wallet(address) do
    Repo.get_by(Member, wallet_address: String.downcase(address))
  end

  @doc "Returns true if the username is already taken (case-insensitive)."
  def username_taken?(username) do
    Repo.exists?(
      from m in Member,
        where: m.username == ^String.downcase(username)
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
      %Member{} = member ->
        {:ok, member}

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

  @doc "Returns a member by email, or nil."
  def get_member_by_email(email) do
    Repo.get_by(Member, email: String.downcase(String.trim(email)))
  end

  @doc "Generates a cryptographically secure 6-digit passcode string."
  def generate_passcode do
    <<n::32>> = :crypto.strong_rand_bytes(4)
    rem(n, 1_000_000)
    |> Integer.to_string()
    |> String.pad_leading(6, "0")
  end

  @doc "Returns true if the member has completed onboarding (has a username)."
  def onboarded?(%Member{username: nil}), do: false
  def onboarded?(%Member{username: ""}), do: false
  def onboarded?(%Member{}), do: true
  def onboarded?(nil), do: false

  @doc """
  GDPR Article 17 — Right to erasure.

  Deletes the member record and cascades to all platform-held PII
  (sparks, contributions, highlight votes, weaves). Stores an abuse-prevention
  log containing only the timestamp and a one-way hash of the wallet address —
  never the address itself.

  Phase 0 note: contributions and insights are PostgreSQL-only and are
  cascade-deleted. From Phase 2 (Codex) and Phase 3 (on-chain), artifacts
  attributed to the wallet address will remain immutable in the Codex/chain;
  the platform-side re-identification path is severed by this deletion.
  """
  def delete_member(%Member{} = member) do
    # Write the abuse-prevention log first, independently of the delete.
    # If the log table doesn't exist yet (migration pending), this silently
    # fails — deletion still proceeds so the user is not blocked.
    wallet_hash =
      if member.wallet_address do
        :crypto.hash(:sha256, member.wallet_address) |> Base.encode16(case: :lower)
      end

    _ =
      Repo.insert(%MemberDeletionLog{
        wallet_hash: wallet_hash,
        deleted_at: DateTime.utc_now(:second)
      })

    # Delete the member; DB ON DELETE CASCADE handles all related rows.
    case Repo.delete(member) do
      {:ok, _} -> {:ok, :ok}
      {:error, cs} -> {:error, cs}
    end
  end

  @doc """
  GDPR Articles 15 + 20 — Right of access and data portability.

  Returns a map containing all platform-held data for the member,
  suitable for JSON serialisation and delivery to the data subject.
  """
  def export_member_data(%Member{} = member) do
    sparks =
      Repo.all(from s in Spark, where: s.author_id == ^member.id, order_by: [asc: s.inserted_at])

    contributions =
      Repo.all(
        from c in Contribution,
          where: c.author_id == ^member.id,
          order_by: [asc: c.inserted_at]
      )

    %{
      exported_at: DateTime.utc_now(:second),
      member: %{
        id: member.id,
        username: member.username,
        wallet_address: member.wallet_address,
        email: member.email,
        email_verified: member.email_verified,
        joined_at: member.inserted_at
      },
      sparks:
        Enum.map(sparks, fn s ->
          %{
            id: s.id,
            title: s.title,
            body: s.body,
            status: s.status,
            created_at: s.inserted_at
          }
        end),
      contributions:
        Enum.map(contributions, fn c ->
          %{
            id: c.id,
            spark_id: c.spark_id,
            body: c.body,
            stance: c.stance,
            created_at: c.inserted_at
          }
        end)
    }
  end
end
