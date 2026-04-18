defmodule Insightnest.Auth.Siwe do
  @moduledoc """
  Pure Elixir SIWE (EIP-4361) message parser and signature verifier.

  Dependencies:
  - ex_keccak  — keccak-256 hashing
  - Secp256k1  — pure Elixir public key recovery (no NIFs beyond ex_keccak)
  """

  alias Insightnest.Auth.Secp256k1

  defstruct [
    :domain,
    :address,
    :statement,
    :uri,
    :version,
    :chain_id,
    :nonce,
    :issued_at
  ]

  @type t :: %__MODULE__{}

  # ── Parse ────────────────────────────────────────────────────────────────────

  @doc """
  Parses a raw EIP-4361 plaintext message into a %Siwe{} struct.
  Returns {:ok, %Siwe{}} or {:error, reason}.
  """
  def parse(raw) when is_binary(raw) do
    lines = String.split(raw, "\n")

    with [header | rest]          <- lines,
         {:ok, domain}            <- parse_header(header),
         {:ok, address, fields}   <- parse_body(rest) do
      {:ok,
       %__MODULE__{
         domain:     domain,
         address:    address,
         statement:  Map.get(fields, :statement),
         uri:        Map.get(fields, :uri),
         version:    Map.get(fields, :version),
         chain_id:   Map.get(fields, :chain_id),
         nonce:      Map.get(fields, :nonce),
         issued_at:  Map.get(fields, :issued_at)
       }}
    end
  end

  def parse(_), do: {:error, "message must be a string"}

  # ── Verify ───────────────────────────────────────────────────────────────────

  @doc """
  Verifies that `signature` was produced by signing `raw_message`
  with the private key of `expected_address`.

  Returns :ok or {:error, reason}.
  """
  def verify(raw_message, signature, expected_address)
      when is_binary(raw_message) and is_binary(signature) and is_binary(expected_address) do
    with {:ok, {r, s, recovery_id}} <- decode_signature(signature) do
      hash = personal_sign_hash(raw_message)

      # Try both recovery IDs — MetaMask sometimes sends v=27/28
      Enum.find_value([recovery_id, 1 - recovery_id], {:error, :invalid_signature}, fn rid ->
        case Secp256k1.recover_address(hash, r, s, rid) do
          {:ok, recovered} ->
            if String.downcase(recovered) == String.downcase(expected_address) do
              :ok
            else
              nil
            end

          {:error, _} ->
            nil
        end
      end)
    end
  end

  def verify(_, _, _), do: {:error, :invalid_arguments}

  # ── Private: EIP-191 hash ────────────────────────────────────────────────────

  # personal_sign prefixes the message before hashing.
  # This is what MetaMask uses for eth_sign / personal_sign.
  defp personal_sign_hash(message) do
    prefix  = "\x19Ethereum Signed Message:\n#{byte_size(message)}"
    ExKeccak.hash_256(prefix <> message)
  end

  # ── Private: signature decoding ──────────────────────────────────────────────

  defp decode_signature("0x" <> hex) do
    case Base.decode16(hex, case: :mixed) do
      {:ok, <<r::binary-32, s::binary-32, v::binary-1>>} ->
        v_int       = :binary.decode_unsigned(v)
        recovery_id = rem(v_int, 27)  # normalise 27/28 → 0/1
        {:ok, {r, s, recovery_id}}

      {:ok, _} ->
        {:error, :invalid_signature_length}

      :error ->
        {:error, :invalid_signature_hex}
    end
  end

  defp decode_signature(_), do: {:error, :invalid_signature_format}

  # ── Private: message parsing ─────────────────────────────────────────────────

  # Line 0: "<domain> wants you to sign in with your Ethereum account:"
  defp parse_header(line) do
    case Regex.run(~r/^(.+) wants you to sign in with your Ethereum account:$/, line) do
      [_, domain] -> {:ok, domain}
      _           -> {:error, "invalid header: #{inspect(line)}"}
    end
  end

  # Line 1: wallet address
  # Line 2: blank
  # Line 3: statement (optional)
  # Line 4+: key-value fields
  defp parse_body([address_line | rest]) do
    address = String.trim(address_line)

    fields =
      rest
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.reduce(%{}, &parse_field/2)

    {:ok, address, fields}
  end

  defp parse_body([]), do: {:error, "missing address line"}

  defp parse_field("URI: " <> v, acc),        do: Map.put(acc, :uri, v)
  defp parse_field("Version: " <> v, acc),    do: Map.put(acc, :version, v)
  defp parse_field("Nonce: " <> v, acc),      do: Map.put(acc, :nonce, v)
  defp parse_field("Issued At: " <> v, acc),  do: Map.put(acc, :issued_at, v)
  defp parse_field("Chain ID: " <> v, acc) do
    Map.put(acc, :chain_id, String.to_integer(v))
  end
  defp parse_field(line, acc) do
    # Anything that doesn't match a known field is treated as the statement
    if Map.has_key?(acc, :statement) do
      acc
    else
      Map.put(acc, :statement, line)
    end
  end
end
