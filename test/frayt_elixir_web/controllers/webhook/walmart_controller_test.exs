defmodule FraytElixirWeb.Webhook.WalmartControllerTest do
  use FraytElixirWeb.ConnCase

  alias FraytElixir.Repo
  alias FraytElixir.Shipment
  alias FraytElixir.Drivers
  alias FraytElixir.Drivers.Driver
  alias FraytElixir.Shipment.Match
  alias FraytElixir.Shipment.MatchWorkflow
  alias FraytElixirWeb.Webhook.WalmartView
  import FraytElixir.Test.StartMatchSupervisor
  import FraytElixir.Test.WebhookHelper
  import FraytElixirWeb.Test.LoginHelper

  setup do
    Ecto.Adapters.SQL.Sandbox.mode(Repo, :auto)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    start_match_webhook_sender(self())
  end

  setup :start_match_supervisor
  setup :login_with_api

  @valid_match_params %{
    "externalOrderId" => "7501192713442",
    "externalDeliveryId" => "7501192713442_1",
    "orderInfo" => %{
      "totalWeight" => 64.0,
      "totalVolume" => 2.7799999713897705,
      "totalQuantity" => 20,
      "size" => "S",
      "orderLineItems" => [
        %{
          "id" => "3c19247d-0f35-4e20-b6ad-0ddc94c4cef0",
          "quantity" => 2,
          "orderedWeight" => 2.0,
          "uom" => "LB",
          "height" => 2.0,
          "width" => 1.0,
          "length" => 3.0,
          "uomDimension" => "FT"
        },
        %{
          "id" => "221ad-81c1a-12aa-31aa-001ac3411",
          "quantity" => 1,
          "orderedWeight" => 3.0,
          "uom" => "LB",
          "height" => 1.0,
          "width" => 1.0,
          "length" => 4.0,
          "uomDimension" => "FT"
        }
      ],
      "barcodeInfo" => [
        %{
          "barcode" => "Q12345"
        },
        %{
          "barcode" => "Q12346"
        }
      ]
    },
    "pickupInfo" => %{
      "pickupAddress" => %{
        "addressLine1" => "708 Walnut Street",
        "addressLine2" => nil,
        "city" => "Cincinnati",
        "state" => "OH",
        "zipCode" => "45202",
        "country" => "US"
      },
      "pickupLocation" => %{
        "latitude" => 39.1043198,
        "longitude" => -84.5118912
      },
      "pickupContact" => %{
        "firstName" => "Walmart",
        "lastName" => "Store number =>5023",
        "phone" => "+12025550194"
      },
      "pickupInstruction" =>
        "Follow orange 'Pickup' signs in Walmart parking lot. Park and wait in any 'Reserved Pickup Parking' spot"
    },
    "dropOffInfo" => %{
      "dropOffAddress" => %{
        "addressLine1" => "3811 Mt Vernon Ave",
        "addressLine2" => nil,
        "city" => "Cincinnati",
        "state" => "OH",
        "zipCode" => "45202",
        "country" => "US"
      },
      "dropOffLocation" => %{
        "latitude" => 39.1474202,
        "longitude" => -84.4311616
      },
      "dropOffContact" => %{
        "firstName" => "TEST",
        "lastName" => "TEST",
        "phone" => "+12025550194"
      },
      "signatureRequired" => true,
      "proofOfDeliveryRequired" => false,
      "isContactlessDelivery" => false,
      "dropOffInstruction" => "Ring the bell once you are at dropoff"
    },
    "isAutonomousDelivery" => false,
    "containsAlcohol" => false,
    "containsPharmacy" => false,
    "containsHazmat" => false,
    "isIdVerificationRequired" => false,
    "deliveryWindowStartTime" => "2021-03-20T00:00:00.000Z",
    "deliveryWindowEndTime" => "2021-03-20T01:00:00.000Z",
    "pickupWindowStartTime" => "2021-03-19T23:30:00.000Z",
    "pickupWindowEndTime" => "2021-03-20T01:00:00.000Z",
    "externalStoreId" => "2612",
    "tip" => 0,
    "batchId" => "b77ac4e8-4a41-4699-b8e3-01c491f75560",
    "seqNumber" => 1,
    "osn" => "1234",
    "customerId" => "SAMS_CLUB",
    "clientId" => "2"
  }

  @valid_match_params_without_order_line_items %{
    "externalOrderId" => "7501192713442",
    "externalDeliveryId" => "7501192713442_1",
    "orderInfo" => %{
      "totalWeight" => 64.0,
      "totalVolume" => 2.7799999713897705,
      "totalQuantity" => 20,
      "size" => "S",
      "orderLineItems" => [],
      "barcodeInfo" => []
    },
    "pickupInfo" => %{
      "pickupAddress" => %{
        "addressLine1" => "708 Walnut Street",
        "addressLine2" => nil,
        "city" => "Cincinnati",
        "state" => "OH",
        "zipCode" => "45202",
        "country" => "US"
      },
      "pickupLocation" => %{
        "latitude" => 39.1043198,
        "longitude" => -84.5118912
      },
      "pickupContact" => %{
        "firstName" => "Walmart",
        "lastName" => "Store number =>5023",
        "phone" => "+12025550194"
      },
      "pickupInstruction" => "Follow orange 'Pickup' signs in Walmart parking lot. Park and
        wait in any 'Reserved Pickup Parking' spot"
    },
    "dropOffInfo" => %{
      "dropOffAddress" => %{
        "addressLine1" => "3811 Mt Vernon Ave",
        "addressLine2" => nil,
        "city" => "Cincinnati",
        "state" => "OH",
        "zipCode" => "45202",
        "country" => "US"
      },
      "dropOffLocation" => %{
        "latitude" => 39.1474202,
        "longitude" => -84.4311616
      },
      "dropOffContact" => %{
        "firstName" => "TEST",
        "lastName" => "TEST",
        "phone" => "+12025550194"
      },
      "signatureRequired" => true,
      "proofOfDeliveryRequired" => false,
      "isContactlessDelivery" => false,
      "dropOffInstruction" => "Ring the bell once you are at dropoff"
    },
    "isAutonomousDelivery" => false,
    "containsAlcohol" => false,
    "containsPharmacy" => false,
    "containsHazmat" => false,
    "isIdVerificationRequired" => false,
    "deliveryWindowStartTime" => "2021-03-20T00:00:00.000Z",
    "deliveryWindowEndTime" => "2021-03-20T01:00:00.000Z",
    "pickupWindowStartTime" => "2021-03-19T23:30:00.000Z",
    "pickupWindowEndTime" => "2021-03-20T01:00:00.000Z",
    "externalStoreId" => "2612",
    "tip" => 0,
    "batchId" => "b77ac4e8-4a41-4699-b8e3-01c491f75560",
    "seqNumber" => 1,
    "osn" => "1234",
    "customerId" => "SAMS_CLUB",
    "clientId" => "2"
  }

  @valid_match_params_with_missing_dimensions %{
    "externalOrderId" => "7501192713442",
    "externalDeliveryId" => "7501192713442_1",
    "orderInfo" => %{
      "totalWeight" => 64.0,
      "totalVolume" => 2.7799999713897705,
      "totalQuantity" => 20,
      "size" => "S",
      "orderLineItems" => [
        %{
          "id" => "1f6ac9f2-0e3f-4ab4-9f4a-ff3cbb4bba21",
          "quantity" => nil,
          "orderedWeight" => nil,
          "uom" => nil,
          "height" => nil,
          "width" => nil,
          "length" => nil,
          "uomDimension" => nil
        }
      ],
      "barcodeInfo" => []
    },
    "pickupInfo" => %{
      "pickupAddress" => %{
        "addressLine1" => "708 Walnut Street",
        "addressLine2" => nil,
        "city" => "Cincinnati",
        "state" => "OH",
        "zipCode" => "45202",
        "country" => "US"
      },
      "pickupLocation" => %{
        "latitude" => 39.1043198,
        "longitude" => -84.5118912
      },
      "pickupContact" => %{
        "firstName" => "Walmart",
        "lastName" => "Store number =>5023",
        "phone" => "+12025550194"
      },
      "pickupInstruction" => "Follow orange 'Pickup' signs in Walmart parking lot. Park and
        wait in any 'Reserved Pickup Parking' spot"
    },
    "dropOffInfo" => %{
      "dropOffAddress" => %{
        "addressLine1" => "3811 Mt Vernon Ave",
        "addressLine2" => nil,
        "city" => "Cincinnati",
        "state" => "OH",
        "zipCode" => "45202",
        "country" => "US"
      },
      "dropOffLocation" => %{
        "latitude" => 39.1474202,
        "longitude" => -84.4311616
      },
      "dropOffContact" => %{
        "firstName" => "TEST",
        "lastName" => "TEST",
        "phone" => "+12025550194"
      },
      "signatureRequired" => true,
      "proofOfDeliveryRequired" => false,
      "isContactlessDelivery" => false,
      "dropOffInstruction" => "Ring the bell once you are at dropoff"
    },
    "isAutonomousDelivery" => false,
    "containsAlcohol" => false,
    "containsPharmacy" => false,
    "containsHazmat" => false,
    "isIdVerificationRequired" => false,
    "deliveryWindowStartTime" => "2021-03-20T00:00:00.000Z",
    "deliveryWindowEndTime" => "2021-03-20T01:00:00.000Z",
    "pickupWindowStartTime" => "2021-03-19T23:30:00.000Z",
    "pickupWindowEndTime" => "2021-03-20T01:00:00.000Z",
    "externalStoreId" => "2612",
    "tip" => 0,
    "batchId" => "b77ac4e8-4a41-4699-b8e3-01c491f75560",
    "seqNumber" => 1,
    "osn" => "1234",
    "customerId" => "SAMS_CLUB",
    "clientId" => "2"
  }

  @match_cancel_params %{
    "cancelReason" => "OTHER"
  }

  describe "when a driver is assigned" do
    test "it should send webhook request to walmart",
         %{conn: conn, api_account: %{company: company}} do
      Ecto.Changeset.change(company, %{integration: :walmart})
      |> Repo.update()

      conn = post(conn, Routes.walmart_path(conn, :create), @valid_match_params)

      assert %{"id" => match_id} = json_response(conn, 200)

      match = Shipment.get_match!(match_id)

      assert %{parking_spot_required: true} = match

      Shipment.MatchWorkflow.force_transition_state(match, :assigning_driver)

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

      {:ok, _match} =
        Shipment.get_match!(match_id)
        |> MatchWorkflow.en_route_to_pickup()

      assert_receive {:ok,
                      %HTTPoison.Response{
                        body: %{
                          "batchId" => nil,
                          "courier" => %{
                            "firstName" => _,
                            "id" => _,
                            "lastName" => _,
                            "location" => %{"latitude" => _, "longitude" => _},
                            "maskedPhoneNumber" => _,
                            "phoneNumber" => _,
                            "vehicle" => %{
                              "color" => _,
                              "licensePlate" => _,
                              "make" => _,
                              "model" => _
                            }
                          },
                          "estimatedDeliveryTime" => _,
                          "estimatedPickupTime" => _,
                          "externalOrderId" => _,
                          "externalStoreId" => _,
                          "id" => _,
                          "payload_id" => _,
                          "status" => "EN_ROUTE_TO_PICKUP",
                          "actualDeliveryTime" => _,
                          "actualPickupTime" => _,
                          "actualReturnTime" => _,
                          "cancelReasonCode" => _,
                          "dropoffEta" => 0,
                          "estimatedReturnTime" => _,
                          "pickupEta" => 0,
                          "pickupParkingSlot" => _,
                          "returnEta" => 0,
                          "returnParkingSlot" => _,
                          "returnReasonCode" => _,
                          "timestamp" => _,
                          "dropoffVerification" => %{
                            "signatureImageUrl" => nil,
                            "deliveryProofImageUrl" => nil
                          }
                        },
                        headers: [{"Content-Type", "application/json"}],
                        request: _,
                        request_url:
                          "https://developer.api.us.stg.walmart.com/api-proxy/service/csp-webhook/service/v1/api/webhook/dsp?clientId=2",
                        status_code: 201
                      }}

      assert 1 == Repo.all(FraytElixir.Webhooks.WebhookRequest) |> Enum.count()
    end

    test "state should be arrived_at_pickup",
         %{conn: conn, api_account: %{company: company}} do
      Ecto.Changeset.change(company, %{integration: :walmart})
      |> Repo.update()

      conn = post(conn, Routes.walmart_path(conn, :create), @valid_match_params)

      assert %{"id" => match_id} = json_response(conn, 200)

      match = Shipment.get_match!(match_id)

      assert %{parking_spot_required: true} = match

      Shipment.MatchWorkflow.force_transition_state(match, :assigning_driver)

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

      {:ok, match} =
        Shipment.get_match!(match_id)
        |> MatchWorkflow.en_route_to_pickup()

      {:ok, _match} = match |> MatchWorkflow.arrive_at_pickup()

      assert_receive {:ok,
                      %HTTPoison.Response{
                        body: %{
                          "batchId" => nil,
                          "courier" => %{
                            "firstName" => _,
                            "id" => _,
                            "lastName" => _,
                            "location" => %{"latitude" => _, "longitude" => _},
                            "maskedPhoneNumber" => _,
                            "phoneNumber" => _,
                            "vehicle" => %{
                              "color" => _,
                              "licensePlate" => _,
                              "make" => _,
                              "model" => _
                            }
                          },
                          "estimatedDeliveryTime" => _,
                          "estimatedPickupTime" => _,
                          "externalOrderId" => _,
                          "externalStoreId" => _,
                          "id" => _,
                          "payload_id" => _,
                          "status" => "ARRIVED_AT_PICKUP",
                          "actualDeliveryTime" => _,
                          "actualPickupTime" => _,
                          "actualReturnTime" => _,
                          "cancelReasonCode" => _,
                          "dropoffEta" => 0,
                          "estimatedReturnTime" => _,
                          "pickupEta" => 0,
                          "pickupParkingSlot" => _,
                          "returnEta" => 0,
                          "returnParkingSlot" => _,
                          "returnReasonCode" => _,
                          "timestamp" => _,
                          "dropoffVerification" => %{
                            "signatureImageUrl" => nil,
                            "deliveryProofImageUrl" => nil
                          }
                        },
                        headers: [{"Content-Type", "application/json"}],
                        request: _,
                        request_url:
                          "https://developer.api.us.stg.walmart.com/api-proxy/service/csp-webhook/service/v1/api/webhook/dsp?clientId=2",
                        status_code: 201
                      }}

      assert 2 == Repo.all(FraytElixir.Webhooks.WebhookRequest) |> Enum.count()
    end

    test "state should be picked_up",
         %{conn: conn, api_account: %{company: company}} do
      Ecto.Changeset.change(company, %{integration: :walmart})
      |> Repo.update()

      conn = post(conn, Routes.walmart_path(conn, :create), @valid_match_params)

      assert %{"id" => match_id} = json_response(conn, 200)

      match = Shipment.get_match!(match_id)

      assert %{parking_spot_required: true} = match

      Shipment.MatchWorkflow.force_transition_state(match, :assigning_driver)

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

      {:ok, match} =
        Shipment.get_match!(match_id)
        |> MatchWorkflow.en_route_to_pickup()

      {:ok, match} = match |> MatchWorkflow.arrive_at_pickup("B12")
      {:ok, _} = match |> MatchWorkflow.pickup()

      assert_receive {:ok,
                      %HTTPoison.Response{
                        body: %{
                          "batchId" => nil,
                          "courier" => %{
                            "firstName" => _,
                            "id" => _,
                            "lastName" => _,
                            "location" => %{"latitude" => _, "longitude" => _},
                            "maskedPhoneNumber" => _,
                            "phoneNumber" => _,
                            "vehicle" => %{
                              "color" => _,
                              "licensePlate" => _,
                              "make" => _,
                              "model" => _
                            }
                          },
                          "estimatedDeliveryTime" => _,
                          "estimatedPickupTime" => _,
                          "externalOrderId" => _,
                          "externalStoreId" => _,
                          "id" => _,
                          "payload_id" => _,
                          "status" => "PICKED_UP",
                          "actualDeliveryTime" => _,
                          "actualPickupTime" => _,
                          "actualReturnTime" => _,
                          "cancelReasonCode" => _,
                          "dropoffEta" => 0,
                          "estimatedReturnTime" => _,
                          "pickupEta" => 0,
                          "pickupParkingSlot" => "B12",
                          "returnParkingSlot" => "",
                          "returnEta" => 0,
                          "returnReasonCode" => _,
                          "timestamp" => _,
                          "dropoffVerification" => %{
                            "signatureImageUrl" => nil,
                            "deliveryProofImageUrl" => nil
                          }
                        },
                        headers: [{"Content-Type", "application/json"}],
                        request: _,
                        request_url:
                          "https://developer.api.us.stg.walmart.com/api-proxy/service/csp-webhook/service/v1/api/webhook/dsp?clientId=2",
                        status_code: 201
                      }}

      assert 3 == Repo.all(FraytElixir.Webhooks.WebhookRequest) |> Enum.count()
    end

    test "state should be EN_ROUTE_TO_DROPOFF",
         %{conn: conn, api_account: %{company: company}} do
      Ecto.Changeset.change(company, %{integration: :walmart})
      |> Repo.update()

      conn = post(conn, Routes.walmart_path(conn, :create), @valid_match_params)

      assert %{"id" => match_id} = json_response(conn, 200)

      match = Shipment.get_match!(match_id)

      Shipment.MatchWorkflow.force_transition_state(match, :assigning_driver)

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

      {:ok, match} =
        Shipment.get_match!(match_id)
        |> MatchWorkflow.en_route_to_pickup()

      {:ok, match} = match |> MatchWorkflow.arrive_at_pickup()
      {:ok, match} = match |> MatchWorkflow.pickup()
      [match_stop | _] = match.match_stops
      match_stop = match_stop |> Repo.preload(match: :driver)
      {:ok, _} = match_stop |> MatchWorkflow.en_route_to_stop()

      assert_receive {:ok,
                      %HTTPoison.Response{
                        body: %{
                          "batchId" => nil,
                          "courier" => %{
                            "firstName" => _,
                            "id" => _,
                            "lastName" => _,
                            "location" => %{"latitude" => _, "longitude" => _},
                            "maskedPhoneNumber" => _,
                            "phoneNumber" => _,
                            "vehicle" => %{
                              "color" => _,
                              "licensePlate" => _,
                              "make" => _,
                              "model" => _
                            }
                          },
                          "estimatedDeliveryTime" => _,
                          "estimatedPickupTime" => _,
                          "externalOrderId" => _,
                          "externalStoreId" => _,
                          "id" => _,
                          "payload_id" => _,
                          "status" => "EN_ROUTE_TO_DROPOFF",
                          "actualDeliveryTime" => _,
                          "actualPickupTime" => _,
                          "actualReturnTime" => _,
                          "cancelReasonCode" => _,
                          "dropoffEta" => 0,
                          "estimatedReturnTime" => _,
                          "pickupEta" => 0,
                          "pickupParkingSlot" => _,
                          "returnEta" => 0,
                          "returnParkingSlot" => _,
                          "returnReasonCode" => _,
                          "timestamp" => _
                        },
                        headers: [{"Content-Type", "application/json"}],
                        request: _,
                        request_url:
                          "https://developer.api.us.stg.walmart.com/api-proxy/service/csp-webhook/service/v1/api/webhook/dsp?clientId=2",
                        status_code: 201
                      }}

      assert Repo.all(FraytElixir.Webhooks.WebhookRequest) |> Enum.count() >= 4
    end

    test "state should be ARRIVED_AT_RETURN, RETURNED",
         %{conn: conn, api_account: %{company: company}} do
      Ecto.Changeset.change(company, %{integration: :walmart})
      |> Repo.update()

      conn = post(conn, Routes.walmart_path(conn, :create), @valid_match_params)

      assert %{"id" => match_id} = json_response(conn, 200)

      match = Shipment.get_match!(match_id)

      Shipment.MatchWorkflow.force_transition_state(match, :assigning_driver)

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

      {:ok, match} =
        Shipment.get_match!(match_id)
        |> MatchWorkflow.en_route_to_pickup()

      {:ok, match} = match |> MatchWorkflow.arrive_at_pickup("A47")
      {:ok, match} = match |> MatchWorkflow.pickup()
      [match_stop | _] = match.match_stops
      match_stop = match_stop |> Repo.preload(match: :driver)
      {:ok, match_stop} = match_stop |> MatchWorkflow.en_route_to_stop()
      match_stop = match_stop |> Repo.preload(match: :driver)
      {:ok, _} = MatchWorkflow.undeliverable_stop(match_stop, "some weird reason")

      assert_receive {:ok,
                      %HTTPoison.Response{
                        body: %{
                          "batchId" => nil,
                          "courier" => %{
                            "firstName" => _,
                            "id" => _,
                            "lastName" => _,
                            "location" => %{"latitude" => _, "longitude" => _},
                            "maskedPhoneNumber" => _,
                            "phoneNumber" => _,
                            "vehicle" => %{
                              "color" => _,
                              "licensePlate" => _,
                              "make" => _,
                              "model" => _
                            }
                          },
                          "estimatedDeliveryTime" => _,
                          "estimatedPickupTime" => _,
                          "externalOrderId" => _,
                          "externalStoreId" => _,
                          "id" => _,
                          "payload_id" => _,
                          "status" => "EN_ROUTE_TO_RETURN",
                          "actualDeliveryTime" => _,
                          "actualPickupTime" => _,
                          "actualReturnTime" => _,
                          "cancelReasonCode" => _,
                          "dropoffEta" => 0,
                          "estimatedReturnTime" => _,
                          "pickupEta" => 0,
                          "pickupParkingSlot" => "A47",
                          "returnParkingSlot" => "",
                          "returnEta" => _,
                          "returnReasonCode" => _,
                          "timestamp" => _,
                          "dropoffVerification" => %{
                            "signatureImageUrl" => nil,
                            "deliveryProofImageUrl" => nil
                          }
                        },
                        headers: [{"Content-Type", "application/json"}],
                        request: _,
                        request_url:
                          "https://developer.api.us.stg.walmart.com/api-proxy/service/csp-webhook/service/v1/api/webhook/dsp?clientId=2",
                        status_code: 201
                      }}

      {:ok, match} = MatchWorkflow.arrive_at_return(match, "B09")

      assert_receive {:ok,
                      %HTTPoison.Response{
                        body: %{
                          "batchId" => nil,
                          "courier" => %{
                            "firstName" => _,
                            "id" => _,
                            "lastName" => _,
                            "location" => %{"latitude" => _, "longitude" => _},
                            "maskedPhoneNumber" => _,
                            "phoneNumber" => _,
                            "vehicle" => %{
                              "color" => _,
                              "licensePlate" => _,
                              "make" => _,
                              "model" => _
                            }
                          },
                          "estimatedDeliveryTime" => _,
                          "estimatedPickupTime" => _,
                          "externalOrderId" => _,
                          "externalStoreId" => _,
                          "id" => _,
                          "payload_id" => _,
                          "status" => "ARRIVED_AT_RETURN",
                          "actualDeliveryTime" => _,
                          "actualPickupTime" => _,
                          "actualReturnTime" => _,
                          "cancelReasonCode" => _,
                          "dropoffEta" => 0,
                          "estimatedReturnTime" => _,
                          "pickupEta" => 0,
                          "pickupParkingSlot" => "A47",
                          "returnParkingSlot" => "B09",
                          "returnEta" => 0,
                          "returnReasonCode" => _,
                          "timestamp" => _,
                          "dropoffVerification" => %{
                            "signatureImageUrl" => nil,
                            "deliveryProofImageUrl" => nil
                          }
                        },
                        headers: [{"Content-Type", "application/json"}],
                        request: _,
                        request_url:
                          "https://developer.api.us.stg.walmart.com/api-proxy/service/csp-webhook/service/v1/api/webhook/dsp?clientId=2",
                        status_code: 201
                      }}

      {:ok, _} = MatchWorkflow.complete_match(match)

      assert_receive {:ok,
                      %HTTPoison.Response{
                        body: %{
                          "batchId" => nil,
                          "courier" => %{
                            "firstName" => _,
                            "id" => _,
                            "lastName" => _,
                            "location" => %{"latitude" => _, "longitude" => _},
                            "maskedPhoneNumber" => _,
                            "phoneNumber" => _,
                            "vehicle" => %{
                              "color" => _,
                              "licensePlate" => _,
                              "make" => _,
                              "model" => _
                            }
                          },
                          "estimatedDeliveryTime" => _,
                          "estimatedPickupTime" => _,
                          "externalOrderId" => _,
                          "externalStoreId" => _,
                          "id" => _,
                          "payload_id" => _,
                          "status" => "RETURNED",
                          "actualDeliveryTime" => _,
                          "actualPickupTime" => _,
                          "actualReturnTime" => _,
                          "cancelReasonCode" => _,
                          "dropoffEta" => 0,
                          "estimatedReturnTime" => _,
                          "pickupEta" => 0,
                          "pickupParkingSlot" => _,
                          "returnEta" => 0,
                          "returnParkingSlot" => _,
                          "returnReasonCode" => _,
                          "timestamp" => _,
                          "dropoffVerification" => %{
                            "signatureImageUrl" => nil,
                            "deliveryProofImageUrl" => nil
                          }
                        },
                        headers: [{"Content-Type", "application/json"}],
                        request: _,
                        request_url:
                          "https://developer.api.us.stg.walmart.com/api-proxy/service/csp-webhook/service/v1/api/webhook/dsp?clientId=2",
                        status_code: 201
                      }}

      assert Repo.all(FraytElixir.Webhooks.WebhookRequest) |> Enum.count() >= 7
    end

    test "state should be ARRIVED_AT_DROPOFF",
         %{conn: conn, api_account: %{company: company}} do
      Ecto.Changeset.change(company, %{integration: :walmart})
      |> Repo.update()

      conn = post(conn, Routes.walmart_path(conn, :create), @valid_match_params)

      assert %{"id" => match_id} = json_response(conn, 200)

      match = Shipment.get_match!(match_id)

      Shipment.MatchWorkflow.force_transition_state(match, :assigning_driver)

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

      {:ok, match} =
        Shipment.get_match!(match_id)
        |> MatchWorkflow.en_route_to_pickup()

      {:ok, match} = match |> MatchWorkflow.arrive_at_pickup("A35")
      {:ok, match} = match |> MatchWorkflow.pickup()
      [match_stop | _] = match.match_stops
      match_stop = match_stop |> Repo.preload(match: :driver)
      {:ok, match_stop} = match_stop |> MatchWorkflow.en_route_to_stop()
      match_stop = match_stop |> Repo.preload(match: :driver)

      match_stop |> MatchWorkflow.arrive_at_stop()

      assert_receive {:ok,
                      %HTTPoison.Response{
                        body: %{
                          "batchId" => nil,
                          "courier" => %{
                            "firstName" => _,
                            "id" => _,
                            "lastName" => _,
                            "location" => %{"latitude" => _, "longitude" => _},
                            "maskedPhoneNumber" => _,
                            "phoneNumber" => _,
                            "vehicle" => %{
                              "color" => _,
                              "licensePlate" => _,
                              "make" => _,
                              "model" => _
                            }
                          },
                          "estimatedDeliveryTime" => _,
                          "estimatedPickupTime" => _,
                          "externalOrderId" => _,
                          "externalStoreId" => _,
                          "id" => _,
                          "payload_id" => _,
                          "status" => "ARRIVED_AT_DROPOFF",
                          "actualDeliveryTime" => _,
                          "actualPickupTime" => _,
                          "actualReturnTime" => _,
                          "cancelReasonCode" => _,
                          "dropoffEta" => 0,
                          "estimatedReturnTime" => _,
                          "pickupEta" => 0,
                          "pickupParkingSlot" => "A35",
                          "returnParkingSlot" => "",
                          "returnEta" => 0,
                          "returnReasonCode" => _,
                          "timestamp" => _,
                          "dropoffVerification" => %{
                            "signatureImageUrl" => nil,
                            "deliveryProofImageUrl" => nil
                          }
                        },
                        headers: [{"Content-Type", "application/json"}],
                        request: _,
                        request_url:
                          "https://developer.api.us.stg.walmart.com/api-proxy/service/csp-webhook/service/v1/api/webhook/dsp?clientId=2",
                        status_code: 201
                      }}

      assert Repo.all(FraytElixir.Webhooks.WebhookRequest) |> Enum.count() >= 5
    end

    test "state should be DELIVERED",
         %{conn: conn, api_account: %{company: company}} do
      Ecto.Changeset.change(company, %{integration: :walmart})
      |> Repo.update()

      conn = post(conn, Routes.walmart_path(conn, :create), @valid_match_params)

      assert %{"id" => match_id} = json_response(conn, 200)

      match = Shipment.get_match!(match_id)

      Shipment.MatchWorkflow.force_transition_state(match, :assigning_driver)

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

      {:ok, match} =
        Shipment.get_match!(match_id)
        |> MatchWorkflow.en_route_to_pickup()

      {:ok, match} = match |> MatchWorkflow.arrive_at_pickup()
      {:ok, match} = match |> MatchWorkflow.pickup()
      [match_stop | _] = match.match_stops
      match_stop = match_stop |> Repo.preload(match: :driver)
      {:ok, match_stop} = match_stop |> MatchWorkflow.en_route_to_stop()
      match_stop = match_stop |> Repo.preload(match: :driver)
      {:ok, match} = match_stop |> MatchWorkflow.arrive_at_stop()
      [match_stop | _] = match.match_stops
      match_stop = match_stop |> Repo.preload(match: :driver)
      {:ok, match} = match_stop |> MatchWorkflow.sign_for_stop()
      [match_stop | _] = match.match_stops
      match_stop = match_stop |> Repo.preload(match: :driver)
      MatchWorkflow.deliver_stop(match_stop)

      assert_receive {:ok,
                      %HTTPoison.Response{
                        body: %{
                          "batchId" => nil,
                          "courier" => %{
                            "firstName" => _,
                            "id" => _,
                            "lastName" => _,
                            "location" => %{"latitude" => _, "longitude" => _},
                            "maskedPhoneNumber" => _,
                            "phoneNumber" => _,
                            "vehicle" => %{
                              "color" => _,
                              "licensePlate" => _,
                              "make" => _,
                              "model" => _
                            }
                          },
                          "estimatedDeliveryTime" => _,
                          "estimatedPickupTime" => _,
                          "externalOrderId" => _,
                          "externalStoreId" => _,
                          "id" => _,
                          "payload_id" => _,
                          "status" => "DELIVERED",
                          "actualDeliveryTime" => _,
                          "actualPickupTime" => _,
                          "actualReturnTime" => _,
                          "cancelReasonCode" => _,
                          "dropoffEta" => 0,
                          "estimatedReturnTime" => _,
                          "pickupEta" => 0,
                          "pickupParkingSlot" => _,
                          "returnEta" => 0,
                          "returnParkingSlot" => _,
                          "returnReasonCode" => _,
                          "timestamp" => _,
                          "dropoffVerification" => %{
                            "signatureImageUrl" => nil,
                            "deliveryProofImageUrl" => nil
                          }
                        },
                        headers: [{"Content-Type", "application/json"}],
                        request: _,
                        request_url:
                          "https://developer.api.us.stg.walmart.com/api-proxy/service/csp-webhook/service/v1/api/webhook/dsp?clientId=2",
                        status_code: 201
                      }}

      assert Repo.all(FraytElixir.Webhooks.WebhookRequest) |> Enum.count() >= 6
    end
  end

  describe "create" do
    test "create match with valid params works", %{conn: conn} do
      conn = post(conn, Routes.walmart_path(conn, :create), @valid_match_params)

      assert %{
               "id" => match_id
             } = json_response(conn, 200)

      match = Shipment.get_match!(match_id)

      resp = %{
        "currency" => "USD",
        "deliveryWindowEndTime" => nil,
        "deliveryWindowStartTime" => DateTime.to_iso8601(match.dropoff_at),
        "estimatedDeliveryTime" => nil,
        "estimatedPickupTime" => nil,
        "externalDeliveryId" => match.meta["external_delivery_id"],
        "externalOrderId" => match.identifier,
        "externalStoreId" => match.meta["external_store_id"],
        "fee" => match.amount_charged,
        "id" => match.id,
        "pickupWindowEndTime" => nil,
        "pickupWindowStartTime" => DateTime.to_iso8601(match.pickup_at),
        "tip" => 0
      }

      assert resp == json_response(conn, 200)
    end

    test "create match with valid params but missing order line items should work", %{conn: conn} do
      conn =
        post(
          conn,
          Routes.walmart_path(conn, :create),
          @valid_match_params_without_order_line_items
        )

      assert %{
               "id" => match_id
             } = json_response(conn, 200)

      match = Shipment.get_match!(match_id)

      resp = %{
        "currency" => "USD",
        "deliveryWindowEndTime" => nil,
        "deliveryWindowStartTime" => DateTime.to_iso8601(match.dropoff_at),
        "estimatedDeliveryTime" => nil,
        "estimatedPickupTime" => nil,
        "externalDeliveryId" => match.meta["external_delivery_id"],
        "externalOrderId" => match.identifier,
        "externalStoreId" => match.meta["external_store_id"],
        "fee" => match.amount_charged,
        "id" => match.id,
        "pickupWindowEndTime" => nil,
        "pickupWindowStartTime" => DateTime.to_iso8601(match.pickup_at),
        "tip" => 0
      }

      assert resp == json_response(conn, 200)

      assert %{vehicle_class: 1, total_weight: 64, total_volume: 4820} = match
    end

    test "create match with valid params but missing line item dimensions should work", %{
      conn: conn
    } do
      conn =
        post(
          conn,
          Routes.walmart_path(conn, :create),
          @valid_match_params_with_missing_dimensions
        )

      assert %{
               "id" => match_id
             } = json_response(conn, 200)

      match = Shipment.get_match!(match_id)

      resp = %{
        "currency" => "USD",
        "deliveryWindowEndTime" => nil,
        "deliveryWindowStartTime" => DateTime.to_iso8601(match.dropoff_at),
        "estimatedDeliveryTime" => nil,
        "estimatedPickupTime" => nil,
        "externalDeliveryId" => match.meta["external_delivery_id"],
        "externalOrderId" => match.identifier,
        "externalStoreId" => match.meta["external_store_id"],
        "fee" => match.amount_charged,
        "id" => match.id,
        "pickupWindowEndTime" => nil,
        "pickupWindowStartTime" => DateTime.to_iso8601(match.pickup_at),
        "tip" => 0
      }

      assert resp == json_response(conn, 200)

      assert %{vehicle_class: 2, total_weight: 500, total_volume: 0} = match
    end

    test "create match with no lat and lng should work", %{conn: conn} do
      location = %{
        "latitude" => nil,
        "longitude" => nil
      }

      pickup_info =
        Map.get(@valid_match_params, "pickupInfo") |> Map.put("pickupLocation", location)

      dropoff_info =
        Map.get(@valid_match_params, "dropOffInfo") |> Map.put("dropOffLocation", location)

      valid_match_params =
        Map.put(@valid_match_params, "pickupInfo", pickup_info)
        |> Map.put("dropOffInfo", dropoff_info)

      conn = post(conn, Routes.walmart_path(conn, :create), valid_match_params)

      assert %{
               "id" => match_id
             } = json_response(conn, 200)

      match = Shipment.get_match!(match_id)

      resp = %{
        "currency" => "USD",
        "deliveryWindowEndTime" => nil,
        "deliveryWindowStartTime" => DateTime.to_iso8601(match.dropoff_at),
        "estimatedDeliveryTime" => nil,
        "estimatedPickupTime" => nil,
        "externalDeliveryId" => match.meta["external_delivery_id"],
        "externalOrderId" => match.identifier,
        "externalStoreId" => match.meta["external_store_id"],
        "fee" => match.amount_charged,
        "id" => match.id,
        "pickupWindowEndTime" => nil,
        "pickupWindowStartTime" => DateTime.to_iso8601(match.pickup_at),
        "tip" => 0
      }

      assert resp == json_response(conn, 200)
    end

    test "create match with no lat and lng and invalid address should throw error", %{conn: conn} do
      location = %{
        "latitude" => nil,
        "longitude" => nil
      }

      pickup_address = %{
        "addressLine1" => "garbage",
        "addressLine2" => nil,
        "city" => "",
        "state" => "",
        "zipCode" => "",
        "country" => ""
      }

      # dropoff_address = %{
      #   "addressLine1" => "garbage",
      #   "addressLine2" => nil,
      #   "city" => "",
      #   "state" => "",
      #   "zipCode" => "",
      #   "country" => ""
      # }

      pickup_info =
        Map.get(@valid_match_params, "pickupInfo")
        |> Map.put("pickupAddress", pickup_address)
        |> Map.put("pickupLocation", location)

      # dropoff_info =
      #   Map.get(@valid_match_params, "dropOffInfo")
      #   |> Map.put("dropOffAddress", dropoff_address)
      #   |> Map.put("dropOffLocation", location)

      valid_match_params = Map.put(@valid_match_params, "pickupInfo", pickup_info)
      # |> Map.put("dropOffInfo", dropoff_info)

      conn = post(conn, Routes.walmart_path(conn, :create), valid_match_params)

      assert %{
               "error" => %{
                 "errorCode" => "INVALID_PICKUP_ADDRESS",
                 "errorMessage" => "Origin address's Address Address is invalid"
               },
               "status" => "error"
             } == json_response(conn, 400)
    end

    test "create match with invalid pickup phone number gives error", %{conn: conn} do
      params =
        @valid_match_params
        |> Map.put(
          "pickupInfo",
          %{
            "pickupAddress" => %{
              "addressLine1" => "708 Walnut Street",
              "city" => "Cincinnati",
              "country" => "US",
              "state" => "OH",
              "zipCode" => "45202"
            },
            "pickupContact" => %{
              "firstName" => "Walmart",
              "lastName" => "Store number =>5023",
              "phone" => "+12029999999999999"
            },
            "pickupInstruction" =>
              "Follow orange 'Pickup' signs in Walmart parking lot. Park and\nwait in any 'Reserved Pickup Parking' spot",
            "pickupLocation" => %{
              "latitude" => 39.1043198,
              "longitude" => -84.5118912
            }
          }
        )

      conn = post(conn, Routes.walmart_path(conn, :create), params)

      assert %{
               "error" => %{
                 "errorCode" => "INVALID_PICKUP_PHONE_NUMBER",
                 "errorMessage" =>
                   "Sender's Phone number The string supplied did not seem to be a valid phone number"
               },
               "status" => "error"
             } == json_response(conn, 400)
    end
  end

  describe "update" do
    test "update match with valid params works", %{conn: conn} do
      conn = post(conn, Routes.walmart_path(conn, :create), @valid_match_params)

      assert %{"id" => match_id} = json_response(conn, 200)

      assert %Match{} = Shipment.get_match!(match_id)

      updated_match_params = @valid_match_params |> Map.put("tip", 100)
      conn = put(conn, Routes.walmart_path(conn, :update, match_id), updated_match_params)

      match = Shipment.get_match!(match_id)

      resp = %{
        "currency" => "USD",
        "deliveryWindowEndTime" => nil,
        "deliveryWindowStartTime" => DateTime.to_iso8601(match.dropoff_at),
        "estimatedDeliveryTime" => nil,
        "estimatedPickupTime" => nil,
        "externalDeliveryId" => match.meta["external_delivery_id"],
        "externalOrderId" => match.identifier,
        "externalStoreId" => match.meta["external_store_id"],
        "fee" => match.amount_charged,
        "id" => match.id,
        "pickupWindowEndTime" => nil,
        "pickupWindowStartTime" => DateTime.to_iso8601(match.pickup_at),
        "tip" => 100
      }

      assert resp == json_response(conn, 200)
    end
  end

  describe "show" do
    test "show a match", %{conn: conn} do
      conn = post(conn, Routes.walmart_path(conn, :create), @valid_match_params)

      assert %{"id" => match_id} = json_response(conn, 200)

      conn = get(conn, Routes.walmart_path(conn, :show, match_id))
      match = Shipment.get_match!(match_id)

      assert %{
               "deliveryWindowEndTime" => DateTime.to_iso8601(match.dropoff_at),
               "deliveryWindowStartTime" => match.meta["delivery_window_start_time"],
               "externalDeliveryId" => match.meta["external_delivery_id"],
               "externalOrderId" => match.identifier,
               "externalStoreId" => match.meta["external_store_id"],
               "fee" => match.amount_charged,
               "id" => match.id,
               "pickupWindowEndTime" => DateTime.to_iso8601(match.pickup_at),
               "pickupWindowStartTime" => match.meta["pickup_window_start_time"],
               "tip" => match.meta["tip"],
               "batchId" => match.meta["batch_id"],
               "clientId" => match.meta["client_id"],
               "containsAlcohol" => match.meta["contains_alcohol"],
               "containsHazmat" => match.meta["contains_hazmat"],
               "containsPharmacy" => match.meta["contains_pharmacy"],
               "dropOffInfo" => %{
                 "dropOffAddress" => %{
                   "addressLine1" => "3811 Mt Vernon Ave",
                   "city" => "Cincinnati",
                   "country" => "US",
                   "state" => "OH",
                   "zipCode" => "45202",
                   "addressLine2" => nil
                 },
                 "dropOffContact" => %{
                   "firstName" => "TEST",
                   "lastName" => "TEST",
                   "phone" => "+12025550194"
                 },
                 "dropOffInstruction" => "Ring the bell once you are at dropoff",
                 "dropOffLocation" => %{"latitude" => 39.1474202, "longitude" => -84.4311616},
                 "isContactlessDelivery" => false,
                 "proofOfDeliveryRequired" => false,
                 "signatureRequired" => true
               },
               "isAutonomousDelivery" => match.meta["is_autonomous_delivery"],
               "isIdVerificationRequired" => match.meta["is_id_verification_required"],
               "orderInfo" => %{
                 "barcodeInfo" => [%{"barcode" => "Q12345"}, %{"barcode" => "Q12346"}],
                 "orderLineItems" => [
                   %{
                     "height" => 2.0,
                     "id" => "3c19247d-0f35-4e20-b6ad-0ddc94c4cef0",
                     "length" => 3.0,
                     "orderedWeight" => 2.0,
                     "quantity" => 2,
                     "uomDimension" => "FT",
                     "width" => 1.0
                   },
                   %{
                     "height" => 1.0,
                     "id" => "221ad-81c1a-12aa-31aa-001ac3411",
                     "length" => 4.0,
                     "orderedWeight" => 3.0,
                     "quantity" => 1,
                     "uomDimension" => "FT",
                     "width" => 1.0
                   }
                 ],
                 "size" => "S",
                 "totalQuantity" => 20,
                 "totalVolume" => 2.7799999713897705,
                 "totalWeight" => 64.0
               },
               "osn" => match.meta["osn"],
               "pickupInfo" => %{
                 "pickupAddress" => %{
                   "addressLine1" => "708 Walnut Street",
                   "city" => "Cincinnati",
                   "country" => "US",
                   "state" => "OH",
                   "zipCode" => "45202",
                   "addressLine2" => nil
                 },
                 "pickupContact" => %{
                   "firstName" => "Walmart",
                   "lastName" => "Store number =>5023",
                   "phone" => "+12025550194"
                 },
                 "pickupInstruction" =>
                   "Follow orange 'Pickup' signs in Walmart parking lot. Park and wait in any 'Reserved Pickup Parking' spot",
                 "pickupLocation" => %{"latitude" => 39.1043198, "longitude" => -84.5118912}
               },
               "seqNumber" => match.meta["seq_number"],
               "customerId" => match.meta["customer_id"],
               "estimatedDeliveryTime" => nil,
               "estimatedPickupTime" => nil,
               "status" => "ASSIGNING_DRIVER",
               "courier" => %{
                 "firstName" => nil,
                 "id" => nil,
                 "lastName" => nil,
                 "location" => %{"latitude" => nil, "longitude" => nil},
                 "maskedPhoneNumber" => nil,
                 "phoneNumber" => nil,
                 "vehicle" => %{
                   "color" => nil,
                   "licensePlate" => nil,
                   "make" => nil,
                   "model" => nil
                 }
               },
               "pickupParkingSlot" => "",
               "returnParkingSlot" => ""
             } == json_response(conn, 200)
    end

    test "assigning a driver will create eta", %{conn: conn} do
      conn = post(conn, Routes.walmart_path(conn, :create), @valid_match_params)

      assert %{"id" => match_id} = json_response(conn, 200)

      match = Shipment.get_match!(match_id)

      Shipment.MatchWorkflow.force_transition_state(match, :assigning_driver)

      %Driver{id: driver_id} =
        driver =
        insert(:driver_with_wallet,
          phone_number: "+12345676543",
          current_location: build(:driver_location)
        )

      is_reassign = false

      assert {:ok, %Match{driver: %Driver{id: ^driver_id}, state: :accepted}} =
               Drivers.assign_match(match, driver, is_reassign)

      match =
        Shipment.get_match!(match_id)
        |> Shipment.MatchWorkflow.force_transition_state(:en_route_to_pickup)

      conn = get(conn, Routes.walmart_path(conn, :show, match_id))
      driver = match.driver

      vehicle =
        Enum.find(
          driver.vehicles,
          %{},
          &(&1.vehicle_class == match.vehicle_class)
        )

      {lng, lat} = driver.current_location.geo_location.coordinates

      assert %{
               "deliveryWindowEndTime" => DateTime.to_iso8601(match.dropoff_at),
               "deliveryWindowStartTime" => match.meta["delivery_window_start_time"],
               "externalDeliveryId" => match.meta["external_delivery_id"],
               "externalOrderId" => match.identifier,
               "externalStoreId" => match.meta["external_store_id"],
               "fee" => match.amount_charged,
               "id" => match.id,
               "pickupWindowEndTime" => DateTime.to_iso8601(match.pickup_at),
               "pickupWindowStartTime" => match.meta["pickup_window_start_time"],
               "tip" => match.meta["tip"],
               "batchId" => match.meta["batch_id"],
               "clientId" => match.meta["client_id"],
               "containsAlcohol" => match.meta["contains_alcohol"],
               "containsHazmat" => match.meta["contains_hazmat"],
               "containsPharmacy" => match.meta["contains_pharmacy"],
               "dropOffInfo" => %{
                 "dropOffAddress" => %{
                   "addressLine1" => "3811 Mt Vernon Ave",
                   "city" => "Cincinnati",
                   "country" => "US",
                   "state" => "OH",
                   "zipCode" => "45202",
                   "addressLine2" => nil
                 },
                 "dropOffContact" => %{
                   "firstName" => "TEST",
                   "lastName" => "TEST",
                   "phone" => "+12025550194"
                 },
                 "dropOffInstruction" => "Ring the bell once you are at dropoff",
                 "dropOffLocation" => %{"latitude" => 39.1474202, "longitude" => -84.4311616},
                 "isContactlessDelivery" => false,
                 "proofOfDeliveryRequired" => false,
                 "signatureRequired" => true
               },
               "isAutonomousDelivery" => match.meta["is_autonomous_delivery"],
               "isIdVerificationRequired" => match.meta["is_id_verification_required"],
               "orderInfo" => %{
                 "barcodeInfo" => [%{"barcode" => "Q12345"}, %{"barcode" => "Q12346"}],
                 "orderLineItems" => [
                   %{
                     "height" => 2.0,
                     "id" => "3c19247d-0f35-4e20-b6ad-0ddc94c4cef0",
                     "length" => 3.0,
                     "orderedWeight" => 2.0,
                     "quantity" => 2,
                     "uomDimension" => "FT",
                     "width" => 1.0
                   },
                   %{
                     "height" => 1.0,
                     "id" => "221ad-81c1a-12aa-31aa-001ac3411",
                     "length" => 4.0,
                     "orderedWeight" => 3.0,
                     "quantity" => 1,
                     "uomDimension" => "FT",
                     "width" => 1.0
                   }
                 ],
                 "size" => "S",
                 "totalQuantity" => 20,
                 "totalVolume" => 2.7799999713897705,
                 "totalWeight" => 64.0
               },
               "osn" => match.meta["osn"],
               "pickupInfo" => %{
                 "pickupAddress" => %{
                   "addressLine1" => "708 Walnut Street",
                   "city" => "Cincinnati",
                   "country" => "US",
                   "state" => "OH",
                   "zipCode" => "45202",
                   "addressLine2" => nil
                 },
                 "pickupContact" => %{
                   "firstName" => "Walmart",
                   "lastName" => "Store number =>5023",
                   "phone" => "+12025550194"
                 },
                 "pickupInstruction" =>
                   "Follow orange 'Pickup' signs in Walmart parking lot. Park and wait in any 'Reserved Pickup Parking' spot",
                 "pickupLocation" => %{"latitude" => 39.1043198, "longitude" => -84.5118912}
               },
               "seqNumber" => match.meta["seq_number"],
               "customerId" => match.meta["customer_id"],
               "estimatedDeliveryTime" => nil,
               "estimatedPickupTime" => WalmartView.get_eta(match) |> DateTime.to_iso8601(),
               "status" => "EN_ROUTE_TO_PICKUP",
               "courier" => %{
                 "firstName" => driver.first_name,
                 "id" => driver.id,
                 "lastName" => driver.last_name,
                 "location" => %{"latitude" => lat, "longitude" => lng},
                 "maskedPhoneNumber" => ExPhoneNumber.format(driver.phone_number, :e164),
                 "phoneNumber" => ExPhoneNumber.format(driver.phone_number, :e164),
                 "vehicle" => %{
                   "color" => nil,
                   "licensePlate" => Map.get(vehicle, :license_plate),
                   "make" => Map.get(vehicle, :make),
                   "model" => Map.get(vehicle, :model)
                 }
               },
               "pickupParkingSlot" => "",
               "returnParkingSlot" => ""
             } == json_response(conn, 200)
    end
  end

  describe "cancel" do
    test "picked up match can be cancelled",
         %{conn: conn, api_account: %{company: company}} do
      Ecto.Changeset.change(company, %{integration: :walmart})
      |> Repo.update()

      conn = post(conn, Routes.walmart_path(conn, :create), @valid_match_params)

      assert %{"id" => match_id} = json_response(conn, 200)

      match = Shipment.get_match!(match_id)
      contract = insert(:contract, allowed_cancellation_states: [:picked_up])
      Ecto.Changeset.change(match, contract: contract) |> Repo.update!()
      Shipment.MatchWorkflow.force_transition_state(match, :assigning_driver)

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

      {:ok, match} =
        Shipment.get_match!(match_id)
        |> MatchWorkflow.en_route_to_pickup()

      {:ok, match} = match |> MatchWorkflow.arrive_at_pickup("C518")
      {:ok, _} = match |> MatchWorkflow.pickup()

      assert_receive {:ok,
                      %HTTPoison.Response{
                        body: %{
                          "batchId" => nil,
                          "courier" => %{
                            "firstName" => _,
                            "id" => _,
                            "lastName" => _,
                            "location" => %{"latitude" => _, "longitude" => _},
                            "maskedPhoneNumber" => _,
                            "phoneNumber" => _,
                            "vehicle" => %{
                              "color" => _,
                              "licensePlate" => _,
                              "make" => _,
                              "model" => _
                            }
                          },
                          "estimatedDeliveryTime" => _,
                          "estimatedPickupTime" => _,
                          "externalOrderId" => _,
                          "externalStoreId" => _,
                          "id" => _,
                          "payload_id" => _,
                          "status" => "PICKED_UP",
                          "actualDeliveryTime" => _,
                          "actualPickupTime" => _,
                          "actualReturnTime" => _,
                          "cancelReasonCode" => _,
                          "dropoffEta" => 0,
                          "estimatedReturnTime" => _,
                          "pickupEta" => 0,
                          "pickupParkingSlot" => "C518",
                          "returnParkingSlot" => "",
                          "returnEta" => 0,
                          "returnReasonCode" => _,
                          "timestamp" => _,
                          "dropoffVerification" => %{
                            "signatureImageUrl" => nil,
                            "deliveryProofImageUrl" => nil
                          }
                        },
                        headers: [{"Content-Type", "application/json"}],
                        request: _,
                        request_url:
                          "https://developer.api.us.stg.walmart.com/api-proxy/service/csp-webhook/service/v1/api/webhook/dsp?clientId=2",
                        status_code: 201
                      }}

      conn = put(conn, Routes.walmart_path(conn, :cancel, match_id), @match_cancel_params)

      assert %{
               "cancelReason" => "OTHER",
               "comment" => nil,
               "cancelledAt" => _
             } = json_response(conn, 200)

      assert true =
               GenServer.whereis({:global, "match_webhook_sender:#{match.id}"})
               |> Process.alive?()

      assert 2 =
               Repo.all(FraytElixir.Webhooks.WebhookRequest)
               |> Enum.filter(&(&1.payload["status"] == "EN_ROUTE_TO_RETURN"))
               |> Enum.count()

      match = Shipment.get_match!(match_id)
      assert :en_route_to_return == match |> Map.get(:state)
      assert :undeliverable == match.match_stops |> List.first() |> Map.get(:state)
      assert Repo.all(FraytElixir.Webhooks.WebhookRequest) |> Enum.count() >= 5
    end

    test "driver can cancel match",
         %{conn: conn, api_account: %{company: company}} do
      Ecto.Changeset.change(company, %{integration: :walmart})
      |> Repo.update()

      conn = post(conn, Routes.walmart_path(conn, :create), @valid_match_params)

      assert %{"id" => match_id} = json_response(conn, 200)
      match = Repo.get(Match, match_id)
      pid = GenServer.whereis({:global, "match_webhook_sender:#{match.id}"})

      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

      driver =
        insert(:driver_with_wallet,
          phone_number: "+12345676543",
          current_location: build(:driver_location)
        )

      {:ok, match} = Drivers.assign_match(match, driver, false)
      {:ok, _match} = Drivers.cancel_match(match, "other")
      assert Repo.all(FraytElixir.Webhooks.WebhookRequest) |> Enum.count() == 1
    end

    test "cancel a match", %{conn: conn} do
      conn = post(conn, Routes.walmart_path(conn, :create), @valid_match_params)

      assert %{"id" => match_id} = json_response(conn, 200)

      conn = put(conn, Routes.walmart_path(conn, :cancel, match_id), @match_cancel_params)

      assert %{
               "cancelReason" => "OTHER",
               "comment" => nil,
               "cancelledAt" => _
             } = json_response(conn, 200)
    end
  end

  describe "update tip" do
    test "should fail when a negative value is provided", %{conn: conn} do
      conn = post(conn, Routes.walmart_path(conn, :create), @valid_match_params)
      assert %{"id" => match_id} = json_response(conn, 200)
      conn = patch(conn, Routes.walmart_path(conn, :update_tip, match_id), %{tip: -90})

      assert %{
               "status" => "error",
               "error" => %{
                 "errorCode" => "TIP_MUST_BE_POSITIVE",
                 "errorMessage" => "Match stops's Tip price must be greater than or equal to 0"
               }
             } = json_response(conn, 400)
    end

    test "should fail when a non-integer value is provided", %{conn: conn} do
      conn = post(conn, Routes.walmart_path(conn, :create), @valid_match_params)
      assert %{"id" => match_id} = json_response(conn, 200)
      conn = patch(conn, Routes.walmart_path(conn, :update_tip, match_id), %{tip: 188.3})

      assert %{
               "status" => "error",
               "error" => %{
                 "errorCode" => "TIP_MUST_BE_INTEGER",
                 "errorMessage" => "Tip is invalid"
               }
             } = json_response(conn, 400)
    end

    test "should fail when the tip deadline is not met", %{conn: conn} do
      conn = post(conn, Routes.walmart_path(conn, :create), @valid_match_params)
      %{"id" => match_id} = json_response(conn, 200)

      inserted_at = NaiveDateTime.utc_now() |> NaiveDateTime.add(-15 * 24 * 60 * 60)
      match = Shipment.get_match!(match_id)
      insert(:match_state_transition, match: match, to: :completed, inserted_at: inserted_at)

      conn = patch(conn, Routes.walmart_path(conn, :update_tip, match_id), %{tip: 133})

      assert %{
               "status" => "error",
               "error" => %{
                 "errorCode" => "TIP_DEADLINE_EXPIRED",
                 "errorMessage" => "Tip price deadline expired"
               }
             } = json_response(conn, 400)
    end

    test "should succeed when the tip is valid", %{conn: conn} do
      conn = post(conn, Routes.walmart_path(conn, :create), @valid_match_params)
      %{"id" => match_id, "externalOrderId" => order_id} = json_response(conn, 200)

      inserted_at = NaiveDateTime.utc_now() |> NaiveDateTime.add(-13 * 24 * 60 * 60)
      match = Shipment.get_match!(match_id)
      insert(:match_state_transition, match: match, to: :completed, inserted_at: inserted_at)
      conn = patch(conn, Routes.walmart_path(conn, :update_tip, match_id), %{tip: 288})

      assert %{
               "id" => ^match_id,
               "externalOrderId" => ^order_id,
               "tip" => 288,
               "tipStatus" => "success"
             } = json_response(conn, 200)
    end
  end
end
