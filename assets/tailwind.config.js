const path = require("path")

module.exports = {
  content: [
    path.join(__dirname, "../lib/**/*.ex"),
    path.join(__dirname, "../lib/**/*.heex"),
    path.join(__dirname, "./js/**/*.js"),
  ],
  theme: {
    extend: {
      fontFamily: {
        display: ["Playfair Display", "Georgia", "serif"],
        sans:    ["DM Sans", "system-ui", "sans-serif"],
        mono:    ["DM Mono", "Courier New", "monospace"],
      },
      colors: {
        ink:       "#141820",
        gold: {
          DEFAULT: "#C9913A",
          light:   "#E8B86D",
        },
        parchment: "#F5F0E8",
        cream:     "#FDFAF5",
        muted:     "#7A7468",
        "brand-slate": "#2D3142",
      },
    },
  },
  plugins: [],
}
