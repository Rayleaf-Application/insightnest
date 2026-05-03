%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/"],
        excluded: ["lib/insightnest_web/components/core_components.ex"]
      },
      strict: true,
      checks: %{
        disabled: [
          {Credo.Check.Refactor.ModuleDependencies},
          # LiveView handle_* callbacks are necessarily long
          {Credo.Check.Refactor.FunctionArity},
        ]
      }
    }
  ]
}
