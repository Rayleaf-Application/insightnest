defmodule Insightnest.Auth.SiweTest do
  use ExUnit.Case, async: true

  alias Insightnest.Auth.Siwe

  # Known test vector — Hardhat account #0
  @private_key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
  @address     "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  @valid_message """
  localhost wants you to sign in with your Ethereum account:
  #{@address}

  Sign in to InsightNest

  URI: http://localhost:4000
  Version: 1
  Chain ID: 1
  Nonce: abc123def456
  Issued At: 2026-01-01T00:00:00.000Z
  """ |> String.trim()

  test "parse/1 extracts address and nonce" do
    assert {:ok, msg} = Siwe.parse(@valid_message)
    assert msg.address == String.downcase(@address)
    assert msg.nonce == "abc123def456"
    assert msg.chain_id == 1
  end

  test "parse/1 rejects malformed message" do
    assert {:error, _} = Siwe.parse("not a siwe message")
  end

  # Sign the message with the known private key to get a test signature,
  # then verify round-trip. In CI this uses a lightweight signing helper.
  # For now, test parse only — full verify tested via integration test.
end
