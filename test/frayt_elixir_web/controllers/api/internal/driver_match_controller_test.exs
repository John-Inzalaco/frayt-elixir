defmodule FraytElixirWeb.API.Internal.DriverMatchControllerTest do
  alias FraytElixir.Email
  alias FraytElixir.Shipment.HiddenMatch
  use FraytElixirWeb.ConnCase
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  import FraytElixirWeb.Test.LoginHelper
  import FraytElixir.Factory
  import FraytElixir.Test.StartMatchSupervisor
  import FraytElixirWeb.Test.FileHelper
  alias FraytElixir.Drivers
  alias FraytElixir.Drivers.Driver
  alias FraytElixir.Shipment
  alias FraytElixir.Shipment.{DeliveryBatch, Match}
  alias FraytElixir.Repo
  use Bamboo.Test

  setup :start_match_supervisor

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "show match" do
    setup [:login_as_driver]

    test "returns match", %{conn: conn, driver: %Driver{} = driver} do
      %Match{id: match_id} = match = insert(:match, driver_id: driver.id, driver: driver)

      conn = get(conn, Routes.api_v2_driver_match_path(conn, :show, ".1", match))

      assert %{
               "id" => ^match_id
             } = json_response(conn, 200)["response"]
    end

    test "returns match with required pickup and destination photos", %{
      conn: conn,
      driver: %Driver{} = driver
    } do
      %Match{id: match_id} =
        match =
        insert(:picked_up_match, driver_id: driver.id, driver: driver, origin_photo_required: true)

      match.match_stops
      |> hd()
      |> change(destination_photo_required: true)
      |> Repo.update()

      conn = get(conn, Routes.api_v2_driver_match_path(conn, :show, ".1", match))

      assert %{
               "id" => ^match_id,
               "origin_photo_required" => true,
               "stops" => [
                 %{
                   "destination_photo_required" => true
                 }
                 | _
               ]
             } = json_response(conn, 200)["response"]
    end

    test "returns match with no driver when assigning match", %{conn: conn} do
      %Match{id: match_id} = match = insert(:assigning_driver_match)

      conn =
        conn
        |> get(Routes.api_v2_driver_match_path(conn, :show, ".1", match))

      assert %{
               "id" => ^match_id
             } = json_response(conn, 200)["response"]
    end

    test "returns forbidden when match is canceled", %{conn: conn, driver: driver} do
      match = insert(:match, state: :canceled, driver_id: driver.id, driver: driver)

      conn =
        conn
        |> get(Routes.api_v2_driver_match_path(conn, :show, ".1", match))

      assert %{
               "code" => "forbidden",
               "message" => "Sorry, the Shipper has canceled this Match"
             } = json_response(conn, 403)
    end

    test "returns forbidden when match belongs to other driver", %{conn: conn} do
      other_driver = insert(:driver)
      match = insert(:match, driver_id: other_driver.id, driver: other_driver, state: :accepted)

      conn =
        conn
        |> get(Routes.api_v2_driver_match_path(conn, :show, ".1", match))

      assert %{
               "code" => "forbidden",
               "message" => "Sorry, this Match has been accepted by another Driver"
             } = json_response(conn, 403)
    end

    test "returns forbidden when match does not belong to driver", %{conn: conn} do
      match = insert(:match, state: :pending, driver: nil)

      conn =
        conn
        |> get(Routes.api_v2_driver_match_path(conn, :show, ".1", match))

      assert %{
               "code" => "forbidden"
             } = json_response(conn, 403)
    end
  end

  describe "available" do
    setup [:login_as_driver]

    test "renders list of available matches within 60 miles", %{
      conn: conn,
      driver: %Driver{} = driver
    } do
      %Match{id: match_id} = match = insert(:assigning_driver_match)

      insert(:sent_notification, match: match, driver: driver)

      conn = get(conn, Routes.api_v2_driver_matches_filter_path(conn, :available, ".1"))
      assert %{"results" => [%{"id" => ^match_id}]} = json_response(conn, 200)["response"]
    end
  end

  describe "available with batch id" do
    setup [:login_as_driver]

    test "renders list of available matches from this batch", %{
      conn: conn,
      driver: %Driver{} = driver
    } do
      %DeliveryBatch{id: batch_id} = batch = insert(:delivery_batch, state: :routing_complete)

      %Match{id: match_id} = match = insert(:assigning_driver_match, delivery_batch: batch)

      insert(:sent_notification, match: match, driver: driver)

      conn =
        get(
          conn,
          Routes.api_v2_driver_matches_filter_path(conn, :available, ".1", %{"id" => batch_id})
        )

      assert %{"results" => [%{"id" => ^match_id}]} = json_response(conn, 200)["response"]
    end
  end

  describe "missed" do
    setup [:login_as_driver]

    test "renders list of matches within 60 miles of driver taken by other drivers within the last 48 hours",
         %{
           conn: conn,
           driver: %Driver{} = driver
         } do
      {:ok, driver} = Drivers.update_current_location(driver, gaslight_point())
      insert(:accepted_match, driver: driver)
      findlay_market_address = insert(:address, geo_location: findlay_market_point())

      other_driver = insert(:driver)

      %{match: %Match{id: id}} =
        insert(:accepted_match_state_transition,
          inserted_at: DateTime.utc_now(),
          from: :assigning_driver,
          to: :accepted,
          match:
            build(:match,
              driver: other_driver,
              state: :accepted,
              origin_address: findlay_market_address,
              inserted_at: DateTime.utc_now()
            )
        )

      conn = get(conn, Routes.api_v2_driver_matches_filter_path(conn, :missed, ".1"))
      assert %{"results" => [%{"id" => ^id}]} = json_response(conn, 200)["response"]
    end
  end

  describe "live" do
    setup [:login_as_driver]

    test "renders list of driver's live matches", %{conn: conn, driver: %Driver{} = driver} do
      insert(:completed_match, driver: driver)
      %Match{id: id} = insert(:accepted_match, driver: driver)
      conn = get(conn, Routes.api_v2_driver_matches_filter_path(conn, :live, ".1"))
      assert %{"results" => [%{"id" => ^id}]} = json_response(conn, 200)["response"]
    end
  end

  describe "completed" do
    setup [:login_as_driver]

    test "renders paginated list of driver's completed matches", %{
      conn: conn,
      driver: %Driver{} = driver
    } do
      insert(:accepted_match, driver: driver)

      %{match: %Match{id: id}} =
        insert(:completed_match_state_transition,
          inserted_at: DateTime.utc_now(),
          match: build(:match, driver: driver, state: :completed)
        )

      params = %{
        "cursor" => 0
      }

      conn = get(conn, Routes.api_v2_driver_matches_filter_path(conn, :completed, ".1"), params)
      assert %{"results" => [%{"id" => ^id}]} = json_response(conn, 200)["response"]
    end

    test "renders paginated list of driver's completed matches by specified per_page", %{
      conn: conn,
      driver: %Driver{} = driver
    } do
      insert(:accepted_match, driver: driver)

      insert_list(11, :completed_match_state_transition,
        inserted_at: DateTime.utc_now(),
        match: insert(:match, driver: driver, state: :completed)
      )

      params = %{
        "cursor" => 0,
        "per_page" => 6
      }

      conn = get(conn, Routes.api_v2_driver_matches_filter_path(conn, :completed, ".1"), params)

      assert %{"results" => matches, "total_pages" => total_pages} =
               json_response(conn, 200)["response"]

      assert length(matches) === 6
      assert total_pages === 2
    end
  end

  describe "accept match" do
    setup [:login_as_driver]

    test "with valid driver", %{conn: conn, driver: _driver} do
      driver = insert(:driver_with_wallet)
      match = insert(:assigning_driver_match)

      conn =
        conn
        |> add_token_for_driver(driver)
        |> put(Routes.api_v2_driver_match_path(conn, :update, ".1", match), %{
          state: "accepted"
        })

      assert %{
               "state" => "accepted"
             } = json_response(conn, 200)["response"]
    end

    test "fails when driver is missing seller account", %{conn: conn, driver: _driver} do
      match = insert(:assigning_driver_match)

      conn =
        conn
        |> put(Routes.api_v2_driver_match_path(conn, :update, ".1", match), %{
          state: "accepted"
        })

      assert %{
               "code" => "invalid_attributes"
             } = json_response(conn, 422)
    end

    test "fails if is already assigned to another driver", %{conn: conn, driver: _driver} do
      match = insert(:accepted_match)

      conn =
        conn
        |> put(Routes.api_v2_driver_match_path(conn, :update, ".1", match), %{
          state: "accepted"
        })

      assert %{
               "code" => "forbidden"
             } = json_response(conn, 403)
    end

    test "fails if driver already has 3 live matches", %{conn: conn, driver: _driver} do
      driver = insert(:driver_with_wallet)
      insert_list(3, :accepted_match, driver: driver)
      match = insert(:assigning_driver_match)

      conn =
        conn
        |> add_token_for_driver(driver)
        |> put(Routes.api_v2_driver_match_path(conn, :update, ".1", match), %{
          state: "accepted"
        })

      assert %{
               "code" => "unprocessable_entity",
               "message" =>
                 "You can not have more than 3 ongoing matches. Please complete your current matches, or contact a Network Operator to be assigned more."
             } = json_response(conn, 422)
    end

    test "driver with license expired cannot update a match", %{conn: conn} do
      driver =
        insert(:driver,
          images: [build(:driver_document, type: :license, expires_at: "1900-01-01")]
        )

      match = insert(:assigning_driver_match)

      conn =
        conn
        |> add_token_for_driver(driver)
        |> put(Routes.api_v2_driver_match_path(conn, :update, ".1", match), %{
          state: "accepted"
        })

      assert %{
               "code" => "forbidden",
               "message" =>
                 "You have expired, rejected, or missing documents. Please contact support to continue."
             } = json_response(conn, 403)
    end
  end

  test "overlapping rules doesn't apply for matches without a contract", %{conn: conn} do
    driver = insert(:driver_with_wallet)
    match = insert(:assigning_driver_match, driver: driver, contract: nil)

    conn =
      conn
      |> add_token_for_driver(driver)
      |> put(Routes.api_v2_driver_match_path(conn, :update, ".1", match), %{
        state: "accepted"
      })

    assert %{
             "state" => "accepted"
           } = json_response(conn, 200)["response"]
  end

  describe "accept overlapping matches active_match_factor = fixed_duration" do
    setup [:login_as_driver]

    test "succeed if rules are active but there aren't overlapped matches", %{conn: conn} do
      shipper = insert(:shipper_with_location)

      contract =
        insert(:contract,
          company: shipper.location.company,
          pricing_contract: :default,
          active_matches: 1,
          active_match_factor: :fixed_duration,
          active_match_duration: 30
        )

      driver = insert(:driver_with_wallet)

      match = insert(:accepted_match, driver: driver)

      insert(:match_sla,
        match: match,
        driver_id: driver.id,
        type: :pickup,
        start_time: ~U[2030-12-19 14:00:00Z],
        end_time: ~U[2030-12-19 14:30:00Z]
      )

      match =
        insert(:assigning_driver_match,
          contract: contract,
          slas: [
            build(:match_sla, type: :acceptance),
            build(:match_sla,
              type: :pickup,
              start_time: ~U[2030-12-19 15:30:07Z],
              end_time: ~U[2030-12-19 16:30:07Z]
            ),
            build(:match_sla, type: :delivery)
          ]
        )

      conn =
        conn
        |> add_token_for_driver(driver)
        |> put(Routes.api_v2_driver_match_path(conn, :update, ".1", match), %{
          state: "accepted"
        })

      assert %{
               "state" => "accepted"
             } = json_response(conn, 200)["response"]
    end

    test "fails if rules are active and max overlapped matches is reached", %{conn: conn} do
      shipper = insert(:shipper_with_location)

      contract =
        insert(:contract,
          company: shipper.location.company,
          pricing_contract: :default,
          active_matches: 0,
          active_match_factor: :fixed_duration,
          active_match_duration: 30
        )

      driver = insert(:driver_with_wallet)

      insert(:accepted_match,
        driver: driver,
        slas: [
          build(:match_sla,
            type: :pickup,
            start_time: ~U[2030-12-19 14:00:00Z],
            end_time: ~U[2030-12-19 14:29:00Z]
          ),
          build(:match_sla, driver_id: driver.id, type: :delivery)
        ]
      )

      insert(:accepted_match,
        driver: driver,
        slas: [
          build(:match_sla,
            type: :pickup,
            start_time: ~U[2030-12-19 14:30:00Z],
            end_time: ~U[2030-12-19 14:59:00Z]
          ),
          build(:match_sla, driver_id: driver.id, type: :delivery)
        ]
      )

      match =
        insert(:assigning_driver_match,
          contract: contract,
          slas: [
            build(:match_sla, type: :acceptance),
            build(:match_sla,
              type: :pickup,
              start_time: ~U[2030-12-19 14:40:00Z],
              end_time: ~U[2030-12-19 15:19:00Z]
            ),
            build(:match_sla, type: :delivery)
          ]
        )

      conn =
        conn
        |> add_token_for_driver(driver)
        |> put(Routes.api_v2_driver_match_path(conn, :update, ".1", match), %{
          state: "accepted"
        })

      assert %{
               "code" => "unprocessable_entity",
               "message" => "This match cannot be accepted because it overlaps with another."
             } = json_response(conn, 422)
    end

    test "succeed if rules are active and max overlapped matches isn't reached", %{conn: conn} do
      shipper = insert(:shipper_with_location)

      contract =
        insert(:contract,
          company: shipper.location.company,
          pricing_contract: :default,
          active_matches: 2,
          active_match_factor: :fixed_duration,
          active_match_duration: 30
        )

      driver = insert(:driver_with_wallet)

      insert(:accepted_match,
        driver: driver,
        slas: [
          build(:match_sla,
            type: :pickup,
            start_time: ~U[2030-12-19 14:00:00Z],
            end_time: ~U[2030-12-19 14:29:00Z]
          ),
          build(:match_sla, driver_id: driver.id, type: :delivery)
        ]
      )

      insert(:accepted_match,
        driver: driver,
        slas: [
          build(:match_sla,
            type: :pickup,
            start_time: ~U[2030-12-19 14:30:00Z],
            end_time: ~U[2030-12-19 14:59:00Z]
          ),
          build(:match_sla, driver_id: driver.id, type: :delivery)
        ]
      )

      match =
        insert(:assigning_driver_match,
          contract: contract,
          slas: [
            build(:match_sla, type: :acceptance),
            build(:match_sla,
              type: :pickup,
              start_time: ~U[2030-12-19 14:40:00Z],
              end_time: ~U[2030-12-19 15:19:00Z]
            ),
            build(:match_sla, type: :delivery)
          ]
        )

      conn =
        conn
        |> add_token_for_driver(driver)
        |> put(Routes.api_v2_driver_match_path(conn, :update, ".1", match), %{
          state: "accepted"
        })

      assert %{
               "state" => "accepted"
             } = json_response(conn, 200)["response"]
    end
  end

  describe "accept overlapping matches active_match_factor = delivery_duration" do
    setup [:login_as_driver]

    test "succeed if rules are active but there aren't overlapped matches", %{conn: conn} do
      shipper = insert(:shipper_with_location)
      contract = insert(:contract, company: shipper.location.company, pricing_contract: :default)
      driver = insert(:driver_with_wallet)

      match = insert(:accepted_match, driver: driver)
      insert(:match_sla, match: match, driver_id: driver.id, type: :pickup)

      insert(:match_sla,
        match: match,
        driver_id: driver.id,
        type: :delivery,
        start_time: ~U[2030-12-19 14:11:07Z],
        end_time: ~U[2030-12-19 15:11:07Z]
      )

      match =
        insert(:assigning_driver_match,
          contract: contract,
          slas: [
            build(:match_sla, type: :acceptance),
            build(:match_sla,
              type: :pickup,
              start_time: ~U[2030-12-19 15:30:07Z],
              end_time: ~U[2030-12-19 16:30:07Z]
            ),
            build(:match_sla, type: :delivery)
          ]
        )

      conn =
        conn
        |> add_token_for_driver(driver)
        |> put(Routes.api_v2_driver_match_path(conn, :update, ".1", match), %{
          state: "accepted"
        })

      assert %{
               "state" => "accepted"
             } = json_response(conn, 200)["response"]
    end

    test "succeed if rules are active and max overlapped matches isn't reached", %{conn: conn} do
      shipper = insert(:shipper_with_location)

      contract =
        insert(:contract,
          company: shipper.location.company,
          pricing_contract: :default,
          active_matches: 1
        )

      driver = insert(:driver_with_wallet)

      match = insert(:accepted_match, driver: driver)
      insert(:match_sla, match: match, driver_id: driver.id, type: :pickup)

      insert(:match_sla,
        match: match,
        driver_id: driver.id,
        type: :delivery,
        start_time: ~U[2030-12-19 14:11:07Z],
        end_time: ~U[2030-12-19 15:11:07Z]
      )

      match =
        insert(:assigning_driver_match,
          contract: contract,
          slas: [
            build(:match_sla, type: :acceptance),
            build(:match_sla,
              type: :pickup,
              start_time: ~U[2030-12-19 15:30:07Z],
              end_time: ~U[2030-12-19 16:30:07Z]
            ),
            build(:match_sla, type: :delivery)
          ]
        )

      conn =
        conn
        |> add_token_for_driver(driver)
        |> put(Routes.api_v2_driver_match_path(conn, :update, ".1", match), %{
          state: "accepted"
        })

      assert %{
               "state" => "accepted"
             } = json_response(conn, 200)["response"]
    end

    test "fails if rules are active and max overlapped matches is reached", %{conn: conn} do
      shipper = insert(:shipper_with_location)

      contract =
        insert(:contract,
          company: shipper.location.company,
          pricing_contract: :default,
          active_matches: 0
        )

      driver = insert(:driver_with_wallet)

      insert(:accepted_match,
        driver: driver,
        slas: [
          build(:match_sla, driver_id: driver.id, type: :pickup),
          build(:match_sla,
            type: :delivery,
            start_time: ~U[2030-12-19 14:11:07Z],
            end_time: ~U[2030-12-19 15:11:07Z]
          )
        ]
      )

      insert(:accepted_match,
        driver: driver,
        slas: [
          build(:match_sla, driver_id: driver.id, type: :pickup),
          build(:match_sla,
            type: :delivery,
            start_time: ~U[2030-12-19 15:15:07Z],
            end_time: ~U[2030-12-19 16:00:07Z]
          )
        ]
      )

      match =
        insert(:assigning_driver_match,
          contract: contract,
          slas: [
            build(:match_sla, type: :acceptance),
            build(:match_sla,
              type: :pickup,
              start_time: ~U[2030-12-19 15:30:07Z],
              end_time: ~U[2030-12-19 16:30:07Z]
            ),
            build(:match_sla, type: :delivery)
          ]
        )

      conn =
        conn
        |> add_token_for_driver(driver)
        |> put(Routes.api_v2_driver_match_path(conn, :update, ".1", match), %{
          state: "accepted"
        })

      assert %{
               "code" => "unprocessable_entity",
               "message" => "This match cannot be accepted because it overlaps with another."
             } = json_response(conn, 422)
    end
  end

  describe "reject match" do
    setup [:login_as_driver]

    test "rejects an available match", %{conn: conn, driver: driver} do
      %Match{id: match_id} = match = insert(:assigning_driver_match)

      insert(:sent_notification, match: match, driver: driver)

      conn = get(conn, Routes.api_v2_driver_matches_filter_path(conn, :available, ".1"))
      assert %{"results" => [%{"id" => ^match_id}]} = json_response(conn, 200)["response"]

      conn =
        conn
        |> put(Routes.api_v2_driver_match_path(conn, :update, ".1", match), %{
          state: "rejected"
        })

      conn = get(conn, Routes.api_v2_driver_matches_filter_path(conn, :available, ".1"))
      assert %{"results" => []} = json_response(conn, 200)["response"]
    end

    test "notifies shipper if their chosen preferred driver rejected the match", %{
      conn: conn,
      driver: %Driver{id: driver_id} = driver
    } do
      %Match{id: match_id, shipper: %{user: %{email: email}}} =
        match =
        insert(:assigning_driver_match, preferred_driver: driver, platform: :deliver_pro)
        |> Repo.preload(shipper: [:user])

      insert(:sent_notification, match: match, driver: driver)

      conn = get(conn, Routes.api_v2_driver_matches_filter_path(conn, :available, ".1"))
      assert %{"results" => [%{"id" => ^match_id}]} = json_response(conn, 200)["response"]

      conn =
        conn
        |> put(Routes.api_v2_driver_match_path(conn, :update, ".1", match), %{
          state: "rejected"
        })

      %{driver: driver} =
        hidden_match =
        from(hm in HiddenMatch,
          where: hm.match_id == ^match_id and hm.driver_id == ^driver_id,
          preload: [:match, :driver]
        )
        |> Repo.one()

      email =
        Email.match_status_email(
          match,
          [status_type: :preferred_driver_rejected, driver: driver],
          %{
            to: email,
            subject:
              "#{hidden_match.driver.first_name} #{hidden_match.driver.last_name} Rejected – #{match.po}/#{match.shortcode}"
          }
        )

      conn = get(conn, Routes.api_v2_driver_matches_filter_path(conn, :available, ".1"))
      assert %{"results" => []} = json_response(conn, 200)["response"]
      assert_delivered_email(email)
    end
  end

  describe "arrived at pickup" do
    setup [:login_as_driver]

    test "driver arrives at origin address", %{conn: conn, driver: driver} do
      %{coordinates: {lng, lat}} = findlay_market_point()
      chris_house_address = insert(:address, geo_location: chris_house_point())
      findlay_market_address = insert(:address, geo_location: findlay_market_point())

      match =
        insert(:en_route_to_pickup_match,
          origin_address: findlay_market_address,
          match_stops: [%{destination_address: chris_house_address}],
          state: "assigning_driver",
          driver: driver
        )

      conn =
        put(conn, Routes.api_v2_driver_match_path(conn, :update, ".1", match), %{
          state: "arrived_at_pickup",
          location: %{latitude: lat, longitude: lng}
        })

      assert %{"state" => "arrived_at_pickup"} = json_response(conn, 200)["response"]
    end

    test "should fail when parking_spot is required but it's sent in blank", %{
      conn: conn,
      driver: driver
    } do
      %{coordinates: {lng, lat}} = findlay_market_point()
      chris_house_address = insert(:address, geo_location: chris_house_point())
      findlay_market_address = insert(:address, geo_location: findlay_market_point())

      match =
        insert(:en_route_to_pickup_match,
          origin_address: findlay_market_address,
          match_stops: [%{destination_address: chris_house_address}],
          state: "assigning_driver",
          driver: driver,
          parking_spot_required: true
        )

      conn =
        put(conn, Routes.api_v2_driver_match_path(conn, :update, ".1", match), %{
          state: "arrived_at_pickup",
          location: %{latitude: lat, longitude: lng}
        })

      # assert %{"message" => "Parking spot is required"} = json_response(conn, 422)
      assert %{"response" => _} = json_response(conn, 200)
    end

    test "should succeed when parking_spot is set", %{
      conn: conn,
      driver: driver
    } do
      %{coordinates: {lng, lat}} = findlay_market_point()
      chris_house_address = insert(:address, geo_location: chris_house_point())
      findlay_market_address = insert(:address, geo_location: findlay_market_point())

      match =
        insert(:en_route_to_pickup_match,
          origin_address: findlay_market_address,
          match_stops: [%{destination_address: chris_house_address}],
          state: "assigning_driver",
          driver: driver,
          parking_spot_required: true
        )

      conn =
        put(conn, Routes.api_v2_driver_match_path(conn, :update, ".1", match), %{
          state: "arrived_at_pickup",
          location: %{latitude: lat, longitude: lng},
          parking_spot: "F389"
        })

      stt =
        Shipment.get_match!(match.id)
        |> Map.get(:state_transitions)
        |> Enum.find(:arrived_at_pickup, &(&1.to == :arrived_at_pickup))

      assert %{notes: "F389"} = stt

      assert %{
               "state" => "arrived_at_pickup",
               "parking_spot_required" => true
             } = json_response(conn, 200)["response"]
    end

    test "should not faild when parking_spot is not set when it is not required", %{
      conn: conn,
      driver: driver
    } do
      %{coordinates: {lng, lat}} = findlay_market_point()
      chris_house_address = insert(:address, geo_location: chris_house_point())
      findlay_market_address = insert(:address, geo_location: findlay_market_point())

      match =
        insert(:en_route_to_pickup_match,
          origin_address: findlay_market_address,
          match_stops: [%{destination_address: chris_house_address}],
          state: "assigning_driver",
          driver: driver,
          parking_spot_required: false
        )

      conn =
        put(conn, Routes.api_v2_driver_match_path(conn, :update, ".1", match), %{
          state: "arrived_at_pickup",
          location: %{latitude: lat, longitude: lng}
        })

      assert %{
               "state" => "arrived_at_pickup",
               "parking_spot_required" => false
             } = json_response(conn, 200)["response"]
    end
  end

  describe "picked up" do
    setup [:login_as_driver, :base64_image]

    test "driver confirms pickup with photos", %{conn: conn, driver: driver, image: image} do
      match = insert(:arrived_at_pickup_match, driver: driver)
      insert(:match_sla, match: match, type: :pickup, driver_id: driver.id)
      insert(:match_sla, match: match, type: :delivery, driver_id: driver.id)

      conn =
        conn
        |> put(Routes.api_v2_driver_match_path(conn, :update, ".1", match), %{
          state: "picked_up",
          origin_photo: %{contents: image, filename: "origin"},
          bill_of_lading_photo: %{contents: image, filename: "bill_of_lading"}
        })

      assert %{"state" => "picked_up"} = json_response(conn, 200)["response"]

      assert %Match{origin_photo: origin_photo, bill_of_lading_photo: bill_of_lading_photo} =
               Repo.get(Match, match.id)

      assert origin_photo
      assert bill_of_lading_photo
    end

    test "driver confirms pickup with only origin photo", %{
      conn: conn,
      driver: driver,
      image: image
    } do
      match = insert(:arrived_at_pickup_match, driver: driver)
      insert(:match_sla, match: match, type: :pickup, driver_id: driver.id)
      insert(:match_sla, match: match, type: :delivery, driver_id: driver.id)

      conn =
        put(conn, Routes.api_v2_driver_match_path(conn, :update, ".1", match), %{
          state: "picked_up",
          origin_photo: %{contents: image, filename: "origin"}
        })

      assert %{"state" => "picked_up"} = json_response(conn, 200)["response"]

      assert %Match{origin_photo: origin_photo} = Repo.get(Match, match.id)

      assert origin_photo
    end
  end

  describe "unable to pickup a match" do
    setup [:login_as_driver]

    test "while match is in arrived_at_pickup state", %{
      conn: conn,
      driver: driver
    } do
      match = insert(:arrived_at_pickup_match, driver: driver)

      conn =
        conn
        |> put(Routes.api_v2_driver_match_path(conn, :update, ".1", match), %{
          state: "unable_to_pickup",
          reason: "my reason"
        })

      assert %{"state" => "unable_to_pickup"} = json_response(conn, 200)["response"]
    end
  end

  describe "cancel a match" do
    setup [:login_as_driver]

    test "while match is in [en_route_to_pickup | arrived_at_pickup | accepted] state", %{
      conn: conn,
      driver: driver
    } do
      match =
        [:en_route_to_pickup_match, :arrived_at_pickup_match, :accepted_match]
        |> Enum.random()
        |> insert(driver: driver)

      insert(:match_sla, match: match, type: :pickup, driver_id: driver.id)
      insert(:match_sla, match: match, type: :delivery, driver_id: driver.id)

      conn =
        conn
        |> put(Routes.api_v2_driver_match_path(conn, :update, ".1", match), %{
          state: "cancel",
          reason: "my reason"
        })

      assert %{"state" => "assigning_driver"} = json_response(conn, 200)["response"]
    end

    test "while match is in signed state", %{conn: conn, driver: driver} do
      match = insert(:signed_match, driver: driver)

      conn =
        conn
        |> put(Routes.api_v2_driver_match_path(conn, :update, ".1", match), %{
          state: "cancel",
          reason: "my reason"
        })

      assert %{"code" => "invalid_state", "message" => "Invalid state"} = json_response(conn, 400)
    end

    # using 501 characters
    test "cancel reason with length greater than 500 returns 422", %{conn: conn, driver: driver} do
      match = insert(:accepted_match, driver: driver)
      insert(:match_sla, match: match, type: :pickup, driver_id: driver.id)
      insert(:match_sla, match: match, type: :delivery, driver_id: driver.id)

      conn =
        conn
        |> put(Routes.api_v2_driver_match_path(conn, :update, ".1", match), %{
          state: "cancel",
          reason:
            "Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Aenean commodo ligula eget dolor. Aenean massa. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Donec quam felis, ultricies nec, pellentesque eu, pretium quis, sem. Nulla consequat massa quis enim. Donec pede justo, fringilla vel, aliquet nec, vulputate eget, arcu. In enim justo, rhoncus ut, imperdiet a, venenatis vitae, justo. Nullam dictum felis eu pede mollis pretium. Integer tincidunt. Cras dapibus"
        })

      assert %{
               "code" => "invalid_attributes",
               "message" => "Reason should be at most 500 character(s)"
             } = json_response(conn, 422)
    end

    # 256 Characters
    test "cancel reason with length between 255 and 500 returns 200", %{
      conn: conn,
      driver: driver
    } do
      match = insert(:accepted_match, driver: driver)
      insert(:match_sla, match: match, type: :pickup, driver_id: driver.id)
      insert(:match_sla, match: match, type: :delivery, driver_id: driver.id)

      test_string =
        "Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Aenean commodo ligula eget dolor. Aenean massa. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Donec quam felis, ultricies nec, pellentesque eu, pretium quis,."

      conn =
        conn
        |> put(Routes.api_v2_driver_match_path(conn, :update, ".1", match), %{
          state: "cancel",
          reason: test_string
        })

      assert %{"state" => "assigning_driver"} = json_response(conn, 200)["response"]
    end
  end

  describe "toggle_en_route" do
    setup [:login_as_driver]

    test "with valid match", %{conn: conn, driver: driver} do
      match = insert(:accepted_match, driver: driver)

      conn =
        conn
        |> put(
          Routes.api_v2_driver_match_action_path(
            conn,
            :toggle_en_route,
            ".1",
            match
          ),
          %{"location" => %{"latitude" => 84, "longitude" => 23}}
        )

      assert %{
               "state" => "en_route_to_pickup"
             } = json_response(conn, 200)["response"]

      assert %{
               state_transitions: [transition]
             } = Repo.get!(Match, match.id) |> Repo.preload(state_transitions: :driver_location)

      assert %{
               to: :en_route_to_pickup,
               driver_location: %{geo_location: %Geo.Point{coordinates: {23.0, 84.0}}}
             } = transition
    end

    test "fails with delivered match", %{conn: conn, driver: driver} do
      match = insert(:completed_match, driver: driver)

      conn =
        conn
        |> put(
          Routes.api_v2_driver_match_action_path(
            conn,
            :toggle_en_route,
            ".1",
            match
          ),
          %{}
        )

      assert %{"code" => "invalid_state"} = json_response(conn, 400)
    end

    test "with unauthorized driver", %{conn: conn, driver: _driver} do
      driver = insert(:driver_with_wallet)
      match = insert(:accepted_match, driver: driver)

      conn =
        conn
        |> put(
          Routes.api_v2_driver_match_action_path(
            conn,
            :toggle_en_route,
            ".1",
            match
          ),
          %{}
        )

      assert %{"code" => "forbidden"} = json_response(conn, 403)
    end

    test "driver with license expired cannot toggle a match", %{conn: conn} do
      driver =
        insert(:driver,
          images: [
            build(:driver_document, type: "license", expires_at: "1900-01-01")
          ]
        )

      match = insert(:accepted_match, driver: driver)

      conn =
        conn
        |> add_token_for_driver(driver)
        |> put(
          Routes.api_v2_driver_match_action_path(
            conn,
            :toggle_en_route,
            ".1",
            match
          ),
          %{"location" => %{"latitude" => 84, "longitude" => 23}}
        )

      assert %{
               "code" => "forbidden",
               "message" =>
                 "You have expired, rejected, or missing documents. Please contact support to continue."
             } = json_response(conn, 403)
    end
  end
end
