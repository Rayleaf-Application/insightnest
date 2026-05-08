defmodule Insightnest.Accounts.PasscodeStoreTest do
  # async: false — tests share the running PasscodeStore GenServer/ETS table.
  use ExUnit.Case, async: false

  alias Insightnest.Accounts.PasscodeStore

  defp unique_email, do: "passcode_#{System.unique_integer([:positive])}@test.com"

  describe "put/2 and get_and_delete/1" do
    test "stored code is returned on first lookup" do
      email = unique_email()
      :ok   = PasscodeStore.put(email, "123456")
      assert {:ok, "123456"} = PasscodeStore.get_and_delete(email)
    end

    test "code is deleted after retrieval — second lookup returns not_found" do
      email = unique_email()
      PasscodeStore.put(email, "999999")
      PasscodeStore.get_and_delete(email)
      assert {:error, :not_found} = PasscodeStore.get_and_delete(email)
    end

    test "returns not_found for an email that was never stored" do
      assert {:error, :not_found} = PasscodeStore.get_and_delete(unique_email())
    end

    test "lookup is case-insensitive for the email" do
      email = unique_email()
      PasscodeStore.put(email, "777777")
      assert {:ok, "777777"} = PasscodeStore.get_and_delete(String.upcase(email))
    end

    test "independent emails do not interfere" do
      {e1, e2} = {unique_email(), unique_email()}
      PasscodeStore.put(e1, "111111")
      PasscodeStore.put(e2, "222222")
      assert {:ok, "111111"} = PasscodeStore.get_and_delete(e1)
      assert {:ok, "222222"} = PasscodeStore.get_and_delete(e2)
    end

    test "stored code can be overwritten" do
      email = unique_email()
      PasscodeStore.put(email, "aaaaaa")
      PasscodeStore.put(email, "bbbbbb")
      assert {:ok, "bbbbbb"} = PasscodeStore.get_and_delete(email)
    end
  end
end
