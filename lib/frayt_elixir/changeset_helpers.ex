defmodule FraytElixir.ChangesetHelpers do
  import Ecto.Changeset

  def cast_from_form(changeset, attrs, fields, opts \\ []) do
    {empty_values, opts} = Keyword.pop(opts, :empty_values, [""])

    attrs = build_attrs_from_form(attrs, empty_values)

    cast(changeset, attrs, fields, opts)
  end

  defp build_attrs_from_form(params, empty_values) do
    params
    |> Enum.map(fn {key, value} ->
      {key, filter_empty_values(value, empty_values)}
    end)
    |> Enum.into(%{})
  end

  defp filter_empty_values(list, empty_values) when is_list(list),
    do: Enum.reject(list, &(&1 in empty_values))

  defp filter_empty_values(list, _empty_values), do: list
end
