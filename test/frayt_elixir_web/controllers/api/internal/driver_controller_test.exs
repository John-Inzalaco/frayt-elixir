defmodule FraytElixirWeb.API.Internal.DriverControllerTest do
  use FraytElixirWeb.ConnCase

  alias FraytElixir.Drivers
  alias FraytElixir.Drivers.{Driver, Vehicle}
  alias FraytElixir.Accounts.User

  import FraytElixir.Factory
  import FraytElixirWeb.Test.LoginHelper
  import FraytElixirWeb.Test.FileHelper
  import FraytElixir.Test.StartMatchSupervisor

  setup :start_match_supervisor

  @update_attrs %{
    first_name: "some updated first_name",
    last_name: "some updated last_name",
    license_number: "some updated license_number",
    license_state: "some updated license_state",
    phone_number: "+1 513-555-1111",
    ssn: "000-00-0000"
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "show" do
    setup [:login_as_driver]

    test "show driver", %{
      conn: conn,
      driver:
        %Driver{
          id: driver_id,
          first_name: first_name,
          last_name: last_name,
          fountain_id: fountain_id,
          can_load: can_load,
          user: %User{email: email},
          vehicles: [
            %Vehicle{
              id: vehicle_id,
              cargo_area_height: cargo_area_height,
              cargo_area_width: cargo_area_width,
              cargo_area_length: cargo_area_length,
              max_cargo_weight: max_cargo_weight,
              door_height: door_height,
              door_width: door_width,
              wheel_well_width: wheel_well_width
            }
            | _
          ]
        } = driver
    } do
      {:ok,
       %Driver{
         current_location: %{
           id: location_id,
           geo_location: %Geo.Point{coordinates: {lng, lat}}
         }
       }} = Drivers.update_current_location(driver, chris_house_point())

      %{id: doc_id} = insert(:agreement_document, user_types: [:driver])

      conn = get(conn, Routes.api_v2_driver_path(conn, :show, ".1"))

      assert %{
               "id" => ^driver_id,
               "email" => ^email,
               "first_name" => ^first_name,
               "last_name" => ^last_name,
               "state" => "approved",
               "fountain_id" => ^fountain_id,
               "is_password_set" => true,
               "can_load" => ^can_load,
               "pending_agreements" => [%{"id" => ^doc_id}],
               "vehicle" => %{
                 "id" => ^vehicle_id,
                 "capacity_height" => ^cargo_area_height,
                 "capacity_width" => ^cargo_area_width,
                 "capacity_length" => ^cargo_area_length,
                 "capacity_weight" => ^max_cargo_weight,
                 "capacity_door_height" => ^door_height,
                 "capacity_door_width" => ^door_width,
                 "capacity_between_wheel_wells" => ^wheel_well_width
               },
               "current_location" => %{
                 "id" => ^location_id,
                 "lat" => ^lat,
                 "lng" => ^lng,
                 "created_at" => _
               }
             } = json_response(conn, 200)["response"]
    end

    test "show driver with no vehicles or addresses", %{conn: conn} do
      %Driver{
        id: driver_id,
        first_name: first_name,
        last_name: last_name,
        fountain_id: fountain_id,
        can_load: can_load,
        user: %User{email: email}
      } = vehicleless_driver = insert(:driver, vehicles: [], address: nil)

      conn = add_token_for_driver(conn, vehicleless_driver)
      conn = get(conn, Routes.api_v2_driver_path(conn, :show, ".1"))

      assert %{
               "id" => ^driver_id,
               "email" => ^email,
               "first_name" => ^first_name,
               "last_name" => ^last_name,
               "state" => "approved",
               "fountain_id" => ^fountain_id,
               "is_password_set" => true,
               "can_load" => ^can_load,
               "vehicle" => nil
             } = json_response(conn, 200)["response"]
    end
  end

  describe "create" do
    test "renders driver when data is valid", %{conn: conn} do
      %{id: market_id} =
        insert(:market, currently_hiring: [:car, :cargo_van, :midsize, :box_truck])

      %{id: tos_id} = insert(:agreement_document, user_types: [:driver])
      %{id: agreement_id} = insert(:agreement_document, user_types: [:driver])
      %{id: privacy_policy_id} = insert(:agreement_document, user_types: [:driver])

      params = %{
        "user" => %{
          "password" => "p@ssw0rd",
          "email" => "some@email.com"
        },
        "agreements" => [
          %{"agreed" => true, "document_id" => tos_id},
          %{"agreed" => true, "document_id" => agreement_id},
          %{"agreed" => true, "document_id" => privacy_policy_id}
        ],
        "vehicle_class" => "car",
        "signature" => "test",
        "phone_number" => "2125650000",
        "market_id" => market_id,
        "english_proficiency" => "advanced"
      }

      conn =
        post(
          conn,
          Routes.api_v2_driver_path(conn, :create, ".1"),
          params
        )

      assert %{
               "driver" => %{},
               "token" => _
             } = json_response(conn, 201)["response"]
    end
  end

  describe "create driver from preapproval" do
    test "renders driver when data is valid", %{conn: conn} do
      %{id: market_id} =
        insert(:market, currently_hiring: [:car, :cargo_van, :midsize, :box_truck])

      %{id: tos_id} = insert(:agreement_document, user_types: [:driver])
      %{id: agreement_id} = insert(:agreement_document, user_types: [:driver])
      %{id: privacy_policy_id} = insert(:agreement_document, user_types: [:driver])

      params = %{
        "user" => %{
          "password" => "p@ssw0rd",
          "email" => "some@email.com"
        },
        "agreements" => [
          %{"agreed" => true, "document_id" => tos_id},
          %{"agreed" => true, "document_id" => agreement_id},
          %{"agreed" => true, "document_id" => privacy_policy_id}
        ],
        "vehicle_class" => "car",
        "signature" => "test",
        "phone_number" => "2125650000",
        "market_id" => market_id,
        "english_proficiency" => "advanced"
      }

      conn =
        post(
          conn,
          Routes.api_v2_driver_path(conn, :create, ".1"),
          params
        )

      assert %{
               "driver" => %{},
               "token" => _
             } = json_response(conn, 201)["response"]
    end
  end

  describe "update driver" do
    setup [:login_as_driver, :base64_image, :create_unregistered_driver]

    test "renders driver when data is valid", %{conn: conn, driver: %Driver{id: id}} do
      conn = put(conn, Routes.api_v2_driver_path(conn, :update, ".1"), driver: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["response"]
    end

    test "renders driver when identity screen data is valid", %{
      conn: conn,
      unregistered_driver: %Driver{} = unregistered_driver,
      image: image
    } do
      {:ok, conn: conn, driver: %Driver{id: id, images: images}} =
        login_as_driver(conn, unregistered_driver)

      assert Enum.empty?(images)

      conn =
        put(conn, Routes.api_v2_driver_path(conn, :update, ".1"), %{
          licenseNumber: "different license number",
          licenseExpirationDate: Date.utc_today(),
          ssn: "010-10-0101",
          licensePhoto: image,
          profilePhoto: image
        })

      assert %{"id" => ^id, "images" => images} = json_response(conn, 200)["response"]
      assert length(images) == 2
    end

    test "create vehicle documents", %{conn: conn} do
      driver = insert(:driver, images: [], vehicles: [build(:vehicle, images: [])])

      params = %{
        "passengers_side" => %{
          file_name: "test/passengers_side.jpeg",
          updated_at: DateTime.utc_now(),
          binary: "content"
        },
        "drivers_side" => %{
          file_name: "test/drivers_side.jpeg",
          updated_at: DateTime.utc_now(),
          binary: "content"
        },
        "cargo_area" => %{
          file_name: "test/cargo_area.jpeg",
          updated_at: DateTime.utc_now(),
          binary: "content"
        },
        "front" => %{
          file_name: "test/front.jpeg",
          updated_at: DateTime.utc_now(),
          binary: "content"
        },
        "back" => %{
          file_name: "test/back.jpeg",
          updated_at: DateTime.utc_now(),
          binary: "content"
        }
      }

      conn =
        conn
        |> add_token_for_driver(driver)
        |> put(Routes.api_v2_driver_path(conn, :update, ".1"), vehicle_photos: params)

      assert %{"vehicle" => %{"images" => images}} = json_response(conn, 200)["response"]
      assert length(images) == 5
    end

    test "only valid types will succeed when creating vehicle documents", %{conn: conn} do
      driver = insert(:driver, images: [], vehicles: [build(:vehicle, images: [])])

      params = %{
        "invalid" => %{
          file_name: "test/invalid.jpeg",
          updated_at: DateTime.utc_now(),
          binary: "content"
        },
        "back" => %{
          file_name: "test/back.jpeg",
          updated_at: DateTime.utc_now(),
          binary: "content"
        }
      }

      conn =
        conn
        |> add_token_for_driver(driver)
        |> put(Routes.api_v2_driver_path(conn, :update, ".1"), vehicle_photos: params)

      assert %{"vehicle" => %{"images" => images}} = json_response(conn, 200)["response"]
      assert length(images) == 1
    end

    test "verify identity step on driver registration", %{conn: conn} do
      params = %{
        "license_photo" => Base.encode64("image_content"),
        "license_expiration_date" => "2030-01-01",
        "profile_photo" => Base.encode64("image_content"),
        "license_number" => "license_number",
        "ssn" => "123456789"
      }

      conn = put(conn, Routes.api_v2_driver_path(conn, :update, ".1"), params)
      json_response(conn, 200)["response"]
    end
  end

  describe "update driver profile photo" do
    setup [:login_as_driver, :base64_image]

    test "with invalid image returns 422", %{conn: conn} do
      conn =
        put(conn, Routes.api_v2_driver_path(conn, :update, ".1"), %{
          "profile_photo" => "asjdklfhalsfjhd"
        })

      assert json_response(conn, 422)
    end
  end

  describe "update driver to set initial password" do
    setup [:create_driver, :create_unregistered_driver]

    test "unregistered driver can set password", %{conn: conn, unregistered_driver: driver} do
      conn =
        conn
        |> add_token_for_driver(driver)

      password_info = %{"password" => "ABCdef@1", "password_confirmation" => "ABCdef@1"}

      conn = put(conn, Routes.api_v2_driver_path(conn, :update, ".1"), password_info)

      assert response(conn, 204)
    end

    test "fails when confirmation doesn't match", %{conn: conn, unregistered_driver: driver} do
      conn =
        conn
        |> add_token_for_driver(driver)

      password_info = %{"password" => "ABC", "password_confirmation" => "XYZ"}

      conn = put(conn, Routes.api_v2_driver_path(conn, :update, ".1"), password_info)

      assert %{"code" => "invalid_attributes"} = json_response(conn, 422)
    end
  end

  describe "update driver to change password" do
    setup [:login_as_driver]

    test "driver can change password", %{conn: conn} do
      password_info = %{
        "current_password" => "password",
        "password" => "ABCdef@3",
        "password_confirmation" => "ABCdef@3"
      }

      conn = put(conn, Routes.api_v2_driver_path(conn, :update, ".1"), password_info)

      assert response(conn, 204)
    end

    test "fails when current password in invalid", %{conn: conn} do
      password_info = %{
        "current_password" => "wrong",
        "password" => "ABCdef@3",
        "password_confirmation" => "ABCdef@3"
      }

      conn = put(conn, Routes.api_v2_driver_path(conn, :update, ".1"), password_info)

      assert %{"code" => "invalid_password"} = json_response(conn, 422)
    end

    test "fails when password is too short", %{conn: conn} do
      password_info = %{
        "current_password" => "password",
        "password" => "ABC@3",
        "password_confirmation" => "ABC@3"
      }

      conn = put(conn, Routes.api_v2_driver_path(conn, :update, ".1"), password_info)

      assert %{"code" => "invalid_attributes"} = json_response(conn, 422)
    end
  end

  describe "update driver can_load" do
    setup [:login_as_driver]

    test "renders driver with valid data", %{conn: conn, driver: %Driver{id: driver_id}} do
      load_params = %{"can_load" => true}

      conn = put(conn, Routes.api_v2_driver_path(conn, :update, ".1"), load_params)

      assert %{
               "id" => ^driver_id,
               "can_load" => true
             } = json_response(conn, 200)["response"]
    end

    test "fails with invalid data", %{conn: conn} do
      load_params = %{"can_load" => "literal garbage"}

      conn = put(conn, Routes.api_v2_driver_path(conn, :update, ".1"), load_params)

      assert json_response(conn, 422)
    end
  end

  describe "update driver registration complete" do
    setup [:login_as_driver]

    test "renders driver with valid data", %{conn: conn, driver: %Driver{id: driver_id}} do
      load_params = %{"state" => "registered"}

      conn = put(conn, Routes.api_v2_driver_path(conn, :update, ".1"), load_params)

      assert %{
               "id" => ^driver_id,
               "state" => "registered"
             } = json_response(conn, 200)["response"]
    end
  end

  describe "update driver wallet" do
    setup [:login_as_driver]

    test "renders driver with valid data", %{conn: conn, driver: %Driver{id: driver_id}} do
      stripe_params = %{
        "ssn" => "000–00–0000",
        "agree_to_tos" => true
      }

      conn = put(conn, Routes.api_v2_driver_path(conn, :update, ".1"), stripe_params)

      assert %{
               "id" => ^driver_id
             } = json_response(conn, 200)["response"]
    end

    test "requires tos agreement", %{conn: conn} do
      driver = insert(:driver, ssn: nil)

      stripe_params = %{
        "ssn" => "000–00–0000",
        "agree_to_tos" => false
      }

      conn =
        conn
        |> add_token_for_driver(driver)
        |> put(Routes.api_v2_driver_path(conn, :update, ".1"), stripe_params)

      assert %{
               "code" => "unprocessable_entity",
               "message" => "Must agree to Branch Terms of Service to create your wallet"
             } = json_response(conn, 422)
    end

    test "renders error with invalid ssn", %{conn: conn} do
      stripe_params = %{
        "ssn" => "000–00–00",
        "agree_to_tos" => true
      }

      conn = put(conn, Routes.api_v2_driver_path(conn, :update, ".1"), stripe_params)

      assert %{"code" => "invalid_attributes", "message" => "Ssn should be 9 numbers"} =
               json_response(conn, 422)
    end
  end

  describe "update driver account" do
    setup [:login_as_driver]

    test "renders driver with valid account details and no password fields", %{conn: conn} do
      account_params = %{
        "email" => "email@example.com",
        "first_name" => "Billy",
        "last_name" => "Bob",
        "phone_number" => "+15132223333",
        "address" => "131 E 14th Street",
        "city" => "Cincinnati",
        "state" => "Ohio",
        "zip" => "45202"
      }

      conn = put(conn, Routes.api_v2_driver_path(conn, :update, ".1"), account_params)

      assert %{
               "state" => "approved",
               "first_name" => "Billy",
               "last_name" => "Bob",
               "phone_number" => "+1 513-222-3333",
               "address" => %{
                 "state" => "Ohio"
               }
             } = json_response(conn, 200)["response"]
    end

    test "updates only phone number", %{conn: conn} do
      account_params = %{
        "phone_number" => "+15132223333"
      }

      conn = put(conn, Routes.api_v2_driver_path(conn, :update, ".1"), account_params)

      assert %{
               "state" => "approved",
               "phone_number" => "+1 513-222-3333"
             } = json_response(conn, 200)["response"]
    end

    test "address with valid params, returns driver", %{conn: conn} do
      address_params = %{
        "address" => "4533 Ruebel Place",
        "city" => "Cincinnati",
        "state" => "Ohio",
        "zip" => "45211"
      }

      conn = put(conn, Routes.api_v2_driver_path(conn, :update, ".1"), address_params)

      assert %{
               "state" => "approved",
               "address" => %{
                 "address" => "4533 Ruebel Place",
                 "city" => "Cincinnati",
                 "state" => "Ohio",
                 "zip" => "45211"
               }
             } = json_response(conn, 200)["response"]
    end

    test "address with invalid params, returns error", %{conn: conn} do
      address_params = %{
        "address" => "",
        "city" => "",
        "state" => "",
        "zip" => ""
      }

      conn = put(conn, Routes.api_v2_driver_path(conn, :update, ".1"), address_params)

      assert %{"code" => "invalid_attributes"} = json_response(conn, 422)
    end
  end

  describe "update driver fleet notifications opt-in" do
    setup [:login_as_driver]

    test "with valid opt-in params, returns 200", %{conn: conn} do
      conn =
        put(conn, Routes.api_v2_driver_path(conn, :update, ".1"), %{
          "schedule_notifications_opt_in" => "true"
        })

      assert %{
               "schedule_opt_state" => "opted_in"
             } = json_response(conn, 200)["response"]
    end

    test "with valid opt-out params, returns 200", %{conn: conn} do
      conn =
        put(conn, Routes.api_v2_driver_path(conn, :update, ".1"), %{
          "schedule_notifications_opt_in" => "false"
        })

      assert %{
               "schedule_opt_state" => "opted_out"
             } = json_response(conn, 200)["response"]
    end
  end

  defp create_driver(_) do
    driver = insert(:driver)
    {:ok, driver: driver}
  end

  defp create_unregistered_driver(_) do
    driver = insert(:unregistered_driver, images: [])
    {:ok, unregistered_driver: driver}
  end
end
