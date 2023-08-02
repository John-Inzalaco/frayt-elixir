defmodule FraytElixir.Devices.DriverDevice do
  @moduledoc """
  Our Driver devices struct.
  """
  use FraytElixir.Schema

  alias FraytElixir.Drivers.Driver

  schema "driver_devices" do
    field :device_uuid, :string
    field :device_model, :string
    field :player_id, :string
    field :os, :string
    field :os_version, :string
    field :is_tablet, :boolean
    field :is_location_enabled, :boolean
    field :app_build_number, :integer
    field :app_version, :string
    field :app_revision, :string

    belongs_to :driver, Driver

    timestamps()
  end

  @optional ~w(app_revision)a
  @required ~w(driver_id device_uuid device_model player_id os os_version is_tablet is_location_enabled app_build_number app_version)a

  @doc false
  def changeset(changeset, attrs) do
    changeset
    |> cast(attrs, @optional ++ @required)
    |> validate_required(@required)
    |> validate_length(:device_model, max: 40)
    |> validate_length(:os, max: 40)
    |> validate_length(:os_version, max: 40)
    |> foreign_key_constraint(:driver_id)
  end
end
