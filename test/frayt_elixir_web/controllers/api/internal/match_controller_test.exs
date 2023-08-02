defmodule FraytElixirWeb.API.Internal.MatchControllerTest do
  use FraytElixirWeb.ConnCase

  alias FraytElixir.Notifications.SentNotification
  alias FraytElixir.Shipment
  alias FraytElixir.Shipment.{Match, Pricing}
  alias FraytElixir.Repo

  import Ecto.Query
  import FraytElixir.Factory
  import FraytElixirWeb.Test.LoginHelper
  import FraytElixir.Test.StartMatchSupervisor
  import FraytElixir.Test.WebhookHelper

  setup :start_match_supervisor

  @create_params %{
    "origin_address" => "600 Kemper Commons Circle, Cincinnati, OH, USA",
    "origin_place_id" => "ChIJE0DHwm5LQIgRNhhS8Fl6AS8",
    "service_level" => 1,
    "vehicle_class" => 3,
    "scheduled" => true,
    "pickup_at" => "2030-04-17T11:00:00.000Z",
    "dropoff_at" => "2030-04-17T21:00:00.000Z",
    "stops" => [
      %{
        "destination_address" => "7285 Dixie Highway, Fairfield, OH, USA",
        "destination_place_id" => "ChIJE0DHwm5LQIgRNhhS8Fl6AS8",
        "load_fee" => false,
        "po" => "po for this match stop",
        "items" => [
          %{
            "description" => "sup",
            "weight" => 20,
            "volume" => 20,
            "pieces" => 2
          }
        ]
      }
    ]
  }

  @create_params_with_too_many_stops %{
    "origin_address" => "600 Kemper Commons Circle, Cincinnati, OH, USA",
    "origin_place_id" => "ChIJE0DHwm5LQIgRNhhS8Fl6AS8",
    "service_level" => 1,
    "vehicle_class" => 3,
    "scheduled" => true,
    "pickup_at" => "2030-04-17T11:00:00.000Z",
    "dropoff_at" => "2030-04-17T21:00:00.000Z",
    "stops" =>
      List.duplicate(
        %{
          "destination_address" => "7285 Dixie Highway, Fairfield, OH, USA",
          "destination_place_id" => "ChIJE0DHwm5LQIgRNhhS8Fl6AS8",
          "load_fee" => false,
          "items" => [
            %{
              "description" => "sup",
              "weight" => 20,
              "volume" => 20,
              "pieces" => 2,
              "type" => "item"
            }
          ]
        },
        61
      )
  }

  @delivery_params %{
    "pickup_notes" => "Dock #5",
    "po" => "ABC123",
    "self_sender" => false,
    "sender" => %{
      "name" => "John Smith",
      "email" => "john@smith.com",
      "phone_number" => "(937) 205-7059"
    },
    "stops" => [
      %{
        "delivery_notes" => "ABC Inc",
        "self_recipient" => false,
        "recipient" => %{
          "email" => "shipper@frayt.com",
          "name" => "Bill Smith",
          "phone_number" => ""
        }
      }
    ]
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    setup [:login_as_shipper]

    test "lists all matches for shipper", %{conn: conn} do
      conn = get(conn, Routes.api_v2_match_path(conn, :index, ".1"))
      assert json_response(conn, 200)["response"] == []
    end

    test "lists all matches for shipper in proper order", %{conn: conn, shipper: shipper} do
      insert_list(2, :match, shipper: shipper, total_distance: 10.0)

      %{id: match_id} = insert(:match, shipper: shipper, total_distance: 5.0)

      conn =
        conn
        |> get(Routes.api_v2_match_path(conn, :index, ".1"), %{
          "order" => "asc",
          "order_by" => "total_distance"
        })

      assert [^match_id | _] = json_response(conn, 200)["response"] |> Enum.map(& &1["id"])
    end

    test "lists all matches for shipper paginates properly", %{conn: conn, shipper: shipper} do
      %{id: match_id} = insert(:match, shipper: shipper)

      insert_list(2, :match, shipper: shipper)

      conn =
        conn
        |> get(Routes.api_v2_match_path(conn, :index, ".1"), %{
          "per_page" => "2",
          "page" => "1",
          "order_by" => "total_distance"
        })

      assert [^match_id | _] = json_response(conn, 200)["response"] |> Enum.map(& &1["id"])
    end

    test "lists all matches for shipper returns error with invalid per_page", %{
      conn: conn,
      shipper: shipper
    } do
      insert(:match, shipper: shipper)

      insert_list(10, :match, shipper: shipper)

      conn =
        conn
        |> get(Routes.api_v2_match_path(conn, :index, ".1"), %{
          "per_page" => "adfasdf",
          "page" => "1",
          "order_by" => "distance"
        })

      assert %{"code" => "invalid_attributes"} = json_response(conn, 422)
    end

    test "lists all matches for shipper filters and searches properly", %{
      conn: conn,
      shipper: shipper
    } do
      %{id: match_id} = insert(:match, state: :accepted, shipper: shipper, shortcode: "12345678")
      insert(:completed_match, shipper: shipper, shortcode: "12345678")
      insert(:match, state: :accepted, shipper: shipper, shortcode: "22222222")

      conn =
        conn
        |> get(Routes.api_v2_match_path(conn, :index, ".1"), %{
          "search" => "12345678",
          "states" => "active"
        })

      assert [^match_id | _] = json_response(conn, 200)["response"] |> Enum.map(& &1["id"])
    end

    test "returns unauthorized for user that is not a shipper", %{conn: conn} do
      conn =
        conn
        |> login_as_shipperless_user()
        |> get(Routes.api_v2_match_path(conn, :index, ".1"))

      assert json_response(conn, 403)["code"] == "forbidden"
    end
  end

  describe "show" do
    setup [:login_as_shipper]

    test "renders match", %{conn: conn, shipper: shipper} do
      %Match{id: match_id} = insert(:match, shipper: shipper)
      conn = get(conn, Routes.api_v2_match_path(conn, :show, ".1", match_id))

      assert %{"id" => ^match_id} = json_response(conn, 200)["response"]
    end

    test "renders match when not logged in", %{conn: conn} do
      %Match{id: match_id} = insert(:match)

      conn =
        conn
        |> logout()
        |> get(Routes.api_v2_match_path(conn, :show, ".1", match_id))

      assert %{"id" => ^match_id} = json_response(conn, 200)["response"]
    end

    test "renders shipperless match when not logged in", %{conn: conn} do
      %Match{id: match_id} = insert(:match, shipper: nil)

      conn =
        conn
        |> logout()
        |> get(Routes.api_v2_match_path(conn, :show, ".1", match_id))

      assert %{"id" => ^match_id} = json_response(conn, 200)["response"]
    end

    test "returns not_found for nonexistent match id", %{conn: conn} do
      conn = get(conn, Routes.api_v2_match_path(conn, :show, ".1", "alkjfasldfasd"))

      assert json_response(conn, 404)
    end
  end

  describe "duplicate match" do
    setup [:login_as_shipper]

    test "duplicates match", %{conn: conn, shipper: shipper} do
      match =
        insert(:match,
          scheduled: false,
          pickup_at: nil,
          dropoff_at: nil,
          po: "test",
          shipper: shipper
        )

      conn =
        post(conn, Routes.api_v2_match_action_path(conn, :duplicate, ".1", match), %{
          "po" => "test 2",
          "pickup_at" => "2030-03-01T00:00:00Z",
          "dropoff_at" => "2030-03-01T10:00:00",
          "scheduled" => true
        })

      assert response = json_response(conn, 201)["response"]

      assert response["id"] != match.id

      assert %{
               "po" => "test 2",
               "pickup_at" => "2030-03-01T00:00:00Z",
               "dropoff_at" => "2030-03-01T10:00:00Z",
               "scheduled" => true
             } = response
    end
  end

  describe "create match" do
    setup [:login_as_shipper]

    test "creates match when data is valid", %{conn: conn, shipper: shipper} do
      conn = post(conn, Routes.api_v2_match_path(conn, :create, ".1"), @create_params)
      response = json_response(conn, 201)["response"]

      assert %{
               "total_distance" => distance,
               "id" => match_id,
               "vehicle_class" => vehicle_class,
               "service_level" => service_level,
               "platform" => "marketplace",
               "stops" => [
                 %{
                   "po" => "po for this match stop"
                 }
                 | _
               ]
             } = response

      assert distance > 0
      assert service_level == @create_params["service_level"]
      assert vehicle_class == @create_params["vehicle_class"]
      match = Shipment.get_match!(match_id)
      assert match.shipper.id == shipper.id
    end

    test "creates a match with platform and preferred_driver params", %{conn: conn} do
      %{id: driver_id} = insert(:driver)

      params =
        Map.merge(@create_params, %{
          "preferred_driver_id" => driver_id,
          "platform" => "marketplace"
        })

      conn = post(conn, Routes.api_v2_match_path(conn, :create, ".1"), params)
      response = json_response(conn, 201)["response"]

      assert %{
               "id" => match_id,
               "platform" => "marketplace",
               "preferred_driver" => %{
                 "id" => ^driver_id
               }
             } = response

      match = Shipment.get_match!(match_id)
      assert match.contract == nil
    end

    test "don't fail when company doesn't have default contract defined", %{conn: conn} do
      conn = post(conn, Routes.api_v2_match_path(conn, :create, ".1"), @create_params)
      response = json_response(conn, 201)["response"]

      assert %{
               "id" => match_id
             } = response

      match = Shipment.get_match!(match_id)
      assert match.contract == nil
    end

    test "a match is created using the company default contract defined", %{conn: conn} do
      {:ok, [{:conn, conn} | _]} = login_as_shipper_with_contract(conn)

      conn = post(conn, Routes.api_v2_match_path(conn, :create, ".1"), @create_params)
      response = json_response(conn, 201)["response"]

      assert %{
               "id" => match_id
             } = response

      match = Shipment.get_match!(match_id)
      assert match.contract.contract_key == "tbc"
    end

    test "creates match when not logged in", %{conn: conn} do
      conn =
        conn
        |> logout()
        |> post(Routes.api_v2_match_path(conn, :create, ".1"), @create_params)

      assert %{"id" => match_id} = json_response(conn, 201)["response"]

      match = Shipment.get_match!(match_id)
      assert match.shipper_id == nil
    end

    test "renders forbidden when not logged in as a shipper", %{conn: conn} do
      conn =
        conn
        |> login_as_shipperless_user()
        |> post(Routes.api_v2_match_path(conn, :create, ".1"), @create_params)

      assert %{"code" => "forbidden"} = json_response(conn, 403)
    end

    test "renders error with more than 60 stops", %{conn: conn} do
      conn =
        post(
          conn,
          Routes.api_v2_match_path(conn, :create, ".1"),
          @create_params_with_too_many_stops
        )

      assert %{"message" => "Match stops length should be at most 60"} = json_response(conn, 422)
    end
  end

  describe "update match" do
    setup [
      :login_as_shipper,
      :create_match,
      :create_match_shipperless_match,
      :create_small_coupon,
      :create_large_coupon
    ]

    test "info as other shipper unauthorized", %{conn: conn, match: match} do
      conn = login_as_different_shipper(conn)

      conn = put(conn, Routes.api_v2_match_path(conn, :update, ".1", match), @create_params)

      assert %{"code" => "forbidden"} = json_response(conn, 403)
    end

    test "allow not logged in", %{
      conn: conn,
      shipperless_match: %Match{id: match_id} = match
    } do
      conn =
        conn
        |> logout()
        |> put(Routes.api_v2_match_path(conn, :update, ".1", match), @create_params)

      assert %{"id" => ^match_id} = json_response(conn, 200)["response"]
    end

    test "delivery info", %{
      conn: conn,
      match: %Match{id: match_id, match_stops: [%{id: stop_id} | _]} = match
    } do
      [stop_attrs | _] = Map.get(@delivery_params, "stops")

      stop_attrs =
        Map.put(stop_attrs, "id", stop_id)
        |> Map.put("po", "updated po")

      delivery_params = Map.put(@delivery_params, "stops", [stop_attrs])
      conn = put(conn, Routes.api_v2_match_path(conn, :update, ".1", match), delivery_params)

      assert %{
               "id" => ^match_id,
               "pickup_notes" => "Dock #5",
               "po" => "ABC123",
               "self_sender" => false,
               "sender" => %{
                 "name" => "John Smith",
                 "phone_number" => "+1 937-205-7059",
                 "email" => "john@smith.com",
                 "notify" => true
               },
               "stops" => [
                 %{
                   "delivery_notes" => "ABC Inc",
                   "self_recipient" => false,
                   "recipient" => %{
                     "email" => "shipper@frayt.com",
                     "name" => "Bill Smith"
                   },
                   "po" => "updated po"
                 }
               ]
             } = json_response(conn, 200)["response"]
    end

    test "delivery info unauthenticated", %{
      conn: conn,
      shipperless_match: %Match{id: match_id, match_stops: [%{id: stop_id} | _]} = match
    } do
      [stop_attrs | _] = Map.get(@delivery_params, "stops")
      delivery_params = Map.put(@delivery_params, "stops", [Map.put(stop_attrs, :id, stop_id)])

      conn =
        conn
        |> logout()
        |> put(Routes.api_v2_match_path(conn, :update, ".1", match), delivery_params)

      assert %{"id" => ^match_id} = json_response(conn, 200)["response"]
    end

    test "add valid coupon to match", %{conn: conn, match: match} do
      coupon_data = %{coupon_code: "10OFF"}

      conn = put(conn, Routes.api_v2_match_path(conn, :update, ".1", match), coupon_data)

      assert %{
               "coupon" => %{
                 "percentage" => 10
               }
             } = json_response(conn, 200)["response"]
    end

    test "add valid coupon to shipperless match", %{
      conn: conn,
      shipperless_match: match,
      shipper: %{id: shipper_id}
    } do
      coupon_data = %{coupon_code: "10OFF"}

      conn = put(conn, Routes.api_v2_match_path(conn, :update, ".1", match), coupon_data)

      assert %{shipper_id: ^shipper_id} = Shipment.get_match!(match.id)

      assert %{
               "coupon" => %{
                 "percentage" => 10
               }
             } = json_response(conn, 200)["response"]
    end

    test "fail to add invalid coupon to match", %{conn: conn, match: match} do
      coupon_data = %{
        coupon_code: "INVALID_CODE"
      }

      conn = put(conn, Routes.api_v2_match_path(conn, :update, ".1", match), coupon_data)

      assert json_response(conn, 422)
    end

    test "shipper added to match coupon", %{conn: conn, match: match} do
      coupon_data = %{
        coupon_code: "10OFF"
      }

      conn = put(conn, Routes.api_v2_match_path(conn, :update, ".1", match), coupon_data)

      assert %{} = json_response(conn, 200)["response"]
    end

    test "updates preferred driver for match in pending state", %{conn: conn, match: match} do
      %{id: driver_id} = insert(:driver)
      update_params = %{preferred_driver_id: driver_id}

      conn = put(conn, Routes.api_v2_match_path(conn, :update, ".1", match), update_params)

      assert %{
               "preferred_driver" => %{
                 "id" => ^driver_id
               }
             } = json_response(conn, 200)["response"]
    end

    test "updates preferred driver for match in assigning_driver state", %{
      conn: conn,
      shipper: shipper
    } do
      %{id: driver_id} = insert(:driver)
      %{id: new_driver_id} = new_driver = insert(:driver)

      set_driver_default_device(new_driver)

      %{id: match_id} =
        match =
        insert(:assigning_driver_match,
          platform: :deliver_pro,
          preferred_driver_id: driver_id,
          shipper: shipper
        )

      update_params = %{preferred_driver_id: new_driver_id}

      conn = put(conn, Routes.api_v2_match_path(conn, :update, ".1", match), update_params)

      assert %{
               "preferred_driver" => %{"id" => ^new_driver_id}
             } = json_response(conn, 200)["response"]

      query =
        from sent in SentNotification,
          where: sent.match_id == ^match_id,
          where: sent.driver_id == ^new_driver_id

      assert [%{driver_id: ^new_driver_id}] = Repo.all(query)
    end
  end

  describe "authorize match" do
    setup do
      start_match_webhook_sender(self())
    end

    test "with stripe credit card", %{conn: conn} do
      credit_card = insert(:credit_card)

      match =
        insert(:match, shipper: credit_card.shipper) |> Repo.preload(shipper: [:credit_card])

      conn =
        conn
        |> add_token_for_shipper(credit_card.shipper)
        |> put(Routes.api_v2_match_path(conn, :update, ".1", match), %{state: "authorized"})

      assert %{
               "state" => "assigning_driver"
             } = json_response(conn, 200)["response"]
    end

    test "when there a shipperless match", %{
      conn: conn
    } do
      %{id: match_id} = match = insert(:match, shipper: nil)

      %{shipper_id: shipper_id, shipper: shipper} = insert(:credit_card)

      conn =
        conn
        |> add_token_for_shipper(shipper)
        |> put(Routes.api_v2_match_path(conn, :update, ".1", match), %{state: "authorized"})

      assert %{"state" => "assigning_driver"} = json_response(conn, 200)["response"]

      assert %Match{shipper_id: ^shipper_id} = Shipment.get_match!(match_id)
    end

    test "fails with unauthenticated shipper", %{
      conn: conn
    } do
      match = insert(:match, shipper: nil)

      conn =
        conn
        |> put(Routes.api_v2_match_path(conn, :update, ".1", match), %{state: "authorized"})

      assert %{"code" => "forbidden"} = json_response(conn, 403)
    end

    test "authorize with bad stripe credit card returns correct status", %{conn: conn} do
      credit_card = insert(:credit_card, stripe_card: "bad_card")

      match =
        insert(:match, shipper: credit_card.shipper) |> Repo.preload(shipper: [:credit_card])

      conn =
        conn
        |> add_token_for_shipper(credit_card.shipper)
        |> put(Routes.api_v2_match_path(conn, :update, ".1", match), %{state: "authorized"})

      assert %{
               "message" => _message
             } = json_response(conn, 422)
    end

    test "with valid coupon", %{conn: conn} do
      credit_card = insert(:credit_card)
      coupon = insert(:small_coupon)

      match =
        insert(:match, shipper: credit_card.shipper) |> Repo.preload(shipper: [:credit_card])

      Pricing.apply_coupon_changeset(match, coupon.code) |> Repo.update()

      conn =
        conn
        |> add_token_for_shipper(credit_card.shipper)
        |> put(Routes.api_v2_match_path(conn, :update, ".1", match), %{state: "authorized"})

      assert %{
               "state" => "assigning_driver"
             } = json_response(conn, 200)["response"]
    end

    test "with already used coupon", %{conn: conn} do
      credit_card = insert(:credit_card)
      coupon = insert(:small_coupon, use_limit: 1)

      match =
        insert(:match, shipper: credit_card.shipper) |> Repo.preload(shipper: [:credit_card])

      Pricing.apply_coupon_changeset(match, coupon.code) |> Repo.update()

      insert(:assigning_driver_match,
        shipper_match_coupon: %{shipper: credit_card.shipper, coupon: coupon}
      )

      conn =
        conn
        |> add_token_for_shipper(credit_card.shipper)
        |> put(Routes.api_v2_match_path(conn, :update, ".1", match), %{state: "authorized"})

      assert %{
               "message" => "Coupon code has already been used"
             } = json_response(conn, 422)
    end
  end

  describe "cancel match" do
    setup [:login_as_shipper, :create_authorized_match]

    test "cancel match returns cancelled", %{conn: conn, authorized_match: match} do
      conn = delete(conn, Routes.api_v2_match_path(conn, :delete, ".1", match))
      assert %{} = json_response(conn, 200)
      assert %Match{state: :canceled} = Shipment.get_match!(match.id)
    end

    test "shipper cannot cancel match that doesn't belong to them", %{
      conn: conn,
      authorized_match: match
    } do
      conn = login_as_different_shipper(conn)
      conn = delete(conn, Routes.api_v2_match_path(conn, :delete, ".1", match))
      assert %{"code" => "forbidden"} = json_response(conn, 403)
    end
  end

  describe "rate driver" do
    setup [:login_as_shipper]

    test "shipper rates driver on completed match", %{conn: conn, shipper: shipper} do
      match = insert(:match, shipper: shipper, driver: build(:driver), state: :completed)
      conn = put(conn, Routes.api_v2_match_path(conn, :update, ".1", match), %{rating: 5})

      assert %{
               "rating" => 5
             } = json_response(conn, 200)["response"]
    end

    test "shipper rates driver poorly with reason on completed match", %{
      conn: conn,
      shipper: shipper
    } do
      match = insert(:match, shipper: shipper, driver: build(:driver), state: :completed)

      conn =
        put(conn, Routes.api_v2_match_path(conn, :update, ".1", match), %{
          rating: 1,
          rating_reason: "The driver was not on time"
        })

      assert %{
               "rating" => 1
             } = json_response(conn, 200)["response"]
    end

    test "returns error when no driver is on the match", %{conn: conn, shipper: shipper} do
      match = insert(:match, shipper: shipper, driver: nil)
      conn = put(conn, Routes.api_v2_match_path(conn, :update, ".1", match), %{rating: 5})

      assert %{
               "code" => "rate_driver",
               "message" => "Match has no driver to rate"
             } = json_response(conn, 422)
    end

    test "returns error when match is not yet completed", %{conn: conn, shipper: shipper} do
      match = insert(:match, shipper: shipper, driver: build(:driver), state: :picked_up)
      conn = put(conn, Routes.api_v2_match_path(conn, :update, ".1", match), %{rating: 5})

      assert %{
               "code" => "rate_driver",
               "message" => "Match is not completed"
             } = json_response(conn, 422)
    end
  end

  defp create_match(%{shipper: shipper}) do
    match =
      insert(:pending_match,
        shipper: nil,
        match_stops: [build(:match_stop, items: [build(:match_stop_item)])],
        shipper: shipper
      )

    {:ok, match: match}
  end

  defp create_authorized_match(%{shipper: shipper}) do
    match = insert(:match, shipper: shipper)
    {:ok, authorized_match: match}
  end

  defp create_match_shipperless_match(_) do
    match =
      insert(:pending_match,
        shipper: nil,
        match_stops: [build(:match_stop, items: [build(:match_stop_item)])]
      )

    {:ok, shipperless_match: match}
  end

  defp login_as_different_shipper(conn) do
    unauthorized_shipper = insert(:shipper)

    conn
    |> add_token_for_shipper(unauthorized_shipper)
  end

  defp login_as_shipperless_user(conn) do
    unauthorized_user = insert(:user)

    conn
    |> add_token_for_user(unauthorized_user)
  end

  defp create_small_coupon(_) do
    coupon = insert(:small_coupon)

    {:ok, coupon: coupon}
  end

  defp create_large_coupon(_) do
    coupon = insert(:large_coupon)

    {:ok, coupon: coupon}
  end
end
