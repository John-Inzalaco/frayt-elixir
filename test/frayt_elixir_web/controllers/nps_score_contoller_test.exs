defmodule FraytElixirWeb.NpsScoreContollerTest do
  use FraytElixirWeb.ConnCase
  use Bamboo.Test

  alias FraytElixir.Repo
  alias FraytElixir.Rating
  alias FraytElixir.Shipment.MatchWorkflow
  import FraytElixir.Test.StartMatchSupervisor
  import FraytElixir.Test.WebhookHelper

  describe "when score is less than 5" do
    setup do
      nps_score = insert(:nps_score) |> Repo.preload(user: [:shipper])
      %{nps_score: nps_score}
    end

    test "feedback field is required", %{conn: conn, nps_score: nps_score} do
      conn =
        post(
          conn,
          Routes.nps_score_path(conn, :update, nps_score.user.shipper.id, nps_score.id, score: 3)
        )

      assert %{"code" => "invalid_attributes", "message" => "Feedback can't be blank"} =
               json_response(conn, 422)
    end

    test "feedback is saved", %{conn: conn, nps_score: nps_score} do
      post(
        conn,
        Routes.nps_score_path(conn, :update, nps_score.user.shipper.id, nps_score.id,
          score: 3,
          feedback: "gibberish"
        )
      )

      assert %{feedback: "gibberish", score: 3} = Rating.get_nps_score(nps_score.id)
    end
  end

  describe "when score is greater than 5" do
    setup do
      nps_score = insert(:nps_score) |> Repo.preload(user: [:shipper])
      %{nps_score: nps_score}
    end

    test "feedback field isnt required", %{conn: conn, nps_score: nps_score} do
      conn =
        post(
          conn,
          Routes.nps_score_path(conn, :update, nps_score.user.shipper.id, nps_score.id, score: 5)
        )

      assert html_response(conn, 200) =~
               "We value your feedback, and are looking forward to delivering terrific experience to you!"
    end

    test "feedback is saved", %{conn: conn, nps_score: nps_score} do
      post(
        conn,
        Routes.nps_score_path(conn, :update, nps_score.user.shipper.id, nps_score.id,
          score: 5,
          feedback: "gibberish"
        )
      )

      assert %{feedback: "gibberish", score: 5} = Rating.get_nps_score(nps_score.id)
    end
  end

  describe "email" do
    setup do
      Ecto.Adapters.SQL.Sandbox.mode(Repo, :auto)
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
      start_match_webhook_sender(self())
    end

    setup :start_match_supervisor

    test "should be sent on first delivery of the month" do
      %{match_stops: [match_stop | _]} = insert(:arrived_at_dropoff_match)
      match_stop = match_stop |> Repo.preload(match: :driver)
      {:ok, match} = MatchWorkflow.sign_for_stop(match_stop)
      [match_stop | _] = match.match_stops
      match_stop = match_stop |> Repo.preload(match: :driver)
      MatchWorkflow.deliver_stop(match_stop)
      [nps_score | _] = FraytElixir.Rating.NpsScore |> Repo.all()

      expected_email =
        FraytElixir.Email.nps_score_email(%{
          email: match.shipper.user.email,
          name: match.shipper.first_name,
          shipper_id: match.shipper.id,
          nps_score_id: nps_score.id
        })

      assert_delivered_email(expected_email)
    end

    test "should not be sent if not the first delivery of the month" do
      %{driver: driver, shipper: shipper, match_stops: [match_stop | _]} =
        insert(:arrived_at_dropoff_match)

      match_stop = match_stop |> Repo.preload(match: :driver)
      {:ok, match} = MatchWorkflow.sign_for_stop(match_stop)
      [match_stop | _] = match.match_stops
      match_stop = match_stop |> Repo.preload(match: :driver)
      MatchWorkflow.deliver_stop(match_stop)

      %{match_stops: [match_stop | _]} =
        insert(:arrived_at_dropoff_match, driver: driver, shipper: shipper)

      match_stop = match_stop |> Repo.preload(match: :driver)
      {:ok, match} = MatchWorkflow.sign_for_stop(match_stop)
      [match_stop | _] = match.match_stops
      match_stop = match_stop |> Repo.preload(match: :driver)
      MatchWorkflow.deliver_stop(match_stop)

      assert 1 == FraytElixir.Rating.NpsScore |> Repo.all() |> Enum.count()
    end
  end
end
