defmodule FraytElixir.MapDiff do
  defmodule Diff do
    defstruct o: nil, n: nil
  end

  @doc """
  When checking to see if the length of a list was changed, do [match_stops: nil]. To check if any contents of items in a list were changed, do: [match_stops: []]
  """

  def has_changed(orig, new, keys), do: get_changed_keys(orig, new) |> has_changed(keys)

  def has_changed(changes, keys) when is_list(keys) do
    check_changes(changes, keys, fn change, keys ->
      keys
      |> Enum.map(&has_changed(change, &1))
      |> Enum.find(false, & &1)
    end)
  end

  def has_changed(changes, {key, []}) do
    case Keyword.has_key?(changes, key) and is_nil(changes[key]) do
      true -> false
      false -> has_changed(changes, key)
    end
  end

  def has_changed(changes, {key, nil}),
    do: Keyword.has_key?(changes, key) and is_nil(changes[key])

  def has_changed(changes, {key, children}) do
    check_changes(changes, key, fn change, key ->
      Keyword.get(change, key)
      |> has_changed(children)
    end)
  end

  def has_changed(changes, key) when is_atom(key) or is_binary(key) do
    check_changes(changes, key, fn change, key ->
      Keyword.has_key?(change, key)
    end)
  end

  defp check_changes(changes, keys, func) when is_list(changes) do
    changes =
      if Keyword.keyword?(changes) do
        [changes]
      else
        changes
      end

    changes
    |> Enum.map(fn change ->
      case change do
        nil -> false
        change -> func.(change, keys)
      end
    end)
    |> Enum.find(false, & &1)
  end

  defp check_changes(_changes, _keys, _func),
    do: false

  def get_changed_keys(orig, new),
    do: get_changes(orig, new) |> get_changed_keys()

  def get_changed_keys(%Diff{o: _, n: _}), do: nil

  def get_changed_keys(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} -> {key, get_changed_keys(value)} end)
    |> case do
      [] -> nil
      keys -> keys
    end
  end

  def get_changed_keys(list) when is_list(list), do: Enum.map(list, &get_changed_keys(&1))

  def get_changes(orig, new) when is_list(orig) and is_list(new),
    do:
      new
      |> Enum.filter(&(orig[elem(&1, 0)] != elem(&1, 1)))
      |> Enum.map(&show_changes(elem(&1, 0), orig[elem(&1, 0)], elem(&1, 1)))
      |> Enum.into(%{})

  def get_changes(orig, new),
    do: get_changes(map_to_list(orig), map_to_list(new))

  defp show_changes(key, orig_val, new_val) do
    cond do
      is_list(new_val) && is_list(orig_val) && Enum.count(orig_val) == Enum.count(new_val) ->
        put_changes(
          key,
          new_val
          |> Enum.with_index()
          |> Enum.map(fn {new, index} ->
            show_changes(nil, Enum.at(orig_val, index), new)
          end)
        )

      is_map(new_val) && is_map(orig_val) ->
        put_changes(key, get_changes(orig_val, new_val))

      true ->
        put_changes(key, %Diff{o: orig_val, n: new_val})
    end
  end

  defp put_changes(nil, value), do: value
  defp put_changes(key, value), do: {key, value}

  defp map_to_list(%_{} = m), do: m |> Map.from_struct() |> Map.to_list()
  defp map_to_list(%{} = m), do: m |> Map.to_list()
end
