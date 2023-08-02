defmodule FraytElixir.CustomContracts.AxleHireDentonDallasTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.CustomContracts.AxleHireDentonDallas

  describe "calculate_pricing" do
    test "with proper parameters" do
      match =
        insert(:match,
          match_stops: [
            insert(:match_stop, distance: 10, index: 0)
          ]
        )

      assert %Changeset{valid?: true} =
               changeset =
               match
               |> AxleHireDentonDallas.calculate_pricing()

      assert %{
               driver_cut: 0.732,
               driver_fees: 219,
               fees: [
                 %{type: :base_fee, amount: 6500, driver_amount: 4539}
               ],
               match_stops: [
                 %{base_price: 6500, tip_price: 0, driver_cut: 0.732}
               ]
             } = Changeset.apply_changes(changeset)
    end
  end
end
