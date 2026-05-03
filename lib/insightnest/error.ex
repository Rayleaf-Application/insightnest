defmodule Insightnest.Error do
  @moduledoc """
  Standardised error types for InsightNest contexts.

  All context functions return tagged tuples:
    {:ok, result}
    {:error, %Insightnest.Error{}}
    {:error, atom}              ← simple domain errors
    {:error, Ecto.Changeset{}}  ← validation errors

  LiveViews pattern-match on these and surface
  user-facing messages via error_message/1.
  """

  defstruct [:code, :message, :details]

  @type t :: %__MODULE__{
    code:    atom(),
    message: String.t(),
    details: map() | nil
  }

  @doc "Creates a standardised error struct."
  def new(code, message, details \\ nil) do
    %__MODULE__{code: code, message: message, details: details}
  end

  @doc """
  Returns a user-facing error message for any error shape
  returned by context functions.
  """
  def message(%__MODULE__{message: msg}), do: msg
  def message(%Ecto.Changeset{} = cs) do
    cs.errors
    |> Enum.map(fn {field, {msg, _}} -> "#{field} #{msg}" end)
    |> Enum.join(", ")
  end
  def message(:not_eligible),                do: "You are not eligible to perform this action."
  def message(:unauthorized),                do: "You are not authorized to do this."
  def message(:not_found),                   do: "Not found."
  def message(:spark_closed),                do: "This Spark is closed."
  def message(:spark_not_published),         do: "This Spark is not published."
  def message(:own_spark),                   do: "You cannot contribute to your own Spark."
  def message(:already_contributed),         do: "You have already contributed to this Spark."
  def message(:weave_in_progress),           do: "A Weave is already in progress for this Spark."
  def message(:no_highlighted_contributions), do: "No highlighted contributions to Weave."
  def message(:already_published),           do: "This Insight has already been published."
  def message(:max_extensions_reached),      do: "Maximum extensions reached."
  def message({:no_engagement, spark}) when not is_nil(spark) do
    "Your Spark \"#{spark.title}\" hasn't received any contributions yet. " <>
    "Let your idea breathe before starting another."
  end
  def message({:no_engagement, _}),         do: "Your previous Spark hasn't received contributions yet."
  def message(other),                        do: "Something went wrong: #{inspect(other)}"
end
