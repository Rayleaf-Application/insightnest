defmodule Insightnest.BDD.AuthScenariosTest do
  use ExUnit.Case, async: true
  use Insightnest.BDDCase

  alias Insightnest.Auth.Siwe

  @address "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  defp valid_siwe_message(nonce \\ "abc123def456") do
    """
    localhost wants you to sign in with your Ethereum account:
    #{@address}

    Sign in to InsightNest

    URI: http://localhost:4000
    Version: 1
    Chain ID: 1
    Nonce: #{nonce}
    Issued At: 2026-01-01T00:00:00.000Z
    """
    |> String.trim()
  end

  # ── Parsing ───────────────────────────────────────────────────────────────────

  scenario "parsing a well-formed SIWE message" do
    step "extracts the wallet address from the message" do
      {:ok, msg} = Siwe.parse(valid_siwe_message())
      # Parser preserves case; normalisation happens at find_or_create_by_wallet.
      assert String.downcase(msg.address) == @address
    end

    step "extracts the nonce" do
      {:ok, msg} = Siwe.parse(valid_siwe_message("xyz987"))
      assert msg.nonce == "xyz987"
    end

    step "extracts the domain" do
      {:ok, msg} = Siwe.parse(valid_siwe_message())
      assert msg.domain == "localhost"
    end

    step "extracts the chain ID as an integer" do
      {:ok, msg} = Siwe.parse(valid_siwe_message())
      assert msg.chain_id == 1
    end

    step "extracts the URI" do
      {:ok, msg} = Siwe.parse(valid_siwe_message())
      assert msg.uri == "http://localhost:4000"
    end

    step "extracts the statement" do
      {:ok, msg} = Siwe.parse(valid_siwe_message())
      assert msg.statement == "Sign in to InsightNest"
    end

    step "extracts the issued_at timestamp" do
      {:ok, msg} = Siwe.parse(valid_siwe_message())
      assert msg.issued_at == "2026-01-01T00:00:00.000Z"
    end

    step "returns the correct struct type" do
      {:ok, msg} = Siwe.parse(valid_siwe_message())
      assert %Siwe{} = msg
    end
  end

  scenario "parsing a malformed SIWE message" do
    step "rejects plain text" do
      assert {:error, _} = Siwe.parse("not a siwe message at all")
    end

    step "rejects an empty string" do
      assert {:error, _} = Siwe.parse("")
    end

    step "rejects a non-binary input" do
      assert {:error, _} = Siwe.parse(nil)
      assert {:error, _} = Siwe.parse(12_345)
    end

    step "rejects a message with an invalid header line" do
      bad = "bad header\n#{@address}\n\nSign in\n\nNonce: abc\n"
      assert {:error, _} = Siwe.parse(bad)
    end
  end

  # ── Verification ─────────────────────────────────────────────────────────────

  scenario "signature verification with invalid inputs" do
    step "rejects non-binary raw_message" do
      assert {:error, :invalid_arguments} = Siwe.verify(nil, "0xaabb", @address)
    end

    step "rejects non-binary signature" do
      assert {:error, :invalid_arguments} = Siwe.verify("msg", nil, @address)
    end

    step "rejects a signature without 0x prefix" do
      assert {:error, :invalid_signature_format} =
               Siwe.verify("msg", "aabbcc", @address)
    end

    step "rejects a signature with non-hex characters" do
      assert {:error, :invalid_signature_hex} =
               Siwe.verify("msg", "0xZZZZZZ", @address)
    end

    step "rejects a valid-hex signature that is the wrong byte length" do
      # 31 bytes r + 32 bytes s + 1 byte v = correct, but 30+32+1 is wrong
      short_hex = Base.encode16(:crypto.strong_rand_bytes(62), case: :lower)
      assert {:error, :invalid_signature_length} =
               Siwe.verify("msg", "0x" <> short_hex, @address)
    end
  end
end
