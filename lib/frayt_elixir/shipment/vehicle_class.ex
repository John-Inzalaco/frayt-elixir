defmodule FraytElixir.Shipment.VehicleClass do
  @type vehicle_class_type :: :car | :midsize | :cargo_van | :box_truck

  @vehicles %{
    1 => %{
      vehicle_class: 1,
      type: :car,
      max_volume: 16,
      max_weight: 250,
      max_length: 48,
      load_time: 10 * 60
    },
    2 => %{
      vehicle_class: 2,
      type: :midsize,
      max_volume: 45,
      max_weight: 500,
      max_length: 72,
      load_time: 15 * 60
    },
    3 => %{
      vehicle_class: 3,
      type: :cargo_van,
      max_volume: 150,
      max_weight: 2_000,
      max_length: 120,
      load_time: 20 * 60
    },
    4 => %{
      vehicle_class: 4,
      type: :box_truck,
      max_volume: 1_000,
      max_weight: 10_000,
      max_length: 312,
      load_time: 30 * 60
    }
  }

  def get_attribute(vehicle_class, attribute_name \\ nil)

  def get_attribute(vehicle_class, nil)
      when is_number(vehicle_class) and vehicle_class > 0 and vehicle_class < 5 do
    @vehicles
    |> Map.get(vehicle_class)
  end

  def get_attribute(vehicle_class, nil) when is_atom(vehicle_class) do
    @vehicles
    |> Enum.find({nil, %{}}, fn {_k, v} -> Map.get(v, :type) == vehicle_class end)
    |> elem(1)
  end

  def get_attribute(vehicle_class, attribute_name)
      when is_atom(vehicle_class) and is_atom(attribute_name) do
    get_attribute(vehicle_class, nil)
    |> Map.get(attribute_name)
  end

  def get_attribute(vehicle_class, attribute_name)
      when (is_atom(attribute_name) or
              is_binary(attribute_name)) and is_number(vehicle_class) and vehicle_class > 0 and
             vehicle_class < 5 do
    get_attribute(vehicle_class, nil)
    |> Map.get(attribute_name)
  end

  def get_attribute(_, _), do: nil

  def get_vehicle_by_volume(volume, field \\ :vehicle_class),
    do: get_vehicle_by(:max_volume, volume / 1728, field)

  def get_vehicle_by_weight(weight, field \\ :vehicle_class),
    do: get_vehicle_by(:max_weight, weight, field)

  def get_vehicle_by_dimensions(dimension, field \\ :vehicle_class),
    do: get_vehicle_by(:max_length, dimension, field)

  defp get_vehicle_by(filter, nil, field), do: get_vehicle_by(filter, 0, field)

  defp get_vehicle_by(filter, amount, field) do
    @vehicles
    |> Enum.find({nil, %{}}, fn {_k, v} -> amount <= Map.get(v, filter) end)
    |> elem(1)
    |> Map.get(field)
  end

  def get_vehicles do
    @vehicles
    |> Enum.reduce(%{}, fn {_k, %{vehicle_class: vehicle_class, type: type}}, acc ->
      Map.put(acc, vehicle_class, type)
    end)
  end

  def select_options do
    Enum.map(@vehicles, fn {value, v} ->
      label = FraytElixirWeb.DisplayFunctions.title_case(v.type)
      {label, value}
    end)
  end
end
