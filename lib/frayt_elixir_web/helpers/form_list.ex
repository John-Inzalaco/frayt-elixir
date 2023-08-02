defmodule FraytElixirWeb.Helpers.FormList do
  import EctoNestedChangeset

  def add_item(changeset, form, field, value) do
    path = get_changeset_path(form, [field])
    append_at(changeset, path, convert_to_map(value))
  end

  def remove_item(changeset, form, field, index) do
    [path] = get_changeset_path(form, [field])
    delete_at(changeset, [path, index])
  end

  def convert_to_map(%model{} = schema) do
    Map.take(schema, model.__schema__(:fields))
  end

  def swap_items(changeset, form, field, {index1, index2}) do
    path = get_changeset_path(form, [field])

    update_at(changeset, path, fn list ->
      list
      |> List.replace_at(index1, Enum.at(list, index2))
      |> List.replace_at(index2, Enum.at(list, index1))
    end)
  end

  defp get_changeset_path(form, field_keys) do
    keys =
      Regex.scan(~r/\[([a-zA-Z0-9_]+)\]/, form.name)
      |> Enum.map(fn match ->
        key = Enum.at(match, 1)

        try do
          String.to_integer(key)
        rescue
          _ -> String.to_existing_atom(key)
        end
      end)

    keys ++ field_keys
  end
end
