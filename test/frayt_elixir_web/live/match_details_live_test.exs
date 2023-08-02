defmodule FraytElixirWeb.MatchDetailsLiveTest do
  use FraytElixirWeb.ConnCase, async: true
  import FraytElixir.Factory
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  alias FraytElixir.Shipment
  setup [:login_as_admin]

  describe "specify details" do
    test "should be visible on pickup", %{conn: conn} do
      match = insert(:assigning_driver_match)

      conn = get(conn, "/admin/matches/#{match.id}")
      {:ok, view, _html} = live(conn)

      view
      |> element("[data-test-id='edit-pickup']")
      |> render_click

      view
      |> element("#origin_address_specify_details")
      |> render_click()

      assert has_element?(view, "#match_origin_address_lat")
      assert has_element?(view, "#match_origin_address_lng")
      assert has_element?(view, "#match_origin_address_address")
      assert has_element?(view, "#match_origin_address_address2")
    end

    test "should be visible on drop off", %{conn: conn} do
      match = insert(:assigning_driver_match)

      [match_stop | _] = match.match_stops
      conn = get(conn, "/admin/matches/#{match.id}")
      {:ok, view, _html} = live(conn)

      view
      |> element("[data-test-id='edit-stop-#{match_stop.id}']")
      |> render_click

      view
      |> element("#origin_address_specify_details")
      |> render_click()

      assert has_element?(view, "#match_stop_destination_address_lat")
      assert has_element?(view, "#match_stop_destination_address_lng")
      assert has_element?(view, "#match_stop_destination_address_address")
      assert has_element?(view, "#match_stop_destination_address_address2")
    end

    test "should update address details for pickup", %{conn: conn} do
      match = insert(:assigning_driver_match)

      conn = get(conn, "/admin/matches/#{match.id}")
      {:ok, view, _html} = live(conn)

      view
      |> element("[data-test-id='edit-pickup']")
      |> render_click

      view
      |> element("#origin_address_specify_details")
      |> render_click()

      attrs = %{
        "bill_of_lading_required" => "false",
        "origin_address" => %{
          "address" => "708 Walnut Street",
          "address2" => "",
          "city" => "Cincinnati",
          "country_code" => "US",
          "county" => "Hamilton County",
          "id" => match.origin_address.id,
          "lat" => "39.10431988",
          "lng" => "-84.5118912",
          "neighborhood" => "Central Business District",
          "state_code" => "OH",
          "zip" => "45202"
        },
        "origin_photo_required" => "false",
        "pickup_notes" => "",
        "scheduled" => "false",
        "self_sender" => "true"
      }

      render_submit(view, :update_pickup, %{match: attrs})

      %{origin_address: origin_address} = Shipment.get_match!(match.id)
      {lng, lat} = origin_address.geo_location.coordinates
      assert {"#{lng}", "#{lat}"} == {"-84.5118912", "39.10431988"}
      assert origin_address.zip == "45202"
      assert origin_address.state_code == "OH"
      assert origin_address.country_code == "US"
    end

    test "should update address details for dropoff", %{conn: conn} do
      match = insert(:assigning_driver_match)

      [match_stop | _] = match.match_stops
      conn = get(conn, "/admin/matches/#{match.id}")
      {:ok, view, _html} = live(conn)

      view
      |> element("[data-test-id='edit-stop-#{match_stop.id}']")
      |> render_click

      view
      |> element("#origin_address_specify_details")
      |> render_click()

      attrs = %{
        "delivery_notes" => "",
        "destination_address" => %{
          "address" => "708 Walnut Street",
          "address2" => "",
          "city" => "Cincinnati",
          "country_code" => "US",
          "county" => "Hamilton County",
          "id" => match_stop.id,
          "lat" => "39.10431988",
          "lng" => "-84.5118912",
          "neighborhood" => "Central Business District",
          "state_code" => "OH",
          "zip" => "45202"
        },
        "destination_photo_required" => "false",
        "has_load_fee" => "false",
        "items" => %{
          "0" => %{
            "barcode_delivery_required" => "false",
            "barcode_pickup_required" => "false",
            "declared_value" => "0.00",
            "description" => "Car Tire",
            "height" => "24",
            "id" => "053b1176-0079-4241-8e81-00bf9ca69b2f",
            "length" => "24",
            "pieces" => "4",
            "type" => "item",
            "volume" => "0.667",
            "weight" => "10",
            "width" => "2"
          }
        },
        "po" => "",
        "recipient" => %{
          "email" => "john068d74f5@doe.com",
          "id" => "b199c050-100b-41ff-a188-3807cbe48a7d",
          "name" => "John Doe",
          "notify" => "true",
          "phone_number" => "+15134020000"
        },
        "self_recipient" => "false",
        "signature_required" => "true"
      }

      render_submit(view, :"update_stop:#{match_stop.id}", %{match_stop: attrs})

      %{match_stops: [match_stop | _]} = Shipment.get_match!(match.id)
      {lng, lat} = match_stop.destination_address.geo_location.coordinates
      assert {"#{lng}", "#{lat}"} == {"-84.5118912", "39.10431988"}
      assert match_stop.destination_address.zip == "45202"
      assert match_stop.destination_address.state_code == "OH"
      assert match_stop.destination_address.country_code == "US"
    end

    test "Arrived At Return should be visible on timeline if a stop is undeliverable", %{
      conn: conn
    } do
      match = insert(:picked_up_match, %{match_stops: [build(:undeliverable_match_stop)]})
      match_state_transition_through_to(:picked_up, match)
      conn = get(conn, "/admin/matches/#{match.id}")
      {:ok, _view, html} = live(conn)

      assert html =~ "<h6>Arrived At Return</h6>"
    end

    test "Match should be marked as Arrived At Returned when clicked on it", %{conn: conn} do
      match = insert(:picked_up_match, %{match_stops: [build(:undeliverable_match_stop)]})
      match_state_transition_through_to(:picked_up, match)
      conn = get(conn, "/admin/matches/#{match.id}")
      {:ok, view, _html} = live(conn)

      assert 5 =
               view
               |> render()
               |> Floki.parse_fragment!()
               |> Floki.find(".circle--checked")
               |> Enum.count()

      assert 6 =
               view
               |> element("[data-test-id='delivery-link-mark-as-returned']")
               |> render_click()
               |> Floki.find(".circle--checked")
               |> Enum.count()
    end

    test "Match should be marked as Completed and the stop should be marked as Returned when clicked on Completed",
         %{conn: conn} do
      match = insert(:picked_up_match, %{match_stops: [build(:undeliverable_match_stop)]})
      match_state_transition_through_to(:picked_up, match)
      conn = get(conn, "/admin/matches/#{match.id}")
      {:ok, view, _html} = live(conn)

      match_state_transition_through_to(:returned, match)

      view
      |> element("[data-test-id='delivery-link']")
      |> render_click()

      assert %{match_stops: [%{state: :returned}]} =
               FraytElixir.Repo.get(FraytElixir.Shipment.Match, match.id)
               |> FraytElixir.Repo.preload(:match_stops)
    end
  end
end
