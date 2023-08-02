defmodule FraytElixirWeb.DriverView do
  use FraytElixirWeb, :view
  alias FraytElixirWeb.{VehicleView, DriverLocationView}
  alias FraytElixir.Repo
  alias Ecto.Association.NotLoaded
  import FraytElixirWeb.DisplayFunctions

  def render("driver.json", %{driver_id: nil}), do: nil

  def render("driver.json", %{driver: nil}), do: nil

  def render("driver.json", %{driver: %NotLoaded{}} = driver) do
    driver = driver |> Repo.preload(driver: [:user])
    render("driver.json", driver)
  end

  def render("driver.json", %{driver: %{current_location: %NotLoaded{}} = driver}) do
    driver = driver |> Repo.preload(:current_location)
    render("driver.json", %{driver: driver})
  end

  def render("driver.json", %{driver: %{vehicles: %NotLoaded{}} = driver}) do
    driver = driver |> Repo.preload(:vehicles)
    render("driver.json", %{driver: driver})
  end

  def render("driver.json", %{driver: %{vehicles: []} = driver}) do
    %{
      id: driver.id,
      email: driver.user.email,
      phone_number: format_phone(driver.phone_number),
      first_name: driver.first_name,
      last_name: get_shortened_initial(driver.last_name),
      current_location:
        render_one(
          driver.current_location,
          DriverLocationView,
          "driver_location.json"
        ),
      vehicle: render_one(nil, VehicleView, "vehicle.json")
    }
  end

  def render("driver.json", %{driver: driver}) do
    %{vehicles: [vehicle | _]} = driver

    %{
      id: driver.id,
      email: driver.user.email,
      phone_number: format_phone(driver.phone_number),
      first_name: driver.first_name,
      last_name: get_shortened_initial(driver.last_name),
      current_location:
        render_one(
          driver.current_location,
          DriverLocationView,
          "driver_location.json"
        ),
      vehicle: render_one(vehicle, VehicleView, "vehicle.json")
    }
  end
end
