defmodule FraytElixir.Shipment.Address do
  use FraytElixir.Schema
  alias Ecto.Changeset
  alias FraytElixir.GeocodedAddressHelper
  alias FraytElixir.Shipment.Address
  alias FraytElixir.Convert

  @states [
    {"AL", "Alabama"},
    {"AK", "Alaska"},
    {"AZ", "Arizona"},
    {"AR", "Arkansas"},
    {"CA", "California"},
    {"CO", "Colorado"},
    {"CT", "Connecticut"},
    {"DE", "Delaware"},
    {"DC", "District of Columbia"},
    {"FL", "Florida"},
    {"GA", "Georgia"},
    {"HI", "Hawaii"},
    {"ID", "Idaho"},
    {"IL", "Illinois"},
    {"IN", "Indiana"},
    {"IA", "Iowa"},
    {"KS", "Kansas"},
    {"KY", "Kentucky"},
    {"LA", "Louisiana"},
    {"ME", "Maine"},
    {"MD", "Maryland"},
    {"MA", "Massachusetts"},
    {"MI", "Michigan"},
    {"MN", "Minnesota"},
    {"MS", "Mississippi"},
    {"MO", "Missouri"},
    {"MT", "Montana"},
    {"NE", "Nebraska"},
    {"NV", "Nevada"},
    {"NH", "New Hampshire"},
    {"NJ", "New Jersey"},
    {"NM", "New Mexico"},
    {"NY", "New York"},
    {"NC", "North Carolina"},
    {"ND", "North Dakota"},
    {"OH", "Ohio"},
    {"OK", "Oklahoma"},
    {"OR", "Oregon"},
    {"PA", "Pennsylvania"},
    {"PR", "Puerto Rico"},
    {"RI", "Rhode Island"},
    {"SC", "South Carolina"},
    {"SD", "South Dakota"},
    {"TN", "Tennessee"},
    {"TX", "Texas"},
    {"UT", "Utah"},
    {"VT", "Vermont"},
    {"VA", "Virginia"},
    {"VI", "Virgin Islands"},
    {"WA", "Washington"},
    {"WV", "West Virginia"},
    {"WI", "Wisconsin"},
    {"WY", "Wyoming"}
  ]
  @state_codes Enum.map(@states, &elem(&1, 0))

  @countries [{"US", "United States"}]

  @country_codes Enum.map(@countries, &elem(&1, 0))

  schema "addresses" do
    field :geo_location, Geo.PostGIS.Geometry
    field :formatted_address, :string
    field :address, :string
    field :address2, :string
    field :neighborhood, :string
    field :city, :string
    field :county, :string
    field :state, :string
    field :state_code, :string
    field :zip, :string
    field :place_id, :string
    field :country_code, :string, default: "US"
    field :country, :string, default: "United States"
    field :name, :string

    timestamps()
  end

  def format_address_changeset(
        %{city: city, state_code: state, zip: zip, address: address1, address2: address2} =
          address
      )
      when not is_nil(address2) do
    changeset(address, %{
      formatted_address: "#{address1} #{address2}, #{city}, #{state} #{zip}"
    })
  end

  def format_address_changeset(
        %{city: city, state_code: state, zip: zip, address: address1} = address
      ) do
    changeset(address, %{
      formatted_address: "#{address1}, #{city}, #{state} #{zip}"
    })
  end

  def admin_geocoding_changeset(address, attrs) do
    address
    |> cast(from_geocoding(attrs), [
      :address,
      :geo_location,
      :address2,
      :city,
      :state,
      :zip,
      :country,
      :county,
      :country_code,
      :neighborhood,
      :formatted_address,
      :name
    ])
    |> validate_required([:address, :city, :state, :zip, :formatted_address, :geo_location])
  end

  def geocoding_changeset(
        address,
        attrs
      ) do
    changeset(
      address,
      from_geocoding(attrs)
    )
  end

  def assoc_address(%Changeset{params: attrs} = changeset, record, key) do
    place_id = get_place_id(attrs, key)
    address = get_address_struct(record, attrs, key)

    cond do
      is_struct(address) ->
        put_assoc(changeset, key, address)

      is_nil(address) && is_nil(place_id) ->
        changeset

      is_map(address) ->
        attrs =
          if has_geo_location?(address) do
            address
          else
            Address.from_geocoding(address)
          end

        cast_address(changeset, key, attrs)

      true ->
        attrs = Address.from_geocoding(address, place_id)

        cast_address(changeset, key, attrs)
    end
  end

  defp get_place_id(attrs, key) do
    case key do
      :origin_address -> Map.get(attrs, "origin_place_id")
      :destination_address -> Map.get(attrs, "destination_place_id")
      :address -> Map.get(attrs, "place_id")
    end
  end

  defp get_address_struct(record, attrs, key) do
    address = Map.get(attrs, Atom.to_string(key))

    case Map.get(record, key) do
      %Address{formatted_address: ^address} = old_address ->
        old_address

      _ ->
        address
    end
  end

  defp has_geo_location?(attrs) do
    cs = changeset(%Address{}, attrs)

    geo = get_field(cs, :geo_location)

    is_struct(geo, Geo.Point)
  end

  defp cast_address(%Changeset{data: data} = changeset, key, attrs) do
    updated_changeset =
      data
      |> cast(%{key => attrs}, [])
      |> cast_assoc(key, required: true)

    merge(changeset, updated_changeset)
  end

  def from_geocoding(address, place_id) when not is_nil(place_id) do
    case from_geocoding("place_id:#{place_id}") do
      %{geo_location: _} = result -> result
      _ -> from_geocoding(address)
    end
  end

  def from_geocoding(address, _), do: from_geocoding(address)

  def from_geocoding(%{address: %{error: "Address is invalid"}}),
    do: %{address: %{error: "Address is invalid"}}

  def from_geocoding(%{id: id} = attrs),
    do: attrs |> Map.drop([:id]) |> from_geocoding() |> Map.put(:id, id)

  def from_geocoding(%{city: city, state: state, zip: zip, address: address_line1} = attrs) do
    address_line2 = Map.get(attrs, :address2, nil)

    from_geocoding(
      "#{address_line1}#{if address_line2, do: " #{address_line2}"}, #{city}, #{state} #{zip}"
    )
  end

  def from_geocoding(address) do
    case GeocodedAddressHelper.get_geocoded_address(address) do
      {:ok,
       %{
         "results" => [
           %{
             "address_components" => address_components,
             "formatted_address" => formatted_address,
             "place_id" => place_id,
             "geometry" => %{
               "location" => %{
                 "lat" => lat,
                 "lng" => lng
               }
             }
           }
           | _
         ]
       }} ->
        locality = address_components |> get_address_component("locality")
        admin_area_l3 = address_components |> get_address_component("administrative_area_level_3")
        sublocality_l1 = address_components |> get_address_component("sublocality_level_1")
        neighborhood = address_components |> get_address_component("neighborhood")

        city =
          cond do
            not is_nil(locality) -> locality
            not is_nil(admin_area_l3) -> admin_area_l3
            not is_nil(sublocality_l1) -> sublocality_l1
            true -> neighborhood
          end

        %{
          address:
            "#{address_components |> get_address_component("street_number")} #{address_components |> get_address_component("route")}",
          geo_location: %Geo.Point{coordinates: {lng, lat}},
          address2: address_components |> get_address_component("subpremise"),
          city: city,
          state:
            address_components
            |> get_address_component("administrative_area_level_1"),
          state_code:
            address_components
            |> get_address_component("administrative_area_level_1", :short),
          zip: address_components |> get_address_component("postal_code"),
          county:
            address_components
            |> get_address_component("administrative_area_level_2"),
          neighborhood: neighborhood,
          country: address_components |> get_address_component("country"),
          country_code: address_components |> get_address_component("country", :short),
          formatted_address: formatted_address,
          place_id: place_id
        }

      _ ->
        %{address: %{error: "Address is invalid"}}
    end
  end

  def get_state_attrs(nil), do: %{}

  def get_state_attrs(state) do
    case String.length(state) do
      2 -> %{state_code: state, state: get_state(state, :name)}
      _ -> %{state_code: get_state(state, :abbr), state: state}
    end
  end

  @allowed_fields ~w(address address2 state city state_code
    place_id zip country county neighborhood country_code
    formatted_address name)a

  @doc false
  def changeset(address, %{address: %{error: error}}) do
    address
    |> change()
    |> add_error(:address, error)
  end

  def changeset(address, attrs) do
    address
    |> cast(attrs, @allowed_fields)
    |> cast_geo_location()
    |> validate_inclusion(:state_code, @state_codes)
    |> maybe_populate_state()
    |> validate_inclusion(:country_code, @country_codes)
    |> maybe_populate_country()
    |> maybe_update_formatted_address()
    |> validate_required([:address, :city, :state])
  end

  def invite_shipper_changeset(address, attrs) do
    address
    |> cast(attrs, @allowed_fields)
    |> validate_inclusion(:state_code, @state_codes)
  end

  defp cast_geo_location(changeset) do
    attrs =
      case changeset.params do
        %{"lat" => lat, "lng" => lng} ->
          lat = Convert.to_float(lat)
          lng = Convert.to_float(lng)

          %{"geo_location" => %Geo.Point{coordinates: {lng, lat}}}

        attrs ->
          attrs
      end

    cast(changeset, attrs, [:geo_location])
  end

  defp maybe_update_formatted_address(changeset) do
    if get_change(changeset, :formatted_address) do
      changeset
    else
      address = get_field(changeset, :address)
      address2 = get_field(changeset, :address2)
      city = get_field(changeset, :city)
      state = get_field(changeset, :state)
      zip = get_field(changeset, :zip)

      changeset
      |> put_change(
        :formatted_address,
        "#{address}#{if address2, do: " #{address2}"}, #{city}, #{state} #{zip}"
      )
    end
  end

  defp maybe_populate_state(%Ecto.Changeset{changes: %{state_code: state_code}} = changeset) do
    if changeset.valid? do
      {_state_code, state} = Enum.find(@states, fn {k, _v} -> k == state_code end)

      changeset |> put_change(:state, state)
    else
      changeset
    end
  end

  defp maybe_populate_state(changeset), do: changeset

  defp maybe_populate_country(%Ecto.Changeset{changes: %{country_code: country_code}} = changeset)
       when changeset.valid? do
    country = Enum.find(@countries, fn {k, _v} -> k === country_code end)

    case country do
      {_country_code, country} -> changeset |> put_change(:country, country)
      _ -> changeset
    end
  end

  defp maybe_populate_country(changeset), do: changeset

  defp get_state(state, :abbr), do: get_state_by_pos(state, 0)

  defp get_state(state, :name),
    do: get_state_by_pos(state, 1)

  def get_state_by_pos(state, pos) do
    @states
    |> Enum.find(nil, fn s -> String.downcase(elem(s, abs(pos - 1))) == String.downcase(state) end)
    |> case do
      nil -> nil
      s -> elem(s, pos)
    end
  end

  defp get_address_component(fields, field, length \\ :long)

  defp get_address_component(fields, field, length) do
    fields
    |> find_address_component(field)
    |> get_name(length)
  end

  defp find_address_component(fields, field),
    do:
      fields
      |> Enum.find(fn v -> Enum.member?(v["types"], field) end)

  defp get_name(nil, _), do: nil
  defp get_name(map, :long), do: map |> Map.get("long_name")
  defp get_name(map, :short), do: map |> Map.get("short_name")

  def country_codes, do: @countries
  def state_codes, do: @states
end
