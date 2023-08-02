defmodule FraytElixirWeb.Admin.MarketsDashboardTest do
  use FraytElixirWeb.FeatureCase
  use Bamboo.Test, shared: true

  import FraytElixirWeb.Test.FeatureTestHelper

  alias FraytElixirWeb.Test.AdminTablePage, as: Admin

  setup context do
    create_and_login_admin(context, role: :driver_services)
  end

  feature "create market with Driver Services role", %{session: session} do
    dashboard =
      session
      |> Admin.visit_page("markets/dashboard")

    dashboard
    |> click(css("a[data-test-id='add-market']"))
    |> click(button("Save"))
    |> assert_has(
      css(
        "span.error span[phx-feedback-for='market[name]']",
        text: "can't be blank"
      )
    )

    dashboard
    |> click(css("a[data-test-id='add-market']"))
    |> fill_in(text_field("market[name]"), with: "Testing")
    |> click(css("a[data-test-id='add-zip-codes']"))
    |> fill_in(text_field("market[zip_codes][0][zip]"), with: "22253")
    |> click(button("Save"))
    |> assert_has(
      css("table[data-test-id='markets'] tr:first-child td[data-test-id='name']",
        text: "Testing"
      )
    )
  end
end
