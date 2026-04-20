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
    },
  },
  plugins: [],
}
