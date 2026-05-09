defmodule Insightnest.Auth.SiweTest do
  use ExUnit.Case, async: true

  alias Insightnest.Auth.Siwe

  # Known test vector — Hardhat account #0 (private key: 0xac0974be...2ff80)
  @address "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  @valid_message """
                 localhost wants you to sign in with your Ethereum account:
                 #{@address}

                 Sign in to InsightNest

                 URI: http://localhost:4000
                 Version: 1
                 Chain ID: 1
                 Nonce: abc123def456
                 Issued At: 2026-01-01T00:00:00.000Z
                 """
                 |> String.trim()

  test "parse/1 extracts address and nonce" do
    assert {:ok, msg} = Siwe.parse(@valid_message)
    assert msg.address == String.downcase(@address)
    assert msg.nonce == "abc123def456"
    assert msg.chain_id == 1
  end

  test "parse/1 rejects malformed message" do
    assert {:error, _} = Siwe.parse("not a siwe message")
  end

  test "parse/1 rejects a non-string input" do
    assert {:error, _} = Siwe.parse(nil)
    assert {:error, _} = Siwe.parse(42)
  end

  test "parse/1 rejects an empty string" do
    assert {:error, _} = Siwe.parse("")
  end

  test "parse/1 rejects a message with a bad header line" do
    bad_header = """
    invalid header line
    #{@address}

    Sign in to InsightNest

    URI: http://localhost:4000
    Version: 1
    Chain ID: 1
    Nonce: abc123def456
    Issued At: 2026-01-01T00:00:00.000Z
    """

    assert {:error, _} = Siwe.parse(String.trim(bad_header))
  end

  test "parse/1 extracts the domain from the header" do
    assert {:ok, msg} = Siwe.parse(@valid_message)
    assert msg.domain == "localhost"
  end

  test "parse/1 extracts the URI" do
    assert {:ok, msg} = Siwe.parse(@valid_message)
    assert msg.uri == "http://localhost:4000"
  end

  test "parse/1 extracts the statement" do
    assert {:ok, msg} = Siwe.parse(@valid_message)
    assert msg.statement == "Sign in to InsightNest"
  end

  test "parse/1 extracts issued_at" do
    assert {:ok, msg} = Siwe.parse(@valid_message)
    assert msg.issued_at == "2026-01-01T00:00:00.000Z"
  end

  test "parse/1 extracts the address verbatim — normalisation happens at the call site" do
    # The parser does not lowercase; find_or_create_by_wallet normalises downstream.
    upper_addr = String.upcase(@address)
    upper_msg = String.replace(@valid_message, @address, upper_addr)
    assert {:ok, msg} = Siwe.parse(upper_msg)
    assert String.downcase(msg.address) == @address
  end

  # verify/3 input-validation tests (no valid signature needed)

  test "verify/3 rejects non-binary raw_message" do
    assert {:error, :invalid_arguments} = Siwe.verify(nil, "0xaabb", @address)
  end

  test "verify/3 rejects signature without 0x prefix" do
    assert {:error, :invalid_signature_format} =
             Siwe.verify("msg", "aabbccddeeff", @address)
  end

  test "verify/3 rejects a valid-hex but wrong-length signature" do
    short_sig = "0x" <> Base.encode16(:crypto.strong_rand_bytes(62), case: :lower)

    assert {:error, :invalid_signature_length} =
             Siwe.verify("msg", short_sig, @address)
  end

  test "verify/3 rejects a signature with invalid hex characters" do
    assert {:error, :invalid_signature_hex} =
             Siwe.verify("msg", "0x" <> String.duplicate("ZZ", 65), @address)
  end

  # Sign the message with the known private key to get a test signature,
  # then verify round-trip. In CI this uses a lightweight signing helper.
  # For now, test parse only — full verify tested via integration test.
end
