defmodule FraytElixirWeb.NavigationTest do
  use FraytElixirWeb.FeatureCase

  setup [:create_and_login_admin]

  feature "active links", %{session: session} do
    insert(:driver, first_name: "Driver", last_name: "One")

    session
    |> visit("http://localhost:4002/admin/matches")
    |> refute_has(css(".active-link"))
    |> click(css(".nav__links a", text: "Companies"))
    |> assert_has(css(".active-link", text: "Companies"))
    |> click(css(".nav__links a", text: "Driver"))
    |> assert_has(css(".active-link", text: "Driver"))
    |> click(css("td", text: "Driver One"))
    |> assert_has(css(".active-link", text: "Driver"))
  end
end
