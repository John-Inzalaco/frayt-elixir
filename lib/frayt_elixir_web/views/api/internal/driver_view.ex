defmodule FraytElixirWeb.API.Internal.DriverView do
  use FraytElixirWeb, :view

  alias FraytElixirWeb.API.Internal.{
    DriverView,
    VehicleView,
    ScheduleView,
    AddressView,
    AgreementDocumentView,
    DriverDeviceView,
    DriverDocumentView
  }

  alias FraytElixir.DriverDocuments
  alias FraytElixir.Accounts
  alias FraytElixir.Repo

  def render("index.json", %{drivers: drivers}) do
    %{response: render_many(drivers, DriverView, "driver.json")}
  end

  def render("show.json", %{driver: driver}) do
    %{response: render_one(driver, DriverView, "driver.json")}
  end

  def render("driver.json", %{driver: driver}) do
    driver =
      Repo.preload(driver, [
        :metrics,
        :address,
        :devices,
        vehicles: [images: DriverDocuments.latest_vehicle_documents_query()],
        images: DriverDocuments.latest_driver_documents_query(),
        schedules: [location: [:company, :address]]
      ])

    metrics = driver.metrics

    pending_agreements = Accounts.list_pending_agreements(driver)
    vehicle = if driver.vehicles, do: List.first(driver.vehicles)

    FraytElixirWeb.DriverView.render("driver.json", %{driver: driver})
    |> Map.merge(%{
      # driver's last name is truncated in `FraytElixirWeb.DriverView` but we don't want that behaviour here.
      # this is why we rewrite the full last_name here.
      last_name: driver.last_name,
      license_number: driver.license_number,
      state: driver.state,
      schedule_opt_state: driver.fleet_opt_state,
      fountain_id: driver.fountain_id,
      is_password_set: !is_nil(driver.user.hashed_password),
      password_reset_code: !is_nil(driver.user.password_reset_code),
      can_load: driver.can_load,
      wallet_state: driver.wallet_state,
      address: render_one(driver.address, AddressView, "address.json"),
      images: render_many(driver.images, DriverDocumentView, "driver_document.json"),
      pending_agreements:
        render_many(pending_agreements, AgreementDocumentView, "agreement_document.json"),
      accepted_schedules: render_many(driver.schedules, ScheduleView, "schedule.json"),
      rating: metrics && metrics.internal_rating,
      shipper_rating: metrics && metrics.rating,
      activity_rating: metrics && metrics.activity_rating,
      fulfillment_rating: metrics && metrics.fulfillment_rating,
      sla_rating: metrics && metrics.sla_rating,
      vehicle: render_one(vehicle, VehicleView, "vehicle.json"),
      devices: render_many(driver.devices, DriverDeviceView, "device.json"),
      default_device_id: driver.default_device_id
    })
  end
end
