defmodule FraytElixir.MapConverter do
  def convert_key_value_to!(map, type, key),
    do: convert_key_value_to(map, type, key, delete_err: true)

  def convert_key_value_to(map, type, key), do: convert_key_value_to(map, type, key, [])

  def convert_key_value_to(map, type, [head | tail], opts) do
    map = convert_key_value_to(map, type, head, opts)
    convert_key_value_to(map, type, tail, opts)
  end

  def convert_key_value_to(map, _type, [], _opts), do: map

  def convert_key_value_to(map, type, key, opts) do
    opts = opts |> Enum.into(%{})
    delete_err = Map.get(opts, :delete_err, false)

    if Map.has_key?(map, key) do
      case safe_convert_value_to(type, map[key]) do
        {:ok, converted_val} -> Map.put(map, key, converted_val)
        :error -> if delete_err, do: Map.delete(map, key), else: map
      end
    else
      map
    end
  end

  defp safe_convert_value_to(type, str) do
    try do
      {:ok, convert_value_to(type, str)}
    rescue
      ArgumentError -> :error
    end
  end

  defp convert_value_to(:atom, str), do: String.to_existing_atom(str)

  defp convert_value_to(:integer, str), do: String.to_integer(str)
end
