defmodule FraytElixir.CustomContractsTest do
  alias FraytElixir.CustomContracts
  alias FraytElixir.Contracts.Contract

  import Ecto.Changeset

  use FraytElixir.DataCase

  describe "get_contact_module" do
    test "gets existing contract module" do
      assert CustomContracts.get_contract_module(%Contract{pricing_contract: :atd}) ==
               CustomContracts.Atd
    end

    test "falls back to default contract module" do
      assert CustomContracts.get_contract_module(%Contract{pricing_contract: :satd}) ==
               CustomContracts.Default

      assert CustomContracts.get_contract_module(nil) == CustomContracts.Default
    end
  end

  describe "get_auto_configure_dropoff_at/1" do
    test "true for valid contract" do
      assert {:ok, true} =
               CustomContracts.get_auto_configure_dropoff_at(%Contract{pricing_contract: :sherwin})
    end

    test "false for invalid contract" do
      assert {:ok, false} =
               CustomContracts.get_auto_configure_dropoff_at(%Contract{
                 pricing_contract: :asfdasdf
               })
    end
  end
end
