defmodule FraytElixir.SLAs.MatchSLA do
  use FraytElixir.Schema
  import Ecto.Changeset
  alias FraytElixir.Drivers.Driver
  alias FraytElixir.Shipment.Match
  alias FraytElixir.SLAs.SLAType

  schema "match_slas" do
    field :type, SLAType.Type
    field :start_time, :utc_datetime
    field :end_time, :utc_datetime
    field :completed_at, :utc_datetime

    belongs_to :match, Match
    belongs_to :driver, Driver, type: :binary_id

    timestamps()
  end

  @required ~w(type start_time end_time match_id)a
  @optional ~w(driver_id completed_at)a

  @doc false
  def changeset(match_sla, attrs) do
    cs = cast(match_sla, attrs, @required ++ @optional)

    cs
    |> validate_required(@required)
    |> validate_date_time(:start_time, less_than_or_equal_to: get_field(cs, :end_time))
    |> unique_constraint(:match_id_type_driver_id,
      message: "Only one SLA type per Driver's Match is allowed"
    )
    |> unique_constraint(:match_id_type,
      message: "Only one SLA type per Match is allowed"
    )
  end
end
