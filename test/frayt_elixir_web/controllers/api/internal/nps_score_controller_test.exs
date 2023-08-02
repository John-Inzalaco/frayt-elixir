defmodule FraytElixirWeb.API.Internal.NpsScoreControllerTest do
  use FraytElixirWeb.ConnCase
  alias FraytElixir.Shipment.{Match}
  alias FraytElixir.Repo
  alias FraytElixir.Rating.NpsScore
  alias FraytElixir.Drivers

  import FraytElixir.Factory
  import FraytElixirWeb.Test.LoginHelper

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "update" do
    setup [:login_as_driver]

    test "should update the score and feedback", %{conn: conn, driver: driver} do
      %Match{match_stops: [stop]} =
        match = insert(:signed_match, match_stops: [build(:signed_match_stop)], driver: driver)

      insert(:match_sla, match: match, driver_id: driver.id)
      insert(:match_sla, match: match, type: :pickup, driver_id: driver.id)
      insert(:match_sla, match: match, type: :delivery, driver_id: driver.id)

      stop = %{stop | match: match}

      {:ok, _, nps_score_id} =
        Drivers.deliver_stop(
          stop,
          %{
            "contents" => "",
            "filename" => ""
          }
        )

      assert Repo.get(NpsScore, nps_score_id)

      conn =
        post(
          conn,
          Routes.api_v2_driver_nps_score_path(conn, :update, ".1", nps_score_id, %{
            score: 5,
            feedback: "abc"
          })
        )

      assert %{"score" => "5", "feedback" => "abc"} == json_response(conn, 201)
    end

    test "feedback is required when score less than 5", %{conn: conn, driver: driver} do
      %Match{match_stops: [stop]} =
        match = insert(:signed_match, match_stops: [build(:signed_match_stop)], driver: driver)

      insert(:match_sla, match: match, driver_id: driver.id)
      insert(:match_sla, match: match, type: :pickup, driver_id: driver.id)
      insert(:match_sla, match: match, type: :delivery, driver_id: driver.id)

      stop = %{stop | match: match}

      {:ok, _, nps_score_id} =
        Drivers.deliver_stop(
          stop,
          %{
            "contents" => "",
            "filename" => ""
          }
        )

      assert Repo.get(NpsScore, nps_score_id)

      conn =
        post(
          conn,
          Routes.api_v2_driver_nps_score_path(conn, :update, ".1", nps_score_id, %{
            score: 4
          })
        )

      assert %{"code" => "invalid_attributes", "message" => "Feedback can't be blank"} ==
               json_response(conn, 422)
    end

    test "feedback is optional when score greater than 5", %{conn: conn, driver: driver} do
      %Match{match_stops: [stop]} =
        match = insert(:signed_match, match_stops: [build(:signed_match_stop)], driver: driver)

      insert(:match_sla, match: match, driver_id: driver.id)
      insert(:match_sla, match: match, type: :pickup, driver_id: driver.id)
      insert(:match_sla, match: match, type: :delivery, driver_id: driver.id)

      stop = %{stop | match: match}

      {:ok, _, nps_score_id} =
        Drivers.deliver_stop(
          stop,
          %{
            "contents" => "",
            "filename" => ""
          }
        )

      assert Repo.get(NpsScore, nps_score_id)

      conn =
        post(
          conn,
          Routes.api_v2_driver_nps_score_path(conn, :update, ".1", nps_score_id, %{
            score: 6
          })
        )

      assert %{"score" => "6", "feedback" => nil} ==
               json_response(conn, 201)
    end

    test "should return an error when driver id doesnt match", %{conn: conn} do
      %Match{match_stops: [stop]} =
        match = insert(:signed_match, match_stops: [build(:signed_match_stop)])

      insert(:match_sla, match: match, driver_id: match.driver.id)
      insert(:match_sla, match: match, type: :pickup, driver_id: match.driver.id)
      insert(:match_sla, match: match, type: :delivery, driver_id: match.driver.id)

      stop = %{stop | match: match}

      {:ok, _, nps_score_id} =
        Drivers.deliver_stop(
          stop,
          %{
            "contents" => "",
            "filename" => ""
          }
        )

      assert Repo.get(NpsScore, nps_score_id)

      conn =
        post(
          conn,
          Routes.api_v2_driver_nps_score_path(conn, :update, ".1", nps_score_id, %{
            score: 6
          })
        )

      assert %{"code" => "not_found", "message" => "Not found"} ==
               json_response(conn, 404)
    end
  end
end
