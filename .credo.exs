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
          {Credo.Check.Refactor.FunctionArity, []},
        ]
      }
    }
  ]
}
