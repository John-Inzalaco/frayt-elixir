defmodule FraytElixirWeb.Admin.PaymentsTest do
  use FraytElixirWeb.FeatureCase
  alias FraytElixirWeb.Test.AdminTablePage, as: Admin

  setup [:create_and_login_admin]

  feature "displays payment charges", %{session: session} do
    driver = insert(:driver, first_name: "Some", last_name: "Driver", state: :approved)
    shipper = insert(:shipper, first_name: "Some", last_name: "Shipper")

    payment =
      insert(:payment_transaction,
        amount: 5432,
        payment_provider_response: "{\"message\": \"some response\"}",
        match:
          build(:match,
            shipper: shipper,
            driver: driver,
            shortcode: "4SI2KL25"
          )
      )

    insert(:shipper_match_coupon,
      match: payment.match,
      shipper: shipper,
      coupon: build(:coupon, code: "welcome-123")
    )

    session
    |> Admin.visit_page("payments")
    |> assert_has(css("td", text: "##{payment.match.shortcode}"))
    |> assert_has(css("td", text: "Some Shipper"))
  end
end
