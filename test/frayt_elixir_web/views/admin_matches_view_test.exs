defmodule FraytElixirWeb.MatchesViewTest do
  use FraytElixirWeb.ConnCase, async: true
  import FraytElixirWeb.Admin.MatchesView
  import FraytElixir.Factory

  test "check_circle" do
    match = insert(:canceled_match)
    assert check_circle(match, :pending) == "circle--open"
    match = insert(:picked_up_match)
    assert check_circle(match, :picked_up) == "circle--checked"
  end

  test "timestamp" do
    match =
      insert(:match,
        state: "picked_up",
        state_transitions: [
          FraytElixir.Repo.insert!(%FraytElixir.Shipment.MatchStateTransition{
            from: "arrived_at_pickup",
            to: "picked_up",
            inserted_at: ~N[2000-01-01 23:00:07]
          })
        ]
      )

    assert timestamp(match.state, match.state_transitions, :picked_up, "UTC") != nil

    assert timestamp(match.state, match.state_transitions, :completed, "UTC") == nil

    assert timestamp(:charged, match.state_transitions, :completed, "UTC") == nil
  end

  test "find_transition" do
    transitions = [
      %{from: :pending, to: :assigning_driver, inserted_at: ~N[2016-04-16 13:30:15]},
      %{from: :assigning_driver, to: :accepted, inserted_at: ~N[2016-04-16 13:30:15]},
      %{from: :pending, to: :assigning_driver, inserted_at: ~N[2016-04-17 13:30:15]},
      %{from: :accepted, to: :en_route_to_pickup, inserted_at: ~N[2016-04-16 13:30:15]},
      %{from: :en_route_to_pickup, to: :arrived_at_pickup, inserted_at: ~N[2016-04-16 13:30:15]},
      %{from: :pending, to: :assigning_driver, inserted_at: ~N[2016-04-15 13:30:15]},
      %{from: :arrived_at_pickup, to: :picked_up, inserted_at: ~N[2016-04-16 13:30:15]}
    ]

    assert find_transition(transitions, 3) == %{
             from: :pending,
             to: :assigning_driver,
             inserted_at: ~N[2016-04-17 13:30:15]
           }

    assert find_transition(transitions, 4) == %{
             from: :assigning_driver,
             to: :accepted,
             inserted_at: ~N[2016-04-16 13:30:15]
           }

    assert find_transition(transitions, 5) == %{
             from: :accepted,
             to: :en_route_to_pickup,
             inserted_at: ~N[2016-04-16 13:30:15]
           }

    assert find_transition(transitions, :en_route_to_pickup) == %{
             from: :accepted,
             to: :en_route_to_pickup,
             inserted_at: ~N[2016-04-16 13:30:15]
           }

    assert find_transition(transitions, 9) == nil
  end

  test "time_between" do
    match =
      insert(:match,
        state: :accepted,
        state_transitions: [
          %{from: :pending, to: :assigning_driver, inserted_at: ~N[2014-10-02 07:23:12]},
          %{from: :assigning_driver, to: :accepted, inserted_at: ~N[2014-10-02 07:29:12]},
          %{from: :accepted, to: :en_route_to_pickup, inserted_at: ~N[2014-10-02 07:33:12]},
          %{
            from: :en_route_to_pickup,
            to: :arrived_at_pickup,
            inserted_at: ~N[2014-10-02 07:29:12]
          },
          %{from: :arrived_at_pickup, to: :picked_up, inserted_at: ~N[2014-10-02 07:29:12]}
        ]
      )

    assert time_between(match, :assigning_driver, :accepted) == 360

    assert time_between(
             %{match | scheduled: false, inserted_at: ~N[2014-10-02 07:22:12]},
             :pending,
             :scheduled
           ) == 60

    assert time_between(match, :accepted, :en_route_to_pickup) == nil
    assert time_between(%{match | state: :picked_up}, :accepted, :en_route_to_pickup) == 240

    assert time_between(match, :picked_up, :completed) == nil
    assert time_between(%{match | state: :charged}, :picked_up, :completed) == nil
  end

  test "monthly_or_daily/3" do
    assert monthly_or_daily("monthly", "first", "second") == "first"
    assert monthly_or_daily("daily", "first", "second") == "second"
  end

  describe "page content" do
    setup [:login_as_admin]

    test "cancel button shows", %{conn: conn} do
      match = insert(:match, driver: nil, state: "assigning_driver", shortcode: "KDI35OSI")
      match_state_transition_through_to(:assigning_driver, match)

      conn = get(conn, "/admin/matches/#{match.id}")
      assert html_response(conn, 200) =~ "Cancel Match"
      refute html_response(conn, 200) =~ "Match Canceled"

      assert html_response(conn, 200) =~
               "Match ##{"KDI35OSI"}"
    end

    test "no cancel button for canceled matches; displays Match Canceled instead of Match MatchID",
         %{conn: conn} do
      match = insert(:match, state: "canceled", shortcode: "KJ43DI34")
      match_state_transition_through_to(:canceled, match)

      conn = get(conn, "/admin/matches/#{match.id}")
      refute html_response(conn, 200) =~ "Cancel Match"

      assert html_response(conn, 200) =~
               "Match ##{"KJ43DI34"} Canceled"

      refute html_response(conn, 200) =~
               "Match ##{"KJ43DI34"}</h3>"
    end

    test "no cancel button for charged matches", %{conn: conn} do
      match = insert(:match, state: "charged")
      match_state_transition_through_to(:charged, match)

      conn = get(conn, "/admin/matches/#{match.id}")
      refute html_response(conn, 200) =~ "Cancel Match"
    end

    test "renew button shows", %{conn: conn} do
      match = insert(:match, state: "canceled", shortcode: "KJ43DI34")
      match_state_transition_through_to(:canceled, match)

      conn = get(conn, "/admin/matches/#{match.id}")
      assert html_response(conn, 200) =~ "Renew Match"
    end

    test "renew button does not show for delivered", %{conn: conn} do
      match = insert(:completed_match, shortcode: "KJ43DI34")
      match_state_transition_through_to(:completed, match)

      conn = get(conn, "/admin/matches/#{match.id}")
      refute html_response(conn, 200) =~ "Renew Match"
    end
  end
end
