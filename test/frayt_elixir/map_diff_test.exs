defmodule FraytElixir.MapDiffTest do
  use FraytElixir.DataCase
  alias FraytElixir.MapDiff
  alias MapDiff.Diff

  describe "get_changes" do
    test "gets changes" do
      match =
        insert(:accepted_match,
          state_transitions: [
            build(:match_state_transition, to: :canceled, match: nil),
            build(:match_state_transition, to: :pending, match: nil)
          ],
          tags: [build(:match_tag)]
        )

      new_match =
        match
        |> Map.put(:origin_address, Map.put(match.origin_address, :address, "asjfhasdf"))
        |> Map.put(:driver, nil)
        |> Map.put(:state, :completed)
        |> Map.put(:match_stops, [])
        |> Map.put(
          :state_transitions,
          Enum.map(match.state_transitions, &Map.put(&1, :to, :pending))
        )
        |> Map.put(
          :tags,
          Enum.map(match.tags, &Map.put(&1, :name, nil)) ++ [build(:match_tag)]
        )

      assert %{
               origin_address: %{address: %Diff{n: "asjfhasdf"}},
               match_stops: %Diff{n: []},
               driver: %Diff{n: nil},
               state: %Diff{n: :completed, o: :accepted},
               state_transitions: [%{to: %Diff{n: :pending}}, %{}],
               tags: %Diff{n: [_, _]}
             } = MapDiff.get_changes(match, new_match)
    end

    test "no changes returns empty match" do
      match = insert(:accepted_match)

      assert %{} = MapDiff.get_changes(match, match)
    end
  end

  describe "get_changed_keys" do
    test "gets changed keys" do
      match =
        insert(:accepted_match,
          state_transitions: [
            build(:match_state_transition, to: :canceled, match: nil),
            build(:match_state_transition, to: :pending, match: nil)
          ],
          tags: [build(:match_tag)]
        )

      new_match =
        match
        |> Map.put(:origin_address, Map.put(match.origin_address, :address, "asjfhasdf"))
        |> Map.put(:driver, nil)
        |> Map.put(:match_stops, [])
        |> Map.put(:state, :completed)
        |> Map.put(
          :state_transitions,
          Enum.map(match.state_transitions, &Map.put(&1, :to, :pending))
        )
        |> Map.put(
          :tags,
          Enum.map(match.tags, &Map.put(&1, :name, nil)) ++ [build(:match_tag)]
        )

      assert [
               driver: nil,
               match_stops: nil,
               origin_address: [address: nil],
               state: nil,
               state_transitions: [[to: nil], nil],
               tags: nil
             ] = MapDiff.get_changed_keys(match, new_match)
    end
  end

  describe "has_changed" do
    test "checks if keys are changed" do
      match =
        insert(:accepted_match,
          state_transitions: [
            build(:match_state_transition, to: :canceled, match: nil),
            build(:match_state_transition, to: :pending, match: nil)
          ],
          tags: [build(:match_tag)]
        )

      new_match =
        match
        |> Map.put(:origin_address, Map.put(match.origin_address, :address, "asjfhasdf"))
        |> Map.put(:driver, nil)
        |> Map.put(:match_stops, [])
        |> Map.put(:state, :completed)
        |> Map.put(
          :state_transitions,
          Enum.map(match.state_transitions, &Map.put(&1, :to, :pending))
        )
        |> Map.put(
          :tags,
          Enum.map(match.tags, &Map.put(&1, :name, nil)) ++ [build(:match_tag)]
        )

      assert MapDiff.has_changed(match, new_match, state_transitions: :to) == true

      assert MapDiff.has_changed(match, new_match,
               match_stops: :destination_address,
               origin_address: []
             ) == true

      assert MapDiff.has_changed(match, new_match, origin_address: [:address]) == true
      assert MapDiff.has_changed(match, new_match, :driver) == true
      assert MapDiff.has_changed(match, new_match, :match_stops) == true
      refute MapDiff.has_changed(match, new_match, match_stops: :destination_address)
      refute MapDiff.has_changed(match, new_match, :shipper)
      refute MapDiff.has_changed(match, new_match, state_transitions: :from)
    end

    test "checks if list was changed" do
      match =
        insert(:accepted_match,
          state_transitions: [
            build(:match_state_transition, to: :canceled, match: nil),
            build(:match_state_transition, to: :pending, match: nil)
          ]
        )

      new_match =
        match
        |> Map.put(:match_stops, [])
        |> Map.put(
          :state_transitions,
          Enum.map(match.state_transitions, &Map.put(&1, :to, :pending))
        )

      assert MapDiff.has_changed(match, new_match, state_transitions: [])
      refute MapDiff.has_changed(match, new_match, state_transitions: nil)
      assert MapDiff.has_changed(match, new_match, match_stops: nil)
      refute MapDiff.has_changed(match, new_match, match_stops: [])

      assert MapDiff.has_changed(match, new_match,
               match_stops: :destination_address,
               match_stops: nil
             )

      assert MapDiff.has_changed(match, new_match,
               state_transitions: nil,
               state_transitions: :to
             )
    end
  end
end
