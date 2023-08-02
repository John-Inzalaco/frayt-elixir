defmodule FraytElixir.DistanceConversion do
  def miles_to_meters(miles) when is_binary(miles) do
    case Float.parse(miles) do
      {parsed_miles, _} -> miles_to_meters(parsed_miles)
      :error -> raise "Could not convert #{miles} to a float"
    end
  end

  def miles_to_meters(miles) when is_integer(miles),
    do: (miles / 1) |> miles_to_meters()

  def miles_to_meters(miles), do: miles * 1609.34
end
