defmodule FraytElixirWeb.Admin.SettingsTest do
  use FraytElixirWeb.FeatureCase
  alias FraytElixirWeb.Test.AdminTablePage, as: Admin

  setup [:create_and_login_admin]

  describe "contract SLAs" do
    setup do
      %{contract: insert(:contract)}
    end

    feature "should display a toggle button per each SLA when clicking `Edit SLAs` button",
            params do
      %{session: session, contract: contract} = params

      session
      |> Admin.visit_page("/settings/contracts/#{contract.id}")
      |> click(css("[data-test-id='edit-contract-sla']"))
      |> assert_has(css("[data-test-id='acceptance-contract-sla']", text: "Use custom SLA"))
      |> assert_has(css("[data-test-id='pickup-contract-sla']", text: "Use custom SLA"))
      |> assert_has(css("[data-test-id='delivery-contract-sla']", text: "Use custom SLA"))
    end

    feature "should add/remove `button--primary` class on toggle each `Use Custom SLA` button",
            params do
      %{session: session, contract: contract} = params

      session =
        session
        |> Admin.visit_page("/settings/contracts/#{contract.id}")
        |> click(css("[data-test-id='edit-contract-sla']"))

      session
      |> click(css("button[data-test-id='acceptance-contract-sla']"))
      |> assert_has(css("button[data-test-id='acceptance-contract-sla'].button--primary"))
      |> click(css("button[data-test-id='acceptance-contract-sla']"))
      |> refute_has(css("button[data-test-id='acceptance-contract-sla'].button--primary"))

      session
      |> click(css("button[data-test-id='pickup-contract-sla']"))
      |> assert_has(css("button[data-test-id='pickup-contract-sla'].button--primary"))
      |> click(css("button[data-test-id='pickup-contract-sla']"))
      |> refute_has(css("button[data-test-id='pickup-contract-sla'].button--primary"))

      session
      |> click(css("button[data-test-id='delivery-contract-sla']"))
      |> assert_has(css("button[data-test-id='delivery-contract-sla'].button--primary"))
      |> click(css("button[data-test-id='delivery-contract-sla']"))
      |> refute_has(css("button[data-test-id='delivery-contract-sla'].button--primary"))
    end

    feature "should display message on clicking Update SLA button when any input is empty",
            params do
      %{session: session, contract: contract} = params

      session =
        session
        |> Admin.visit_page("/settings/contracts/#{contract.id}")
        |> click(css("[data-test-id='edit-contract-sla']"))

      session
      |> click(css("button[data-test-id='acceptance-contract-sla']"))
      |> click(css("button[data-test-id='pickup-contract-sla']"))
      |> click(css("button[data-test-id='delivery-contract-sla']"))

      session
      |> click(css("button[data-test-id='update-contract-slas']"))
      |> assert_has(css("[data-test-id='acceptance-error-message']", text: "can't be blank"))
      |> assert_has(css("[data-test-id='pickup-error-message']", text: "can't be blank"))
      |> assert_has(css("[data-test-id='delivery-error-message']", text: "can't be blank"))
    end

    feature "should display an error message on clicking Update SLA button when the input is empty",
            params do
      %{session: session, contract: contract} = params

      session =
        session
        |> Admin.visit_page("/settings/contracts/#{contract.id}")
        |> click(css("[data-test-id='edit-contract-sla']"))

      session
      |> click(css("button[data-test-id='acceptance-contract-sla']"))
      |> click(css("button[data-test-id='pickup-contract-sla']"))
      |> click(css("button[data-test-id='delivery-contract-sla']"))

      session
      |> click(css("button[data-test-id='update-contract-slas']"))
      |> assert_has(css("[data-test-id='acceptance-error-message']", text: "can't be blank"))
      |> assert_has(css("[data-test-id='pickup-error-message']", text: "can't be blank"))
      |> assert_has(css("[data-test-id='delivery-error-message']", text: "can't be blank"))
    end

    feature "should display an error message when typing an invalid duration expression",
            params do
      %{session: session, contract: contract} = params

      session =
        session
        |> Admin.visit_page("/settings/contracts/#{contract.id}")
        |> click(css("[data-test-id='edit-contract-sla']"))

      session
      |> click(css("button[data-test-id='acceptance-contract-sla']"))
      |> fill_in(css("[data-test-id='acceptance-sla-form-input']"), with: "foo")
      |> click(css("button[data-test-id='pickup-contract-sla']"))
      |> fill_in(css("[data-test-id='pickup-sla-form-input']"), with: "bar + foo - baz")
      |> click(css("button[data-test-id='delivery-contract-sla']"))
      |> fill_in(css("[data-test-id='delivery-sla-form-input']"), with: "baz")

      session
      |> click(css("button[data-test-id='update-contract-slas']"))
      |> assert_has(
        css("[data-test-id='acceptance-error-message']", text: "foo is not an allowed variable")
      )
      |> assert_has(
        css("[data-test-id='pickup-error-message']",
          text: "baz, foo and bar are not allowed variables"
        )
      )
      |> assert_has(
        css("[data-test-id='delivery-error-message']", text: "baz is not an allowed variable")
      )
    end

    feature "should succeed when valid duration expressions are provided", params do
      %{session: session, contract: contract} = params

      session =
        session
        |> Admin.visit_page("/settings/contracts/#{contract.id}")
        |> click(css("[data-test-id='edit-contract-sla']"))

      acceptance_duration = "travel_duration + stop_count * 10"
      pickup_duration = "travel_duration + stop_count * 2"

      session
      |> click(css("button[data-test-id='acceptance-contract-sla']"))
      |> fill_in(css("[data-test-id='acceptance-sla-form-input']"), with: acceptance_duration)
      |> click(css("button[data-test-id='pickup-contract-sla']"))
      |> fill_in(css("[data-test-id='pickup-sla-form-input']"), with: pickup_duration)

      session
      |> click(css("button[data-test-id='update-contract-slas']"))
      |> assert_has(
        css("[data-test-id='acceptance-sla-duration-label']", text: acceptance_duration)
      )
      |> assert_has(css("[data-test-id='pickup-sla-duration-label']", text: pickup_duration))
      |> assert_has(css("[data-test-id='delivery-sla-duration-label']", text: "Default"))
    end
  end
end
