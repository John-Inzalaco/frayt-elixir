defmodule FraytElixir.Routing do
  alias FraytElixir.Matches
  alias FraytElixir.Shipment.{Match, MatchStop}

  def get_route(match) do
    try do
      {source, {d_long, d_lat}} = get_destination(match)

      {o_long, o_lat} = match.driver.current_location.geo_location.coordinates

      {:ok, [{o_lat, o_long}, {d_lat, d_long}], source, match}
    rescue
      error -> {:error, error, match}
    end
  end

  def get_routes(matches) do
    matches
    |> Enum.map(fn match -> get_route(match) end)
    |> Enum.reduce([routes: [], failed: []], fn route, [{_key1, routes}, {_key2, failed}] ->
      case route do
        {:ok, route, source, match} -> [routes: [{route, source, match} | routes], failed: failed]
        {:error, error, match} -> [routes: routes, failed: [{error, match} | failed]]
      end
    end)
  end

  defp get_destination(match) do
    case Matches.get_next_location(match) do
      {:ok, %Match{} = match} ->
        {:match_origin_addr, match.origin_address.geo_location.coordinates}

      {:ok, %MatchStop{} = stop} ->
        {:match_stop_dest_addr, stop.destination_address.geo_location.coordinates}

      {:error, message} ->
        raise message
    end
  end
end
