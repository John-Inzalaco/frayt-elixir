defmodule FraytElixir.Shipment.MatchStateTransition do
  use FraytElixir.Schema
  import Ecto.Query, only: [from: 2]
  alias FraytElixir.Shipment.Match
  alias FraytElixir.Drivers.DriverLocation
  alias FraytElixir.Shipment.MatchState
  alias FraytElixir.Shipment

  schema "match_state_transitions" do
    field :from, MatchState.Type
    field :to, MatchState.Type
    field :notes, :string
    field :driver_location_inserted_at, :naive_datetime
    field :code, :string
    belongs_to :driver_location, DriverLocation
    belongs_to :match, Match

    timestamps()
  end

  def get_latest(match_id),
    do:
      from(state in __MODULE__,
        where: state.match_id == ^match_id,
        order_by: [desc: state.inserted_at],
        limit: 1
      )
      |> FraytElixir.Repo.one()

  @optional ~w(notes driver_location_id driver_location_inserted_at code)a
  @required ~w(from to match_id)a

  @doc false
  def changeset(match_state_transition, attrs) do
    match_state_transition
    |> cast(attrs, @optional ++ @required)
    |> validate_required(@required)
    |> validate_code(attrs)
  end

  defp validate_code(changeset, %{to: :admin_canceled}) do
    match = Shipment.get_match!(get_field(changeset, :match_id))

    if match.contract && not Enum.empty?(match.contract.cancellation_codes) do
      if get_field(changeset, :code) do
        changeset
      else
        add_error(changeset, :code, "Cancellation code cannot be empty")
      end
    else
      changeset
    end
  end

  defp validate_code(changeset, _) do
    changeset
  end
end
