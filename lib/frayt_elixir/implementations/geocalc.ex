defimpl Geocalc.Point, for: Geo.Point do
  def latitude(%Geo.Point{coordinates: {_, lat}}), do: lat
  def longitude(%Geo.Point{coordinates: {lng, _}}), do: lng
end
