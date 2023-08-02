defmodule FraytElixir.CustomContracts.StackedTemplateTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.Shipment.MatchFee
  alias FraytElixir.CustomContracts.{StackedTemplate, StackedTemplate.Tier}

  @multi_contract_config %StackedTemplate{
    tiers: [
      lite: %Tier{
        parameters: [weight: 100, pieces: 4],
        per_mile: 100,
        service_level: 1,
        driver_cut: 0.7,
        zones: %{
          10.0 => %{price: 1000, driver_cut: 0.9},
          20.0 => %{price: 1500, driver_cut: 0.8}
        }
      },
      standard: %Tier{
        parameters: [weight: 400, pieces: 16],
        per_mile: 200,
        service_level: 1,
        driver_cut: 0.7,
        zones: %{
          10.0 => %{price: 2000, driver_cut: 0.9},
          20.0 => %{price: 2500, driver_cut: 0.8}
        }
      },
      slow: %Tier{
        parameters: [weight: 100, pieces: 4],
        per_mile: nil,
        service_level: 2,
        driver_cut: 0.7,
        zones: %{
          10.0 => %{price: 500, driver_cut: 0.9},
          20.0 => %{price: 1000, driver_cut: 0.8}
        }
      }
    ],
    stacked_driver_cut: 0.6,
    parameters: [:weight, :pieces],
    state_markup: %{
      "CA" => 0.4
    }
  }

  @weight_contract_config %StackedTemplate{
    tiers: [
      lite: %Tier{
        parameters: [weight: 100],
        per_mile: 100,
        service_level: 1,
        driver_cut: 0.8
      },
      standard: %Tier{
        parameters: [weight: 400],
        per_mile: 200,
        service_level: 1,
        driver_cut: 0.8
      }
    ],
    stacked_driver_cut: 0.7,
    parameters: [:weight]
  }

  @pieces_contract_config %StackedTemplate{
    tiers: [
      lite: %Tier{
        parameters: [pieces: 4],
        per_mile: 100,
        service_level: 1,
        driver_cut: 0.8
      },
      standard: %Tier{
        parameters: [pieces: 16],
        per_mile: 200,
        service_level: 1,
        driver_cut: 0.8
      }
    ],
    stacked_driver_cut: 0.8,
    parameters: [:pieces]
  }

  @unstacked_contract_config %StackedTemplate{
    tiers: [
      lite: %Tier{
        parameters: [pieces: 4],
        per_mile: 100,
        service_level: 1,
        driver_cut: 0.8
      },
      standard: %Tier{
        parameters: [pieces: 16],
        per_mile: 200,
        service_level: 1,
        driver_cut: 0.8
      }
    ],
    parameters: [:pieces],
    stack_tiers?: false
  }

  defp build_match(distance, weight, pieces, origin_state \\ "AL", service_level \\ 1),
    do:
      insert(:match,
        service_level: service_level,
        total_weight: weight,
        total_distance: distance,
        origin_address: insert(:address, state_code: origin_state),
        fees: [],
        match_stops: [
          build(:match_stop,
            has_load_fee: true,
            distance: distance,
            items: [build(:match_stop_item, weight: ceil(weight / pieces), pieces: pieces)]
          )
        ]
      )

  describe "stacked contract" do
    test "with proper parameters" do
      match = build_match(21, 25, 3)

      assert %Changeset{valid?: true} =
               changeset = StackedTemplate.calculate_pricing(match, @multi_contract_config)

      assert %{
               driver_cut: 0.7,
               fees: [
                 %MatchFee{type: :base_fee, amount: 1600}
               ],
               match_stops: [
                 %{base_price: 1600, tip_price: 0, driver_cut: 0.7}
               ]
             } = Changeset.apply_changes(changeset)
    end

    test "stacks base fee when under included miles" do
      match = build_match(20, 1200, 16)

      assert %{
               fees: [%MatchFee{type: :base_fee, amount: 7500}],
               driver_cut: 0.6
             } =
               match
               |> StackedTemplate.calculate_pricing(@multi_contract_config)
               |> Changeset.apply_changes()
    end

    test "stacks base fee over included miles" do
      match = build_match(21, 800, 48)

      assert %{
               fees: [%MatchFee{type: :base_fee, amount: 8100}],
               driver_cut: 0.6
             } =
               match
               |> StackedTemplate.calculate_pricing(@multi_contract_config)
               |> Changeset.apply_changes()
    end

    test "adds tip equal to 40% of base price in CA" do
      match = build_match(20, 1200, 16, "CA")

      assert %{
               match_stops: [
                 %{tip_price: 3000, driver_cut: 0.6}
               ],
               fees: [
                 %MatchFee{type: :base_fee, amount: 7500},
                 %MatchFee{type: :driver_tip, amount: 3000}
               ],
               driver_cut: 0.6
             } =
               match
               |> StackedTemplate.calculate_pricing(@multi_contract_config)
               |> Changeset.apply_changes()
    end

    test "individually calcs multiple stops" do
      match =
        insert(:match,
          total_weight: 1200,
          total_distance: 21,
          origin_address: insert(:address, state_code: "CA"),
          fees: [],
          match_stops: [
            build(:match_stop,
              has_load_fee: true,
              distance: 10,
              items: [build(:match_stop_item, weight: 400, pieces: 1)]
            ),
            build(:match_stop,
              has_load_fee: true,
              distance: 11,
              items: [build(:match_stop_item, weight: 800, pieces: 1)]
            )
          ]
        )

      assert %{
               fees: [
                 %MatchFee{type: :base_fee, amount: 7000},
                 %MatchFee{type: :driver_tip, amount: 2800}
               ],
               match_stops: [
                 %{tip_price: 800, base_price: 2000, driver_cut: 0.9},
                 %{tip_price: 2000, base_price: 5000, driver_cut: 0.6}
               ],
               driver_cut: 0.6857142857142857
             } =
               match
               |> StackedTemplate.calculate_pricing(@multi_contract_config)
               |> Changeset.apply_changes()
    end

    test "uses correct service level" do
      match = build_match(10, 100, 1, "AL", 2)

      assert %{
               fees: [
                 %MatchFee{type: :base_fee, amount: 500}
               ],
               driver_cut: 0.9
             } =
               match
               |> StackedTemplate.calculate_pricing(@multi_contract_config)
               |> Changeset.apply_changes()
    end

    test "fails with no matching service level" do
      match = build_match(10, 100, 1, "AL", 3)

      assert %Changeset{
               valid?: false,
               errors: [service_level: {"is invalid", [validation: :available_service_level]}]
             } = StackedTemplate.calculate_pricing(match, @multi_contract_config)
    end

    test "fails when over mile limit" do
      match = build_match(21, 100, 1, "AL", 2)

      assert %Changeset{
               valid?: false,
               changes: %{
                 match_stops: [stop_changeset]
               }
             } = StackedTemplate.calculate_pricing(match, @multi_contract_config)

      assert %Changeset{
               errors: [
                 distance:
                   {"cannot be over %{limit} miles", [validation: :mile_limit, limit: 20.0]}
               ]
             } = stop_changeset
    end
  end

  describe "weight contract" do
    test "calculates according to weight" do
      match = build_match(10, 100, 1)

      assert %Changeset{valid?: true} =
               changeset = StackedTemplate.calculate_pricing(match, @weight_contract_config)

      assert %{
               driver_cut: 0.8,
               fees: [
                 %MatchFee{type: :base_fee, amount: 1000}
               ],
               match_stops: [
                 %{base_price: 1000, tip_price: 0, driver_cut: 0.8}
               ]
             } = Changeset.apply_changes(changeset)
    end

    test "scales with weight" do
      match = build_match(10, 400, 1)

      assert %Changeset{valid?: true} =
               changeset = StackedTemplate.calculate_pricing(match, @weight_contract_config)

      assert %{
               driver_cut: 0.8,
               fees: [
                 %MatchFee{type: :base_fee, amount: 2000}
               ],
               match_stops: [
                 %{base_price: 2000, tip_price: 0, driver_cut: 0.8}
               ]
             } = Changeset.apply_changes(changeset)
    end
  end

  describe "pieces contract" do
    test "calculates according to pieces" do
      match = build_match(10, 1, 4)

      assert %Changeset{valid?: true} =
               changeset = StackedTemplate.calculate_pricing(match, @pieces_contract_config)

      assert %{
               driver_cut: 0.8,
               fees: [
                 %MatchFee{type: :base_fee, amount: 1000}
               ],
               match_stops: [
                 %{base_price: 1000, tip_price: 0, driver_cut: 0.8}
               ]
             } = Changeset.apply_changes(changeset)
    end

    test "scales with pieces" do
      match = build_match(10, 1, 16)

      assert %Changeset{valid?: true} =
               changeset = StackedTemplate.calculate_pricing(match, @pieces_contract_config)

      assert %{
               driver_cut: 0.8,
               fees: [
                 %MatchFee{type: :base_fee, amount: 2000}
               ],
               match_stops: [
                 %{base_price: 2000, tip_price: 0, driver_cut: 0.8}
               ]
             } = Changeset.apply_changes(changeset)
    end
  end

  describe "unstacked contract" do
    test "calculates according to pieces" do
      match = build_match(10, 1, 4)

      assert %Changeset{valid?: true} =
               changeset = StackedTemplate.calculate_pricing(match, @unstacked_contract_config)

      assert %{
               driver_cut: 0.8,
               fees: [
                 %MatchFee{type: :base_fee, amount: 1000}
               ],
               match_stops: [
                 %{base_price: 1000, tip_price: 0, driver_cut: 0.8}
               ]
             } = Changeset.apply_changes(changeset)
    end

    test "fails when stacking" do
      match = build_match(10, 1, 17)

      assert %Changeset{
               valid?: false,
               errors: [
                 contract:
                   {"is above the pieces limit for this contract",
                    [validation: :available_service_level]}
               ]
             } = StackedTemplate.calculate_pricing(match, @unstacked_contract_config)
    end
  end
end
