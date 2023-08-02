defmodule FraytElixir.Drivers.DriverDocument do
  use FraytElixir.Schema
  use Waffle.Ecto.Schema

  alias FraytElixir.Photo
  alias FraytElixir.Drivers.{Driver, DriverDocumentType}
  alias FraytElixir.Document.State

  schema "driver_documents" do
    field :type, DriverDocumentType.Type
    field :document, Photo.Type
    field :state, State.Type, default: :pending_approval
    field :notes, :string
    field :expires_at, :date

    belongs_to :driver, Driver

    timestamps()
  end

  @allowed_fields ~w(type notes state expires_at driver_id)a

  @doc false
  def changeset(driver_document, attrs) do
    driver_document
    |> cast(attrs, @allowed_fields)
    |> cast_attachments(attrs, [:document])
    |> validate_required([:type, :driver_id, :document])
    |> validate_required_when(:expires_at, [{:type, :equal_to, :license}])
  end
end
