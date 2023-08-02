defmodule FraytElixirWeb.Webhook.BringgControllerTest do
  use FraytElixirWeb.ConnCase

  alias FraytElixir.Shipment
  alias FraytElixir.Shipment.{Match, MatchStop, Address, MatchStopItem, MatchStop}
  alias FraytElixir.Accounts.{Company, Location, Shipper}
  alias FraytElixir.Drivers.Driver
  alias FraytElixir.Drivers
  alias FraytElixir.Repo
  import FraytElixir.Test.StartMatchSupervisor

  import FraytElixir.Test.StartMatchSupervisor
  import FraytElixir.Test.WebhookHelper

  setup do
    start_match_webhook_sender(self())
  end

  setup :start_match_supervisor

  setup %{conn: conn} do
    client_id = "77dbea32-b9b5-42f6-9915-663c512196fe"

    %Company{locations: [%Location{shippers: [bringg_shipper]}]} =
      bringg =
      insert(:company_with_location,
        name: "Bringg",
        autoselect_vehicle_class: true,
        integration: :bringg,
        api_key: client_id,
        webhook_config: %{client_id: client_id, secret: "abcd"}
      )

    {
      :ok,
      conn: put_req_header(conn, "authorization", "Bearer #{client_id}"),
      bringg_company: bringg,
      bringg_shipper: bringg_shipper,
      bringg_client_id: client_id
    }
  end

  @valid_bringg_params %{
    "customer" => %{
      "allow_sending_email" => true,
      "allow_sending_sms" => true,
      "email" => "test@bringg.com",
      "external_id" => "561e1a26",
      "extras" => nil,
      "id" => 97_894_364,
      "language" => nil,
      "name" => "Test Customer",
      "phone" => "+12025550194"
    },
    "external_id" => "561e1a26",
    "extras" => nil,
    "id" => 270_529_236,
    "left_to_be_paid" => nil,
    "packages" => [],
    "pre_delivery_tip" => nil,
    "preparation_external_id" => nil,
    "preparation_status" => "ACKNOWLEDGED",
    "preparation_status_id" => 0,
    "price_before_tax" => nil,
    "priority" => 270_529_236,
    "quote_id" => nil,
    "request_id" => "f7f85b77-fc7a-4fae-9067-390d3ed8d3f8",
    "required_skills" => [],
    "run_id" => nil,
    "service_plan_id" => nil,
    "tag_id" => nil,
    "task_configuration_id" => nil,
    "team" => %{"external_id" => "104947", "name" => "Team 1"},
    "tip" => nil,
    "title" => "Test order bringg",
    "total_price" => 100,
    "type" => "delivery",
    "way_points" => [
      %{
        "address" => "863 Dawsonville Hwy",
        "address_second_line" => nil,
        "address_type" => nil,
        "asap" => false,
        "borough" => nil,
        "city" => "Gainesville",
        "customer" => %{
          "allow_sending_email" => true,
          "allow_sending_sms" => true,
          "email" => "",
          "external_id" => "97894419",
          "extras" => nil,
          "id" => 97_894_419,
          "language" => nil,
          "name" => "Warehouse",
          "phone" => nil
        },
        "district" => nil,
        "extras" => nil,
        "first_attempt_promise_no_earlier_than" => nil,
        "first_attempt_promise_no_later_than" => nil,
        "house_number" => nil,
        "id" => 362_323_772,
        "inventory" => [
          %{
            "age_restricted" => nil,
            "external_id" => "18419863",
            "extras" => nil,
            "height" => 10,
            "id" => 963_020_124,
            "image" => "/images/product-placeholder.png",
            "length" => 50.5,
            "name" => "Inventory",
            "original_quantity" => 1,
            "price" => 20,
            "scan_string" => "7f54b00ef8edc6cd",
            "services" => [],
            "size" => nil,
            "volume" => nil,
            "weight" => 100.5,
            "width" => 50.5
          }
        ],
        "lat" => 39.8656099,
        "lng" => -84.2917405,
        "no_earlier_than" => "2023-05-25T16:50:00.000Z",
        "no_later_than" => "2023-05-25T17:00:00.000Z",
        "notes" => [],
        "pickup_dropoff_option" => "pickup",
        "position" => 1,
        "scheduled_at" => nil,
        "state" => "GA",
        "street" => nil,
        "zipcode" => "30501"
      },
      %{
        "address" => "863 Dawsonville Hwy",
        "address_second_line" => nil,
        "address_type" => nil,
        "asap" => false,
        "borough" => nil,
        "city" => "Englewood",
        "customer" => %{
          "allow_sending_email" => true,
          "allow_sending_sms" => true,
          "email" => "",
          "external_id" => "97894420",
          "extras" => nil,
          "id" => 97_894_420,
          "language" => nil,
          "name" => "Test Customer",
          "phone" => "+12025550194"
        },
        "district" => nil,
        "extras" => nil,
        "first_attempt_promise_no_earlier_than" => nil,
        "first_attempt_promise_no_later_than" => nil,
        "house_number" => nil,
        "id" => 362_323_773,
        "inventory" => [
          %{
            "age_restricted" => nil,
            "external_id" => "18419863",
            "extras" => nil,
            "height" => 10,
            "id" => 963_020_126,
            "image" => "/images/product-placeholder.png",
            "length" => 50,
            "name" => "Inventory",
            "original_quantity" => 1,
            "price" => 20,
            "scan_string" => "7f54b00ef8edc6cd",
            "services" => [],
            "size" => nil,
            "volume" => nil,
            "weight" => 100,
            "width" => 50
          }
        ],
        "lat" => 39.8774786,
        "lng" => -84.3123227,
        "no_earlier_than" => "2023-05-25T17:00:00.000Z",
        "no_later_than" => "2023-05-25T18:00:00.000Z",
        "notes" => [],
        "pickup_dropoff_option" => "dropoff",
        "position" => 2,
        "scheduled_at" => nil,
        "state" => "GA",
        "street" => nil,
        "zipcode" => "30501"
      }
    ]
  }

  describe "create match" do
    test "create match with valid params works", %{
      conn: conn,
      bringg_shipper: %Shipper{id: bringg_shipper_id}
    } do
      bringg_params = %{
        "customer" => %{
          "email" => "test@bringg.com",
          "external_id" => "11557429",
          "id" => 11_557_429,
          "name" => "Test Customer",
          "phone" => "+12025550194"
        },
        "external_id" => "561e1a26",
        "extras" => nil,
        "id" => 20_377_415,
        "priority" => 20_377_415,
        "request_id" => "72afd436-dfb9-491e-a388-ac7ad0393dec",
        "run_id" => nil,
        "title" => "Test order",
        "type" => false,
        "tip" => 10.4,
        "way_points" => [
          %{
            "address" => "863 Dawsonville Hwy",
            "address_second_line" => nil,
            "address_type" => nil,
            "asap" => false,
            "borough" => nil,
            "city" => "Gainesville",
            "customer" => %{
              "email" => "",
              "external_id" => "11557430",
              "id" => 11_557_430,
              "name" => "Warehouse",
              "phone" => nil
            },
            "district" => nil,
            "house_number" => nil,
            "id" => 27_750_916,
            "inventory" => [
              %{
                "external_id" => "18419863",
                "height" => 10,
                "id" => 58_592_537,
                "length" => 50.5,
                "name" => "Inventory",
                "original_quantity" => 1,
                "scan_string" => "7f54b00ef8edc6cd",
                "volume" => nil,
                "weight" => 100.5,
                "width" => 50.5,
                "price" => 20
              }
            ],
            "lat" => 39.8656099,
            "lng" => -84.2917405,
            "pickup_dropoff_option" => "pickup",
            "position" => 1,
            "no_earlier_than" => "2030-11-09T16:50:00.000000Z",
            "no_later_than" => "2030-11-09T17:00:00.000000Z",
            "state" => "GA",
            "zipcode" => "30501",
            "notes" => [
              %{
                "note" => "Pick me up!"
              }
            ]
          },
          %{
            "address" => "863 Dawsonville Hwy",
            "address_second_line" => nil,
            "address_type" => nil,
            "asap" => false,
            "borough" => nil,
            "city" => "Englewood",
            "customer" => %{
              "email" => "test@bringg.com",
              "external_id" => "11557429",
              "id" => 11_557_429,
              "name" => "Test Customer",
              "phone" => "+12025550194"
            },
            "district" => nil,
            "house_number" => nil,
            "id" => 27_750_917,
            "inventory" => [
              %{
                "external_id" => "18419863",
                "height" => 10,
                "id" => 58_592_538,
                "length" => 50,
                "name" => "Inventory",
                "original_quantity" => 1,
                "scan_string" => "7f54b00ef8edc6cd",
                "volume" => nil,
                "weight" => 100,
                "width" => 50,
                "price" => 20
              }
            ],
            "lat" => 39.8774786,
            "lng" => -84.3123227,
            "pickup_dropoff_option" => "dropoff",
            "position" => 2,
            "no_earlier_than" => "2030-11-09T17:00:00.000000Z",
            "no_later_than" => "2030-11-09T18:00:00.000000Z",
            "state" => "GA",
            "zipcode" => "30501",
            "notes" => [
              %{
                "note" => "Drop me off!"
              }
            ]
          }
        ]
      }

      conn = post(conn, Routes.bringg_path(conn, :create), bringg_params)

      assert %{"delivery_id" => match_id, "success" => true} = json_response(conn, 200)

      assert %Match{
               id: ^match_id,
               state: :scheduled,
               identifier: identifier,
               shipper_id: ^bringg_shipper_id,
               pickup_at: ~U[2030-11-09 16:55:00Z],
               dropoff_at: ~U[2030-11-09 17:30:00Z],
               match_stops: [
                 %{
                   tip_price: 1040
                 }
               ]
             } = Shipment.get_match!(match_id)

      assert identifier == "20377415"
    end

    test "create match with autoselect and large volume", %{
      conn: conn,
      bringg_shipper: %Shipper{id: _bringg_shipper_id}
    } do
      bringg_params = %{
        "customer" => %{
          "email" => "test@bringg.com",
          "external_id" => "11557429",
          "id" => 11_557_429,
          "name" => "Test Customer",
          "phone" => "+12025550194"
        },
        "external_id" => "561e1a26",
        "extras" => nil,
        "id" => 20_377_415,
        "priority" => 20_377_415,
        "request_id" => "72afd436-dfb9-491e-a388-ac7ad0393dec",
        "run_id" => nil,
        "title" => "Test order",
        "type" => false,
        "tip" => 10.4,
        "way_points" => [
          %{
            "address" => "863 Dawsonville Hwy",
            "address_second_line" => nil,
            "address_type" => nil,
            "asap" => false,
            "borough" => nil,
            "city" => "Gainesville",
            "customer" => %{
              "email" => "",
              "external_id" => "11557430",
              "id" => 11_557_430,
              "name" => "Warehouse",
              "phone" => nil
            },
            "district" => nil,
            "house_number" => nil,
            "id" => 27_750_916,
            "inventory" => [
              %{
                "external_id" => "18419863",
                "height" => 11.05,
                "id" => 58_592_538,
                "length" => 11.05,
                "name" => "Inventory",
                "original_quantity" => 150,
                "scan_string" => "7f54b00ef8edc6cd",
                "volume" => nil,
                "weight" => 1,
                "width" => 11.05,
                "price" => 20
              }
            ],
            "lat" => 39.8656099,
            "lng" => -84.2917405,
            "pickup_dropoff_option" => "pickup",
            "position" => 1,
            "no_earlier_than" => "2030-11-09T16:50:00.000000Z",
            "no_later_than" => "2030-11-09T17:00:00.000000Z",
            "state" => "GA",
            "zipcode" => "30501",
            "notes" => [
              %{
                "note" => "Pick me up!"
              }
            ]
          },
          %{
            "address" => "863 Dawsonville Hwy",
            "address_second_line" => nil,
            "address_type" => nil,
            "asap" => false,
            "borough" => nil,
            "city" => "Englewood",
            "customer" => %{
              "email" => "test@bringg.com",
              "external_id" => "11557429",
              "id" => 11_557_429,
              "name" => "Test Customer",
              "phone" => "+12025550194"
            },
            "district" => nil,
            "house_number" => nil,
            "id" => 27_750_917,
            "inventory" => [
              %{
                "external_id" => "18419863",
                "height" => 11.05,
                "id" => 58_592_538,
                "length" => 11.05,
                "name" => "Inventory",
                "original_quantity" => 150,
                "scan_string" => "7f54b00ef8edc6cd",
                "volume" => nil,
                "weight" => 1,
                "width" => 11.05,
                "price" => 20
              }
            ],
            "lat" => 39.8774786,
            "lng" => -84.3123227,
            "pickup_dropoff_option" => "dropoff",
            "position" => 2,
            "no_earlier_than" => "2030-11-09T17:00:00.000000Z",
            "no_later_than" => "2030-11-09T18:00:00.000000Z",
            "state" => "GA",
            "zipcode" => "30501",
            "notes" => [
              %{
                "note" => "Drop me off!"
              }
            ]
          }
        ]
      }

      conn = post(conn, Routes.bringg_path(conn, :create), bringg_params)

      assert %{"delivery_id" => match_id, "success" => true} = json_response(conn, 200)

      assert %Match{
               vehicle_class: 3,
               total_volume: 259_200
             } = Shipment.get_match!(match_id)
    end

    test "without lat/lng", %{conn: conn} do
      bringg_params = %{
        "customer" => %{
          "allow_sending_email" => true,
          "allow_sending_sms" => true,
          "email" => nil,
          "external_id" => "16917499",
          "extras" => nil,
          "id" => 16_917_499,
          "language" => nil,
          "name" => "KIMBERLY RODRIGUEZ",
          "phone" => nil
        },
        "external_id" => "20301218.860.47.6-D",
        "extras" => nil,
        "id" => 38_864_428,
        "left_to_be_paid" => nil,
        "pre_delivery_tip" => 0,
        "price_before_tax" => nil,
        "priority" => 38_864_428,
        "request_id" => "fe4d8cbd-a0c0-4f3a-9422-a3940d81a294",
        "run_id" => nil,
        "service_plan_id" => nil,
        "tag_id" => 1142,
        "task_configuration_id" => nil,
        "tip" => 0,
        "title" => "Delivery for KIMBERLY RODRIGUEZ",
        "total_price" => 0,
        "type" => "delivery",
        "way_points" => [
          %{
            "address" => "2559 COLDEN AVE,BSMT 1A, BRONX NY, 10469",
            "address_second_line" => nil,
            "address_type" => nil,
            "asap" => nil,
            "borough" => nil,
            "city" => "BRONX",
            "customer" => %{
              "allow_sending_email" => true,
              "allow_sending_sms" => false,
              "email" => "kimrodri32@icloud.com",
              "external_id" => "16917500",
              "extras" => nil,
              "id" => 16_917_500,
              "language" => nil,
              "name" => "KIMBERLY RODRIGUEZ",
              "phone" => "+19174438857"
            },
            "district" => nil,
            "extras" => nil,
            "first_attempt_promise_no_earlier_than" => nil,
            "first_attempt_promise_no_later_than" => nil,
            "house_number" => nil,
            "id" => 50_818_517,
            "inventory" => [
              %{
                "age_restricted" => nil,
                "external_id" => "4137",
                "extras" => nil,
                "height" => 0,
                "id" => 98_718_180,
                "image" => "/images/product-placeholder.png",
                "length" => 0,
                "name" => "Red Plastic Table Cover",
                "original_quantity" => 2,
                "price" => 20,
                "scan_string" => nil,
                "size" => nil,
                "volume" => nil,
                "weight" => 0,
                "width" => 0
              }
            ],
            "lat" => 40.8645808,
            "lng" => -73.8599432,
            "no_earlier_than" => "2030-12-19T20:00:00.000Z",
            "no_later_than" => "2030-12-19T21:00:00.000Z",
            "notes" => [
              %{
                "external_id" => "38657921",
                "id" => 38_657_921,
                "note" => "Call before arriving "
              }
            ],
            "pickup_dropoff_option" => "dropoff",
            "position" => 2,
            "scheduled_at" => nil,
            "state" => "NY",
            "street" => nil,
            "zipcode" => "10469"
          },
          %{
            "address" => "1 Fordham Plaza, Bronx NY, 10458",
            "address_second_line" => nil,
            "address_type" => nil,
            "asap" => nil,
            "borough" => nil,
            "city" => "Bronx",
            "customer" => %{
              "allow_sending_email" => true,
              "allow_sending_sms" => true,
              "email" => nil,
              "external_id" => "16332658",
              "extras" => nil,
              "id" => 16_332_658,
              "language" => nil,
              "name" => "Bronx - E Fordham R",
              "phone" => "+13473916714"
            },
            "district" => nil,
            "extras" => nil,
            "first_attempt_promise_no_earlier_than" => nil,
            "first_attempt_promise_no_later_than" => nil,
            "house_number" => nil,
            "id" => 50_818_516,
            "inventory" => [
              %{
                "age_restricted" => nil,
                "external_id" => "4137",
                "extras" => nil,
                "height" => 0,
                "id" => 98_718_171,
                "image" => "/images/product-placeholder.png",
                "length" => 0,
                "name" => "Red Plastic Table Cover",
                "original_quantity" => 2,
                "price" => 20,
                "scan_string" => nil,
                "size" => nil,
                "volume" => nil,
                "weight" => 0,
                "width" => 0
              }
            ],
            "lat" => nil,
            "lng" => nil,
            "no_earlier_than" => "2030-12-19T19:50:00.000Z",
            "no_later_than" => "2030-12-19T20:00:00.000Z",
            "notes" => [
              %{
                "external_id" => "38657920",
                "id" => 38_657_920,
                "note" => "Pickup Order 20301218.860.47.6-D"
              }
            ],
            "pickup_dropoff_option" => "pickup",
            "position" => 1,
            "scheduled_at" => nil,
            "state" => "NY",
            "street" => nil,
            "zipcode" => "10458"
          }
        ]
      }

      conn = post(conn, Routes.bringg_path(conn, :create), bringg_params)

      assert %{"delivery_id" => match_id, "success" => true} = json_response(conn, 200)

      assert %Match{
               origin_address: %Address{address: "1 Fordham Plaza, Bronx NY, 10458"}
             } = Shipment.get_match!(match_id)
    end

    test "create with invalid auth header fails", %{
      conn: conn
    } do
      conn = conn |> delete_req_header("authorization")

      bringg_params = %{
        "customer" => %{
          "email" => "test@bringg.com",
          "external_id" => "11557429",
          "id" => 11_557_429,
          "name" => "Test Customer",
          "phone" => "+12025550194"
        },
        "external_id" => "561e1a26",
        "extras" => nil,
        "id" => 20_377_415,
        "priority" => 20_377_415,
        "request_id" => "72afd436-dfb9-491e-a388-ac7ad0393dec",
        "run_id" => nil,
        "title" => "Test order",
        "type" => false,
        "way_points" => [
          %{
            "address" => "606 Taywood Rd, OH , USA",
            "address_second_line" => nil,
            "address_type" => nil,
            "asap" => false,
            "borough" => nil,
            "city" => "Englewood",
            "customer" => %{
              "email" => "",
              "external_id" => "11557430",
              "id" => 11_557_430,
              "name" => "Warehouse",
              "phone" => nil
            },
            "district" => nil,
            "house_number" => nil,
            "id" => 27_750_916,
            "inventory" => [
              %{
                "external_id" => "18419863",
                "height" => 10,
                "id" => 58_592_537,
                "length" => 50,
                "name" => "Inventory",
                "original_quantity" => 1,
                "scan_string" => "7f54b00ef8edc6cd",
                "volume" => nil,
                "weight" => 100,
                "width" => 50,
                "price" => 20
              }
            ],
            "lat" => 39.8656099,
            "lng" => -84.2917405,
            "no_earlier_than" => "2030-09-11T17:47:57.801Z",
            "no_later_than" => "2030-09-11T17:47:57.801Z",
            "pickup_dropoff_option" => "pickup",
            "position" => 1,
            "scheduled_at" => "2030-09-11T18:17:57.801Z",
            "state" => nil,
            "zipcode" => "45322",
            "notes" => [
              %{
                "note" => "Pick me up!"
              }
            ]
          },
          %{
            "address" => "501 W National Rd, OH , USA",
            "address_second_line" => nil,
            "address_type" => nil,
            "asap" => false,
            "borough" => nil,
            "city" => "Englewood",
            "customer" => %{
              "email" => "test@bringg.com",
              "external_id" => "11557429",
              "id" => 11_557_429,
              "name" => "Test Customer",
              "phone" => "+12025550194"
            },
            "district" => nil,
            "house_number" => nil,
            "id" => 27_750_917,
            "inventory" => [
              %{
                "external_id" => "18419863",
                "height" => 10,
                "id" => 58_592_538,
                "length" => 50,
                "name" => "Inventory",
                "original_quantity" => 1,
                "scan_string" => "7f54b00ef8edc6cd",
                "volume" => nil,
                "weight" => 100,
                "width" => 50,
                "price" => 20
              }
            ],
            "lat" => 39.8774786,
            "lng" => -84.3123227,
            "no_earlier_than" => "2030-09-11T18:47:57.801Z",
            "no_later_than" => "2030-09-11T19:47:57.801Z",
            "pickup_dropoff_option" => "dropoff",
            "position" => 2,
            "scheduled_at" => "2030-09-11T19:17:57.801Z",
            "state" => nil,
            "zipcode" => "45322",
            "notes" => [
              %{
                "note" => "Drop me off!"
              }
            ]
          }
        ]
      }

      conn = post(conn, Routes.bringg_path(conn, :create), bringg_params)

      assert json_response(conn, :forbidden)
    end
  end

  describe "update match" do
    test "update with non bringg match fails", %{conn: conn} do
      %Match{id: match_id} =
        insert(:match,
          identifier: "20377415",
          pickup_notes: "Some notes that already exist",
          match_stops: [build(:match_stop, items: [build(:match_stop_item, pieces: 5)])]
        )

      bringg_params = %{
        "task_id" => 20_377_415,
        "delivery_id" => match_id,
        "task_note" => %{
          "id" => 10_284_559,
          "note" => "New notes from Bringg",
          "user_id" => 660_963,
          "task_id" => 7_694_849,
          "created_at" => "2030-06-09T12:59:29.883Z",
          "updated_at" => "2030-06-09T12:59:29.883Z",
          "type" => "TaskNote",
          "way_point_id" => 11_812_926,
          "external_id" => "10284559"
        },
        "task_inventory" => %{
          "original_quantity" => 3,
          "id" => 37_792_187,
          "name" => "Mild Chicken Sandwich"
        }
      }

      conn = post(conn, Routes.bringg_path(conn, :update), bringg_params)

      assert json_response(conn, 403)
    end

    test "updates notes and inventory", %{conn: conn, bringg_shipper: bringg_shipper} do
      %Match{id: match_id} =
        insert(:match,
          identifier: "20377415",
          shipper: bringg_shipper,
          pickup_notes: "Some notes that already exist",
          match_stops: [
            build(:match_stop_with_item,
              items: [build(:match_stop_item, pieces: 5, external_id: "37792187")]
            )
          ]
        )

      bringg_params = %{
        "task_id" => 20_377_415,
        "delivery_id" => match_id,
        "task_note" => %{
          "id" => 10_284_559,
          "note" => "New notes from Bringg",
          "user_id" => 660_963,
          "task_id" => 7_694_849,
          "created_at" => "2030-06-09T12:59:29.883Z",
          "updated_at" => "2030-06-09T12:59:29.883Z",
          "type" => "TaskNote",
          "way_point_id" => 11_812_926,
          "external_id" => "10284559"
        },
        "task_inventory" => %{
          "original_quantity" => 3,
          "id" => 37_792_187,
          "name" => "Mild Chicken Sandwich"
        }
      }

      conn = post(conn, Routes.bringg_path(conn, :update), bringg_params)

      assert %{"success" => true} = json_response(conn, 200)

      assert %Match{
               id: ^match_id,
               state: :assigning_driver,
               pickup_notes: pickup_notes,
               match_stops: [%MatchStop{items: [%MatchStopItem{pieces: 3}]}]
             } = Shipment.get_match!(match_id)

      assert pickup_notes == "Some notes that already exist; New notes from Bringg"
    end

    test "updates scheduled time and address", %{conn: conn, bringg_shipper: bringg_shipper} do
      %Match{id: match_id} =
        insert(:match,
          origin_address: build(:address),
          shipper: bringg_shipper,
          identifier: "20377415",
          pickup_at: nil
        )

      bringg_params = %{
        "task_id" => 7_694_849,
        "delivery_id" => match_id,
        "way_point" => %{
          "scheduled_at" => "2030-06-29T11:00:00.000Z",
          "id" => 11_812_925,
          "address" => "4533 Ruebel Place",
          "zipcode" => "45211",
          "lat" => 39.1584446,
          "lng" => -84.62863829999999,
          "position" => 1
        }
      }

      conn = post(conn, Routes.bringg_path(conn, :update), bringg_params)

      assert %{"success" => true} = json_response(conn, 200)

      assert %Match{
               id: ^match_id,
               origin_address: %Address{address: "4533 Ruebel Place"},
               state: :assigning_driver,
               pickup_at: ~U[2030-06-29 11:00:00Z]
             } = Shipment.get_match!(match_id)
    end
  end

  describe "cancel match" do
    test "cancels existing match", %{conn: conn, bringg_shipper: bringg_shipper} do
      %{id: match_id} =
        insert(:match, identifier: "123456", state: :assigning_driver, shipper: bringg_shipper)

      bringg_params = %{
        "delivery_id" => match_id,
        "id" => 123_456,
        "reason" => "Text describing the reason for the cancellation",
        "reason_id" => 1
      }

      conn = post(conn, Routes.bringg_path(conn, :cancel), bringg_params)

      assert %{"success" => true} = json_response(conn, 200)

      assert %Match{
               id: ^match_id,
               state: :canceled,
               identifier: "123456",
               state_transitions: [state_transition]
             } = Shipment.get_match!(match_id)

      assert state_transition.notes ==
               "Canceled by Bringg: Text describing the reason for the cancellation"
    end

    test "cancels existing match without reason string", %{
      conn: conn,
      bringg_shipper: bringg_shipper
    } do
      %{id: match_id} =
        insert(:match, identifier: "123456", state: :assigning_driver, shipper: bringg_shipper)

      bringg_params = %{
        "delivery_id" => match_id,
        "id" => 123_456,
        "reason_id" => 1
      }

      conn = post(conn, Routes.bringg_path(conn, :cancel), bringg_params)

      assert %{"success" => true} = json_response(conn, 200)

      assert %Match{
               id: ^match_id,
               state: :canceled,
               identifier: "123456",
               state_transitions: [state_transition]
             } = Shipment.get_match!(match_id)

      assert state_transition.notes ==
               "Canceled by Bringg"
    end

    test "attempting to cancel no bring match fails", %{conn: conn} do
      %{id: match_id} = insert(:match, identifier: "123456", state: :assigning_driver)

      bringg_params = %{
        "delivery_id" => match_id,
        "id" => 123_456,
        "reason_id" => 1
      }

      conn = post(conn, Routes.bringg_path(conn, :cancel), bringg_params)

      assert json_response(conn, :forbidden)
    end
  end

  describe "merchant registered" do
    test "registers a merchant", %{conn: conn} do
      bringg_params = %{
        "merchant_uuid" => "c1bfbbaa-15fd-423c-a2f2-bcc393d3bdb0"
      }

      conn = post(conn, Routes.bringg_path(conn, :merchant_registered), bringg_params)

      assert %{"success" => true, "merchant_uuid" => merchant_uuid} = json_response(conn, 200)

      assert %Company{
               name: "random name",
               integration_id: "c1bfbbaa-15fd-423c-a2f2-bcc393d3bdb0",
               integration: :bringg,
               api_key: "api_key",
               webhook_config: %{
                 client_id: "client_id",
                 secret: "secret"
               }
             } = FraytElixir.Repo.get_by(Company, integration_id: merchant_uuid)
    end
  end

  describe "when a driver is assigned" do
    test "it should send webhook request to bringg",
         %{conn: conn} do
      conn = post(conn, Routes.bringg_path(conn, :create), @valid_bringg_params)

      assert %{"delivery_id" => match_id} = json_response(conn, 200)

      match = Shipment.get_match!(match_id)

      match = Shipment.MatchWorkflow.force_transition_state(match, :assigning_driver)

      %Driver{id: driver_id} =
        driver =
        insert(:driver_with_wallet,
          phone_number: "+12345676543",
          current_location: build(:driver_location)
        )

      is_reassign = false
      pid = GenServer.whereis({:global, "match_webhook_sender:#{match.id}"})

      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

      assert {:ok, %Match{driver: %Driver{id: ^driver_id}, state: :accepted}} =
               Drivers.assign_match(match, driver, is_reassign)

      assert 1 ==
               Repo.all(FraytElixir.Webhooks.WebhookRequest)
               |> Enum.count()

      assert_receive {:ok,
                      %HTTPoison.Response{
                        body: %{
                          "payload_id" => _,
                          "reported_time" => _,
                          "task_id" => _,
                          "user" => %{
                            "email" => _,
                            "external_id" => _,
                            "name" => _
                          }
                        },
                        headers: [
                          {"Authorization", _}
                        ],
                        request: %HTTPoison.Request{
                          body: _,
                          headers: [],
                          method: :post,
                          options: _,
                          params: %{},
                          url:
                            "https://us2-admin-api.bringg.com/open_fleet_services/assign_driver"
                        },
                        request_url:
                          "https://us2-admin-api.bringg.com/open_fleet_services/assign_driver",
                        status_code: 201
                      }}
    end

    test "state should be en_route_to_pickup",
         %{conn: conn} do
      conn = post(conn, Routes.bringg_path(conn, :create), @valid_bringg_params)

      assert %{"delivery_id" => match_id} = json_response(conn, 200)

      match = Shipment.get_match!(match_id)

      pid = GenServer.whereis({:global, "match_webhook_sender:#{match.id}"})

      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

      match = Shipment.MatchWorkflow.force_transition_state(match, :assigning_driver)

      %Driver{id: driver_id} =
        driver =
        insert(:driver_with_wallet,
          phone_number: "+12345676543",
          current_location: build(:driver_location)
        )

      is_reassign = false

      assert {:ok, %Match{driver: %Driver{id: ^driver_id}, state: :accepted}} =
               Drivers.assign_match(match, driver, is_reassign)

      {:ok, _match} =
        Shipment.get_match!(match_id)
        |> Shipment.MatchWorkflow.en_route_to_pickup()

      assert 2 ==
               Repo.all(FraytElixir.Webhooks.WebhookRequest)
               |> Enum.count()

      assert_receive {
        :ok,
        %HTTPoison.Response{
          body: %{
            "lat" => _,
            "lng" => _,
            "payload_id" => _,
            "reported_time" => _,
            "task_id" => _
          },
          headers: [
            {"Authorization", _}
          ],
          request: %HTTPoison.Request{
            body: _,
            headers: [],
            method: :post,
            options: _,
            params: %{},
            url: "https://us2-admin-api.bringg.com/open_fleet_services/start_task"
          },
          request_url: "https://us2-admin-api.bringg.com/open_fleet_services/start_task",
          status_code: 201
        }
      }
    end

    test "state should be arrived_at_pickup",
         %{conn: conn} do
      conn = post(conn, Routes.bringg_path(conn, :create), @valid_bringg_params)

      assert %{"delivery_id" => match_id} = json_response(conn, 200)

      match = Shipment.get_match!(match_id)

      pid = GenServer.whereis({:global, "match_webhook_sender:#{match.id}"})

      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

      match = Shipment.MatchWorkflow.force_transition_state(match, :assigning_driver)

      %Driver{id: driver_id} =
        driver =
        insert(:driver_with_wallet,
          phone_number: "+12345676543",
          current_location: build(:driver_location)
        )

      is_reassign = false

      assert {:ok, %Match{driver: %Driver{id: ^driver_id}, state: :accepted}} =
               Drivers.assign_match(match, driver, is_reassign)

      {:ok, match} =
        Shipment.get_match!(match_id)
        |> Shipment.MatchWorkflow.en_route_to_pickup()

      {:ok, _} =
        match
        |> Shipment.MatchWorkflow.arrive_at_pickup()

      assert 3 ==
               Repo.all(FraytElixir.Webhooks.WebhookRequest)
               |> Enum.count()

      assert_receive {
        :ok,
        %HTTPoison.Response{
          body: %{
            "lat" => _,
            "lng" => _,
            "payload_id" => _,
            "reported_time" => _,
            "task_id" => _
          },
          headers: [
            {"Authorization", _}
          ],
          request: %HTTPoison.Request{
            body: _,
            headers: [],
            method: :post,
            options: _,
            params: %{},
            url: "https://us2-admin-api.bringg.com/open_fleet_services/checkin"
          },
          request_url: "https://us2-admin-api.bringg.com/open_fleet_services/checkin",
          status_code: 201
        }
      }
    end

    test "state should be picked_up",
         %{conn: conn} do
      conn = post(conn, Routes.bringg_path(conn, :create), @valid_bringg_params)

      assert %{"delivery_id" => match_id} = json_response(conn, 200)

      match = Shipment.get_match!(match_id)

      pid = GenServer.whereis({:global, "match_webhook_sender:#{match.id}"})

      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

      match = Shipment.MatchWorkflow.force_transition_state(match, :assigning_driver)

      %Driver{id: driver_id} =
        driver =
        insert(:driver_with_wallet,
          phone_number: "+12345676543",
          current_location: build(:driver_location)
        )

      is_reassign = false

      assert {:ok, %Match{driver: %Driver{id: ^driver_id}, state: :accepted}} =
               Drivers.assign_match(match, driver, is_reassign)

      {:ok, match} =
        Shipment.get_match!(match_id)
        |> Shipment.MatchWorkflow.en_route_to_pickup()

      {:ok, match} =
        match
        |> Shipment.MatchWorkflow.arrive_at_pickup()

      {:ok, _match} = match |> Shipment.MatchWorkflow.pickup()

      assert 6 ==
               Repo.all(FraytElixir.Webhooks.WebhookRequest)
               |> Enum.count()

      assert_receive {
        :ok,
        %HTTPoison.Response{
          body: %{
            "payload_id" => _,
            "task_id" => _,
            "image" => _,
            "type" => _,
            "way_point_position" => 1
          },
          headers: [
            {"Authorization", _}
          ],
          request: %HTTPoison.Request{
            body: _,
            headers: [],
            method: :post,
            options: _,
            params: %{},
            url: "https://us2-admin-api.bringg.com/open_fleet_services/create_note"
          },
          request_url: "https://us2-admin-api.bringg.com/open_fleet_services/create_note",
          status_code: 201
        }
      }

      assert_receive {
        :ok,
        %HTTPoison.Response{
          body: %{
            "payload_id" => _,
            "task_id" => _,
            "lat" => _,
            "lng" => _,
            "reported_time" => _
          },
          headers: [
            {"Authorization", _}
          ],
          request: %HTTPoison.Request{
            body: _,
            headers: [],
            method: :post,
            options: _,
            params: %{},
            url: "https://us2-admin-api.bringg.com/open_fleet_services/checkout"
          },
          request_url: "https://us2-admin-api.bringg.com/open_fleet_services/checkout",
          status_code: 201
        }
      }
    end
  end

  test "state should be en_route_to_dropoff",
       %{conn: conn} do
    conn = post(conn, Routes.bringg_path(conn, :create), @valid_bringg_params)

    assert %{"delivery_id" => match_id} = json_response(conn, 200)

    match = Shipment.get_match!(match_id)

    pid = GenServer.whereis({:global, "match_webhook_sender:#{match.id}"})

    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

    match = Shipment.MatchWorkflow.force_transition_state(match, :assigning_driver)

    %Driver{id: driver_id} =
      driver =
      insert(:driver_with_wallet,
        phone_number: "+12345676543",
        current_location: build(:driver_location)
      )

    is_reassign = false

    assert {:ok, %Match{driver: %Driver{id: ^driver_id}, state: :accepted}} =
             Drivers.assign_match(match, driver, is_reassign)

    {:ok, match} =
      Shipment.get_match!(match_id)
      |> Shipment.MatchWorkflow.en_route_to_pickup()

    {:ok, match} =
      match
      |> Shipment.MatchWorkflow.arrive_at_pickup()

    {:ok, match} = match |> Shipment.MatchWorkflow.pickup()

    [match_stop | _] = match.match_stops
    match_stop = match_stop |> Repo.preload(match: :driver)
    {:ok, _} = match_stop |> Shipment.MatchWorkflow.en_route_to_stop()

    assert_receive {
      :ok,
      %HTTPoison.Response{
        body: %{
          "payload_id" => _,
          "lat" => _,
          "lng" => _
        },
        headers: [
          {"Authorization", _}
        ],
        request: %HTTPoison.Request{
          body: _,
          headers: [],
          method: :post,
          options: _,
          params: %{},
          url: "https://us2-admin-api.bringg.com/open_fleet_services/update_driver_location"
        },
        request_url:
          "https://us2-admin-api.bringg.com/open_fleet_services/update_driver_location",
        status_code: 201
      }
    }

    assert 7 ==
             Repo.all(FraytElixir.Webhooks.WebhookRequest)
             |> Enum.count()
  end

  test "state should be arrived",
       %{conn: conn, bringg_shipper: %Shipper{id: _bringg_shipper_id}} do
    conn = post(conn, Routes.bringg_path(conn, :create), @valid_bringg_params)

    assert %{"delivery_id" => match_id} = json_response(conn, 200)

    match = Shipment.get_match!(match_id)

    pid = GenServer.whereis({:global, "match_webhook_sender:#{match.id}"})

    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

    match = Shipment.MatchWorkflow.force_transition_state(match, :assigning_driver)

    %Driver{id: driver_id} =
      driver =
      insert(:driver_with_wallet,
        phone_number: "+12345676543",
        current_location: build(:driver_location)
      )

    is_reassign = false

    assert {:ok, %Match{driver: %Driver{id: ^driver_id}, state: :accepted}} =
             Drivers.assign_match(match, driver, is_reassign)

    {:ok, match} =
      Shipment.get_match!(match_id)
      |> Shipment.MatchWorkflow.en_route_to_pickup()

    {:ok, match} =
      match
      |> Shipment.MatchWorkflow.arrive_at_pickup()

    {:ok, match} = match |> Shipment.MatchWorkflow.pickup()

    [match_stop | _] = match.match_stops
    match_stop = match_stop |> Repo.preload(match: :driver)

    {:ok, match_stop} =
      match_stop
      |> Shipment.MatchWorkflow.en_route_to_stop()

    match_stop =
      match_stop
      |> Repo.preload(match: :driver)

    {:ok, _match} =
      match_stop
      |> Shipment.MatchWorkflow.arrive_at_stop()

    assert 8 ==
             Repo.all(FraytElixir.Webhooks.WebhookRequest)
             |> Enum.map(& &1.webhook_url)
             |> Enum.count()
  end

  test "state should be delivered",
       %{conn: conn} do
    conn = post(conn, Routes.bringg_path(conn, :create), @valid_bringg_params)

    assert %{"delivery_id" => match_id} = json_response(conn, 200)

    match = Shipment.get_match!(match_id)

    pid = GenServer.whereis({:global, "match_webhook_sender:#{match.id}"})

    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

    match = Shipment.MatchWorkflow.force_transition_state(match, :assigning_driver)

    %Driver{id: driver_id} =
      driver =
      insert(:driver_with_wallet,
        phone_number: "+12345676543",
        current_location: build(:driver_location)
      )

    is_reassign = false

    assert {:ok, %Match{driver: %Driver{id: ^driver_id}, state: :accepted}} =
             Drivers.assign_match(match, driver, is_reassign)

    {:ok, match} =
      Shipment.get_match!(match_id)
      |> Shipment.MatchWorkflow.en_route_to_pickup()

    {:ok, match} =
      match
      |> Shipment.MatchWorkflow.arrive_at_pickup()

    {:ok, match} = match |> Shipment.MatchWorkflow.pickup()

    [match_stop | _] = match.match_stops
    match_stop = match_stop |> Repo.preload(match: :driver)

    {:ok, match_stop} =
      match_stop
      |> Shipment.MatchWorkflow.en_route_to_stop()

    match_stop =
      match_stop
      |> Repo.preload(match: :driver)

    {:ok, match} =
      match_stop
      |> Shipment.MatchWorkflow.arrive_at_stop()

    [match_stop | _] = match.match_stops

    {:ok, match} =
      match_stop
      |> Repo.preload(match: :driver)
      |> Shipment.MatchWorkflow.sign_for_stop()

    [match_stop | _] = match.match_stops

    {:ok, _match} =
      match_stop
      |> Repo.preload(match: :driver)
      |> Shipment.MatchWorkflow.deliver_stop()

    assert 11 ==
             Repo.all(FraytElixir.Webhooks.WebhookRequest)
             |> Enum.count()
  end

  test "state should be shipper_canceled",
       %{conn: conn} do
    conn = post(conn, Routes.bringg_path(conn, :create), @valid_bringg_params)

    assert %{"delivery_id" => match_id} = json_response(conn, 200)

    match = Shipment.get_match!(match_id)

    pid = GenServer.whereis({:global, "match_webhook_sender:#{match.id}"})

    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

    match = Shipment.MatchWorkflow.force_transition_state(match, :assigning_driver)

    %Driver{id: driver_id} =
      driver =
      insert(:driver_with_wallet,
        phone_number: "+12345676543",
        current_location: build(:driver_location)
      )

    is_reassign = false

    assert {:ok, %Match{driver: %Driver{id: ^driver_id}, state: :accepted}} =
             Drivers.assign_match(match, driver, is_reassign)

    {:ok, _match} =
      Shipment.get_match!(match_id)
      |> Shipment.MatchWorkflow.shipper_cancel_match("Unique cancel reason")

    assert 2 ==
             Repo.all(FraytElixir.Webhooks.WebhookRequest)
             |> Enum.count()

    assert_receive {
      :ok,
      %HTTPoison.Response{
        body: %{
          "payload_id" => _
        },
        headers: [
          {"Authorization", _}
        ],
        request: %HTTPoison.Request{
          body: _,
          headers: [],
          method: :post,
          options: _,
          params: %{},
          url: "https://us2-admin-api.bringg.com/open_fleet_services/cancel_delivery"
        },
        request_url: "https://us2-admin-api.bringg.com/open_fleet_services/cancel_delivery",
        status_code: 201
      }
    }
  end
end
