defmodule FraytElixir.CustomContracts.SherwinSameDayTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.CustomContracts.SherwinSameDay

  describe "calculate_pricing" do
    test "flat $20 for same day car under 10 miles" do
      match =
        insert(:match,
          vehicle_class: 1,
          service_level: 2,
          match_stops: [build(:match_stop, distance: 5)]
        )

      assert %Changeset{valid?: true} = changeset = SherwinSameDay.calculate_pricing(match)

      assert %{
               driver_cut: 0.8,
               fees: [
                 %{type: :base_fee, amount: 1800, driver_amount: 1357}
               ]
             } = Changeset.apply_changes(changeset)
    end
  end
end
