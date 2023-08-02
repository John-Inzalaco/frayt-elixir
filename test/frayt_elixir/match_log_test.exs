defmodule FraytElixir.MatchLogTest do
  use FraytElixir.DataCase
  alias FraytElixir.{MatchLog, Matches}
  alias FraytElixir.Shipment.Match

  describe "match log" do
    test "returns correct transitions and hidden matches in proper order" do
      now = DateTime.utc_now()
      match1 = insert(:match, state: :admin_canceled)
      driver = insert(:driver)
      match2 = insert(:match)
      match_state_transition_through_to(:picked_up, match2)

      [%{id: rightid1}, %{id: rightid2}, %{id: rightid3}, %{id: rightid4}] =
        match_state_transition_through_to(:en_route_to_pickup, match1)

      insert(:hidden_match,
        match: match2,
        driver: driver,
        type: "driver_cancellation",
        reason: "Something came up",
        inserted_at: DateTime.add(now, 3600 * 2)
      )

      %{id: rightid5} =
        insert(:hidden_match,
          match: match1,
          driver: driver,
          type: "driver_cancellation",
          reason: "Something came up",
          inserted_at: DateTime.add(now, 3600 * 2)
        )

      %{id: rightid7} =
        insert(:match_state_transition,
          from: :en_route_to_pickup,
          to: :canceled,
          match: match1,
          inserted_at: DateTime.add(now, 3600 * 2 + 60)
        )

      %{id: rightid8} =
        insert(:match_state_transition,
          from: :canceled,
          to: :assigning_driver,
          match: match1,
          inserted_at: DateTime.add(now, 3600 * 2 + 65)
        )

      %{id: rightid9} =
        insert(:match_state_transition,
          from: :assigning_driver,
          to: :accepted,
          match: match1,
          inserted_at: DateTime.add(now, 3600 * 2 + 90)
        )

      %{id: rightid6} =
        insert(:hidden_match,
          match: match1,
          driver: driver,
          type: "driver_cancellation",
          reason: "Something else came up",
          inserted_at: DateTime.add(now, 3600 * 3)
        )

      %{id: rightid10} =
        insert(:match_state_transition,
          from: :accepted,
          to: :canceled,
          match: match1,
          inserted_at: DateTime.add(now, 3600 * 3 + 60)
        )

      %{id: rightid11} =
        insert(:match_state_transition,
          from: :canceled,
          to: :assigning_driver,
          match: match1,
          inserted_at: DateTime.add(now, 3600 * 3 + 65)
        )

      %{id: rightid12} =
        insert(:match_state_transition,
          from: :assigning_driver,
          to: :accepted,
          match: match1,
          inserted_at: DateTime.add(now, 3600 * 3 + 90)
        )

      %{id: rightid13} =
        insert(:match_state_transition,
          from: :accepted,
          to: :admin_canceled,
          match: match1,
          inserted_at: DateTime.add(now, 3600 * 4)
        )

      assert [
               rightid1,
               rightid2,
               rightid3,
               rightid4,
               rightid5,
               rightid7,
               rightid8,
               rightid9,
               rightid6,
               rightid10,
               rightid11,
               rightid12,
               rightid13
             ] ==
               MatchLog.get_match_log(match1)
               |> Enum.filter(fn action -> !Map.get(action, :action, nil) end)
               |> Enum.map(& &1.id)
    end

    test "match log includes edits" do
      match = insert(:match)
      assert {:ok, updated_match} = Matches.update_match(match, %{po: "something new"})

      assert [
               %{action: :created, entity_name: "Origin Address"},
               %{action: :created, entity_name: "Stop Address #" <> _},
               %{action: :created, entity_name: "Stop #" <> _},
               %{action: :created, entity_name: "Base Fee"},
               %{action: :created, entity_name: "Match"},
               %{action: :updated, entity_name: "Match", patch: %{po: _}},
               %{action: :updated, entity_name: "Match", patch: %{timezone: _}},
               %{action: :updated, entity_name: "Stop #" <> _, patch: %{base_price: _}},
               %{action: :updated, entity_name: "Base Fee"},
               %{action: :updated, entity_name: "Match", patch: %{driver_fees: _}},
               %{action: :updated, entity_name: "Match", patch: %{amount_charged: _}}
             ] = MatchLog.get_match_log(updated_match)
    end

    test "match log includes related entity edits" do
      %Match{match_stops: [match_stop]} = match = insert(:match)

      {:ok, %Match{match_stops: [match_stop]} = updated_match} =
        Matches.update_match(
          match,
          %{
            origin_address: "123 happy trail",
            stops: [
              %{
                destination_address: "456 sad road",
                id: match_stop.id
              }
            ],
            vehicle_class: 1,
            service_level: 1
          }
        )

      match_log = MatchLog.get_match_log(updated_match)

      assert match_log
             |> Enum.find(fn action ->
               action.entity_name == "Origin Address" && action.action == :created
             end)

      assert match_log
             |> Enum.find(fn action ->
               action.entity_name =~ "Stop #" && action.action == :created
             end)

      assert match_log
             |> Enum.find(fn action ->
               action.entity_name =~ "Stop Address #" && action.action == :created
             end)

      assert {:ok, updated_match} =
               Matches.update_match(
                 updated_match,
                 %{
                   match_stops: [
                     %{
                       id: match_stop.id,
                       has_load_fee: true,
                       items: [
                         %{
                           id: match_stop.items |> Enum.at(0, %{}) |> Map.get(:id),
                           length: "20",
                           width: "30",
                           height: "50",
                           weight: "400",
                           pieces: "4"
                         }
                       ]
                     }
                   ],
                   vehicle_class: "1",
                   po: "SOME_NEW_PO",
                   service_level: "1"
                 }
               )

      match_log = MatchLog.get_match_log(updated_match)

      assert match_log
             |> Enum.find(fn action ->
               action.entity_name =~ "Stop #" && action.action == :updated
             end)
    end
  end
end
