defmodule InsightNest.Auth.Guardian do
  use Guardian, otp_app: :insightnest

  alias InsightNest.Accounts

  @doc """
  The subject embedded in the JWT token.
  We use the member's UUID as a string.
  """
  def subject_for_token(%{id: id}, _claims) do
    {:ok, to_string(id)}
  end

  def subject_for_token(_, _), do: {:error, :unknown_resource_type}

  @doc """
  Reverse lookup: given claims extracted from a JWT, return the member.
  Called by Guardian on every authenticated request.
  """
  def resource_from_claims(%{"sub" => id}) do
    case Accounts.get_member(id) do
      nil -> {:error, :resource_not_found}
      member -> {:ok, member}
    end
  end

  def resource_from_claims(_), do: {:error, :missing_sub_claim}
end
