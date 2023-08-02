defmodule FraytElixir.Accounts.DriverSchedule do
  use FraytElixir.Schema
  alias FraytElixir.Accounts.Schedule
  alias FraytElixir.Drivers.Driver

  schema "drivers_schedules" do
    belongs_to :driver, Driver
    belongs_to :schedule, Schedule

    timestamps()
  end

  @doc false
  def changeset(drivers_schedules, attrs) do
    drivers_schedules
    |> cast(attrs, [:driver_id, :schedule_id])
    |> validate_required([:driver_id, :schedule_id])
  end
end
