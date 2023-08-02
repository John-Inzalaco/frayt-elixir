defmodule FraytElixir.Shipment.MatchStopStateTest do
  use FraytElixir.DataCase

  alias FraytElixir.Shipment.MatchStopState

  test "range lists all states in between the two provided states" do
    state1 = :pending
    state2 = :signed
    range = MatchStopState.range(state1, state2)

    assert Enum.all?(range, fn state ->
             Enum.member?(
               [
                 :pending,
                 :en_route,
                 :arrived,
                 :signed
               ],
               state
             )
           end)

    assert range |> Enum.uniq() |> Enum.count() == 4
  end

  test "is_live/1 is true if your state is in the list of live match stop states" do
    state = :arrived
    assert MatchStopState.is_live?(state)
  end

  test "is_live/1 is false if your state is not in the list of live match stop states" do
    state = :pending
    refute MatchStopState.is_live?(state)
  end

  test "live_range/0 should give a list of live match stop states" do
    assert [
             :en_route,
             :arrived,
             :signed
           ] = MatchStopState.live_range()
  end

  test "completed_range/0 should give a list of completed match stop states" do
    assert [:delivered, :undeliverable] = MatchStopState.completed_range()
  end
end
