defmodule FraytElixir.Shipment.MatchStateTest do
  use FraytElixir.DataCase

  alias FraytElixir.Shipment.MatchState

  test "range lists all states in between the two provided states" do
    state1 = :assigning_driver
    state2 = :picked_up
    range = MatchState.range(state1, state2)

    assert Enum.all?(range, fn state ->
             Enum.member?(
               [
                 :assigning_driver,
                 :accepted,
                 :en_route_to_pickup,
                 :arrived_at_pickup,
                 :picked_up
               ],
               state
             )
           end)

    assert range |> Enum.uniq() |> Enum.count() == 5
  end

  test "is_live/1 is true if your state is in the list of live match states" do
    state = :arrived_at_pickup
    assert MatchState.is_live?(state)
  end

  test "is_live/1 is false if your state is not in the list of live match states" do
    state = :assigning_driver
    refute MatchState.is_live?(state)
  end

  test "live_range/0 should give a list of live match states" do
    assert [
             :accepted,
             :en_route_to_pickup,
             :arrived_at_pickup,
             :picked_up,
             :en_route_to_return,
             :arrived_at_return,
             :unable_to_pickup
           ] = MatchState.live_range()
  end
end
