defmodule Insightnest.Accounts.AvatarTest do
  use ExUnit.Case, async: true

  alias Insightnest.Accounts.Avatar

  describe "generate/1" do
    test "returns a non-empty SVG string" do
      svg = Avatar.generate("0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266")
      assert is_binary(svg)
      assert svg =~ "<svg"
      assert svg =~ "</svg>"
    end

    test "output includes the dark background rect" do
      svg = Avatar.generate("any_seed")
      assert svg =~ ~s(fill="#1c1917")
    end

    test "output embeds viewBox with positive dimensions" do
      svg = Avatar.generate("wallet_x")
      assert svg =~ ~r/viewBox="0 0 \d+ \d+"/
    end

    test "is deterministic — same seed produces identical SVG" do
      seed = "0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
      assert Avatar.generate(seed) == Avatar.generate(seed)
    end

    test "produces different output for different seeds" do
      svg1 = Avatar.generate("0x" <> String.duplicate("aa", 20))
      svg2 = Avatar.generate("0x" <> String.duplicate("bb", 20))
      refute svg1 == svg2
    end

    test "handles nil seed without raising" do
      svg = Avatar.generate(nil)
      assert is_binary(svg)
      assert svg =~ "<svg"
    end

    test "nil seed produces same output as 'anonymous' seed" do
      assert Avatar.generate(nil) == Avatar.generate("anonymous")
    end
  end

  describe "data_uri/1" do
    test "returns a base64-encoded data URI" do
      uri = Avatar.data_uri("some_wallet")
      assert String.starts_with?(uri, "data:image/svg+xml;base64,")
    end

    test "the encoded payload decodes to a valid SVG" do
      uri = Avatar.data_uri("some_wallet")
      encoded = String.replace_prefix(uri, "data:image/svg+xml;base64,", "")
      decoded = Base.decode64!(encoded)
      assert decoded =~ "<svg"
    end

    test "is deterministic for the same seed" do
      seed = "reproducible_seed"
      assert Avatar.data_uri(seed) == Avatar.data_uri(seed)
    end
  end
end
