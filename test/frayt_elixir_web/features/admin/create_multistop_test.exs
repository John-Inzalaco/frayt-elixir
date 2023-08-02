defmodule FraytElixirWeb.Admin.CreateMultistopTest do
  use FraytElixirWeb.FeatureCase
  alias FraytElixirWeb.Test.AdminTablePage, as: Admin
  import FraytElixir.Test.WebhookHelper

  setup do
    start_batch_webhook_sender(self())
  end

  setup [:create_and_login_admin]

  setup do
    {:ok, _spid} =
      start_supervised({Task.Supervisor, name: FraytElixir.Shipment.DeliveryBatchSupervisor})

    :ok
  end

  feature "creates a delivery batch", %{session: session} do
    insert_list(3, :company_with_location)
    company = insert(:company, name: "Company 1")
    insert_list(3, :location, company: company)
    location = insert(:location, company: company, location: "Downtown", store_number: "123")
    insert(:schedule_with_drivers, location: location)
    insert(:shipper, location: location)

    session
    |> Admin.visit_page("matches/multistop")
    |> assert_has(css("h3", text: "New Match Batch"))
    |> set_value(css("option[value='#{company.id}']"), :selected)
    |> set_value(css("option[value='#{location.id}']"), :selected)
    |> assert_has(css("#deliveries_pickup_at option", count: 8))
    |> attach_file(file_field("deliveries_csv"), path: "test/fixtures/deliveries.csv")
    |> click(button("Create Match Batch"))
    |> assert_has(css("h1", text: "Batches"))
    |> assert_has(css("td", text: company.name))
  end

  feature "displays a flash if the csv has the wrong fields", %{session: session} do
    insert_list(3, :company_with_location)
    company = insert(:company, name: "Company 1")
    insert_list(3, :location, company: company)
    location = insert(:location, company: company, location: "Downtown", store_number: "123")
    insert(:schedule_with_drivers, location: location)

    session
    |> Admin.visit_page("matches/multistop")
    |> assert_has(css("h3", text: "New Match Batch"))
    |> set_value(css("option[value='#{company.id}']"), :selected)
    |> set_value(css("option[value='#{location.id}']"), :selected)
    |> assert_has(css("#deliveries_pickup_at option", count: 8))
    |> attach_file(file_field("deliveries_csv"), path: "test/fixtures/bonuses.csv")
    |> click(button("Create Match Batch"))
    |> assert_has(css("h3", text: "New Match Batch"))
    |> assert_has(css(".error"))
  end
end
