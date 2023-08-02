defmodule FraytElixirWeb.API.Internal.MatchViewTest do
  use FraytElixirWeb.ConnCase, async: true
  alias FraytElixirWeb.API.Internal.MatchView
  alias FraytElixir.Shipment.Match

  import FraytElixir.Factory

  describe "index.json" do
    test "returns matches" do
      matches = insert_list(3, :match)
      assert %{response: [%{}, %{}, %{}]} = MatchView.render("index.json", matches: matches)
    end

    test "returns matches and page count " do
      matches = insert_list(3, :match)

      assert %{response: [%{}, %{}, %{}], page_count: 1} =
               MatchView.render("index.json", matches: matches, page_count: 1)
    end
  end

  describe "match.json" do
    test "rendered match returns correct values" do
      origin_address = insert(:address, geo_location: chris_house_point())
      destination_address = insert(:address, geo_location: findlay_market_point())

      %Match{
        id: id,
        sender_id: sender_id,
        total_distance: distance,
        dropoff_at: dropoff_at,
        pickup_at: pickup_at,
        inserted_at: inserted_at,
        po: po,
        shortcode: shortcode
      } =
        match =
        insert(:match,
          origin_address: origin_address,
          origin_photo: %{file_name: "origin_photo.png", updated_at: DateTime.utc_now()},
          bill_of_lading_photo: %{
            file_name: "bill_of_lading_photo.png",
            updated_at: DateTime.utc_now()
          },
          match_stops: [
            build(:match_stop,
              destination_address: destination_address,
              signature_photo: %{file_name: "signature_photo.png", updated_at: DateTime.utc_now()},
              destination_photo: %{
                file_name: "destination_photo.png",
                updated_at: DateTime.utc_now()
              }
            )
          ],
          vehicle_class: 2,
          service_level: 2,
          unload_method: :lift_gate,
          sender: insert(:contact),
          self_sender: false,
          fees: [
            build(:match_fee, type: :base_fee, amount: 10_00),
            build(:match_fee, type: :lift_gate_fee, amount: 50_00, description: "lift gatey thing")
          ]
        )

      transitions = match_state_transition_through_to(:charged, match)

      insert(:match_state_transition,
        to: :assigning_driver,
        inserted_at: ~N[2000-01-02 12:23:43],
        match: match
      )

      insert(:match_state_transition,
        to: :accepted,
        inserted_at: ~N[2000-01-02 12:25:43],
        match: match
      )

      insert(:match_state_transition,
        to: :picked_up,
        inserted_at: ~N[2000-01-02 12:45:43],
        match: match
      )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2000-01-02 12:59:43],
        match: match
      )

      activated_at = Enum.find(transitions, &(&1.to == :assigning_driver)).inserted_at
      accepted_at = Enum.find(transitions, &(&1.to == :accepted)).inserted_at
      picked_up_at = Enum.find(transitions, &(&1.to == :picked_up)).inserted_at
      completed_at = Enum.find(transitions, &(&1.to == :completed)).inserted_at

      rendered_match = MatchView.render("match.json", %{match: match})

      assert %{
               accepted_at: ^accepted_at,
               activated_at: ^activated_at,
               bill_of_lading_photo: "some_url",
               completed_at: ^completed_at,
               total_distance: ^distance,
               driver: %{},
               dropoff_at: ^dropoff_at,
               id: ^id,
               identifier: nil,
               canceled_at: nil,
               cancel_reason: nil,
               inserted_at: ^inserted_at,
               origin_address: rendered_origin_address,
               origin_photo: "some_url",
               picked_up_at: ^picked_up_at,
               pickup_at: ^pickup_at,
               pickup_notes: nil,
               po: ^po,
               scheduled: false,
               service_level: 2,
               shortcode: ^shortcode,
               state: :assigning_driver,
               vehicle_class: 2,
               unload_method: :lift_gate,
               sender: %{
                 id: ^sender_id
               },
               market: nil,
               self_sender: false,
               fees: [
                 %{
                   type: :base_fee,
                   amount: 10_00
                 },
                 %{
                   description: "lift gatey thing",
                   type: :lift_gate_fee,
                   amount: 50_00
                 }
               ]
             } = rendered_match

      assert rendered_origin_address[:formatted_address] == origin_address.formatted_address
    end
  end
end
