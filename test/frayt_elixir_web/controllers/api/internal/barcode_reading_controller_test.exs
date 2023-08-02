defmodule FraytElixirWeb.API.Internal.BarcodeReadingControllerTest do
  use FraytElixirWeb.ConnCase
  alias FraytElixirWeb.Test.FileHelper

  describe "create barcode_reading" do
    setup [:login_as_driver]

    test "renders barcode_reading when data is invalid", %{conn: conn, driver: driver} do
      match =
        insert(:match,
          driver: driver,
          match_stops: [build(:match_stop, items: [build(:match_stop_item_with_barcode)])]
        )

      match_id = match.id
      match_stop = Map.get(match, :match_stops) |> List.first()
      item = Map.get(match_stop, :items) |> List.first()

      attrs = %{
        barcode: "123barcode456",
        type: :wrong_type,
        state: :captured
      }

      conn =
        post(
          conn,
          Routes.api_v2_driver_match_stop_item_barcode_reading_path(
            conn,
            :create,
            ".1",
            match_id,
            match_stop.id,
            item.id
          ),
          attrs
        )

      assert %{"code" => "invalid_attributes"} = json_response(conn, 422)
    end

    test "renders barcode_reading when data is missing", %{conn: conn} do
      match =
        insert(:match,
          match_stops: [build(:match_stop, items: [build(:match_stop_item_with_barcode)])]
        )

      match_id = match.id
      match_stop = Map.get(match, :match_stops) |> List.first()
      item = Map.get(match_stop, :items) |> List.first()
      attrs = %{}

      conn =
        post(
          conn,
          Routes.api_v2_driver_match_stop_item_barcode_reading_path(
            conn,
            :create,
            ".1",
            match_id,
            match_stop.id,
            item.id
          ),
          attrs
        )

      assert %{"code" => "invalid_attributes"} = json_response(conn, 422)
    end

    test "renders barcode_reading when data is valid", %{conn: conn} do
      match =
        insert(:match,
          match_stops: [build(:match_stop, items: [build(:match_stop_item_with_barcode)])]
        )

      match_id = match.id
      match_stop = Map.get(match, :match_stops) |> List.first()
      item = Map.get(match_stop, :items) |> List.first()

      attrs = %{
        barcode: "123barcode456",
        type: :pickup,
        state: :captured
      }

      conn =
        post(
          conn,
          Routes.api_v2_driver_match_stop_item_barcode_reading_path(
            conn,
            :create,
            ".1",
            match_id,
            match_stop.id,
            item.id
          ),
          attrs
        )

      assert json_response(conn, 201)
    end

    test "renders when creating missing barcode", %{conn: conn} do
      match =
        insert(:match,
          match_stops: [build(:match_stop, items: [build(:match_stop_item_with_barcode)])]
        )

      match_id = match.id
      match_stop = Map.get(match, :match_stops) |> List.first()
      item = Map.get(match_stop, :items) |> List.first()

      attrs = %{
        barcode: nil,
        type: :pickup,
        state: :missing,
        photo: FileHelper.base64_image()
      }

      conn =
        post(
          conn,
          Routes.api_v2_driver_match_stop_item_barcode_reading_path(
            conn,
            :create,
            ".1",
            match_id,
            match_stop.id,
            item.id
          ),
          attrs
        )

      assert json_response(conn, 201)
    end
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end
end
