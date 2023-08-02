defmodule FraytElixirWeb.API.V2x1.MatchControllerTest do
  use FraytElixirWeb.ConnCase
  alias FraytElixir.Shipment
  alias FraytElixir.Shipment.Match
  alias FraytElixir.Accounts.ApiAccount
  import FraytElixirWeb.Test.LoginHelper

  import FraytElixir.Test.StartMatchSupervisor
  import FraytElixir.Test.WebhookHelper

  setup do
    start_match_webhook_sender(self())
  end

  setup :start_match_supervisor

  describe "create match" do
    setup :login_with_api

    test "with a single item", %{
      conn: conn,
      api_account: %ApiAccount{company: _company}
    } do
      params = %{
        origin_address: "1266 Norman Ave Cincinnati OH 45231",
        destination_address: "641 Evangeline Rd Cincinnati OH 45240",
        items: [
          %{
            weight: "25",
            length: "10",
            width: "10",
            height: "10",
            pieces: "1",
            description: "A suspicious cube"
          }
        ],
        vehicle_class: "1",
        service_level: "1"
      }

      conn = post(conn, RoutesApiV2_1.api_match_path(conn, :create), params)

      assert %{"id" => match_id} = json_response(conn, 201)["response"]

      assert %Match{id: ^match_id, state: :assigning_driver} = Shipment.get_match!(match_id)
    end

    test "with a box trucks", %{conn: conn} do
      insert(:market, has_box_trucks: true, zip_codes: [insert(:market_zip_code, zip: "45202")])

      params = %{
        origin_address: "1266 Norman Ave Cincinnati OH 45231",
        destination_address: "641 Evangeline Rd Cincinnati OH 45240",
        items: [
          %{
            weight: "25",
            length: "10",
            width: "10",
            height: "10",
            pieces: "1",
            description: "A suspicious cube"
          }
        ],
        pickup_at: "2030-01-21T14:00:00Z",
        vehicle_class: "4",
        service_level: "1",
        unload_method: "lift_gate"
      }

      conn = post(conn, RoutesApiV2_1.api_match_path(conn, :create), params)

      assert %{
               "id" => match_id,
               "unload_method" => "lift_gate",
               "fees" => [
                 %{
                   "type" => "base_fee",
                   "amount" => 215_00
                 },
                 %{
                   "type" => "holiday_fee",
                   "amount" => 100_00,
                   "description" => "Birthday of Martin Luther King, Jr"
                 },
                 %{
                   "type" => "lift_gate_fee",
                   "amount" => 30_00
                 }
               ]
             } = json_response(conn, 201)["response"]

      assert %Match{id: ^match_id, state: :scheduled} = Shipment.get_match!(match_id)
    end

    test "with autoselect vehicle enabled", %{
      conn: conn
    } do
      params = %{
        "destination_address" => "string",
        "delivery_notes" => "string",
        "identifier" => "string",
        "items" => [
          %{
            "description" => "Car Tire",
            "height" => 24,
            "length" => 8,
            "pieces" => 4,
            "volume" => 0,
            "weight" => 80,
            "width" => 24
          }
        ],
        "po" => "string",
        "has_load_fee" => true,
        "origin_address" => "string",
        "pickup_notes" => "string",
        "recipient_email" => "string",
        "recipient_name" => "string",
        "recipient_phone" => "+15134020000",
        "notify_recipient" => true,
        "self_recipient" => false,
        "dropoff_at" => "2030-09-28T18:31:00Z",
        "pickup_at" => "2030-09-28T09:31:00Z",
        "service_level" => "1",
        "contract" => "menards"
      }

      api_account =
        insert(:api_account,
          company: build(:company_with_location, autoselect_vehicle_class: true)
        )

      insert(:contract,
        contract_key: "menards",
        pricing_contract: :menards,
        company: api_account.company
      )

      conn =
        conn
        |> add_token_for_api_account(api_account)
        |> post(RoutesApiV2_1.api_match_path(conn, :create), params)

      assert %{
               "id" => match_id,
               "origin_address" => %{},
               "destination_address" => %{},
               "service_level" => 1,
               "items" => [_],
               "vehicle_class" => 2,
               "has_load_fee" => true,
               "pickup_notes" => "string",
               "delivery_notes" => "string",
               "po" => "string",
               "recipient" => %{
                 "name" => "string",
                 "phone_number" => "+1 513-402-0000",
                 "email" => "string",
                 "notify" => true
               },
               "pickup_at" => "2030-09-28T09:31:00Z",
               "dropoff_at" => "2030-09-28T18:31:00Z",
               "identifier" => "string",
               "contract" => "menards",
               "tip_price" => nil,
               "price" => 4500
             } = json_response(conn, 201)["response"]

      assert %Match{id: ^match_id, state: :scheduled} = Shipment.get_match!(match_id)
    end
  end

  describe "estimate match" do
    setup :login_with_api

    test "returns an unauthorized match", %{
      conn: conn
    } do
      params = %{
        "destination_address" => "string",
        "delivery_notes" => "string",
        "identifier" => "string",
        "items" => [
          %{
            "description" => "Car Tire",
            "height" => 24,
            "length" => 8,
            "pieces" => 4,
            "volume" => 0,
            "weight" => 80,
            "width" => 24
          }
        ],
        "po" => "string",
        "has_load_fee" => true,
        "origin_address" => "string",
        "pickup_notes" => "string",
        "recipient_email" => "string",
        "recipient_name" => "string",
        "recipient_phone" => "+15134020000",
        "notify_recipient" => true,
        "self_recipient" => false,
        "dropoff_at" => "2030-09-27T18:31:00Z",
        "pickup_at" => "2030-09-27T14:31:00Z",
        "service_level" => "1",
        "tip" => 1119
      }

      api_account =
        insert(:api_account,
          company: build(:company_with_location, autoselect_vehicle_class: true)
        )

      conn =
        conn
        |> add_token_for_api_account(api_account)
        |> post(RoutesApiV2_1.api_estimate_match_path(conn, :estimate), params)

      assert %{
               "id" => "" <> _,
               "origin_address" => %{},
               "destination_address" => %{},
               "service_level" => 1,
               "items" => [_],
               "vehicle_class" => 2,
               "has_load_fee" => true,
               "pickup_notes" => "string",
               "delivery_notes" => "string",
               "po" => "string",
               "recipient" => %{
                 "name" => "string",
                 "phone_number" => "+1 513-402-0000",
                 "email" => "string",
                 "notify" => true
               },
               "pickup_at" => "2030-09-27T14:31:00Z",
               "dropoff_at" => "2030-09-27T18:31:00Z",
               "scheduled" => true,
               "identifier" => "string",
               "contract" => nil,
               "distance" => 5.0,
               "tip_price" => 1119,
               "price" => price,
               "state" => "pending"
             } = json_response(conn, 200)["response"]

      assert price > 0
    end
  end
end
