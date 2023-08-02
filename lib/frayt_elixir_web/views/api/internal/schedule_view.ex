defmodule FraytElixirWeb.API.Internal.ScheduleView do
  use FraytElixirWeb, :view
  alias FraytElixirWeb.API.Internal.ScheduleView
  alias FraytElixirWeb.LocationView
  alias Ecto.Association.NotLoaded
  alias FraytElixir.Repo

  def render("index.json", %{schedules: schedules}) do
    %{response: render_many(schedules, ScheduleView, "schedule.json")}
  end

  def render("show.json", %{schedule: schedule}) do
    %{response: render_one(schedule, ScheduleView, "schedule.json")}
  end

  def render("schedule.json", %{schedule: %{location: %NotLoaded{}} = schedule}) do
    schedule = schedule |> Repo.preload(:location)
    render("schedule.json", %{schedule: schedule})
  end

  def render(
        "schedule.json",
        %{
          schedule: %{
            id: id,
            sla: sla,
            max_drivers: max_drivers,
            min_drivers: min_drivers,
            sunday: sunday,
            monday: monday,
            tuesday: tuesday,
            wednesday: wednesday,
            thursday: thursday,
            friday: friday,
            saturday: saturday,
            location: location
          }
        }
      ) do
    %{
      id: id,
      sla: sla,
      max_drivers: max_drivers,
      min_drivers: min_drivers,
      sunday: sunday,
      monday: monday,
      tuesday: tuesday,
      wednesday: wednesday,
      thursday: thursday,
      friday: friday,
      saturday: saturday,
      location:
        render_one(
          location,
          LocationView,
          "location.json"
        )
    }
  end

  def render("schedule.json", nil), do: nil
end
