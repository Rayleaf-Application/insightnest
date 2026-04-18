// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin")

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/insightnest_web.ex",
    "../lib/insightnest_web/**/*.*ex"
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
