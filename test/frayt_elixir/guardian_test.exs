defmodule FraytElixir.GuardianTest do
  use FraytElixir.DataCase

  alias FraytElixir.Guardian
  alias FraytElixir.Accounts.User
  alias FraytElixir.Accounts

  import FraytElixir.Factory

  test "subject_for_token" do
    assert {:ok, "123"} = Guardian.subject_for_token(%User{id: "123"}, "some claims")
  end

  test "resource_from_claim" do
    {:ok, %User{id: user_id}} =
      Accounts.create_user(%{email: "some@email.com", password: "mysecretpasswordissohardtoguess"})

    assert {:ok, %User{id: ^user_id}} = Guardian.resource_from_claims(%{"sub" => user_id})
  end

  test "resource_from_claim with an api account" do
    api_account = insert(:api_account_with_company)

    {:ok, _token, claims} =
      FraytElixir.Guardian.encode_and_sign(api_account, %{"aud" => "frayt_api"})

    assert {:ok, decoded_api_account} = Guardian.resource_from_claims(claims)
    assert api_account.id == decoded_api_account.id
  end
end
