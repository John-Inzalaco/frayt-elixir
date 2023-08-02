defmodule FraytElixir.CustomContracts.TireAgentTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.CustomContracts.TireAgent

  describe "calculate_pricing" do
    defp build_match(vehicle_class, distance, origin_zip),
      do:
        insert(:match,
          vehicle_class: vehicle_class,
          total_distance: distance,
          fees: [],
          origin_address: build(:address, zip: origin_zip)
        )

    test "with proper parameters" do
      match = build_match(1, 10, "90210")

      assert %Changeset{valid?: true} = changeset = TireAgent.calculate_pricing(match)

      assert %{
               driver_cut: 0.75,
               fees: [%{type: :base_fee, amount: 14_99, driver_amount: 10_50}]
             } = Changeset.apply_changes(changeset)
    end

    test "Tier 1 Car Additional Price" do
      match = build_match(1, 50, "90210")

      assert %{
               fees: [%{type: :base_fee, amount: 54_99, driver_amount: 39_34}],
               driver_cut: 0.75
             } = match |> TireAgent.calculate_pricing() |> Changeset.apply_changes()
    end

    test "Tier 1 Midsize Base Price" do
      match = build_match(2, 9, "90210")

      assert %{
               fees: [%{type: :base_fee, amount: 24_99, driver_amount: 17_71}],
               driver_cut: 0.75
             } = match |> TireAgent.calculate_pricing() |> Changeset.apply_changes()
    end

    test "Tier 1 Midsize Additional Price" do
      match = build_match(2, 50, "90210")

      assert %{
               fees: [%{type: :base_fee, amount: 74_99, driver_amount: 53_76}],
               driver_cut: 0.75
             } = match |> TireAgent.calculate_pricing() |> Changeset.apply_changes()
    end

    test "Tier 1 Cargo Van Base Price" do
      match = build_match(3, 9, "90210")

      assert %{
               fees: [%{type: :base_fee, amount: 34_99, driver_amount: 24_92}],
               driver_cut: 0.75
             } = match |> TireAgent.calculate_pricing() |> Changeset.apply_changes()
    end

    test "Tier 1 Cargo Van Additional Price" do
      match = build_match(3, 50, "90210")

      assert %{
               fees: [%{type: :base_fee, amount: 94_99, driver_amount: 68_18}],
               driver_cut: 0.75
             } = match |> TireAgent.calculate_pricing() |> Changeset.apply_changes()
    end

    test "Tier 2 Car Base Price" do
      match = build_match(1, 9, "30004")

      assert %{
               fees: [%{type: :base_fee, amount: 16_00, driver_amount: 11_23}],
               driver_cut: 0.75
             } = match |> TireAgent.calculate_pricing() |> Changeset.apply_changes()
    end

    test "Tier 2 Car Additional Price" do
      match = build_match(1, 50, "30004")

      assert %{
               fees: [%{type: :base_fee, amount: 66_00, driver_amount: 47_28}],
               driver_cut: 0.75
             } = match |> TireAgent.calculate_pricing() |> Changeset.apply_changes()
    end

    test "Tier 2 Midsize Base Price" do
      match = build_match(2, 9, "30004")

      assert %{
               fees: [%{type: :base_fee, amount: 29_99, driver_amount: 21_32}],
               driver_cut: 0.75
             } = match |> TireAgent.calculate_pricing() |> Changeset.apply_changes()
    end

    test "Tier 2 Midsize Additional Price" do
      match = build_match(2, 50, "30004")

      assert %{
               fees: [%{type: :base_fee, amount: 89_99, driver_amount: 64_58}],
               driver_cut: 0.75
             } = match |> TireAgent.calculate_pricing() |> Changeset.apply_changes()
    end

    test "Tier 2 Cargo Van Base Price" do
      match = build_match(3, 9, "30004")

      assert %{
               fees: [%{type: :base_fee, amount: 41_99, driver_amount: 29_97}],
               driver_cut: 0.75
             } = match |> TireAgent.calculate_pricing() |> Changeset.apply_changes()
    end

    test "Tier 2 Cargo Van Additional Price" do
      match = build_match(3, 50, "30004")

      assert %{
               fees: [%{type: :base_fee, amount: 113_99, driver_amount: 81_88}],
               driver_cut: 0.75
             } = match |> TireAgent.calculate_pricing() |> Changeset.apply_changes()
    end

    test "Box Truck returns not implemented" do
      match = build_match(4, 50, "30004")

      assert %Ecto.Changeset{
               errors: [
                 {:vehicle_class,
                  {"Box Truck are not supported in this contract", [validation: :no_box_truck]}}
                 | _
               ]
             } = match |> TireAgent.calculate_pricing()
    end

    test "Any Other Argument raises invalid exception" do
      match = build_match(5, 2_23, "30004")

      assert %Ecto.Changeset{
               errors: [
                 {:vehicle_class, {"Invalid Vehicle Class", [validation: :is_valid_vehicle]}}
                 | _
               ]
             } = match |> TireAgent.calculate_pricing()
    end

    test "fails with multiple stops" do
      match = insert(:match, match_stops: build_match_stops_with_items([:pending, :pending]))

      assert %Changeset{
               valid?: false,
               errors: [match_stops: {_, [count: 1, validation: :assoc_length, kind: :max]}]
             } = TireAgent.calculate_pricing(match)
    end
  end
end
