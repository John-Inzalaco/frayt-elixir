defmodule FraytElixirWeb.Admin.DriversTest do
  use FraytElixirWeb.FeatureCase
  alias FraytElixirWeb.Test.AdminTablePage, as: Admin

  setup [:create_and_login_admin]

  feature "see drivers on drivers page", %{session: session} do
    driver =
      insert(:driver,
        first_name: "Abe",
        last_name: "Miller",
        address: %{city: "Cincinnati", state: "OH"},
        state: "approved",
        updated_at: ~N[2001-01-01 23:00:07]
      )

    insert(:vehicle, driver: driver, vehicle_class: 2)
    insert(:vehicle, driver: driver, vehicle_class: 3)
    insert_list(2, :match, driver: driver, state: "canceled")
    insert(:match, driver: driver, state: "accepted")
    insert(:match, driver: driver, state: "en_route_to_pickup")
    insert(:match, driver: driver, state: "picked_up")
    insert_list(2, :match, driver: driver, state: "charged")

    session
    |> Admin.visit_page("drivers")
    |> assert_has(css("h1", text: "Drivers"))
    |> assert_has(css("td", text: "Abe Miller"))
    |> assert_has(css("td", text: "Approved"))
    |> assert_has(css("td", text: "Midsize, Cargo Van"))
    |> assert_has(css("td", text: "Cincinnati, OH"))
    |> assert_has(css("td", text: "01/01/2001"))
  end

  feature "approve driver", %{session: session} do
    %{vehicles: [vehicle], id: driver_id} =
      insert(:driver,
        state: :pending_approval,
        first_name: "John",
        last_name: "Pena",
        images: [
          build(:driver_document, type: "license", state: :approved),
          build(:driver_document, type: "profile", state: :approved),
          build(:driver_document, type: "license", state: :approved)
        ]
      )

    insert(:vehicle_document, type: "back", vehicle: vehicle, state: :approved)
    insert(:vehicle_document, type: "insurance", vehicle: vehicle, state: :approved)
    insert(:vehicle_document, type: "registration", vehicle: vehicle, state: :approved)
    insert(:vehicle_document, type: "front", vehicle: vehicle, state: :approved)
    insert(:vehicle_document, type: "cargo_area", vehicle: vehicle, state: :approved)
    insert(:vehicle_document, type: "drivers_side", vehicle: vehicle, state: :approved)
    insert(:vehicle_document, type: "passengers_side", vehicle: vehicle, state: :approved)
    insert(:vehicle_document, type: "vehicle_type", vehicle: vehicle, state: :approved)

    session
    |> Admin.visit_page("drivers/#{driver_id}")
    |> assert_has(css("span[data-test-id='driver-status-label']", text: "Pending Approval"))
    |> click(button("Approve Driver"))
    |> click(css("button[data-test-id='confirm-driver-approval-btn']"))
    |> assert_has(
      css(
        "p[data-test-id='success-message']",
        text: "The driver has been approved successfully!"
      )
    )
    |> click(button("Close"))
    |> assert_has(css("span[data-test-id='driver-status-label']", text: "Approved"))
    |> refute_has(css("button", text: "Approve Driver"))
  end

  feature "unreject driver", %{session: session} do
    driver = insert(:driver, state: :rejected)

    session
    |> Admin.visit_page("drivers/#{driver.id}")
    |> assert_has(css("span[data-test-id='driver-status-label']", text: "Rejected"))
    |> click(button("Unreject Driver"))
    |> click(css("button[data-test-id='confirm-driver-unrejection-btn']"))
    |> assert_has(
      css(
        "p[data-test-id='success-message']",
        text: "The driver has been unrejected successfully!"
      )
    )
    |> click(button("Close"))
    |> assert_has(css("span[data-test-id='driver-status-label']", text: "Pending Approval"))
    |> refute_has(css("button", text: "Unreject Driver"))
  end
end
