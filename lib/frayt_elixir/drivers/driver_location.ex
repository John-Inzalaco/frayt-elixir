defmodule FraytElixir.Drivers.DriverLocation do
  use FraytElixir.Schema

  alias FraytElixir.Drivers.Driver

  schema "driver_locations" do
    field :geo_location, Geo.PostGIS.Geometry
    field :formatted_address, :string
    belongs_to :driver, Driver

    timestamps()
  end

  @required [:geo_location, :driver_id, :inserted_at]

  @doc false
  def changeset(driver_location, attrs) do
    driver_location
    |> cast(attrs, @required)
    |> validate_required(@required)
  end
end
