defmodule FraytElixirWeb.API.MatchControllerTest do
  use FraytElixirWeb.ConnCase

  alias FraytElixir.Shipment
  alias FraytElixir.Shipment.Match
  alias FraytElixir.Payments.CreditCard
  alias FraytElixir.Accounts.{ApiAccount, Company, User, Location, Shipper}
  import FraytElixirWeb.Test.LoginHelper
  import FraytElixir.Factory

  import FraytElixir.Guardian

  import FraytElixir.Test.StartMatchSupervisor
  import FraytElixir.Test.WebhookHelper

  setup do
    start_match_webhook_sender(self())
  end

  setup :start_match_supervisor

  describe "Create Estimate" do
    test "create estimate with valid params is successful", %{conn: conn} do
      params = %{
        origin_address: "1266 Norman Ave Cincinnati OH 45231",
        destination_address: "641 Evangeline Rd Cincinnati OH 45240",
        weight: "25",
        dimensions_length: "1",
        dimensions_width: "1",
        dimensions_height: "1",
        pieces: "1",
        vehicle_class: "1",
        service_level: "1"
      }

      conn = post(conn, Routes.estimates_path(conn, :create_estimate), params)

      response = json_response(conn, 201)["response"]

      assert %{
               "fees" => fees,
               "total_distance" => distance,
               "id" => match_id,
               "vehicle_class" => vehicle_class,
               "service_level" => service_level
             } = response

      assert distance > 0
      assert length(fees) > 0
      assert service_level == 1
      assert vehicle_class == 1
      assert _shipment = Shipment.get_match!(match_id)
    end

    test "bad token in api request returns 401", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "bearer: fafasf")
        |> post(Routes.estimates_path(conn, :create_estimate), %{})

      assert json_response(conn, 401)
    end

    test "Class 4 returns 422 and not implemented", %{conn: conn} do
      params = %{
        origin_address: "1266 Norman Ave Cincinnati OH 45231",
        destination_address: "641 Evangeline Rd Cincinnati OH 45240",
        weight: "25",
        dimensions_length: "1",
        dimensions_width: "1",
        dimensions_height: "1",
        pieces: "1",
        vehicle_class: "4",
        service_level: "1",
        unload_method: "dock_to_dock"
      }

      conn = post(conn, Routes.estimates_path(conn, :create_estimate), params)

      assert %{
               "code" => "calculate_match_metrics",
               "message" => "Vehicle class box trucks are not supported in this market"
             } = json_response(conn, 422)
    end

    test "Invalid destination address returns 422", %{conn: conn} do
      params = %{
        origin_address: "1266 Norman Ave Cincinnati OH 45231",
        destination_address: "garbage",
        weight: "25",
        dimensions_length: "1",
        dimensions_width: "1",
        dimensions_height: "1",
        pieces: "1",
        vehicle_class: "1",
        service_level: "1"
      }

      conn = post(conn, Routes.estimates_path(conn, :create_estimate), params)

      assert %{"code" => "update_match"} = json_response(conn, 422)
    end

    test "Invalid origin address returns 422", %{conn: conn} do
      params = %{
        origin_address: "garbage",
        destination_address: "1266 Norman Ave Cincinnati OH 45231",
        weight: "25",
        dimensions_length: "1",
        dimensions_width: "1",
        dimensions_height: "1",
        pieces: "1",
        vehicle_class: "1",
        service_level: "1"
      }

      conn = post(conn, Routes.estimates_path(conn, :create_estimate), params)

      assert %{"code" => "update_match"} = json_response(conn, 422)
    end

    test "Invalid class choice returns 422 Invalid Args", %{conn: conn} do
      params = %{
        origin_address: "1266 Norman Ave Cincinnati OH 45231",
        destination_address: "641 Evangeline Rd Cincinnati OH 45240",
        weight: "25",
        dimensions_length: "1",
        dimensions_width: "1",
        dimensions_height: "1",
        pieces: "1",
        vehicle_class: "7",
        service_level: "1"
      }

      conn = post(conn, Routes.estimates_path(conn, :create_estimate), params)

      assert %{"code" => "update_match"} = json_response(conn, 422)
    end

    test "create estimate without required params gives useful error message", %{conn: conn} do
      params = %{
        origin_address: "1266 Norman Ave Cincinnati OH 45231",
        weight: "25",
        vehicle_class: "1",
        service_level: "1"
      }

      conn = post(conn, Routes.estimates_path(conn, :create_estimate), params)

      assert %{"message" => message} = json_response(conn, 422)
      assert String.contains?(message, "Destination")
    end

    test "with contract pricing", %{conn: conn} do
      params = %{
        origin_address: "1266 Norman Ave Cincinnati OH 45231",
        destination_address: "641 Evangeline Rd Cincinnati OH 45240",
        weight: "25",
        dimensions_length: "1",
        dimensions_width: "1",
        dimensions_height: "1",
        pieces: "1",
        vehicle_class: "1",
        service_level: "1",
        contract: "menards"
      }

      api_account = insert(:api_account_with_company)
      conn = add_token_for_api_account(conn, api_account)

      insert(:contract,
        contract_key: "menards",
        pricing_contract: :menards,
        company: api_account.company
      )

      conn = post(conn, Routes.estimates_path(conn, :create_estimate), params)

      response = json_response(conn, 201)["response"]

      assert %{
               "contract" => %{
                 "contract_key" => "menards"
               },
               "total_distance" => 5.0,
               "fees" => [
                 %{
                   "type" => "base_fee",
                   "amount" => 2000
                 }
               ]
             } = response
    end

    #  TODO: DEM-421 5/27/22 Once OR has fixed the contracts on their end, reneable this

    @tag :skip
    test "with garbage contract should throw 422", %{conn: conn} do
      params = %{
        origin_address: "1266 Norman Ave Cincinnati OH 45231",
        destination_address: "641 Evangeline Rd Cincinnati OH 45240",
        weight: "25",
        dimensions_length: "1",
        dimensions_width: "1",
        dimensions_height: "1",
        pieces: "1",
        vehicle_class: "1",
        service_level: "1",
        contract: "garbage"
      }

      conn = post(conn, Routes.estimates_path(conn, :create_estimate), params)

      assert %{"message" => "Contract is invalid"} = json_response(conn, 422)
    end

    test "chooses sedan vehicle class for dimensions less than 35 cubic ft", %{conn: conn} do
      params = %{
        origin_address: "1266 Norman Ave Cincinnati OH 45231",
        destination_address: "641 Evangeline Rd Cincinnati OH 45240",
        weight: "25",
        dimensions_length: "10",
        dimensions_width: "10",
        dimensions_height: "10",
        pieces: "1",
        service_level: "1"
      }

      api_account =
        insert(:api_account,
          company: build(:company_with_location, autoselect_vehicle_class: true)
        )

      conn =
        conn
        |> add_token_for_api_account(api_account)
        |> post(Routes.estimates_path(conn, :create_estimate), params)

      response = json_response(conn, 201)["response"]

      assert %{
               "id" => match_id,
               "vehicle_class" => 1
             } = response

      assert %{
               total_weight: 25,
               vehicle_class: 1,
               match_stops: [
                 %{
                   items: [
                     %{
                       pieces: 1,
                       width: 10.0,
                       length: 10.0,
                       height: 10.0,
                       weight: 25.0
                     }
                   ]
                 }
                 | _
               ]
             } = Shipment.get_match!(match_id)
    end

    test "chooses midsize vehicle class for dimensions less than 50 cubic ft but more than 35", %{
      conn: conn
    } do
      params = %{
        origin_address: "1266 Norman Ave Cincinnati OH 45231",
        destination_address: "641 Evangeline Rd Cincinnati OH 45240",
        weight: "25",
        dimensions_length: "45",
        dimensions_width: "40",
        dimensions_height: "40",
        pieces: "1",
        service_level: "1"
      }

      api_account =
        insert(:api_account,
          company: build(:company_with_location, autoselect_vehicle_class: true)
        )

      conn =
        conn
        |> add_token_for_api_account(api_account)
        |> post(Routes.estimates_path(conn, :create_estimate), params)

      response = json_response(conn, 201)["response"]

      assert %{
               "id" => match_id,
               "vehicle_class" => 2
             } = response

      assert %{
               vehicle_class: 2,
               match_stops: [
                 %{
                   items: [
                     %{
                       width: 40.0,
                       length: 45.0,
                       height: 40.0
                     }
                   ]
                 }
                 | _
               ]
             } = Shipment.get_match!(match_id)
    end

    test "chooses cargo vehicle class for dimensions less than 160 cubic ft but more than 60", %{
      conn: conn
    } do
      params = %{
        origin_address: "1266 Norman Ave Cincinnati OH 45231",
        destination_address: "641 Evangeline Rd Cincinnati OH 45240",
        weight: "25",
        dimensions_length: "60",
        dimensions_width: "60",
        dimensions_height: "60",
        pieces: "1",
        service_level: "1"
      }

      api_account =
        insert(:api_account,
          company: build(:company_with_location, autoselect_vehicle_class: true)
        )

      conn =
        conn
        |> add_token_for_api_account(api_account)
        |> post(Routes.estimates_path(conn, :create_estimate), params)

      response = json_response(conn, 201)["response"]

      assert %{
               "id" => match_id,
               "vehicle_class" => 3
             } = response

      assert %{
               vehicle_class: 3,
               match_stops: [
                 %{
                   items: [
                     %{
                       width: 60.0,
                       length: 60.0,
                       height: 60.0
                     }
                   ]
                 }
                 | _
               ]
             } = Shipment.get_match!(match_id)
    end

    test "returns error if dimensions are larger than cargo van and auto_vehicle_selection is true",
         %{
           conn: conn
         } do
      params = %{
        origin_address: "1266 Norman Ave Cincinnati OH 45231",
        destination_address: "641 Evangeline Rd Cincinnati OH 45240",
        weight: "25",
        dimensions_length: "60",
        dimensions_width: "60",
        dimensions_height: "60",
        pieces: "10",
        service_level: "1"
      }

      api_account =
        insert(:api_account,
          company: build(:company_with_location, autoselect_vehicle_class: true)
        )

      conn =
        conn
        |> add_token_for_api_account(api_account)
        |> post(Routes.estimates_path(conn, :create_estimate), params)

      assert %{"message" => message} = json_response(conn, 422)
      assert String.contains?(message, "Vehicle class can't be blank")
    end

    test "company can override smartly chosen sedan vehicle class for midsize vehicle class", %{
      conn: conn
    } do
      params = %{
        origin_address: "1266 Norman Ave Cincinnati OH 45231",
        destination_address: "641 Evangeline Rd Cincinnati OH 45240",
        weight: "25",
        dimensions_length: "10",
        dimensions_width: "10",
        dimensions_height: "10",
        pieces: "1",
        service_level: "1",
        vehicle_class: "2"
      }

      api_account = insert(:api_account, company: build(:company, autoselect_vehicle_class: true))

      conn =
        conn
        |> add_token_for_api_account(api_account)
        |> post(Routes.estimates_path(conn, :create_estimate), params)

      response = json_response(conn, 201)["response"]

      assert %{
               "id" => match_id,
               "vehicle_class" => 2
             } = response

      assert %{
               vehicle_class: 2,
               match_stops: [
                 %{
                   items: [
                     %{
                       width: 10.0,
                       length: 10.0,
                       height: 10.0
                     }
                   ]
                 }
                 | _
               ]
             } = Shipment.get_match!(match_id)
    end

    test "company without smart vehicle selection must specify vehicle class", %{conn: conn} do
      params = %{
        origin_address: "1266 Norman Ave Cincinnati OH 45231",
        destination_address: "641 Evangeline Rd Cincinnati OH 45240",
        weight: "25",
        dimensions_length: "1",
        dimensions_width: "1",
        dimensions_height: "1",
        pieces: "1",
        service_level: "1"
      }

      api_account =
        insert(:api_account, company: build(:company, autoselect_vehicle_class: false))

      conn =
        conn
        |> add_token_for_api_account(api_account)
        |> post(Routes.estimates_path(conn, :create_estimate), params)

      assert json_response(conn, 422)
    end
  end

  describe "create match" do
    setup :login_with_api

    test "create match from estimate with valid params works", %{
      conn: conn,
      api_account: %ApiAccount{company: company}
    } do
      %Match{id: estimate_id} = insert(:estimate)

      %CreditCard{shipper: %Shipper{user: %User{email: email}}} =
        insert(:credit_card,
          shipper: build(:shipper, location: build(:location, company: company))
        )

      params = %{
        estimate: estimate_id,
        dimensionsLength: 48,
        dimensionsWidth: 40,
        dimensionsHeight: 40,
        vehicle_class: 1,
        weight: 25,
        pieces: 1,
        loadUnload: false,
        shipper_email: email,
        identifier: "N47881",
        recipient_name: "John",
        recipient_email: "john@smith.com",
        recipient_phone: "(513) 402-0000"
      }

      conn = post(conn, Routes.api_match_path(conn, :create), params)

      assert %{
               "id" => match_id,
               "total_price" => _,
               "identifier" => identifier,
               "stops" => [
                 %{
                   "recipient" => %{
                     "name" => "John",
                     "email" => "john@smith.com",
                     "phone_number" => "+1 513-402-0000"
                   }
                 }
               ]
             } = json_response(conn, 201)["response"]

      assert identifier == "N47881"

      assert %Match{id: ^match_id, state: :assigning_driver, identifier: ^identifier} =
               Shipment.get_match!(match_id)
    end

    test "create match from estimate with scheduling works", %{
      conn: conn,
      api_account: %ApiAccount{company: company}
    } do
      %Match{id: estimate_id} = insert(:estimate, scheduled: false)

      %CreditCard{shipper: %Shipper{user: %User{email: email}}} =
        insert(:credit_card,
          shipper: build(:shipper, location: build(:location, company: company))
        )

      params = %{
        estimate: estimate_id,
        dimensionsLength: 48,
        dimensionsWidth: 40,
        dimensionsHeight: 40,
        vehicle_class: 1,
        pieces: 1,
        weight: 100,
        loadUnload: false,
        shipper_email: email,
        identifier: "N47881",
        scheduled_pickup: "2030-09-28T09:31",
        scheduled_dropoff: "2030-09-28T18:31"
      }

      conn = post(conn, Routes.api_match_path(conn, :create), params)

      assert %{
               "id" => ^estimate_id,
               "scheduled" => true,
               "total_price" => _match_price,
               "identifier" => "N47881"
             } = json_response(conn, 201)["response"]
    end

    test "create match from estimate without shipper email uses company shipper", %{
      conn: conn,
      api_account: %ApiAccount{
        company: %Company{
          locations: [%Location{shippers: [%Shipper{id: shipper_id} | _shippers]} | _locations]
        }
      }
    } do
      %Match{id: estimate_id} = insert(:estimate)

      params = %{
        estimate: estimate_id,
        dimensionsLength: 48,
        dimensionsWidth: 40,
        dimensionsHeight: 40,
        pieces: 1,
        weight: 100,
        vehicleClass: 1,
        loadUnload: false
      }

      conn = post(conn, Routes.api_match_path(conn, :create), params)

      assert %{"id" => match_id, "total_price" => _} = json_response(conn, 201)["response"]

      assert %Match{id: ^match_id, state: :assigning_driver, shipper_id: ^shipper_id} =
               Shipment.get_match!(match_id)
    end

    test "create match from estimate without shipper email fails if company has no shippers", %{
      conn: conn,
      api_account: _api_account
    } do
      api_account = insert(:api_account_without_shipper)
      {:ok, token, _} = encode_and_sign(api_account, %{aud: "frayt_api"})
      conn = conn |> Plug.Conn.put_req_header("authorization", "bearer: " <> token)

      %Match{id: estimate_id} = insert(:estimate)

      params = %{
        estimate: estimate_id,
        dimensionsLength: 48,
        dimensionsWidth: 40,
        dimensionsHeight: 40,
        pieces: 1,
        weight: 100,
        loadUnload: false
      }

      conn = post(conn, Routes.api_match_path(conn, :create), params)

      assert %{"code" => "forbidden", "message" => message} = json_response(conn, 403)

      assert String.contains?(message, "Invalid shipper")
    end

    test "create a match with a shipper from another company", %{
      conn: conn,
      api_account: _api_account
    } do
      %Match{id: estimate_id} = insert(:estimate)
      %CreditCard{shipper: %Shipper{user: %User{email: email}}} = insert(:credit_card)

      params = %{
        estimate: estimate_id,
        dimensionsLength: 48,
        dimensionsWidth: 40,
        dimensionsHeight: 40,
        pieces: 1,
        weight: 100,
        loadUnload: false,
        shipper_email: email
      }

      conn = post(conn, Routes.api_match_path(conn, :create), params)

      assert %{"code" => "forbidden", "message" => message} = json_response(conn, 403)

      assert String.contains?(message, "Invalid shipper")
    end

    test "chooses sedan if dimensions are less than 30cubic ft, regardless of estimate's dimensions or vehicle_class if autoselect_vehicle_class is true",
         %{
           conn: conn,
           api_account: _api_account
         } do
      %Match{
        id: estimate_id
      } =
        insert(:estimate,
          vehicle_class: nil,
          match_stops: [
            build(:estimate_match_stop,
              items: [build(:match_stop_item, width: 45, height: 40, length: 40)]
            )
          ]
        )

      params = %{
        estimate: estimate_id,
        dimensionsLength: 12,
        dimensionsWidth: 12,
        dimensionsHeight: 12,
        pieces: 1,
        weight: 25,
        loadUnload: false
      }

      shipper = insert(:shipper)

      api_account =
        insert(:api_account,
          company:
            build(:company_with_location,
              autoselect_vehicle_class: true,
              locations: [insert(:location, shippers: [shipper])]
            )
        )

      conn =
        conn
        |> add_token_for_api_account(api_account)
        |> post(Routes.api_match_path(conn, :create), params)

      assert %{
               "vehicle_class" => 1
             } = json_response(conn, 201)["response"]
    end

    test "chooses estimate's original vehicle class if no vehicle_class is passed and autoselect_vehicle_class is false",
         %{
           conn: conn,
           api_account: _api_account
         } do
      %Match{
        id: estimate_id
      } =
        insert(:estimate,
          vehicle_class: 2,
          match_stops: [
            build(:estimate_match_stop,
              items: [build(:match_stop_item, width: 45, height: 40, length: 40)]
            )
          ]
        )

      params = %{
        estimate: estimate_id,
        dimensionsLength: 12,
        dimensionsWidth: 12,
        dimensionsHeight: 12,
        pieces: 1,
        weight: 25,
        loadUnload: false
      }

      conn = post(conn, Routes.api_match_path(conn, :create), params)

      assert %{
               "vehicle_class" => 2
             } = json_response(conn, 201)["response"]
    end

    test "chooses passed in vehicle_class if autoselect_vehicle_class is false", %{
      conn: conn,
      api_account: _api_account
    } do
      %Match{
        id: estimate_id
      } =
        insert(:estimate,
          vehicle_class: 2,
          match_stops: [
            build(:estimate_match_stop,
              items: [build(:match_stop_item, width: 45, height: 40, length: 40)]
            )
          ]
        )

      params = %{
        estimate: estimate_id,
        dimensionsLength: 12,
        dimensionsWidth: 12,
        dimensionsHeight: 12,
        vehicle_class: 1,
        pieces: 1,
        weight: 25,
        loadUnload: false
      }

      conn = post(conn, Routes.api_match_path(conn, :create), params)

      assert %{
               "vehicle_class" => 1
             } = json_response(conn, 201)["response"]
    end

    test "create match with no recipient contact info", %{conn: conn} do
      stop = build(:estimate_match_stop, self_recipient: true, recipient: nil)
      match = insert(:estimate, match_stops: [stop])

      params = %{
        estimate: match.id,
        recipient_name: "Joe",
        dimensionsLength: 12,
        dimensionsWidth: 12,
        dimensionsHeight: 12,
        pieces: 1,
        weight: 25
      }

      conn = post(conn, Routes.api_match_path(conn, :create), params)

      assert %{
               "stops" => [
                 %{
                   "self_recipient" => false,
                   "recipient" => %{"name" => "Joe", "notify" => false}
                 }
               ]
             } = json_response(conn, 201)["response"]
    end
  end

  describe "list_matches" do
    setup :login_with_api

    test "list matches includes matches from logged in company", %{
      conn: conn,
      api_account: %ApiAccount{
        company: %Company{
          locations: [%Location{shippers: [shipper | _shippers]} | _locations]
        }
      }
    } do
      [match1, match2] = insert_list(2, :match, shipper: shipper)

      params = %{
        cursor: 0,
        limit: 10
      }

      conn = get(conn, Routes.api_match_path(conn, :index), params)
      assert %{"response" => response_matches} = json_response(conn, 200)
      assert Enum.count(response_matches) == 2
      assert match1.id in (response_matches |> Enum.map(& &1["id"]))
      assert match2.id in (response_matches |> Enum.map(& &1["id"]))
    end
  end

  describe "get match" do
    setup :login_with_api

    test "get match created by api account company shipper", %{
      conn: conn,
      api_account: %ApiAccount{
        company: %Company{
          locations: [%Location{shippers: [shipper | _shippers]} | _locations]
        }
      }
    } do
      %Match{id: match_id} = match = insert(:match, shipper: shipper)
      conn = get(conn, Routes.api_match_path(conn, :show, match))
      assert %{"response" => %{"id" => ^match_id}} = json_response(conn, 200)
    end

    test "get match created by another company", %{
      conn: conn,
      api_account: _api_account
    } do
      match = insert(:match)
      conn = get(conn, Routes.api_match_path(conn, :show, match))
      assert %{"code" => "forbidden", "message" => message} = json_response(conn, 403)
      assert String.contains?(message, "Invalid match")
    end

    test "get non-existant match", %{
      conn: conn,
      api_account: _api_account
    } do
      conn = get(conn, Routes.api_match_path(conn, :show, "goo"))
      assert _ = json_response(conn, 404)
    end
  end

  describe "cancel match" do
    setup :login_with_api

    test "when created by logged in company", %{
      conn: conn,
      api_account: %ApiAccount{company: company}
    } do
      shipper = insert(:shipper, location: build(:location, company: company))
      match = insert(:match, shipper: shipper)
      conn = delete(conn, Routes.api_match_path(conn, :delete, match))
      assert %{} = json_response(conn, 200)
      assert %Match{state: :canceled} = Shipment.get_match!(match.id)
    end

    test "cannot cancel a picked up match", %{
      conn: conn,
      api_account: %ApiAccount{company: company}
    } do
      shipper = insert(:shipper, location: build(:location, company: company))
      match = insert(:picked_up_match, shipper: shipper)
      conn = delete(conn, Routes.api_match_path(conn, :delete, match))

      assert %{"code" => "invalid_state"} = json_response(conn, 400)
    end

    test "created by different company", %{
      conn: conn,
      api_account: _api_account
    } do
      match = insert(:match)
      conn = delete(conn, Routes.api_match_path(conn, :delete, match))
      assert %{"code" => "forbidden", "message" => message} = json_response(conn, 403)
      assert String.contains?(message, "Invalid match")
    end

    test "delete a non-existant match", %{
      conn: conn,
      api_account: _api_account
    } do
      conn = delete(conn, Routes.api_match_path(conn, :delete, "goo"))
      assert _ = json_response(conn, 404)
    end
  end

  describe "get match status" do
    setup :login_with_api

    test "get status of match created by api account company shipper", %{
      conn: conn,
      api_account: %ApiAccount{
        company: company
      }
    } do
      shipper = insert(:shipper, location: build(:location, company: company))

      %Match{id: match_id} =
        match =
        insert(:signed_match,
          shipper: shipper,
          match_stops: build_match_stops_with_items([:signed])
        )

      conn = get(conn, Routes.api_match_status_path(conn, :status, match))

      assert %{
               "match" => ^match_id,
               "status" => "Signed",
               "stage" => 10
             } = json_response(conn, 200)
    end

    test "fail to get status of match created by a different company shipper", %{
      conn: conn,
      api_account: %ApiAccount{}
    } do
      match = insert(:signed_match)
      conn = get(conn, Routes.api_match_status_path(conn, :status, match))

      assert %{"code" => "forbidden", "message" => message} = json_response(conn, 403)
      assert String.contains?(message, "Invalid match")
    end
  end
end
