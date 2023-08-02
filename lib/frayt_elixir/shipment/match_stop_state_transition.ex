defmodule FraytElixir.Shipment.MatchStopStateTransition do
  use FraytElixir.Schema
  import Ecto.Query, only: [from: 2]
  alias FraytElixir.Shipment.{MatchStop, MatchStopState}
  alias FraytElixir.Drivers.DriverLocation

  schema "match_stop_state_transitions" do
    field :from, MatchStopState.Type
    field :to, MatchStopState.Type
    field :notes, :string
    field :driver_location_inserted_at, :naive_datetime
    belongs_to :driver_location, DriverLocation
    belongs_to :match_stop, MatchStop

    timestamps()
  end

  def get_delivered_at_date(match_id),
    do:
      from(state in __MODULE__,
        where: state.match_id == ^match_id and state.to == "delivered",
        order_by: [desc: state.inserted_at],
        distinct: state.to,
        select: state.inserted_at
      )
      |> FraytElixir.Repo.one()

  def get_latest(match_stop_id),
    do:
      from(state in __MODULE__,
        where: state.match_stop_id == ^match_stop_id,
        order_by: [desc: state.inserted_at],
        limit: 1
      )
      |> FraytElixir.Repo.one()

  @optional ~w(notes driver_location_id driver_location_inserted_at)a
  @required ~w(from to match_stop_id)a

  @doc false
  def changeset(state_transition, attrs) do
    state_transition
    |> cast(attrs, @optional ++ @required)
    |> validate_required(@required)
  end
end
