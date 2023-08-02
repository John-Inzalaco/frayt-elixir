defmodule FraytElixir.Contracts.CancellationPayRule do
  use Ecto.Schema
  import Ecto.Changeset
  import FraytElixir.Validators
  import FraytElixir.ChangesetHelpers
  alias FraytElixir.Shipment.MatchState
  alias FraytElixir.Vehicle.VehicleType
  alias FraytElixir.Accounts.UserType

  embedded_schema do
    field :time_on_match, :integer
    field :restrict_states, :boolean, default: false
    field :in_states, {:array, MatchState.Type}, default: []
    field :max_matches, :integer
    field :cancellation_percent, :float, default: 0.75
    field :driver_percent, :float, default: 0.75
    field :vehicle_class, {:array, VehicleType.Type}, default: VehicleType.all_types()
    field :canceled_by, {:array, UserType.Type}, default: [:admin, :shipper]
  end

  @allowed_field ~w(time_on_match max_matches cancellation_percent driver_percent restrict_states in_states vehicle_class canceled_by)a

  def changeset(details, attrs) do
    details
    |> cast_from_form(attrs, @allowed_field)
    |> validate_subset(:canceled_by, [:admin, :shipper])
    |> validate_length(:canceled_by, min: 1)
    |> validate_length(:vehicle_class, min: 1)
    |> validate_required([
      :driver_percent,
      :cancellation_percent,
      :restrict_states,
      :in_states,
      :vehicle_class
    ])
    |> validate_when(:in_states, [{:restrict_states, :equal_to, true}], &validate_assoc_length/3,
      min: 1
    )
    |> validate_number(:cancellation_percent,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 1,
      message: "must be between 0% and 100%"
    )
    |> validate_number(:driver_percent,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 1,
      message: "must be between 0% and 100%"
    )
  end
end
