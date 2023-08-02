defmodule FraytElixir.GeocodedAddressHelper do
  alias FraytElixir.Cache
  alias Ecto.Association.NotLoaded
  alias FraytElixir.Shipment.Address
  alias FraytElixir.Repo

  def get_geocoded_address(address) do
    case Cache.get({:geocode_cache, address}) do
      nil ->
        if address in ["", nil] do
          {:error, "INVALID_REQUEST"}
        else
          geocoder = Application.get_env(:frayt_elixir, :geocoder, &GoogleMaps.geocode/1)

          with {_, result} <- geocoder.(address) do
            if is_map(result) do
              unless Map.get(result, "partial_match", false),
                do: Cache.put({:geocode_cache, address}, {:ok, result})
            end

            {:ok, result}
          end
        end

      cached_address ->
        cached_address
    end
  end

  def get_timezone(%{origin_address: %NotLoaded{}} = match),
    do: match |> Repo.preload(:origin_address) |> get_timezone()

  def get_timezone(%{
        origin_address: %Address{geo_location: %{coordinates: {_, _} = coordinates}}
      }),
      do: get_timezone(coordinates)

  def get_timezone({lng, lat} = coordinates) do
    case Cache.get({:timezone_cache, coordinates}) do
      nil ->
        get_timezone =
          Application.get_env(:frayt_elixir, :timezone_finder, &GoogleMaps.timezone/2)

        case get_timezone.({lat, lng}, []) do
          {:ok, result} ->
            Cache.put({:timezone_cache, coordinates}, result["timeZoneId"])

            result["timeZoneId"]

          _ ->
            "UTC"
        end

      timezone ->
        timezone
    end
  end
end
