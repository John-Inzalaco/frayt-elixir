defmodule FraytElixir.Utils do
  def map_keys(map, keymap) do
    Enum.reduce(keymap, %{}, fn {oldkey, newkey}, new_map ->
      new_map |> maybe_put(newkey, Map.get(map, oldkey))
    end)
  end

  def maybe_put(map, _key, nil), do: map
  def maybe_put(map, key, value), do: Map.put(map, key, value)

  def maybe_parse_phone(nil), do: nil

  def maybe_parse_phone(phone_number) do
    case ExPhoneNumber.parse(phone_number, "") do
      {:ok, phone_number} ->
        phone_number

      _ ->
        case phone_number == e164ify_phone(phone_number) do
          true -> phone_number
          false -> phone_number |> e164ify_phone() |> maybe_parse_phone()
        end
    end
  end

  defp e164ify_phone(phone_number) do
    phone_number = String.replace(phone_number, ~r/\D+/, "")

    case String.length(phone_number) do
      10 -> "+1" <> phone_number
      11 -> "+" <> phone_number
      _ -> phone_number
    end
  end

  def convert_changeset_error(cs) do
    Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  def vehicle_class_atom_to_integer(vehicle_class) when is_list(vehicle_class) do
    Enum.map(vehicle_class, &vehicle_class_atom_to_integer(&1))
  end

  def vehicle_class_atom_to_integer(vehicle_class) do
    case vehicle_class do
      :car -> 1
      :midsize -> 2
      :cargo_van -> 3
      :box_truck -> 4
    end
  end

  def vehicle_class_integer_to_atom(vehicle_class) do
    case vehicle_class do
      1 -> :car
      2 -> :midsize
      3 -> :cargo_van
      4 -> :box_truck
    end
  end
end
