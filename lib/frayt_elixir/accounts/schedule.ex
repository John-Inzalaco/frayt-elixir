defmodule FraytElixir.Accounts.Schedule do
  use FraytElixir.Schema
  alias FraytElixir.Accounts.{DriverSchedule, Location}
  alias FraytElixir.Drivers.Driver

  schema "schedules" do
    field :friday, :time
    field :max_drivers, :integer
    field :min_drivers, :integer
    field :monday, :time
    field :saturday, :time
    field :sla, :integer
    field :sunday, :time
    field :thursday, :time
    field :tuesday, :time
    field :wednesday, :time
    belongs_to :location, Location
    many_to_many :drivers, Driver, join_through: DriverSchedule

    timestamps()
  end

  @doc false
  def changeset(schedule, attrs) do
    schedule
    |> cast(attrs, [
      :monday,
      :tuesday,
      :wednesday,
      :thursday,
      :friday,
      :saturday,
      :sunday,
      :min_drivers,
      :max_drivers,
      :sla,
      :location_id
    ])
    |> validate_required([:min_drivers, :max_drivers], message: "Please enter estimated value")
    |> validate_number_by_field(:min_drivers,
      less_than: :max_drivers,
      message: "Must be between 0 and max drivers estimate"
    )
    |> validate_number_by_field(:max_drivers,
      greater_than: :min_drivers,
      message: "Must be greater than min drivers estimate"
    )
  end
end
