defmodule FraytElixir.Shipment.HiddenMatch do
  use FraytElixir.Schema
  alias FraytElixir.Shipment.Match
  alias FraytElixir.Drivers.Driver

  schema "hidden_matches" do
    field :reason, :string
    field :type, :string

    belongs_to :match, Match
    belongs_to :driver, Driver

    timestamps()
  end

  def changeset(match, attrs) do
    match
    |> cast(attrs, [:driver_id, :reason, :type, :match_id])
    |> validate_required([:type])
    |> validate_required_when(:reason, [{:type, :equal_to, "driver_cancellation"}],
      message: "can't be blank"
    )
    |> validate_length(:reason, max: 500)
    |> foreign_key_constraint(:driver_id)
    |> foreign_key_constraint(:match_id)
  end
end
