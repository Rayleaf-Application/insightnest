defmodule Insightnest.Accounts.Avatar do
  @moduledoc """
  Generates a deterministic GitHub-style 5×5 identicon SVG
  from any string (typically a wallet address).

  The grid is symmetric (left half mirrored to right).
  Colour is derived from the first 3 bytes of the hash.
  Background is always the platform dark (#1c1917).
  """

  @grid_size    5
  @cell_px      16    # each cell in pixels
  @padding      4     # padding around the grid
  @bg           "#1c1917"

  @doc """
  Returns an inline SVG string for the given seed.
  Size in pixels = grid_size * cell_px + padding * 2 = 88px default.
  """
  def generate(seed) when is_binary(seed) do
    hash   = :crypto.hash(:sha256, String.downcase(seed)) |> :binary.bin_to_list()
    color  = extract_color(hash)
    cells  = extract_cells(hash)
    size   = @grid_size * @cell_px + @padding * 2

    rects =
      cells
      |> Enum.with_index()
      |> Enum.filter(fn {filled, _} -> filled end)
      |> Enum.map(fn {_, idx} ->
        row = div(idx, @grid_size)
        col = rem(idx, @grid_size)
        x   = col * @cell_px + @padding
        y   = row * @cell_px + @padding
        ~s(<rect x="#{x}" y="#{y}" width="#{@cell_px}" height="#{@cell_px}" fill="#{color}" rx="2"/>)
      end)
      |> Enum.join("\n    ")

    """
    <svg xmlns="http://www.w3.org/2000/svg"
         viewBox="0 0 #{size} #{size}"
         width="#{size}" height="#{size}"
         shape-rendering="crispEdges">
      <rect width="#{size}" height="#{size}" fill="#{@bg}" rx="8"/>
      #{rects}
    </svg>
    """
  end

  def generate(nil), do: generate("anonymous")

  @doc "Returns a data URI suitable for use in an <img> src attribute."
  def data_uri(seed) do
    svg     = generate(seed)
    encoded = Base.encode64(svg)
    "data:image/svg+xml;base64,#{encoded}"
  end

  # ── Private ──────────────────────────────────────────────────────────────────

  # Extract HSL colour from hash bytes, convert to hex.
  # Hue from bytes 0-1, high saturation and medium lightness for vibrancy.
  defp extract_color([b0, b1 | _]) do
    hue        = rem(b0 * 256 + b1, 360)
    saturation = 45 + rem(b0, 30)   # 45–75%
    lightness  = 55 + rem(b1, 20)   # 55–75%
    hsl_to_hex(hue, saturation, lightness)
  end

  # Use bytes 2-16 for cell fill decisions.
  # Grid is 5×5 but symmetric — only 15 unique cells (left half + middle col).
  defp extract_cells(hash) do
    # bytes 2..16 — one bit per unique cell position
    source = Enum.slice(hash, 2, 15)

    # Build 5×5 symmetric grid
    for row <- 0..4 do
      for col <- 0..4 do
        # Mirror: cols 0,1 mirror cols 4,3; col 2 is center
        mirror_col = min(col, @grid_size - 1 - col)
        idx        = row * 3 + mirror_col
        byte       = Enum.at(source, idx, 0)
        rem(byte, 2) == 1
      end
    end
    |> List.flatten()
  end

  # Convert HSL to #rrggbb hex
  defp hsl_to_hex(h, s, l) do
    s_f = s / 100.0
    l_f = l / 100.0

    c = (1 - abs(2 * l_f - 1)) * s_f
    x = c * (1 - abs(rem_float(h / 60.0, 2) - 1))
    m = l_f - c / 2

    {r1, g1, b1} =
      cond do
        h < 60  -> {c, x, 0.0}
        h < 120 -> {x, c, 0.0}
        h < 180 -> {0.0, c, x}
        h < 240 -> {0.0, x, c}
        h < 300 -> {x, 0.0, c}
        true    -> {c, 0.0, x}
      end

    r = round((r1 + m) * 255)
    g = round((g1 + m) * 255)
    b = round((b1 + m) * 255)

    "##{hex2(r)}#{hex2(g)}#{hex2(b)}"
  end

  defp hex2(n), do: n |> Integer.to_string(16) |> String.pad_leading(2, "0") |> String.upcase()

  defp rem_float(a, b) do
    a - b * Float.floor(a / b)
  end
end
