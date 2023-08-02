defmodule FraytElixir.AtomizeKeys do
  def atomize_keys(%{__struct__: _} = map), do: map

  def atomize_keys(map) when is_map(map),
    do:
      Map.new(map, fn {k, v} ->
        {
          atomize_key(k),
          atomize_keys(v)
        }
      end)

  def atomize_keys(list) when is_list(list), do: Enum.map(list, &atomize_keys(&1))
  def atomize_keys(map), do: map

  defp atomize_key(key) when is_bitstring(key), do: String.to_atom(key)
  defp atomize_key(key), do: key
end
