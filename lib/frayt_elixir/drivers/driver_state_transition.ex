defmodule FraytElixir.Drivers.DriverStateTransition do
  use FraytElixir.Schema

  alias FraytElixir.Drivers.{Driver, DriverState}

  schema "driver_state_transitions" do
    field :from, DriverState.Type
    field :to, DriverState.Type
    field :notes, :string
    belongs_to :driver, Driver

    timestamps()
  end

  @allowed_fields ~w(from to notes driver_id)a
  @doc false
  def changeset(driver_state_transition, attrs) do
    driver_state_transition
    |> cast(attrs, @allowed_fields)
    |> validate_required([:to, :from, :driver_id])
    |> validate_state_transaction()
  end

  defp validate_state_transaction(changeset) do
    from = get_field(changeset, :from)

    validate_change(changeset, :to, fn _field, to ->
      if from == to do
        [{to, "invalid driver state transition"}]
      else
        []
      end
    end)
  end
end
