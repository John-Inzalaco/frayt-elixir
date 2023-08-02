defmodule FraytElixir.Shipment.Contact do
  use FraytElixir.Schema
  import Ecto.Changeset
  alias FraytElixir.Type.PhoneNumber

  schema "contacts" do
    field :email, :string
    field :name, :string
    field :notify, :boolean, default: true
    field :phone_number, PhoneNumber

    timestamps()
  end

  @doc false
  def changeset(contact, attrs) do
    contact
    |> cast(attrs, [:name, :phone_number, :email, :notify])
    |> validate_required([:name, :notify])
    |> validate_required_when(:email, [
      {:phone_number, :equal_to, nil},
      {:notify, :equal_to, true}
    ])
    |> validate_required_when(:phone_number, [
      {:email, :equal_to, nil},
      {:notify, :equal_to, true}
    ])
    |> validate_phone_number(:phone_number)
  end
end
