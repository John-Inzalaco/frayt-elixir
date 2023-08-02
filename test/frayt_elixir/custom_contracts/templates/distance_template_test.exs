defmodule FraytElixir.CustomContracts.DistanceTemplateTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.CustomContracts.DistanceTemplate
  alias DistanceTemplate.{LevelTier, DistanceTier}

  @basic_config %DistanceTemplate{
    level_type: :none,
    tiers: [
      %LevelTier{
        default: %DistanceTier{
          base_price: 10_00,
          base_distance: 10,
          driver_cut: 0.75
        }
      }
    ]
  }

  @distance_config %DistanceTemplate{
    level_type: :distance,
    tiers: [
      %LevelTier{
        default: %DistanceTier{
          base_price: 10_00,
          base_distance: 5,
          driver_cut: 0.75
        }
      },
      %LevelTier{
        default: %DistanceTier{
          base_price: 20_00,
          base_distance: 10,
          price_per_mile: 1_00,
          driver_cut: 0.85,
          per_mile_tapering: %{
            20 => 1_35,
            30 => 1_45,
            40 => 1_50,
            50 => 1_75
          }
        }
      }
    ]
  }

  @vc_config %DistanceTemplate{
    level_type: :vehicle_class,
    tiers: [
      car: %LevelTier{
        first: %DistanceTier{
          base_price: 20_00,
          price_per_mile: 1_00,
          base_distance: 10,
          driver_cut: 0.75
        },
        default: %DistanceTier{
          base_price: 10_00,
          price_per_mile: 1_50,
          base_distance: 5,
          driver_cut: 0.75
        }
      },
      midsize: %LevelTier{
        default: %DistanceTier{
          base_price: 20_00,
          price_per_mile: 2_00,
          base_distance: 10,
          driver_cut: 0.85
        }
      },
      cargo_van: %LevelTier{
        first:
          {2,
           %DistanceTier{
             base_price: 20_00,
             price_per_mile: 1_00,
             base_distance: 10,
             driver_cut: 0.75
           }},
        default: %DistanceTier{
          base_price: 10_00,
          price_per_mile: 1_50,
          base_distance: 5,
          driver_cut: 0.75
        }
      }
    ]
  }

  @scheduled_config %DistanceTemplate{
    level_type: {:scheduled, [schedule_buffer: 1 * 60 * 60]},
    tiers: [
      dash: %LevelTier{
        default: %DistanceTier{
          base_price: 10_00,
          price_per_mile: 1_50,
          base_distance: 10,
          driver_cut: 0.75,
          markup: 1.1
        }
      },
      scheduled: %LevelTier{
        default: %DistanceTier{
          base_price: 20_00,
          price_per_mile: 2_00,
          base_distance: 10,
          driver_cut: 0.75
        }
      }
    ]
  }

  @tapered_w_limit_config %DistanceTemplate{
    level_type: :distance,
    tiers: [
      %LevelTier{
        default: %DistanceTier{
          price_per_mile: nil,
          base_price: 23_00,
          base_distance: 10,
          driver_cut: 0.75,
          max_weight: 100,
          max_volume: 21_952,
          per_mile_tapering: %{
            49 => 1_35,
            150 => 1_08
          }
        }
      }
    ]
  }

  @tapered_no_limit_config %DistanceTemplate{
    level_type: :distance,
    tiers: [
      %LevelTier{
        default: %DistanceTier{
          base_price: 25_00,
          price_per_mile: 1_02,
          base_distance: 10,
          driver_cut: 0.75,
          max_weight: 100,
          max_volume: 21_952,
          per_mile_tapering: %{
            49 => 1_60,
            150 => 1_28
          }
        }
      }
    ]
  }

  @default_tip_config %DistanceTemplate{
    level_type: :none,
    tiers: [
      %LevelTier{
        first: %DistanceTier{
          price_per_mile: 1_50,
          base_price: 25_00,
          markup: 1.0,
          max_weight: 20,
          base_distance: 5,
          driver_cut: 0.75,
          default_tip: 2_00
        },
        default: %DistanceTier{
          price_per_mile: 1_50,
          base_price: 15_00,
          markup: 1.0,
          max_weight: 20,
          base_distance: 5,
          driver_cut: 0.75,
          default_tip: 0
        }
      }
    ]
  }

  @fees_config %DistanceTemplate{
    @distance_config
    | fees: [
        load_fee: %{
          250 => {24_99, 18_74},
          1000 => {44_99, 33_74}
        },
        route_surcharge: {50, 0},
        holiday_fee: {100_00, 75_00},
        lift_gate_fee: {30_00, 22_50},
        return_charge: 0.50,
        preferred_driver_fee: 0.15,
        toll_fees: true
      ]
  }

  defp apply_and_order(changeset) do
    m = Changeset.apply_changes(changeset)

    %{
      m
      | match_stops: Enum.sort_by(m.match_stops, & &1.index, :asc),
        fees: Enum.sort_by(m.fees, & &1.type, :asc)
    }
  end

  describe "distance type" do
    test "uses travel distance to select tier and per_mile" do
      match =
        insert(:match,
          match_stops: [
            insert(:match_stop, index: 0, distance: 5),
            insert(:match_stop, index: 1, distance: 12)
          ]
        )

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @distance_config)

      assert %{
               fees: [
                 %{type: :base_fee, amount: 32_70}
               ],
               match_stops: [
                 %{index: 0, base_price: 10_00},
                 %{index: 1, base_price: 22_70}
               ]
             } = apply_and_order(changeset)
    end

    test "when set to :radius_from_origin use radial distance to select tier and per_mile" do
      match =
        insert(:match,
          origin_address: build(:address, geo_location: gaslight_point()),
          match_stops: [
            insert(:match_stop,
              index: 0,
              distance: 1,
              radial_distance: 2,
              destination_address: build(:address, geo_location: findlay_market_point())
            ),
            insert(:match_stop,
              index: 1,
              distance: 1,
              radial_distance: 20,
              destination_address: build(:address, geo_location: wilmington_point())
            )
          ]
        )

      assert %Changeset{valid?: true} =
               changeset =
               DistanceTemplate.calculate_pricing(match, %{
                 @distance_config
                 | distance_type: :radius_from_origin
               })

      assert %{
               fees: [
                 %{type: :base_fee, amount: 43_50}
               ],
               match_stops: [
                 %{index: 0, base_price: 10_00},
                 %{index: 1, base_price: 33_50}
               ]
             } = apply_and_order(changeset)
    end
  end

  describe "no levels distance template" do
    test "calculates pricing" do
      match =
        insert(:match,
          origin_address: insert(:address, state_code: "PA"),
          match_stops: [build(:match_stop, distance: 5, index: 0)]
        )

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @basic_config)

      assert %{
               driver_cut: 0.75,
               fees: [
                 %{type: :base_fee, amount: 10_00}
               ]
             } = apply_and_order(changeset)
    end

    test "fails when over base_distance with no per_mile" do
      match = insert(:match, match_stops: [build(:match_stop, distance: 15, index: 0)])

      assert %Changeset{valid?: false, changes: %{match_stops: [changeset]}} =
               DistanceTemplate.calculate_pricing(match, @basic_config)

      assert %Changeset{
               valid?: false,
               errors: [
                 distance: {"cannot be over %{limit} miles", [validation: :mile_limit, limit: 10]}
               ]
             } = changeset
    end
  end

  describe "distance template" do
    test "calculates pricing" do
      match = insert(:match, match_stops: [build(:match_stop, distance: 5, index: 0)])

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @distance_config)

      assert %{
               driver_cut: 0.75,
               fees: [
                 %{type: :base_fee, amount: 10_00}
               ]
             } = apply_and_order(changeset)
    end

    test "uses higher tier for higher distance" do
      match = insert(:match, match_stops: [build(:match_stop, distance: 7, index: 0)])

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @distance_config)

      assert %{
               driver_cut: 0.85,
               fees: [
                 %{type: :base_fee, amount: 20_00}
               ]
             } = apply_and_order(changeset)
    end

    test "uses per mile for over max distance" do
      match = insert(:match, match_stops: [build(:match_stop, distance: 60, index: 0)])

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @distance_config)

      assert %{
               driver_cut: 0.85,
               fees: [
                 %{type: :base_fee, amount: 90_50}
               ]
             } = apply_and_order(changeset)
    end

    test "Add tip_price when zero tip included" do
      match =
        insert(:match,
          total_weight: 10,
          match_stops: [
            build(:match_stop, distance: 5, tip_price: 0, index: 0)
          ]
        )

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @default_tip_config)

      assert %{
               driver_cut: 0.75,
               fees: [
                 %{type: :base_fee, amount: 25_00},
                 %{type: :driver_tip, amount: 2_00}
               ]
             } = apply_and_order(changeset)
    end

    test "when zero tip included a default_tip is added on the first stop only" do
      match =
        insert(:match,
          total_weight: 10,
          match_stops: [
            build(:match_stop, distance: 5, tip_price: 0, index: 0),
            build(:match_stop, distance: 5, tip_price: 0, index: 1)
          ]
        )

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @default_tip_config)

      assert %{
               driver_cut: 0.75,
               fees: [
                 %{type: :base_fee, amount: 40_00},
                 %{type: :driver_tip, amount: 2_00}
               ]
             } = apply_and_order(changeset)
    end

    test "Add tip_price when tip included" do
      match =
        insert(:match,
          total_weight: 10,
          match_stops: [
            build(:match_stop, distance: 5, tip_price: 10_00, index: 0)
          ]
        )

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @default_tip_config)

      assert %{
               driver_cut: 0.75,
               fees: [
                 %{type: :base_fee, amount: 25_00},
                 %{type: :driver_tip, amount: 10_00}
               ]
             } = apply_and_order(changeset)
    end
  end

  describe "weight + volume cap for" do
    @cargo_config %DistanceTemplate{
      level_type: :none,
      tiers: [
        %LevelTier{
          first: %DistanceTier{
            base_price: 25_00,
            max_weight: 20,
            max_volume: 20,
            base_distance: 50,
            driver_cut: 0.75
          },
          default: %DistanceTier{
            base_price: 15_00,
            max_item_weight: 20,
            base_distance: 50,
            driver_cut: 0.75
          }
        }
      ]
    }

    test "max_weight can't be more than 20 lbs" do
      match =
        insert(:match,
          total_weight: 21,
          total_volume: 20,
          match_stops: [build(:match_stop, distance: 5, index: 0)]
        )

      assert %Changeset{
               valid?: false,
               errors: [
                 total_weight:
                   {"cannot be over %{limit} lbs total", [validation: :max_weight, limit: 20]}
               ]
             } = DistanceTemplate.calculate_pricing(match, @cargo_config)

      match =
        insert(:match,
          total_weight: 20,
          total_volume: 20,
          match_stops: [build(:match_stop, distance: 5, index: 0)]
        )

      assert %Changeset{valid?: true} = DistanceTemplate.calculate_pricing(match, @cargo_config)
    end

    test "max_volume can't be more than 20 cubic ft" do
      match =
        insert(:match,
          total_weight: 20,
          total_volume: 21 * 1728,
          match_stops: [build(:match_stop, distance: 5, index: 0)]
        )

      assert %Changeset{
               valid?: false,
               errors: [
                 total_volume:
                   {"cannot be over %{limit} ft³ total", [validation: :max_volume, limit: 20]}
               ]
             } = DistanceTemplate.calculate_pricing(match, @cargo_config)

      match =
        insert(:match,
          total_weight: 20,
          total_volume: 20 * 1728,
          match_stops: [build(:match_stop, distance: 5, index: 0)]
        )

      assert %Changeset{valid?: true} = DistanceTemplate.calculate_pricing(match, @cargo_config)
    end

    test "max_item_weight can't be more than 20 lbs per item" do
      match =
        insert(:match,
          match_stops: [
            build(:match_stop,
              distance: 5,
              index: 1,
              items: [insert(:match_stop_item, weight: 21)]
            )
          ]
        )

      assert %Changeset{
               valid?: false,
               changes: %{
                 match_stops: [
                   %{
                     errors: [
                       items:
                         {"cannot be over %{limit} lbs for an item",
                          [validation: :max_item_weight, limit: 20]}
                     ]
                   }
                 ]
               }
             } = DistanceTemplate.calculate_pricing(match, @cargo_config)

      match =
        insert(:match,
          total_weight: 19,
          total_volume: 19,
          match_stops: [
            build(:match_stop,
              distance: 5,
              index: 1,
              items: [insert(:match_stop_item, weight: 20)]
            )
          ]
        )

      assert %Changeset{valid?: true} = DistanceTemplate.calculate_pricing(match, @cargo_config)
    end
  end

  describe "vehicle_class distance template" do
    test "calculates pricing" do
      match =
        insert(:match, vehicle_class: 1, match_stops: [build(:match_stop, distance: 5, index: 0)])

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @vc_config)

      assert %{
               driver_cut: 0.75,
               fees: [
                 %{type: :base_fee, amount: 20_00, driver_amount: 14_12}
               ],
               match_stops: [
                 %{base_price: 20_00, tip_price: 0, driver_cut: 0.75}
               ]
             } = apply_and_order(changeset)
    end

    test "calculates pricing for additional distance" do
      match =
        insert(:match,
          vehicle_class: 2,
          match_stops: [
            build(:match_stop, distance: 12, index: 0),
            build(:match_stop, distance: 10, index: 1)
          ]
        )

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @vc_config)

      assert %{
               driver_cut: 0.85,
               fees: [
                 %{type: :base_fee, amount: 44_00, driver_amount: 35_82}
               ],
               match_stops: [
                 %{base_price: 24_00, tip_price: 0, driver_cut: 0.85},
                 %{base_price: 20_00, tip_price: 0, driver_cut: 0.85}
               ]
             } = apply_and_order(changeset)
    end

    test "applies different pricing for first & following stops" do
      match =
        insert(:match,
          vehicle_class: 1,
          match_stops: [
            build(:match_stop, distance: 6, index: 0),
            build(:match_stop, distance: 6, index: 1)
          ]
        )

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @vc_config)

      assert %{
               driver_cut: 0.75,
               fees: [
                 %{type: :base_fee, amount: 31_50, driver_amount: 22_40}
               ],
               match_stops: [
                 %{base_price: 20_00, tip_price: 0, driver_cut: 0.75},
                 %{base_price: 11_50, tip_price: 0, driver_cut: 0.75}
               ]
             } = apply_and_order(changeset)
    end

    test "applies different pricing for first 3 stop & following stops" do
      match =
        insert(:match,
          vehicle_class: 3,
          match_stops: [
            build(:match_stop, distance: 6, index: 0),
            build(:match_stop, distance: 6, index: 1),
            build(:match_stop, distance: 6, index: 2),
            build(:match_stop, distance: 6, index: 3)
          ]
        )

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @vc_config)

      assert %{
               driver_cut: 0.75,
               fees: [
                 %{type: :base_fee, amount: 71_50, driver_amount: 51_24}
               ],
               match_stops: [
                 %{base_price: 20_00, tip_price: 0, driver_cut: 0.75},
                 %{base_price: 20_00, tip_price: 0, driver_cut: 0.75},
                 %{base_price: 20_00, tip_price: 0, driver_cut: 0.75},
                 %{base_price: 11_50, tip_price: 0, driver_cut: 0.75}
               ]
             } = apply_and_order(changeset)
    end

    test "applies tips from stops" do
      match =
        insert(:match,
          vehicle_class: 1,
          match_stops: [
            build(:match_stop, distance: 6, tip_price: 1_00, index: 0),
            build(:match_stop, distance: 6, tip_price: 6_00, index: 1)
          ]
        )

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @vc_config)

      assert %{
               driver_cut: 0.75,
               fees: [
                 %{type: :base_fee, amount: 31_50, driver_amount: 22_20},
                 %{type: :driver_tip, amount: 7_00, driver_amount: 7_00}
               ],
               match_stops: [
                 %{base_price: 20_00, tip_price: 1_00, driver_cut: 0.75},
                 %{base_price: 11_50, tip_price: 6_00, driver_cut: 0.75}
               ]
             } = apply_and_order(changeset)
    end

    test "errors on vehicle class not covered by contract" do
      match = insert(:match, vehicle_class: 4)

      assert %Changeset{
               errors: [vehicle_class: {"is not supported in this contract", []}]
             } = DistanceTemplate.calculate_pricing(match, @vc_config)
    end
  end

  describe "scheduled distance template" do
    test "uses dash when not scheduled with markup" do
      match =
        insert(:match, scheduled: false, match_stops: [build(:match_stop, distance: 5, index: 0)])

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @scheduled_config)

      assert %{
               driver_cut: 0.75,
               fees: [
                 %{type: :base_fee, amount: 11_00, driver_amount: 7_63}
               ],
               match_stops: [
                 %{base_price: 11_00, tip_price: 0, driver_cut: 0.75}
               ]
             } = apply_and_order(changeset)
    end

    test "uses scheduled when scheduled out further than buffer" do
      match =
        insert(:match,
          scheduled: true,
          pickup_at: ~N[2021-01-01 11:00:00],
          match_stops: [build(:match_stop, distance: 5, index: 0)],
          state_transitions: [
            insert(:match_state_transition,
              from: :pending,
              to: :scheduled,
              inserted_at: ~N[2021-01-01 10:00:00]
            )
          ]
        )

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @scheduled_config)

      assert %{
               driver_cut: 0.75,
               fees: [
                 %{type: :base_fee, amount: 20_00, driver_amount: 14_12}
               ],
               match_stops: [
                 %{base_price: 20_00, tip_price: 0, driver_cut: 0.75}
               ]
             } = apply_and_order(changeset)
    end
  end

  describe "tapered price" do
    test "without a price_per_mile defined and the tapered mileage limit NOT exceeded" do
      match = insert(:match, vehicle_class: 1, match_stops: [build(:match_stop, distance: 150)])

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @tapered_w_limit_config)

      assert %{
               driver_cut: 0.75,
               fees: [
                 %{type: :base_fee, amount: 184_73, driver_amount: 132_88}
               ]
             } = Changeset.apply_changes(changeset)
    end

    test "without a price_per_mile defined and the tapered mileage limit IS exceeded" do
      match = insert(:match, vehicle_class: 1, match_stops: [build(:match_stop, distance: 151)])

      assert %Changeset{
               changes: %{
                 match_stops: [
                   %Changeset{
                     errors: [
                       distance:
                         {"cannot be over %{limit} miles", [validation: :mile_limit, limit: 150]}
                     ],
                     valid?: false
                   }
                 ]
               }
             } = DistanceTemplate.calculate_pricing(match, @tapered_w_limit_config)
    end

    test "with a price_per_mile defined and the tapered mileage limit NOT exceeded" do
      match = insert(:match, vehicle_class: 1, match_stops: [build(:match_stop, distance: 150)])

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @tapered_no_limit_config)

      assert %{
               driver_cut: 0.75,
               fees: [
                 %{type: :base_fee, amount: 216_68, driver_amount: 155_92}
               ]
             } = Changeset.apply_changes(changeset)
    end

    test "with a price_per_mile defined and the tapered mileage limit IS exceeded" do
      match = insert(:match, vehicle_class: 1, match_stops: [build(:match_stop, distance: 180)])

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @tapered_no_limit_config)

      assert %{
               driver_cut: 0.75,
               fees: [
                 %{type: :base_fee, amount: 247_28, driver_amount: 177_98}
               ]
             } = Changeset.apply_changes(changeset)
    end
  end

  describe "cargo_value_cut" do
    @cargo_value_config %{
      @basic_config
      | tiers: [
          %LevelTier{
            default: %DistanceTier{
              base_price: 10_00,
              price_per_mile: 1_50,
              base_distance: 10,
              driver_cut: 0.75,
              cargo_value_cut: 0.5
            }
          }
        ]
    }

    test "uses cargo value when more than base price" do
      match =
        insert(:match,
          match_stops: [
            build(:match_stop,
              distance: 10,
              items: [
                build(:match_stop_item, declared_value: 100_00, pieces: 2),
                build(:match_stop_item, declared_value: 50_00)
              ]
            ),
            build(:match_stop,
              distance: 10,
              items: [
                build(:match_stop_item, declared_value: 10, pieces: 2),
                build(:match_stop_item, declared_value: 50)
              ]
            ),
            build(:match_stop,
              distance: 20,
              items: [
                build(:match_stop_item, declared_value: 10, pieces: 2),
                build(:match_stop_item, declared_value: 50)
              ]
            ),
            build(:match_stop,
              distance: 20,
              items: [
                build(:match_stop_item, declared_value: 100_00)
              ]
            )
          ]
        )

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @cargo_value_config)

      assert %{
               driver_cut: 0.75,
               fees: [
                 %{type: :base_fee, amount: 175_00, driver_amount: 125_87}
               ],
               match_stops: [
                 %{base_price: 75_00, driver_cut: 0.75},
                 %{base_price: 10_00, driver_cut: 0.75},
                 %{base_price: 25_00, driver_cut: 0.75},
                 %{base_price: 65_00, driver_cut: 0.75}
               ]
             } = apply_and_order(changeset)
    end
  end

  describe "calculates fees for" do
    defp insert_fee_match(attrs \\ []) do
      insert(
        :match,
        [
          vehicle_class: 1,
          scheduled: true,
          pickup_at: ~N[2030-01-02 00:00:00],
          match_stops: [build(:match_stop, index: 0, has_load_fee: false)],
          market: nil,
          expected_toll: 0,
          fees: []
        ] ++ attrs
      )
    end

    test "none when conditions are not met" do
      match = insert_fee_match()

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @fees_config)

      assert %{fees: [%{type: :base_fee}]} = apply_and_order(changeset)
    end

    test "when preferred driver is selected by shipper" do
      match = insert_fee_match(preferred_driver: build(:driver))

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @fees_config)

      assert %{
               fees: [
                 %{type: :base_fee, amount: 10_00, driver_amount: 691},
                 %{type: :preferred_driver_fee, amount: 150, driver_amount: 75}
               ]
             } = apply_and_order(changeset)
    end

    test "return charge when stops are undeliverable" do
      match =
        insert_fee_match(
          match_stops: [
            build(:match_stop,
              index: 0,
              distance: 5,
              has_load_fee: false,
              state: :returned
            ),
            build(:match_stop,
              index: 1,
              distance: 12,
              has_load_fee: false,
              state: :returned
            ),
            build(:match_stop,
              index: 2,
              distance: 12,
              has_load_fee: false,
              state: :pending
            )
          ]
        )

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @fees_config)

      assert %{
               fees: [
                 %{type: :base_fee, amount: 55_40, driver_amount: 44_16},
                 %{
                   type: :return_charge,
                   amount: 16_35,
                   driver_amount: 13_40,
                   description: "2 stops were returned"
                 },
                 %{type: :route_surcharge}
               ]
             } = apply_and_order(changeset)
    end

    test "load/unload except when below weight" do
      match =
        insert_fee_match(
          match_stops: [
            build(:match_stop,
              index: 0,
              has_load_fee: true,
              items: [build(:match_stop_item, pieces: 10, weight: 1)]
            )
          ]
        )

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @fees_config)

      assert %{fees: fees} = apply_and_order(changeset)

      refute Enum.find(fees, &(&1.type == :load_fee))
    end

    test "load/unload when weight >= min weight tier" do
      match =
        insert_fee_match(
          match_stops: [
            build(:match_stop,
              index: 0,
              has_load_fee: true,
              items: [build(:match_stop_item, pieces: 10, weight: 25)]
            )
          ]
        )

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @fees_config)

      assert %{
               fees: [%{type: :base_fee}, %{type: :load_fee, amount: 24_99, driver_amount: 18_74}]
             } = apply_and_order(changeset)
    end

    test "load/unload increases tiers with weight" do
      match =
        insert_fee_match(
          match_stops: [
            build(:match_stop,
              index: 0,
              has_load_fee: true,
              items: [build(:match_stop_item, pieces: 10, weight: 100)]
            )
          ]
        )

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @fees_config)

      assert %{
               fees: [%{type: :base_fee}, %{type: :load_fee, amount: 44_99, driver_amount: 33_74}]
             } = apply_and_order(changeset)
    end

    test "lift gate" do
      match = insert_fee_match(vehicle_class: 4, unload_method: :lift_gate)

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @fees_config)

      assert %{
               fees: [
                 %{type: :base_fee},
                 %{type: :lift_gate_fee, amount: 30_00, driver_amount: 22_50}
               ]
             } = apply_and_order(changeset)
    end

    test "holiday" do
      match =
        insert_fee_match(scheduled: true, pickup_at: ~N[2030-12-25 12:00:00], vehicle_class: 4)

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @fees_config)

      assert %{
               fees: [
                 %{type: :base_fee},
                 %{type: :holiday_fee, amount: 100_00, driver_amount: 75_00}
               ]
             } = apply_and_order(changeset)
    end

    test "route surcharge" do
      match =
        insert_fee_match(
          match_stops: [build(:match_stop, index: 0), build(:match_stop, index: 1)]
        )

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @fees_config)

      assert %{
               fees: [%{type: :base_fee}, %{type: :route_surcharge, amount: 50, driver_amount: 0}]
             } = apply_and_order(changeset)
    end

    test "tolls when market has tolls enabled" do
      match =
        insert_fee_match(expected_toll: 10_00, market: build(:market, calculate_tolls: true))

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @fees_config)

      assert %{
               fees: [
                 %{type: :base_fee},
                 %{type: :toll_fees, amount: 10_00, driver_amount: 10_00}
               ]
             } = apply_and_order(changeset)
    end

    test "tolls unless no expected tolls" do
      match = insert_fee_match(expected_toll: 0, market: build(:market, calculate_tolls: true))

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @fees_config)

      assert %{fees: fees} = apply_and_order(changeset)

      refute Enum.find(fees, &(&1.type == :toll_fees))
    end

    test "tolls unless without market with enabled tolls" do
      match =
        insert_fee_match(expected_toll: 10_00, market: build(:market, calculate_tolls: false))

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @fees_config)

      assert %{fees: fees} = apply_and_order(changeset)

      refute Enum.find(fees, &(&1.type == :toll_fees))
    end

    test "can remove fees that no longer apply" do
      match =
        insert_fee_match(
          fees: [
            build(:match_fee, type: :holiday_fee),
            build(:match_fee, type: :lift_gate_fee)
          ]
        )

      assert %Changeset{} = changeset = DistanceTemplate.calculate_pricing(match, @fees_config)

      assert %{fees: [%{type: :base_fee}]} = apply_and_order(changeset)
    end
  end

  describe "applies markups for" do
    @markups_config %DistanceTemplate{
      @basic_config
      | markups: [
          state: %{
            "OR" => 1.5
          },
          market: true,
          time_surcharge: [
            {{~T[15:30:00], ~T[07:00:00]}, 1.2},
            holidays: 1.5,
            weekends: 1.3
          ]
        ]
    }

    test "state markup" do
      match =
        insert(:match,
          origin_address: insert(:address, state_code: "OR"),
          match_stops: [build(:match_stop, distance: 5, index: 0)]
        )

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @markups_config)

      assert %{
               driver_cut: 0.75,
               fees: [
                 %{type: :base_fee, amount: 15_00}
               ]
             } = apply_and_order(changeset)
    end

    test "market markup" do
      match =
        insert(:match,
          match_stops: [build(:match_stop, distance: 5, index: 0)],
          markup: 2
        )

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @markups_config)

      assert %{
               driver_cut: 0.75,
               fees: [
                 %{type: :base_fee, amount: 20_00}
               ]
             } = apply_and_order(changeset)
    end

    test "multiple markups" do
      match =
        insert(:match,
          origin_address: insert(:address, state_code: "OR"),
          match_stops: [build(:match_stop, distance: 5, index: 0)],
          markup: 2
        )

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @markups_config)

      assert %{
               driver_cut: 0.75,
               fees: [
                 %{type: :base_fee, amount: 30_00}
               ]
             } = apply_and_order(changeset)
    end
  end

  describe "time surcharge markup" do
    defp insert_match_at(time) do
      insert(:match,
        match_stops: [build(:match_stop, distance: 5, index: 0)],
        state_transitions: [
          insert(:match_state_transition,
            to: :assigning_driver,
            inserted_at: time
          )
        ]
      )
    end

    test "does not add time surcharge within 7am and 3:30pm" do
      noon = ~U[2019-05-06 15:29:00Z]

      match = insert_match_at(noon)

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @markups_config)

      assert %{
               fees: [
                 %{type: :base_fee, amount: 10_00, driver_amount: 6_91}
               ]
             } = apply_and_order(changeset)
    end

    test "adds time surcharge on saturday" do
      saturday = ~U[2019-12-28 12:00:00Z]

      match = insert_match_at(saturday)

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @markups_config)

      assert %{
               fees: [
                 %{type: :base_fee, amount: 13_00, driver_amount: 9_07}
               ]
             } = apply_and_order(changeset)
    end

    test "adds time surcharge on sunday" do
      sunday = ~U[2019-12-29 12:00:00Z]

      match = insert_match_at(sunday)

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @markups_config)

      assert %{
               fees: [
                 %{type: :base_fee, amount: 13_00, driver_amount: 9_07}
               ]
             } = apply_and_order(changeset)
    end

    test "adds time surcharge during holidays" do
      christmas = ~U[2019-12-25 12:00:00Z]

      match = insert_match_at(christmas)

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @markups_config)

      assert %{
               fees: [
                 %{type: :base_fee, amount: 15_00, driver_amount: 10_51}
               ]
             } = apply_and_order(changeset)
    end

    test "adds time surcharge before 7:00am" do
      after_4pm = ~U[2020-02-04 06:00:00Z]

      match = insert_match_at(after_4pm)

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @markups_config)

      assert %{
               fees: [
                 %{type: :base_fee, amount: 12_00, driver_amount: 8_35}
               ]
             } = apply_and_order(changeset)
    end

    test "adds time surcharge after 3:30pm" do
      after_4pm = ~U[2020-02-04 18:00:00Z]

      match = insert_match_at(after_4pm)

      assert %Changeset{valid?: true} =
               changeset = DistanceTemplate.calculate_pricing(match, @markups_config)

      assert %{
               fees: [
                 %{type: :base_fee, amount: 12_00, driver_amount: 8_35}
               ]
             } = apply_and_order(changeset)
    end
  end

  describe "include_tolls?" do
    test "returns true when toll fees are true" do
      m = insert(:match)
      assert DistanceTemplate.include_tolls?(m, %{@basic_config | fees: [toll_fees: true]})
    end

    test "returns false when toll fees are true" do
      m = insert(:match)
      refute DistanceTemplate.include_tolls?(m, @basic_config)
    end
  end

  describe "market modifiers" do
    test "applies them" do
      market_config = insert(:market_config, multiplier: 1.1)

      match = insert(:match, contract: market_config.contract, market_id: market_config.market_id)

      %{changes: %{match_stops: match_stops}} =
        DistanceTemplate.calculate_pricing(match, @markups_config)

      match_stops
      |> Enum.each(fn %{changes: changes} ->
        assert changes == %{base_price: 1100}
      end)
    end
  end
end
