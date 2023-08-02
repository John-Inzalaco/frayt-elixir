defmodule FraytElixir.VehiclesTest do
  use FraytElixir.DataCase
  use Bamboo.Test
  # import FraytElixir.Factory
  import FraytElixir.Shipment.VehicleClass

  test "get_attribute/2 gets the max cargo for a vehicle class" do
    assert 45 == get_attribute(2, :max_volume)
  end

  test "get_attribute/2 gets a vehicle by type name atom" do
    assert 150 = get_attribute(:cargo_van, :max_volume)
  end

  test "get_attribute/2 returns the full map when no field is given" do
    assert %{
             type: :car,
             vehicle_class: 1,
             max_volume: 16
           } = get_attribute(1)

    assert %{
             type: :car,
             vehicle_class: 1,
             max_volume: 16
           } = get_attribute(:car)
  end

  test "get_vehicle_by_volume/1 gets the integer vehicle class appropriate for a given volume" do
    assert 1 == get_vehicle_by_dimensions(nil)
    assert 1 == get_vehicle_by_volume(20)
  end

  test "get_vehicles/0 returns a key value map of classes and types" do
    assert %{1 => :car} = get_vehicles()
  end

  describe "get_vehicle_by_weight/2" do
    test "gets the appropriate integer vehicle class for car" do
      assert 1 == get_vehicle_by_dimensions(nil)
      assert 1 == get_vehicle_by_weight(250)
    end

    test "gets the appropriate integer vehicle class for midsize" do
      assert 2 == get_vehicle_by_weight(251)
      assert 2 == get_vehicle_by_weight(500)
    end

    test "gets the appropriate integer vehicle class for cargo van" do
      assert 3 == get_vehicle_by_weight(501)
      assert 3 == get_vehicle_by_weight(1500)
    end

    test "gets the appropriate integer vehicle class for box truck" do
      assert 4 == get_vehicle_by_weight(2001)
      assert 4 == get_vehicle_by_weight(10_000)
    end

    test "returns nil when too big" do
      refute get_vehicle_by_weight(10_001)
    end
  end

  describe "get_vehicle_by_dimensions/1" do
    test "gets the appropriate integer vehicle class for car" do
      assert 1 == get_vehicle_by_dimensions(nil)
      assert 1 == get_vehicle_by_dimensions(48)
    end

    test "gets the appropriate integer vehicle class for midsize" do
      assert 2 == get_vehicle_by_dimensions(49)
      assert 2 == get_vehicle_by_dimensions(72)
    end

    test "gets the appropriate integer vehicle class for cargo van" do
      assert 3 == get_vehicle_by_dimensions(73)
      assert 3 == get_vehicle_by_dimensions(120)
    end

    test "gets the appropriate integer vehicle class for box truck" do
      assert 4 == get_vehicle_by_dimensions(121)
      assert 4 == get_vehicle_by_dimensions(312)
    end

    test "returns nil when too big" do
      refute get_vehicle_by_dimensions(313)
    end
  end
end
