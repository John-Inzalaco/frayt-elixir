defmodule FraytElixirWeb.Test.MatchPage do
  use Wallaby.DSL
  import Wallaby.Query

  def edit_fee(session, fee_type, %{
        amount: amount,
        driver_amount: driver_amount
      }) do
    session
    |> click(css("[data-test-id='edit-payment']"))
    |> click(css("[data-test-id='manual_price_input']"))
    |> fill_in(css("[data-test-id='#{fee_type}_amount_input']"), with: "")
    |> fill_in(css("[data-test-id='#{fee_type}_amount_input']"), with: amount)
    |> fill_in(css("[data-test-id='#{fee_type}_driver_amount_input']"), with: "")
    |> fill_in(css("[data-test-id='#{fee_type}_driver_amount_input']"), with: driver_amount)
    |> click(css("[data-test-id='save-payment']"))
  end

  def edit_stop(session, stop_id, %{destination_address: address}),
    do:
      session
      |> click(css("[data-test-id='edit-stop-#{stop_id}']"))
      |> fill_in(css("[data-test-id='destination_address-input']"), with: address)
      |> click(css("[data-test-id='has-load-fee-input']"))
      |> click(css("[data-test-id='save-stop']"))

  def edit_pickup(session, %{origin_address: address}),
    do:
      session
      |> click(css("[data-test-id='edit-pickup']"))
      |> fill_in(css("[data-test-id='origin_address-input']"), with: "")
      |> fill_in(css("[data-test-id='origin_address-input']"), with: address)
      |> click(css("[data-test-id='save-pickup']"))

  def edit_logistics(session, %{po: po, vehicle_class: vehicle_class}),
    do:
      session
      |> click(css("[data-test-id='edit-logistics']"))
      |> set_value(
        css("[data-test-id='vehicle-class-input'] option[value='#{vehicle_class}']"),
        :selected
      )
      |> fill_in(css("[data-test-id='po-input']"), with: po)
      |> click(css("[data-test-id='save-logistics']"))
end
