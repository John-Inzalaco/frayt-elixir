defmodule FraytElixir.CustomContracts.DefaultTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.Shipment
  alias FraytElixir.Shipment.VehicleClass
  alias FraytElixir.CustomContracts.Default

  defp check_base_price(
         vehicle_class,
         service_level,
         distance,
         stop_index
       ) do
    service_level =
      Shipment.get_attribute(:service_levels)
      |> Enum.find(&(elem(&1, 1) == service_level))
      |> elem(0)

    vehicle_class = VehicleClass.get_attribute(vehicle_class, :vehicle_class)

    match =
      insert(:match,
        vehicle_class: vehicle_class,
        service_level: service_level,
        total_distance: distance,
        match_stops: [build(:match_stop, index: stop_index, distance: distance)]
      )

    case Default.calculate_pricing(match) do
      %Changeset{valid?: true} = changeset ->
        base_price =
          Changeset.get_field(changeset, :match_stops) |> List.last() |> Map.get(:base_price)

        {:ok, base_price}

      changeset ->
        assert %Changeset{changes: %{match_stops: stops}} = changeset

        assert %Changeset{errors: [{field, {message, meta}}]} = List.last(stops)
        {:error, field, message, meta}
    end
  end

  describe "calculate_pricing" do
    test "for car" do
      assert {:ok, 28_34} == check_base_price(:car, :dash, 9, 1)
      assert {:ok, 49_14} == check_base_price(:car, :dash, 23, 1)
      assert {:ok, 156_34} == check_base_price(:car, :dash, 100, 1)
      assert {:ok, 221_36} == check_base_price(:car, :dash, 151, 1)

      assert {:ok, 22_67} == check_base_price(:car, :same_day, 9, 1)
      assert {:ok, 39_31} == check_base_price(:car, :same_day, 23, 1)
      assert {:ok, 124_87} == check_base_price(:car, :same_day, 100, 1)

      assert {:error, :distance, "cannot be over %{limit} miles",
              [validation: :mile_limit, limit: 100]} ==
               check_base_price(:car, :same_day, 101, 1)

      assert {:ok, 35_10} == check_base_price(:car, :dash, 23, 5)
      assert {:ok, 17_60} == check_base_price(:car, :dash, 9, 5)
    end

    test "for midsize" do
      assert {:ok, 38_84} == check_base_price(:midsize, :dash, 9, 1)
      assert {:ok, 63_54} == check_base_price(:midsize, :dash, 23, 1)
      assert {:ok, 190_84} == check_base_price(:midsize, :dash, 100, 1)
      assert {:ok, 268_06} == check_base_price(:midsize, :dash, 151, 1)

      assert {:ok, 31_07} == check_base_price(:midsize, :same_day, 9, 1)
      assert {:ok, 50_83} == check_base_price(:midsize, :same_day, 23, 1)
      assert {:ok, 152_87} == check_base_price(:midsize, :same_day, 100, 1)

      assert {:error, :distance, "cannot be over %{limit} miles",
              [validation: :mile_limit, limit: 100]} ==
               check_base_price(:midsize, :same_day, 101, 1)

      assert {:ok, 20_70} == check_base_price(:midsize, :dash, 9, 5)
      assert {:ok, 41_70} == check_base_price(:midsize, :dash, 23, 5)
    end

    test "for cargo van" do
      assert {:ok, 58_79} == check_base_price(:cargo_van, :dash, 9, 1)
      assert {:ok, 91_94} == check_base_price(:cargo_van, :dash, 23, 1)
      assert {:ok, 262_79} == check_base_price(:cargo_van, :dash, 100, 1)
      assert {:ok, 366_42} == check_base_price(:cargo_van, :dash, 151, 1)

      assert {:ok, 47_03} == check_base_price(:cargo_van, :same_day, 9, 1)
      assert {:ok, 73_55} == check_base_price(:cargo_van, :same_day, 23, 1)
      assert {:ok, 210_13} == check_base_price(:cargo_van, :same_day, 100, 1)

      assert {:error, :distance, "cannot be over %{limit} miles",
              [validation: :mile_limit, limit: 100]} ==
               check_base_price(:cargo_van, :same_day, 101, 1)

      assert {:ok, 26_90} ==
               check_base_price(:cargo_van, :dash, 9, 5)

      assert {:ok, 54_90} ==
               check_base_price(:cargo_van, :dash, 23, 5)
    end

    test "for box truck" do
      assert {:ok, 203_00} == check_base_price(:box_truck, :dash, 1, 1)
      assert {:ok, 269_00} == check_base_price(:box_truck, :dash, 23, 1)
      assert {:ok, 540_00} == check_base_price(:box_truck, :dash, 100, 1)
      assert {:ok, 1_239_50} == check_base_price(:box_truck, :dash, 501, 1)

      assert {:ok, 26_25} ==
               check_base_price(:box_truck, :dash, 1, 5)

      assert {:ok, 80_25} ==
               check_base_price(:box_truck, :dash, 23, 5)
    end
  end

  describe "include_tolls?" do
    test "returns true for dash" do
      match = insert(:match, service_level: 1)

      assert Default.include_tolls?(match)
    end

    test "returns true for same day" do
      match = insert(:match, service_level: 2)

      assert Default.include_tolls?(match)
    end
  end
end
