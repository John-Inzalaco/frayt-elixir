defmodule FraytElixir.CustomContracts.ContractFeesTest do
  use FraytElixir.DataCase
  alias FraytElixir.CustomContracts.ContractFees

  @fees_config [
    load_fee: %{
      250 => {24_99, 18_74},
      1000 => {44_99, 33_74}
    },
    route_surcharge: {50, 0},
    holiday_fee: {100_00, 75_00},
    lift_gate_fee: {30_00, 22_50},
    return_charge: 0.50,
    toll_fees: true
  ]

  @price_attrs %{
    total_base_fee: 10_00,
    driver_tips: 0,
    total_driver_base: 8_00
  }

  describe "calculates fees for" do
    defp insert_fee_match(attrs \\ []) do
      insert(
        :match,
        [
          vehicle_class: 1,
          scheduled: true,
          pickup_at: ~N[2030-01-02 00:00:00],
          match_stops: [build(:match_stop, index: 0, has_load_fee: false)],
          market: nil,
          expected_toll: 0,
          fees: []
        ] ++ attrs
      )
    end

    defp order_fees({_driver_fees, fees}) do
      Enum.sort_by(fees, & &1.type, :asc)
    end

    test "none when conditions are not met" do
      match = insert_fee_match()

      assert [%{type: :base_fee}] =
               match |> ContractFees.calculate_fees(@price_attrs, @fees_config) |> order_fees()
    end

    test "return charge when stops are undeliverable" do
      match =
        insert_fee_match(
          match_stops: [
            build(:match_stop,
              index: 0,
              distance: 5,
              has_load_fee: false,
              base_price: 12_00,
              state: :returned
            ),
            build(:match_stop,
              index: 1,
              distance: 12,
              has_load_fee: false,
              base_price: 16_00,
              state: :returned
            ),
            build(:match_stop,
              index: 2,
              distance: 12,
              has_load_fee: false,
              base_price: 20_00,
              state: :pending
            )
          ]
        )

      assert [
               %{type: :base_fee, amount: 48_00, driver_amount: 38_29},
               %{
                 type: :return_charge,
                 amount: 14_00,
                 driver_amount: 10_50,
                 description: "2 stops were returned"
               },
               %{type: :route_surcharge}
             ] =
               match
               |> ContractFees.calculate_fees(
                 %{@price_attrs | total_base_fee: 48_00, total_driver_base: 40_00},
                 @fees_config
               )
               |> order_fees()
    end

    test "load/unload except when below weight" do
      match =
        insert_fee_match(
          match_stops: [
            build(:match_stop,
              index: 0,
              has_load_fee: true,
              items: [build(:match_stop_item, pieces: 10, weight: 1)]
            )
          ]
        )

      refute match
             |> ContractFees.calculate_fees(@price_attrs, @fees_config)
             |> order_fees()
             |> Enum.find(&(&1.type == :load_fee))
    end

    test "load/unload when weight >= min weight tier" do
      match =
        insert_fee_match(
          match_stops: [
            build(:match_stop,
              index: 0,
              has_load_fee: true,
              items: [build(:match_stop_item, pieces: 10, weight: 25)]
            )
          ]
        )

      assert [%{type: :base_fee}, %{type: :load_fee, amount: 24_99, driver_amount: 18_74}] =
               match |> ContractFees.calculate_fees(@price_attrs, @fees_config) |> order_fees()
    end

    test "load/unload increases tiers with weight" do
      match =
        insert_fee_match(
          match_stops: [
            build(:match_stop,
              index: 0,
              has_load_fee: true,
              items: [build(:match_stop_item, pieces: 10, weight: 100)]
            )
          ]
        )

      assert [%{type: :base_fee}, %{type: :load_fee, amount: 44_99, driver_amount: 33_74}] =
               match |> ContractFees.calculate_fees(@price_attrs, @fees_config) |> order_fees()
    end

    test "lift gate" do
      match = insert_fee_match(vehicle_class: 4, unload_method: :lift_gate)

      assert [
               %{type: :base_fee},
               %{type: :lift_gate_fee, amount: 30_00, driver_amount: 22_50}
             ] = match |> ContractFees.calculate_fees(@price_attrs, @fees_config) |> order_fees()
    end

    test "holiday" do
      match =
        insert_fee_match(scheduled: true, pickup_at: ~N[2030-12-25 12:00:00], vehicle_class: 4)

      assert [
               %{type: :base_fee},
               %{type: :holiday_fee, amount: 100_00, driver_amount: 75_00}
             ] = match |> ContractFees.calculate_fees(@price_attrs, @fees_config) |> order_fees()
    end

    test "route surcharge" do
      match =
        insert_fee_match(
          match_stops: [build(:match_stop, index: 0), build(:match_stop, index: 1)]
        )

      assert [%{type: :base_fee}, %{type: :route_surcharge, amount: 50, driver_amount: 0}] =
               match |> ContractFees.calculate_fees(@price_attrs, @fees_config) |> order_fees()
    end

    test "tolls when market has tolls enabled" do
      match =
        insert_fee_match(expected_toll: 10_00, market: build(:market, calculate_tolls: true))

      assert [
               %{type: :base_fee},
               %{type: :toll_fees, amount: 10_00, driver_amount: 10_00}
             ] = match |> ContractFees.calculate_fees(@price_attrs, @fees_config) |> order_fees()
    end

    test "tolls unless no expected tolls" do
      match = insert_fee_match(expected_toll: 0, market: build(:market, calculate_tolls: true))

      refute match
             |> ContractFees.calculate_fees(@price_attrs, @fees_config)
             |> order_fees()
             |> Enum.find(&(&1.type == :toll_fees))
    end

    test "tolls unless without market with enabled tolls" do
      match =
        insert_fee_match(expected_toll: 10_00, market: build(:market, calculate_tolls: false))

      refute match
             |> ContractFees.calculate_fees(@price_attrs, @fees_config)
             |> order_fees()
             |> Enum.find(&(&1.type == :toll_fees))
    end

    test "applies custom fees" do
      match = insert_fee_match(fees: [])

      custom_fee_fn = fn type, _match ->
        %{type: type, amount: 100_00, driver_amount: 75_00}
      end

      assert [%{type: :base_fee}, %{type: :custom_fee, amount: 100_00, driver_amount: 75_00}] =
               match
               |> ContractFees.calculate_fees(@price_attrs, custom_fee: custom_fee_fn)
               |> order_fees()
    end

    test "can remove fees that no longer apply" do
      match =
        insert_fee_match(
          fees: [
            build(:match_fee, type: :holiday_fee),
            build(:match_fee, type: :lift_gate_fee)
          ]
        )

      assert [%{type: :base_fee}] =
               match |> ContractFees.calculate_fees(@price_attrs, @fees_config) |> order_fees()
    end
  end
end
