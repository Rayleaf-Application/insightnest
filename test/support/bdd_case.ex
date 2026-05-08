defmodule Insightnest.BDDCase do
  @moduledoc """
  Lightweight BDD DSL layered over ExUnit.

  Provides `scenario/2` (translates to `describe`) and `step/2` (translates
  to `test`) with naming conventions that make output read like specifications.

  Usage:

      defmodule MyFeatureTest do
        use Insightnest.DataCase, async: true
        use Insightnest.BDDCase

        scenario "member creates their first spark" do
          setup do
            {:ok, member: AccountsFixtures.onboarded_member()}
          end

          step "given valid attrs, the spark is persisted", %{member: m} do
            assert {:ok, spark} = Sparks.create_spark(valid_attrs(), m.id)
            assert spark.status == "draft"
          end
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      import Insightnest.BDDCase
    end
  end

  @doc "Groups related steps under a named scenario (maps to ExUnit `describe`)."
  defmacro scenario(name, do: block) do
    quote do
      describe "Scenario: #{unquote(name)}" do
        unquote(block)
      end
    end
  end

  @doc "A single assertion step inside a scenario (maps to ExUnit `test`)."
  defmacro step(description, do: block) do
    quote do
      test unquote(description) do
        unquote(block)
      end
    end
  end

  defmacro step(description, context, do: block) do
    quote do
      test unquote(description), unquote(context) do
        unquote(block)
      end
    end
  end
end
