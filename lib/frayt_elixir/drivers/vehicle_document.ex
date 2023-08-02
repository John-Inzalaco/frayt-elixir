defmodule FraytElixir.Drivers.VehicleDocument do
  use FraytElixir.Schema
  use Waffle.Ecto.Schema

  alias FraytElixir.Photo
  alias FraytElixir.Drivers.{Vehicle, VehicleDocumentType}
  alias FraytElixir.Document.State

  schema "vehicle_documents" do
    field :type, VehicleDocumentType.Type
    field :document, Photo.Type
    field :state, State.Type
    field :notes, :string
    field :expires_at, :date

    belongs_to :vehicle, Vehicle

    timestamps()
  end

  @allowed_fields ~w(type notes expires_at vehicle_id state)a

  @doc false
  def changeset(vehicle, attrs) do
    vehicle
    |> cast(attrs, @allowed_fields)
    |> cast_attachments(attrs, [:document])
    |> validate_required([:type, :vehicle_id, :document])
    |> validate_required_when(:expires_at, [{:type, :equal_to, :insurance}])
    |> validate_required_when(:expires_at, [{:type, :equal_to, :registration}])
  end
end
