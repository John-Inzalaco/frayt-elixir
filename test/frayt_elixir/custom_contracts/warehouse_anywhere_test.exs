defmodule FraytElixir.CustomContracts.WarehouseAnywhereTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.CustomContracts.WarehouseAnywhere

  describe "calculate_pricing" do
    defp build_match(distance),
      do:
        insert(:match,
          total_distance: distance,
          fees: []
        )

    test "with proper parameters" do
      match = build_match(10)

      assert %Changeset{valid?: true} =
               changeset =
               match
               |> WarehouseAnywhere.calculate_pricing()

      assert %{
               fees: [%{type: :base_fee, amount: 2500, driver_amount: 1772}]
             } =
               changeset
               |> Changeset.apply_changes()
    end

    test "over 10 miles" do
      match = build_match(15)

      assert %Changeset{valid?: true} =
               changeset =
               match
               |> WarehouseAnywhere.calculate_pricing()

      assert %{
               fees: [%{type: :base_fee, amount: 3500, driver_amount: 2493}]
             } =
               changeset
               |> Changeset.apply_changes()
    end

    test "fails with multiple stops" do
      match = insert(:match, match_stops: build_match_stops_with_items([:pending, :pending]))

      assert %Changeset{
               valid?: false,
               errors: [match_stops: {_, [count: 1, validation: :assoc_length, kind: :max]}]
             } = WarehouseAnywhere.calculate_pricing(match)
    end

    test "returns error for box truck" do
      assert %Changeset{
               errors: [
                 {:vehicle_class, {"Box Truck are not supported in this contract", _}} | _
               ]
             } =
               build_match(10)
               |> Map.put(:vehicle_class, 4)
               |> WarehouseAnywhere.calculate_pricing()
    end
  end
end
