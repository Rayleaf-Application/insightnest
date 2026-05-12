defmodule Insightnest.Logger.IpFilter do
  @moduledoc """
  OTP Logger filter that anonymises IP addresses in log messages before
  they reach any persistent sink.

  IPv4: masks the last octet          → 203.0.113.0
  IPv6: masks the last 80 bits (5 groups) → 2001:db8:85a3::0:0:0:0:0

  Install in config/prod.exs:
    config :logger, :default_handler,
      filters: [{Insightnest.Logger.IpFilter, :filter}]
  """

  @ipv4 ~r/\b(\d{1,3}\.\d{1,3}\.\d{1,3})\.\d{1,3}\b/
  @ipv6 ~r/\b([0-9a-fA-F]{0,4}(?::[0-9a-fA-F]{0,4}){2})(?::[0-9a-fA-F]{0,4}){5}\b/

  def filter(%{msg: {:string, msg}} = event, _extra) do
    %{event | msg: {:string, anonymise(msg)}}
  end

  def filter(%{msg: {format, args}} = event, _extra) when is_list(args) do
    sanitised = Enum.map(args, fn
      arg when is_binary(arg) -> anonymise(arg)
      arg -> arg
    end)
    %{event | msg: {format, sanitised}}
  end

  def filter(event, _extra), do: event

  defp anonymise(str) when is_binary(str) do
    str
    |> String.replace(@ipv4, "\\1.0")
    |> String.replace(@ipv6, "\\1:0:0:0:0:0")
  end
end
