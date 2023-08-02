defmodule FraytElixirWeb.LocationDetailsLiveTest do
  use FraytElixirWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias FraytElixir.Accounts

  describe "add a shipper to a location" do
    setup [:login_as_admin]

    test "cannot add an existing user who is not a shipper", %{conn: conn} do
      company = insert(:company)
      location = insert(:location, company: company)
      driver = insert(:driver, user: build(:user))
      conn = get(conn, "/admin/companies/#{company.id}/locations/#{location.id}")
      {:ok, view, _html} = live(conn)

      view
      |> element("[data-test-id='add-shipper']")
      |> render_click

      form_view = find_live_child(view, "modal")

      form_view
      |> element("[data-test-id='search-shipper-form']")
      |> render_change(%{
        "_target" => ["search_shipper", "email_1"],
        "search_shipper" => %{"email_1" => driver.user.email}
      })

      result_view =
        form_view
        |> element("[data-test-id='search-shipper-form']")
        |> render_submit

      assert result_view =~ "Shipper does not exist"
    end

    test "can add an existing user who is a shipper", %{conn: conn} do
      company = insert(:company)
      location = insert(:location, company: company)
      shipper = insert(:shipper, first_name: "Existing", last_name: "Shipper", user: build(:user))
      conn = get(conn, "/admin/companies/#{company.id}/locations/#{location.id}")
      {:ok, view, _html} = live(conn)

      view
      |> element("[data-test-id='add-shipper']")
      |> render_click

      form_view = find_live_child(view, "modal")

      form_view
      |> element("[data-test-id='search-shipper-form']")
      |> render_change(%{
        "_target" => ["search_shipper", "email_1"],
        "search_shipper" => %{"email_1" => shipper.user.email}
      })

      result_view =
        form_view
        |> element("[data-test-id='search-shipper-form']")
        |> render_submit

      refute result_view =~ "Shipper not found"
    end

    test "cannot add a new user", %{conn: conn} do
      company = insert(:company)
      location = insert(:location, company: company)
      conn = get(conn, "/admin/companies/#{company.id}/locations/#{location.id}")
      {:ok, view, _html} = live(conn)

      view
      |> element("[data-test-id='add-shipper']")
      |> render_click

      form_view = find_live_child(view, "modal")

      form_view
      |> element("[data-test-id='search-shipper-form']")
      |> render_change(%{
        "_target" => ["search_shipper", "email_1"],
        "search_shipper" => %{"email_1" => "random@email.com"}
      })

      result_view =
        form_view
        |> element("[data-test-id='search-shipper-form']")
        |> render_submit

      assert result_view =~ "Shipper does not exist"
    end

    test "can add an existing user who already has a location", %{conn: conn} do
      company = insert(:company)
      location = insert(:location, company: company)

      shipper =
        insert(:shipper_with_location,
          location: build(:location),
          first_name: "Existing",
          last_name: "Shipper",
          user: build(:user)
        )

      conn = get(conn, "/admin/companies/#{company.id}/locations/#{location.id}")
      {:ok, view, _html} = live(conn)

      view
      |> element("[data-test-id='add-shipper']")
      |> render_click

      form_view = find_live_child(view, "modal")

      form_view
      |> element("[data-test-id='search-shipper-form']")
      |> render_change(%{
        "_target" => ["search_shipper", "email_1"],
        "search_shipper" => %{"email_1" => shipper.user.email}
      })

      result_view =
        form_view
        |> element("[data-test-id='search-shipper-form']")
        |> render_submit

      assert result_view =~ "Shipper is already assigned to a location"

      form_view
      |> element("[data-test-id='move-here']")
      |> render_click

      result_view =
        form_view
        |> element("[data-test-id='search-shipper-form']")
        |> render_submit

      refute result_view =~ "Shipper not found"

      assert Accounts.get_shipper!(shipper.id).location_id == location.id

      shippers =
        Accounts.get_location!(location.id).shippers
        |> Enum.map(& &1.id)

      assert shippers == [shipper.id]
    end

    test "deletes shippers from a location", %{conn: conn} do
      company = insert(:company)
      location = insert(:location, company: company)

      shipper =
        insert(:shipper_with_location,
          location: location,
          first_name: "Existing",
          last_name: "Shipper",
          user: build(:user)
        )

      conn = get(conn, "/admin/companies/#{company.id}/locations/#{location.id}")
      {:ok, view, _html} = live(conn)

      result_view =
        view
        |> element("[data-test-id='delete-shipper']")
        |> render_click

      refute result_view =~ "Existing Shipper"

      assert Accounts.get_shipper!(shipper.id).location_id == nil
      assert Accounts.get_location!(location.id).shippers == []
    end
  end
end
