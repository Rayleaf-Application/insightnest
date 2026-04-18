defmodule Insightnest.Auth.Secp256k1 do
  @moduledoc """
  Pure Elixir secp256k1 public key recovery.
  No NIFs. Uses only Elixir's native big integer arithmetic.

  Used exclusively by Insightnest.Auth.Siwe for SIWE signature verification.
  """

  # ── secp256k1 curve parameters ───────────────────────────────────────────────

  # Prime field modulus
  @p 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F

  # Curve order
  @n 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141

  # Generator point
  @gx 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798
  @gy 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8

  # Curve coefficient (b not needed for point ops, a=0 for secp256k1)

  # ── Public API ───────────────────────────────────────────────────────────────

  @doc """
  Recovers the Ethereum address that produced `signature` over `message_hash`.

  - `message_hash`  — 32-byte binary (keccak-256 of the prefixed message)
  - `r`, `s`        — 32-byte binaries from the signature
  - `recovery_id`   — 0 or 1

  Returns `{:ok, "0x..."}` (lowercase hex) or `{:error, reason}`.
  """
  def recover_address(message_hash, r, s, recovery_id)
      when is_binary(message_hash) and byte_size(message_hash) == 32
      and is_binary(r) and byte_size(r) == 32
      and is_binary(s) and byte_size(s) == 32
      and recovery_id in [0, 1] do
    r_int = :binary.decode_unsigned(r)
    s_int = :binary.decode_unsigned(s)
    z     = :binary.decode_unsigned(message_hash)

    with {:ok, pub_key} <- recover_public_key(z, r_int, s_int, recovery_id) do
      {:ok, public_key_to_address(pub_key)}
    end
  end

  def recover_address(_, _, _, _), do: {:error, :invalid_inputs}

  # ── Private: ECDSA public key recovery ───────────────────────────────────────

  # Given hash z, signature (r, s) and recovery_id, compute:
  # Q = r⁻¹ * (s * R - z * G)
  defp recover_public_key(z, r, s, recovery_id) do
    # 1. Compute candidate x coordinate from r
    x = r + recovery_id * @n

    if x >= @p do
      {:error, :x_out_of_range}
    else
      # 2. Compute R point (compressed y parity from recovery_id)
      case point_from_x(x, recovery_id) do
        {:error, reason} ->
          {:error, reason}

        {:ok, r_point} ->
          # 3. Q = r⁻¹ * (s * R - z * G)
          r_inv = mod_inv(r, @n)

          # s * R
          sr = point_mul(r_point, s)

          # z * G
          zg = point_mul({@gx, @gy}, z)

          # s * R - z * G
          sr_minus_zg = point_add(sr, point_negate(zg))

          # r⁻¹ * (s * R - z * G)
          q = point_mul(sr_minus_zg, r_inv)

          {:ok, q}
      end
    end
  end

  # Recover a curve point from x coordinate.
  # y² = x³ + 7 (mod p)  [secp256k1: a=0, b=7]
  defp point_from_x(x, recovery_id) do
    y_sq = rem(mod_pow(x, 3, @p) + 7, @p)
    y    = mod_pow(y_sq, div(@p + 1, 4), @p)

    # Check that y² ≡ y_sq (mod p) — if not, no solution exists
    if mod_pow(y, 2, @p) != y_sq do
      {:error, :no_curve_point}
    else
      # Choose the correct y parity
      y_final =
        if rem(y, 2) == rem(recovery_id, 2) do
          y
        else
          @p - y
        end

      {:ok, {x, y_final}}
    end
  end

  # ── Private: EC point arithmetic ─────────────────────────────────────────────

  # Point at infinity
  defp point_add(:infinity, p), do: p
  defp point_add(p, :infinity), do: p

  defp point_add({x1, y1}, {x2, y2}) do
    if x1 == x2 do
      if y1 == y2 do
        point_double({x1, y1})
      else
        :infinity
      end
    else
      # slope = (y2 - y1) / (x2 - x1)  mod p
      m = rem(mod_mult(mod_sub(y2, y1, @p), mod_inv(mod_sub(x2, x1, @p), @p), @p), @p)

      x3 = mod_sub(mod_sub(mod_mult(m, m, @p), x1, @p), x2, @p)
      y3 = mod_sub(mod_mult(m, mod_sub(x1, x3, @p), @p), y1, @p)

      {x3, y3}
    end
  end

  defp point_double(:infinity), do: :infinity

  defp point_double({x, y}) do
    # slope = (3 * x² + a) / (2 * y)  mod p   [a=0 for secp256k1]
    m = rem(
      mod_mult(3 * mod_pow(x, 2, @p), mod_inv(mod_mult(2, y, @p), @p), @p),
      @p
    )

    x3 = mod_sub(mod_mult(m, m, @p), 2 * x, @p)
    y3 = mod_sub(mod_mult(m, mod_sub(x, x3, @p), @p), y, @p)

    {x3, y3}
  end

  # Double-and-add scalar multiplication
  defp point_mul(_, 0), do: :infinity
  defp point_mul(point, 1), do: point

  defp point_mul(point, k) when k > 0 do
    if rem(k, 2) == 1 do
      point_add(point, point_mul(point, k - 1))
    else
      point_mul(point_double(point), div(k, 2))
    end
  end

  # Negate a point (reflect over x-axis)
  defp point_negate(:infinity), do: :infinity
  defp point_negate({x, y}), do: {x, mod_sub(0, y, @p)}

  # ── Private: modular arithmetic helpers ──────────────────────────────────────

  defp mod_sub(a, b, m) do
    rem(rem(a - b, m) + m, m)
  end

  defp mod_mult(a, b, m) do
    rem(a * b, m)
  end

  # Modular exponentiation (fast, uses Erlang's :crypto.mod_pow under the hood)
  defp mod_pow(base, exp, mod) do
    :crypto.mod_pow(base, exp, mod)
    |> :binary.decode_unsigned()
  end

  # Modular multiplicative inverse via Fermat's little theorem
  # Valid because p is prime: a⁻¹ ≡ a^(p-2) (mod p)
  defp mod_inv(a, m) do
    mod_pow(rem(a, m), m - 2, m)
  end

  # ── Private: public key → Ethereum address ───────────────────────────────────

  # Encodes the public key as an uncompressed 64-byte binary (no 0x04 prefix),
  # hashes with keccak-256, takes the last 20 bytes.
  defp public_key_to_address({x, y}) do
    x_bytes = pad32(:binary.encode_unsigned(x))
    y_bytes = pad32(:binary.encode_unsigned(y))

    key_bytes = x_bytes <> y_bytes
    hash      = ExKeccak.hash_256(key_bytes)

    <<_::binary-size(12), address::binary-size(20)>> = hash

    "0x" <> Base.encode16(address, case: :lower)
  end

  # Zero-pad a binary to 32 bytes on the left
  defp pad32(bin) when byte_size(bin) == 32, do: bin
  defp pad32(bin), do: :binary.copy(<<0>>, 32 - byte_size(bin)) <> bin
end
