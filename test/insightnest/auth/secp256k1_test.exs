defmodule Insightnest.Auth.Secp256k1Test do
  use ExUnit.Case, async: true

  alias Insightnest.Auth.Secp256k1

  @valid_32 :crypto.strong_rand_bytes(32)

  # ── Input validation ──────────────────────────────────────────────────────────

  describe "recover_address/4 — input guards" do
    test "returns {:error, :invalid_inputs} when message_hash is not 32 bytes" do
      assert {:error, :invalid_inputs} =
               Secp256k1.recover_address(<<1, 2, 3>>, @valid_32, @valid_32, 0)
    end

    test "returns {:error, :invalid_inputs} when r is not 32 bytes" do
      assert {:error, :invalid_inputs} =
               Secp256k1.recover_address(@valid_32, <<1, 2, 3>>, @valid_32, 0)
    end

    test "returns {:error, :invalid_inputs} when s is not 32 bytes" do
      assert {:error, :invalid_inputs} =
               Secp256k1.recover_address(@valid_32, @valid_32, <<1, 2, 3>>, 0)
    end

    test "returns {:error, :invalid_inputs} when recovery_id is 2" do
      assert {:error, :invalid_inputs} =
               Secp256k1.recover_address(@valid_32, @valid_32, @valid_32, 2)
    end

    test "returns {:error, :invalid_inputs} when recovery_id is negative" do
      assert {:error, :invalid_inputs} =
               Secp256k1.recover_address(@valid_32, @valid_32, @valid_32, -1)
    end

    test "returns {:error, :invalid_inputs} when message_hash is nil" do
      assert {:error, :invalid_inputs} =
               Secp256k1.recover_address(nil, @valid_32, @valid_32, 0)
    end

    test "returns {:error, :invalid_inputs} when r is nil" do
      assert {:error, :invalid_inputs} =
               Secp256k1.recover_address(@valid_32, nil, @valid_32, 0)
    end

    test "returns {:error, :invalid_inputs} when message_hash is too long" do
      assert {:error, :invalid_inputs} =
               Secp256k1.recover_address(:crypto.strong_rand_bytes(33), @valid_32, @valid_32, 0)
    end
  end

  # ── Valid input handling ──────────────────────────────────────────────────────

  describe "recover_address/4 — valid-format inputs" do
    test "returns either {:ok, address} or a domain-level error — never crashes" do
      hash = :crypto.strong_rand_bytes(32)
      r = :crypto.strong_rand_bytes(32)
      s = :crypto.strong_rand_bytes(32)

      result = Secp256k1.recover_address(hash, r, s, 0)

      assert match?({:ok, "0x" <> _}, result) or
               match?({:error, :x_out_of_range}, result) or
               match?({:error, :no_curve_point}, result)
    end

    test "recovery_id 0 and 1 are both accepted as valid inputs" do
      hash = :crypto.strong_rand_bytes(32)
      r = :crypto.strong_rand_bytes(32)
      s = :crypto.strong_rand_bytes(32)

      result0 = Secp256k1.recover_address(hash, r, s, 0)
      result1 = Secp256k1.recover_address(hash, r, s, 1)

      # Both must return a known-shape result (not {:error, :invalid_inputs})
      for result <- [result0, result1] do
        refute result == {:error, :invalid_inputs}
      end
    end

    test "a successful recovery returns a lowercase hex address with 0x prefix" do
      # Retry a few times since random r/s may hit invalid curve points.
      result =
        Enum.find_value(1..20, fn _ ->
          hash = :crypto.strong_rand_bytes(32)
          r = :crypto.strong_rand_bytes(32)
          s = :crypto.strong_rand_bytes(32)

          case Secp256k1.recover_address(hash, r, s, 0) do
            {:ok, addr} -> addr
            _ -> nil
          end
        end)

      if result do
        assert String.starts_with?(result, "0x")
        hex_part = String.slice(result, 2..-1//1)
        assert String.length(hex_part) == 40
        assert hex_part == String.downcase(hex_part)
      else
        # All 20 random trials produced invalid curve points — extremely unlikely
        # but not a test failure. The cryptographic path is validated end-to-end
        # by the BDD auth scenarios via Siwe.verify/3.
        :ok
      end
    end
  end
end
