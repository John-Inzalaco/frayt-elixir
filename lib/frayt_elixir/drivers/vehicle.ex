defmodule FraytElixir.Drivers.Vehicle do
  use FraytElixir.Schema

  alias FraytElixir.Drivers.{Driver, VehicleDocument}

  schema "vehicles" do
    field :license_plate, :string
    field :make, :string
    field :model, :string
    field :vehicle_class, :integer
    field :vin, :string
    field :year, :integer

    field :cargo_area_width, :integer
    field :cargo_area_height, :integer
    field :cargo_area_length, :integer
    field :door_width, :integer
    field :door_height, :integer
    field :wheel_well_width, :integer
    field :max_cargo_weight, :integer
    field :lift_gate, :boolean, default: false
    field :pallet_jack, :boolean, default: false
    belongs_to :driver, Driver
    has_many :images, VehicleDocument, on_delete: :nothing

    timestamps()
  end

  @allowed_fields ~w(make model year vin vehicle_class license_plate cargo_area_width
    cargo_area_length cargo_area_height wheel_well_width max_cargo_weight
    door_width door_height lift_gate pallet_jack driver_id
  )a

  @doc false
  def changeset(vehicle, attrs) do
    vehicle
    |> cast(attrs, @allowed_fields)
    |> validate_required([:make, :model, :year, :vin, :vehicle_class, :license_plate])
    |> validate_box_trucks()
  end

  def admin_changeset(vehicle, attrs) do
    vehicle
    |> cast(attrs, [
      :make,
      :model,
      :year,
      :vin,
      :vehicle_class,
      :license_plate,
      :cargo_area_width,
      :cargo_area_length,
      :cargo_area_height,
      :wheel_well_width,
      :max_cargo_weight,
      :door_width,
      :door_height,
      :lift_gate,
      :pallet_jack
    ])
    |> validate_box_trucks()
  end

  def applying_driver_changeset(vehicle, attrs) do
    vehicle
    |> cast(attrs, @allowed_fields)
    |> validate_required([:vehicle_class])
  end

  def cargo_capacity_changeset(vehicle, attrs) do
    vehicle
    |> cast(attrs, [
      :cargo_area_width,
      :cargo_area_length,
      :cargo_area_height,
      :door_width,
      :door_height,
      :wheel_well_width,
      :max_cargo_weight,
      :lift_gate,
      :pallet_jack
    ])
    |> validate_required([:cargo_area_width, :cargo_area_length, :cargo_area_height])
    |> validate_box_trucks()
  end

  defp validate_box_trucks(changeset) do
    lift_gate = get_field(changeset, :lift_gate)
    pallet_jack = get_field(changeset, :pallet_jack)
    vehicle_class = get_field(changeset, :vehicle_class)

    cond do
      vehicle_class == 4 ->
        changeset

      lift_gate ->
        add_error(changeset, :lift_gate, "vehicle class does not have a lift gate",
          validation: :lift_gate_excluded
        )

      pallet_jack ->
        add_error(changeset, :pallet_jack, "vehicle class does not allow pallet jacks",
          validation: :pallet_jack_excluded
        )

      true ->
        changeset
    end
  end

  def document_changeset(vehicle, attrs) do
    vehicle
    |> cast(attrs, [])
    |> cast_assoc(:images)
  end
end
