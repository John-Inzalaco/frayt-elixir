defmodule FraytElixirWeb.API.V2x2.MatchControllerTest do
  use FraytElixirWeb.ConnCase
  alias FraytElixir.Matches
  alias FraytElixir.Accounts.ApiAccount
  import FraytElixirWeb.Test.LoginHelper
  import FraytElixir.AtomizeKeys

  import FraytElixir.Test.StartMatchSupervisor
  import FraytElixir.Test.WebhookHelper

  alias FraytElixirWeb.API.V2x2.Schemas.{
    MatchResponse,
    MatchRequest,
    CancelMatchRequest,
    MatchEstimateResponse
  }

  setup do
    start_match_webhook_sender(self())
  end

  setup :start_match_supervisor

  describe "show match" do
    setup :login_with_api

    test "returns a match", %{
      conn: conn,
      api_account: %{company: %{locations: [%{shippers: [shipper]}]}}
    } do
      attrs = MatchRequest.schema().example |> atomize_keys()

      {:ok, match} = Matches.create_match(attrs, shipper)

      conn = get(conn, RoutesApiV2_2.api_match_path(conn, :show, match.id))

      assert response = json_response(conn, 200)["response"]

      expected_response = MatchResponse.schema().example["response"]

      assert_copy(expected_response, response,
        ignore_recursive: ["id", "inserted_at", "eta"],
        ignore: ["shortcode"]
      )
    end
  end

  describe "create match" do
    setup :login_with_api

    test "creates a match", %{conn: conn} do
      params = MatchRequest.schema().example

      conn = post(conn, RoutesApiV2_2.api_match_path(conn, :create), params)

      assert response = json_response(conn, 201)["response"]

      expected_response = MatchResponse.schema().example["response"]

      assert_copy(expected_response, response,
        ignore_recursive: ["id", "inserted_at", "eta"],
        ignore: ["shortcode"]
      )
    end
  end

  describe "estimate match" do
    setup :login_with_api

    test "creates unauthorized match", %{conn: conn} do
      params = MatchRequest.schema().example

      conn = post(conn, RoutesApiV2_2.api_estimate_match_path(conn, :estimate), params)

      assert response = json_response(conn, 200)["response"]
      expected_response = MatchEstimateResponse.schema().example["response"]

      assert_copy(expected_response, response,
        ignore_recursive: ["id", "inserted_at", "eta"],
        ignore: ["shortcode"]
      )
    end
  end

  describe "update match" do
    setup :login_with_api

    test "updates a match", %{
      conn: conn,
      api_account: %ApiAccount{company: %{locations: [%{shippers: [shipper]}]}}
    } do
      match = insert(:assigning_driver_match, shipper: shipper)
      stop = match.match_stops |> List.first()

      params = %{
        "pickup_notes" => "Go to the front",
        "stops" => [%{"tip_price" => 2000, "id" => stop.id}]
      }

      conn = patch(conn, RoutesApiV2_2.api_match_path(conn, :update, match), params)

      assert %{"pickup_notes" => "Go to the front", "stops" => [%{"driver_tip" => 20.0}]} =
               json_response(conn, 200)["response"]
    end

    test "does not allow updating of a match in picked up state", %{
      conn: conn,
      api_account: %ApiAccount{company: %{locations: [%{shippers: [shipper]}]}}
    } do
      match = insert(:picked_up_match, shipper: shipper)
      params = %{"pickup_notes" => "Go to the side"}

      conn = patch(conn, RoutesApiV2_2.api_match_path(conn, :update, match), params)

      assert %{"message" => "Match may not be updated in its current state."} =
               json_response(conn, 403)
    end

    test "does not allow updating invalid match field", %{
      conn: conn,
      api_account: %ApiAccount{company: %{locations: [%{shippers: [shipper]}]}}
    } do
      match = insert(:assigning_driver_match, shipper: shipper)
      params = %{"vehicle_class" => 1}

      conn = patch(conn, RoutesApiV2_2.api_match_path(conn, :update, match), params)

      assert %{"message" => "Vehicle class cannot be updated"} = json_response(conn, 422)
    end

    test "does not allow updating invalid match stop field", %{
      conn: conn,
      api_account: %ApiAccount{company: %{locations: [%{shippers: [shipper]}]}}
    } do
      match = insert(:assigning_driver_match, shipper: shipper)
      stop = match.match_stops |> List.first()

      params = %{
        "pickup_notes" => "Go to the front",
        "match_stops" => [%{"id" => stop.id, "has_load_fee" => true}]
      }

      conn = patch(conn, RoutesApiV2_2.api_match_path(conn, :update, match), params)

      assert %{"message" => "Match stops's Has load fee cannot be updated"} =
               json_response(conn, 422)
    end

    test "properly updates field for a specific item", %{
      conn: conn,
      api_account: %ApiAccount{company: %{locations: [%{shippers: [shipper]}]}}
    } do
      match = insert(:assigning_driver_match, shipper: shipper)
      stop = match.match_stops |> List.first()
      item = stop.items |> List.first()

      params = %{
        "pickup_notes" => "Go to the front",
        "match_stops" => [%{"id" => stop.id, "items" => [%{"id" => item.id, "weight" => 200}]}]
      }

      conn = patch(conn, RoutesApiV2_2.api_match_path(conn, :update, match), params)

      assert %{"stops" => [%{"items" => [%{"weight" => 200.0}]}]} =
               json_response(conn, 200)["response"]
    end

    test "updates field for the correct stop", %{
      conn: conn,
      api_account: %ApiAccount{company: %{locations: [%{shippers: [shipper]}]}}
    } do
      match =
        insert(:assigning_driver_match,
          shipper: shipper,
          match_stops: [build(:match_stop), build(:match_stop), build(:match_stop)]
        )

      stop = match.match_stops |> Enum.at(2)

      params = %{
        "pickup_notes" => "Go to the front",
        "stops" => [%{"id" => stop.id, "self_recipient" => true}]
      }

      conn = patch(conn, RoutesApiV2_2.api_match_path(conn, :update, match), params)

      %{"stops" => stops} = json_response(conn, 200)["response"]
      assert %{"self_recipient" => true} = stops |> Enum.find(&(&1["id"] == stop.id))
    end

    test "tells user that they must use PATCH instead of PUT for this endpoint", %{
      conn: conn,
      api_account: %ApiAccount{company: %{locations: [%{shippers: [shipper]}]}}
    } do
      match = insert(:picked_up_match, shipper: shipper)
      params = %{"pickup_notes" => "Go to the side", "pickup_photo_required" => true}

      conn = put(conn, RoutesApiV2_2.api_match_path(conn, :update, match), params)

      assert %{"message" => "Must use PATCH and not PUT to update a match"} =
               json_response(conn, 403)
    end
  end

  describe "delete match" do
    setup :login_with_api

    test "cancels match", %{
      conn: conn,
      api_account: %ApiAccount{company: %{locations: [%{shippers: [shipper]}]}}
    } do
      %{id: match_id} = match = insert(:assigning_driver_match, shipper: shipper)

      attrs = CancelMatchRequest.schema().example

      conn = delete(conn, RoutesApiV2_2.api_match_path(conn, :delete, match), attrs)

      assert %{"id" => ^match_id, "state" => "canceled", "cancel_reason" => "your reason"} =
               json_response(conn, 200)["response"]
    end

    test "cancels match with no reason", %{
      conn: conn,
      api_account: %ApiAccount{company: %{locations: [%{shippers: [shipper]}]}}
    } do
      %{id: match_id} = match = insert(:assigning_driver_match, shipper: shipper)

      conn = delete(conn, RoutesApiV2_2.api_match_path(conn, :delete, match), %{})

      assert %{"id" => ^match_id, "state" => "canceled"} = json_response(conn, 200)["response"]
    end
  end
end
