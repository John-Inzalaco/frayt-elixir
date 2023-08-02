defmodule FraytElixirWeb.API.Internal.BackgroundCheckControllerTest do
  use FraytElixirWeb.ConnCase

  import FraytElixirWeb.Test.LoginHelper

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "create" do
    setup [:login_as_driver]

    test "payment_result when payment_method is invalid", %{conn: conn} do
      payment_params = %{
        intent_id: "random_intent_id",
        method_id: nil
      }

      conn =
        post(
          conn,
          Routes.api_v2_driver_background_check_path(conn, :create, ".1"),
          payment_params
        )

      assert %{"code" => "invalid_attributes", "message" => "Method can't be blank"} =
               json_response(conn, 422)
    end

    test "renders payment_result when data is valid", %{conn: conn} do
      payment_params = %{method_id: "random_method_id"}

      conn =
        post(
          conn,
          Routes.api_v2_driver_background_check_path(conn, :create, ".1"),
          payment_params
        )

      assert %{
               "payment_intent_client_secret" => "client_secret",
               "payment_intent_error" => nil,
               "requires_action" => false
             } = json_response(conn, 201)
    end

    test "driver with a box truck vehicle cannot pay for a background check", %{conn: conn} do
      driver =
        insert(:driver,
          vehicles: [
            build(:vehicle, vehicle_class: 1),
            build(:vehicle, vehicle_class: 3),
            build(:vehicle, vehicle_class: 4)
          ]
        )

      conn =
        add_token_for_driver(conn, driver)
        |> post(
          Routes.api_v2_driver_background_check_path(conn, :create, ".1"),
          %{method_id: "random_method_id"}
        )

      assert %{"message" => "Background check payments are not needed for box truck drivers"} =
               json_response(conn, 422)
    end

    test "driver with a BGC :pending, :charged or, :submitted cannot be charged again", %{
      conn: conn
    } do
      payment_params = %{
        intent_id: nil,
        method_id: "random_method_id"
      }

      post(
        conn,
        Routes.api_v2_driver_background_check_path(conn, :create, ".1"),
        payment_params
      )

      conn =
        post(
          conn,
          Routes.api_v2_driver_background_check_path(conn, :create, ".1"),
          payment_params
        )

      assert %{
               "payment_intent_error" =>
                 "There is an authorization in progress or you have already paid for your background check."
             } = json_response(conn, 422)
    end
  end
end
