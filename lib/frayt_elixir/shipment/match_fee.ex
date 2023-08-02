defmodule FraytElixir.Shipment.MatchFee do
  use FraytElixir.Schema
  import Ecto.Changeset

  alias FraytElixir.Shipment.Match
  alias FraytElixir.Shipment.MatchFeeType

  schema "match_fees" do
    field :amount, :integer
    field :description, :string
    field :driver_amount, :integer
    field :type, MatchFeeType.Type
    belongs_to :match, Match

    timestamps()
  end

  @doc false
  def changeset(match_fee, attrs) do
    match_fee
    |> cast(attrs, [:amount, :driver_amount, :type, :description])
    |> validate_required([:amount, :driver_amount, :type])
  end
end
