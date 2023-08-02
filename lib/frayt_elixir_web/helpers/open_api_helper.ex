defmodule FraytElixirWeb.OpenApiHelper do
  def params_to_map(%_{} = struct) do
    struct
    |> Map.from_struct()
    |> params_to_map()
  end

  def params_to_map(%{} = map) do
    map
    |> Enum.map(fn {key, value} ->
      {key,
       case value do
         value when is_map(value) or is_struct(value) -> params_to_map(value)
         values when is_list(values) -> Enum.map(values, &params_to_map(&1))
         value -> value
       end}
    end)
    |> Enum.into(%{})
  end
end
