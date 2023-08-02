defmodule FraytElixir.CustomContracts.WalmartTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.CustomContracts.Walmart

  describe "walmart" do
    setup do
      match =
        insert(
          :match,
          vehicle_class: 1,
          total_distance: 5,
          total_weight: 30,
          origin_address: build(:address, state_code: "OH"),
          match_stops: [
            build(
              :match_stop,
              tip_price: 0,
              distance: 5,
              index: 0,
              items: [
                build(:match_stop_item, weight: 10, pieces: 5),
                build(:match_stop_item, weight: 10, pieces: 4),
                build(:match_stop_item, weight: 10, pieces: 3)
              ]
            )
          ]
        )

      [match: match]
    end

    test "add on-demand priority fee", %{match: match} do
      dropoff_at = DateTime.utc_now() |> DateTime.add(179 * 60, :second)

      assert %Changeset{valid?: true} =
               changeset =
               match
               |> Map.put(:scheduled, true)
               |> Map.put(:pickup_at, dropoff_at)
               |> Map.put(:dropoff_at, dropoff_at)
               |> Walmart.calculate_pricing()

      assert %{
               fees: [
                 %{type: :base_fee, amount: 18_00},
                 %{
                   type: :priority_fee,
                   amount: 3_00,
                   driver_amount: 2_25,
                   description: "On demand fee"
                 }
               ]
             } = Changeset.apply_changes(changeset)
    end

    test "add standard fee when further out than on-demand", %{match: match} do
      dropoff_at = DateTime.utc_now() |> DateTime.add(180 * 60, :second)

      assert %Changeset{valid?: true} =
               changeset =
               match
               |> Map.put(:scheduled, true)
               |> Map.put(:pickup_at, dropoff_at)
               |> Map.put(:dropoff_at, dropoff_at)
               |> Walmart.calculate_pricing()

      assert %{
               fees: [
                 %{type: :base_fee, amount: 18_00},
                 %{
                   type: :priority_fee,
                   amount: 0,
                   driver_amount: 0,
                   description: "Standard fee"
                 }
               ]
             } = Changeset.apply_changes(changeset)
    end

    test "selects standard when less than scheduled", %{match: match} do
      dropoff_at = DateTime.utc_now() |> DateTime.add(239 * 60, :second)

      assert %Changeset{valid?: true} =
               changeset =
               match
               |> Map.put(:scheduled, true)
               |> Map.put(:pickup_at, dropoff_at)
               |> Map.put(:dropoff_at, dropoff_at)
               |> Walmart.calculate_pricing()

      assert %{
               fees: [
                 %{type: :base_fee, amount: 18_00},
                 %{
                   type: :priority_fee,
                   amount: 0,
                   driver_amount: 0,
                   description: "Standard fee"
                 }
               ]
             } = Changeset.apply_changes(changeset)
    end

    test "selects scheduled", %{match: match} do
      dropoff_at = DateTime.utc_now() |> DateTime.add(240 * 60, :second)

      assert %Changeset{valid?: true} =
               changeset =
               match
               |> Map.put(:scheduled, true)
               |> Map.put(:pickup_at, dropoff_at)
               |> Map.put(:dropoff_at, dropoff_at)
               |> Walmart.calculate_pricing()

      assert %{
               fees: [
                 %{type: :base_fee, amount: 18_00},
                 %{
                   type: :priority_fee,
                   amount: -1_00,
                   driver_amount: -0_75,
                   description: "Scheduled fee"
                 }
               ]
             } = Changeset.apply_changes(changeset)
    end

    test "without markup", %{match: match} do
      assert %Changeset{valid?: true} = changeset = Walmart.calculate_pricing(match)

      assert %{
               driver_cut: 0.75,
               driver_fees: 91,
               fees: [
                 %{type: :base_fee, amount: 18_00, driver_amount: 12_59},
                 %{type: :priority_fee, amount: 3_00, driver_amount: 2_25}
               ]
             } = Changeset.apply_changes(changeset)
    end

    test "with markups NY", %{match: match} do
      assert %Changeset{valid?: true} =
               changeset =
               match.origin_address.state_code
               |> update_in(fn _ -> "NY" end)
               |> Walmart.calculate_pricing()

      assert %{
               driver_cut: 0.75,
               driver_fees: 102,
               fees: [
                 %{type: :base_fee, amount: 21_60, driver_amount: 15_18},
                 %{type: :priority_fee, amount: 3_00, driver_amount: 2_25}
               ]
             } = Changeset.apply_changes(changeset)
    end

    test "with markups CA", %{match: match} do
      assert %Changeset{valid?: true} =
               changeset =
               match.origin_address.state_code
               |> update_in(fn _ -> "CA" end)
               |> Walmart.calculate_pricing()

      assert %{
               driver_cut: 0.75,
               driver_fees: 102,
               fees: [
                 %{type: :base_fee, amount: 21_60, driver_amount: 15_18},
                 %{type: :priority_fee, amount: 3_00, driver_amount: 2_25}
               ]
             } = Changeset.apply_changes(changeset)
    end

    test "with unsupported match weight", %{match: match} do
      match = Map.put(match, :total_weight, 9000)

      assert %Changeset{
               valid?: false,
               errors: [weight: {"is not supported in this contract", []}]
             } = Walmart.calculate_pricing(match)
    end
  end
end
