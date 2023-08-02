defmodule FraytElixir.CustomContracts.XpressRunTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.CustomContracts.XpressRun
  alias FraytElixir.Shipment.MatchFee

  describe "calculate_pricing" do
    defp build_match(vehicle_class, distance, weight, pieces, origin_state \\ "AL"),
      do:
        insert(:match,
          total_weight: weight,
          vehicle_class: vehicle_class,
          total_distance: distance,
          origin_address: insert(:address, state_code: origin_state),
          fees: [],
          match_stops: [
            build(:match_stop,
              has_load_fee: true,
              distance: 0,
              items: [build(:match_stop_item, weight: ceil(weight / pieces), pieces: pieces)]
            ),
            build(:match_stop,
              has_load_fee: true,
              distance: distance,
              items: [build(:match_stop_item, weight: ceil(weight / pieces), pieces: pieces)]
            )
          ]
        )

    test "with proper parameters" do
      match = build_match(1, 18.5, 99, 1)

      assert %Changeset{valid?: true} =
               changeset =
               match
               |> XpressRun.calculate_pricing()

      assert %{
               driver_cut: 0.75,
               fees: [
                 %MatchFee{type: :base_fee, amount: 3063, driver_amount: 2133},
                 %MatchFee{type: :load_fee, amount: 1500, driver_amount: 1125},
                 %{type: :route_surcharge, amount: 50, driver_amount: 0}
               ],
               match_stops: [
                 %{base_price: 1000, tip_price: 0, driver_cut: 0.75},
                 %{base_price: 2063, tip_price: 0, driver_cut: 0.75}
               ]
             } =
               changeset
               |> Changeset.apply_changes()
    end

    test "with preferred driver fee" do
      driver = insert(:driver)
      match = insert(:match, preferred_driver: driver, platform: :deliver_pro)

      assert %Changeset{valid?: true} = changeset = XpressRun.calculate_pricing(match)

      assert %{
               driver_cut: 0.75,
               fees: [
                 %{
                   type: :base_fee,
                   amount: 3743,
                   driver_amount: 2668
                 },
                 %{
                   type: :preferred_driver_fee,
                   amount: 187,
                   driver_amount: 94
                 }
               ]
             } = Changeset.apply_changes(changeset)
    end
  end
end
