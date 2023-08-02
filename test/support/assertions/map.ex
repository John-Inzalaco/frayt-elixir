defmodule FraytElixir.Assertions.Map do
  import ExUnit.Assertions

  def assert_copy(new, orig, opts \\ []) do
    ignore = Keyword.get(opts, :ignore, [])
    ignore_recursively = Keyword.get(opts, :ignore_recursive, [])

    new =
      new
      |> ignore_keys(ignore)
      |> ignore_keys_recursively(ignore_recursively)

    orig =
      orig
      |> ignore_keys(ignore)
      |> ignore_keys_recursively(ignore_recursively)

    assert new == orig
  end

  defp ignore_keys(map, keys) do
    map
    |> Enum.map(fn {key, value} ->
      {key, key in keys || value}
    end)
  end

  defp ignore_keys_recursively(map, keys) when length(keys) > 0 do
    map
    |> ignore_keys(keys)
    |> Enum.map(fn {key, value} ->
      {key, ignore_child_keys(value, keys)}
    end)
    |> Enum.into(%{})
  end

  defp ignore_keys_recursively(map, _), do: map

  defp ignore_child_keys(map, keys) when is_map(map), do: ignore_keys_recursively(map, keys)

  defp ignore_child_keys(list, keys) when is_list(list),
    do: Enum.map(list, &ignore_child_keys(&1, keys))

  defp ignore_child_keys(value, _keys), do: value
end
