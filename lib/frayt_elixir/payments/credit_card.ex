defmodule FraytElixir.Payments.CreditCard do
  use FraytElixir.Schema
  import Ecto.Query, only: [from: 2]

  alias FraytElixir.Accounts.Shipper

  schema "credit_cards" do
    field :stripe_card, :string
    field :stripe_token, :string
    field :last4, :string
    belongs_to :shipper, Shipper

    timestamps()
  end

  @doc false
  def changeset(credit_card, attrs) do
    credit_card
    |> cast(attrs, [:stripe_token, :stripe_card, :shipper_id, :last4])
    |> validate_required([:stripe_card])
  end

  def where_shipper_is(%Shipper{id: shipper_id}) do
    from cc in __MODULE__,
      where: cc.shipper_id == type(^shipper_id, :binary_id)
  end
end
