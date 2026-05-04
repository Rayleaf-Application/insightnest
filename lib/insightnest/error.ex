defmodule Insightnest.Error do
  @moduledoc """
  Standardised user-facing error messages.
  LiveViews call Error.message(reason) instead of
  pattern-matching on raw atoms in the view layer.
  """

  def message(%Ecto.Changeset{} = cs) do
    cs.errors
    |> Enum.map(fn {field, {msg, _}} ->
      "#{Phoenix.Naming.humanize(field)} #{msg}"
    end)
    |> Enum.join(", ")
  end

  def message(:not_eligible),                 do: "You are not eligible to perform this action."
  def message(:unauthorized),                 do: "You are not authorized to do this."
  def message(:not_found),                    do: "Not found."
  def message(:spark_closed),                 do: "This Spark is closed."
  def message(:spark_not_published),          do: "This Spark is not published."
  def message(:own_spark),                    do: "You cannot contribute to your own Spark."
  def message(:already_contributed),          do: "You have already contributed to this Spark."
  def message(:weave_in_progress),            do: "A Weave is already in progress for this Spark."
  def message(:no_highlighted_contributions), do: "No highlighted contributions to Weave. Highlight some first."
  def message(:already_published),            do: "This Insight has already been published."
  def message(:max_extensions_reached),       do: "Maximum extensions reached."
  def message(:address_mismatch),             do: "Signature address does not match."
  def message(:invalid_signature),            do: "Invalid signature."
  def message(:nonce_mismatch),               do: "Nonce mismatch — please try again."
  def message({:no_engagement, %{title: t}}) do
    "Your Spark \"#{t}\" hasn't received any contributions yet. " <>
    "Let your idea breathe before starting another."
  end
  def message({:no_engagement, _}), do: "Your previous Spark hasn't received contributions yet."
  def message(other),               do: "Something went wrong (#{inspect(other)})."
end
