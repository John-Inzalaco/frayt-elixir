defmodule FraytElixir.SLAsTest do
  use FraytElixir.DataCase

  alias FraytElixir.SLAs
  alias FraytElixir.SLAs.{MatchSLA, ContractSLA}
  alias FraytElixir.Shipment.Match
  alias Ecto.Changeset

  describe "validate_sla_scheduling/1" do
    test "validation passes" do
      m = insert(:match, contract: insert(:contract, slas: []))
      changeset = Changeset.change(m)

      assert %Changeset{valid?: true} = SLAs.validate_sla_scheduling(changeset)
    end

    test "validation fails when acceptance :end_time SLA is scheduled less than the min_duration from the end time" do
      match =
        insert(:match,
          timezone: "America/Phoenix",
          contract:
            insert(:contract,
              slas: [
                %ContractSLA{
                  type: :acceptance,
                  duration_type: :end_time,
                  min_duration: "60",
                  time: ~T[12:00:00]
                }
              ]
            )
        )

      assert %Changeset{valid?: false, errors: errors} =
               match
               |> Changeset.change(%{scheduled: true, pickup_at: ~N[2030-01-01 18:00:01]})
               |> SLAs.validate_sla_scheduling()

      assert [pickup_at: {"cannot be after 11:00AM for this service level", _}] = errors

      assert %Changeset{valid?: true} =
               match
               |> Changeset.change(%{scheduled: true, pickup_at: ~N[2030-01-01 18:00:00]})
               |> SLAs.validate_sla_scheduling()
    end

    test "validation fails when acceptance :end_time SLA is placed less than the min_duration from the end time" do
      time = Time.utc_now()

      formatted_time = time |> Time.add(-60 * 60) |> Timex.format!("{h12}:{0m}{AM}")

      match =
        insert(:match,
          timezone: "Etc/UTC",
          contract:
            insert(:contract,
              slas: [
                %ContractSLA{
                  type: :acceptance,
                  duration_type: :end_time,
                  time: time,
                  min_duration: "60"
                }
              ]
            )
        )

      assert %Changeset{valid?: false, errors: errors} =
               match
               |> Changeset.change()
               |> SLAs.validate_sla_scheduling()

      message = "cannot be after #{formatted_time} for this service level"

      assert [authorized_at: {^message, _}] = errors

      match =
        insert(:match,
          contract:
            insert(:contract,
              slas: [
                %ContractSLA{
                  type: :acceptance,
                  duration_type: :end_time,
                  min_duration: "60",
                  time: Time.add(time, 70 * 60, :second)
                }
              ]
            )
        )

      assert %Changeset{valid?: true} =
               match
               |> Changeset.change()
               |> SLAs.validate_sla_scheduling()
    end

    test "validation fails when delivery :end_time SLA has a dropoff at time" do
      match =
        insert(:match,
          scheduled: true,
          contract:
            insert(:contract,
              slas: [
                %ContractSLA{
                  type: :delivery,
                  duration_type: :end_time,
                  time: ~T[05:00:00]
                }
              ]
            )
        )

      assert %Changeset{valid?: false, errors: errors} =
               match
               |> Changeset.change(%{dropoff_at: ~N[2020-01-01 00:00:00]})
               |> SLAs.validate_sla_scheduling()

      assert [dropoff_at: {"cannot be set for this service level", [validation: :empty]}] = errors
    end

    test "validation fails when delivery :duration_before_time SLA has a dropoff at time" do
      match =
        insert(:match,
          scheduled: true,
          contract:
            insert(:contract,
              slas: [
                %ContractSLA{
                  type: :delivery,
                  duration_type: :duration_before_time,
                  time: ~T[05:00:00],
                  duration: "30"
                }
              ]
            )
        )

      assert %Changeset{valid?: false, errors: errors} =
               match
               |> Changeset.change(%{dropoff_at: ~N[2020-01-01 00:00:00]})
               |> SLAs.validate_sla_scheduling()

      assert [dropoff_at: {"cannot be set for this service level", [validation: :empty]}] = errors
    end
  end

  describe "stop_delivery_time/0" do
    test "returns the stop delivery time" do
      assert SLAs.stop_delivery_time() == 300
    end
  end

  describe "get_active_match_slas/1" do
    setup do
      driver = insert(:driver)

      match =
        insert(:match,
          driver: driver,
          slas: [
            build(:match_sla, driver: nil, type: :acceptance),
            build(:match_sla, driver: nil, type: :pickup),
            build(:match_sla, driver: driver, type: :pickup),
            build(:match_sla, driver: nil, type: :delivery),
            build(:match_sla, driver: driver, type: :delivery)
          ]
        )

      %{match: match}
    end

    test "returns acceptance sla for assigning_driver", %{match: match} do
      assert {:acceptance, [%MatchSLA{type: :acceptance, driver_id: nil}]} =
               SLAs.get_active_match_slas(%{match | state: :assigning_driver})
    end

    test "returns pickup sla for accepted matches", %{match: match} do
      %{driver_id: driver_id} = match

      assert {:pickup,
              [
                %MatchSLA{type: :pickup, driver_id: nil},
                %MatchSLA{type: :pickup, driver_id: ^driver_id}
              ]} = SLAs.get_active_match_slas(%{match | state: :accepted})

      assert {:pickup,
              [
                %MatchSLA{type: :pickup, driver_id: nil},
                %MatchSLA{type: :pickup, driver_id: ^driver_id}
              ]} = SLAs.get_active_match_slas(%{match | state: :en_route_to_pickup})

      assert {:pickup,
              [
                %MatchSLA{type: :pickup, driver_id: nil},
                %MatchSLA{type: :pickup, driver_id: ^driver_id}
              ]} = SLAs.get_active_match_slas(%{match | state: :arrived_at_pickup})
    end

    test "returns delivery sla for picked up matches", %{match: match} do
      %{driver_id: driver_id} = match

      assert {:delivery,
              [
                %MatchSLA{type: :delivery, driver_id: nil},
                %MatchSLA{type: :delivery, driver_id: ^driver_id}
              ]} = SLAs.get_active_match_slas(%{match | state: :picked_up})
    end

    test "returns nil for match with no active slas", %{match: match} do
      refute SLAs.get_active_match_slas(%{match | state: :inactive})
    end
  end

  describe "get_match_sla/3" do
    test "returns the corresponding frayt sla" do
      m = insert(:match, slas: [])
      %{id: sla_id} = insert(:match_sla, match: m, type: :pickup, driver_id: nil)

      assert %MatchSLA{id: ^sla_id} = SLAs.get_match_sla(m, :pickup)
    end

    test "returns the corresponding driver sla" do
      m = insert(:match, slas: [])
      d = %{id: driver_id} = insert(:driver)
      %{id: sla_id} = insert(:match_sla, match: m, type: :delivery, driver: d)

      assert %MatchSLA{id: ^sla_id} = SLAs.get_match_sla(m, :delivery, driver_id)
    end

    test "returns nil when no match is found" do
      m = insert(:match, slas: [])

      refute SLAs.get_match_sla(m, :acceptance)
    end
  end

  describe "change_match_sla/2" do
    @valid_attrs %{
      type: :pickup,
      start_time: ~U[2020-01-01 00:00:00Z],
      end_time: ~U[2020-01-01 12:00:00Z],
      completed_at: ~U[2020-01-01 11:00:00Z]
    }

    test "returns a valid changeset when changing all fields" do
      match = insert(:match, slas: [])
      driver = insert(:driver)

      attrs =
        @valid_attrs
        |> Map.put(:match_id, match.id)
        |> Map.put(:driver_id, driver.id)

      assert %Changeset{valid?: true, changes: changes} =
               SLAs.change_match_sla(%MatchSLA{}, attrs)

      assert changes.match_id == match.id
      assert changes.driver_id == driver.id
      assert changes.type == @valid_attrs.type
      assert changes.start_time == @valid_attrs.start_time
      assert changes.end_time == @valid_attrs.end_time
      assert changes.completed_at == @valid_attrs.completed_at
    end

    test "validates required fields" do
      assert %Changeset{valid?: false, errors: errors} = SLAs.change_match_sla(%MatchSLA{}, %{})

      assert {_, [validation: :required]} = errors[:match_id]
      assert {_, [validation: :required]} = errors[:type]
      assert {_, [validation: :required]} = errors[:start_time]
      assert {_, [validation: :required]} = errors[:end_time]
    end

    test "validates start_time is before or at end time" do
      match = insert(:match, slas: [])

      attrs =
        @valid_attrs
        |> Map.put(:match_id, match.id)
        |> Map.put(:start_time, ~N[2020-01-01 23:00:00])

      assert %Changeset{
               valid?: false,
               errors: [
                 start_time:
                   {_,
                    [
                      time: ~U[2020-01-01 12:00:00Z],
                      validation: :date_time,
                      kind: :less_than_or_equal_to
                    ]}
               ]
             } = SLAs.change_match_sla(%MatchSLA{}, attrs)
    end

    test "allows duplicate record for match and type when driver is nil, and set on another" do
      match = insert(:match, slas: [build(:match_sla, driver: insert(:driver), type: :pickup)])
      driver = insert(:driver)

      attrs =
        @valid_attrs
        |> Map.put(:match_id, match.id)

      assert {:ok, %MatchSLA{}} = SLAs.change_match_sla(%MatchSLA{}, attrs) |> Repo.insert()

      attrs =
        attrs
        |> Map.put(:driver_id, driver.id)

      assert {:ok, %MatchSLA{}} = SLAs.change_match_sla(%MatchSLA{}, attrs) |> Repo.insert()
    end

    test "validates uniqueness for match, type and driver" do
      driver = insert(:driver)
      match = insert(:match, slas: [build(:match_sla, driver: driver, type: :pickup)])

      attrs =
        @valid_attrs
        |> Map.put(:match_id, match.id)
        |> Map.put(:driver_id, driver.id)

      changeset = %Changeset{valid?: true} = SLAs.change_match_sla(%MatchSLA{}, attrs)
      assert {:error, %Changeset{valid?: false, errors: errors}} = Repo.insert(changeset)

      assert [match_id_type_driver_id: {"Only one SLA type per Driver's Match is allowed", _}] =
               errors
    end

    test "validates uniqueness for match, type and driver when driver is nil" do
      match = insert(:match, slas: [build(:match_sla, driver: nil, type: :pickup)])

      attrs = Map.put(@valid_attrs, :match_id, match.id)

      changeset = %Changeset{valid?: true} = SLAs.change_match_sla(%MatchSLA{}, attrs)

      assert {:error, %Changeset{valid?: false, errors: errors}} = Repo.insert(changeset)

      assert [match_id_type: {"Only one SLA type per Match is allowed", _}] = errors
    end
  end

  describe "calculate_match_slas/2" do
    test "calculates slas for: :frayt" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      match =
        insert(:match,
          slas: [],
          driver: insert(:driver),
          scheduled: true,
          pickup_at: DateTime.add(now, 60 * 60, :second)
        )

      insert(:match_state_transition, to: :scheduled, inserted_at: now, match: match)

      assert {:ok, %Match{slas: slas}} = SLAs.calculate_match_slas(match, for: :frayt)

      assert [
               %MatchSLA{
                 type: :delivery,
                 driver_id: nil,
                 start_time: delivery_start,
                 end_time: delivery_end
               },
               %MatchSLA{
                 type: :pickup,
                 driver_id: nil,
                 start_time: pickup_start,
                 end_time: pickup_end
               },
               %MatchSLA{
                 type: :acceptance,
                 driver_id: nil,
                 start_time: acceptance_start,
                 end_time: acceptance_end
               }
             ] = slas

      assert acceptance_start == now
      assert acceptance_end == pickup_start
      assert pickup_end == delivery_start
      assert DateTime.compare(delivery_end, delivery_start) == :gt
    end

    test "calculates slas for: :driver" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      %{id: driver_id} = driver = insert(:driver)

      match =
        insert(:match,
          slas: [],
          driver: driver,
          scheduled: true,
          pickup_at: DateTime.add(now, 60 * 60, :second)
        )

      insert(:match_state_transition, to: :accepted, inserted_at: now, match: match)

      assert {:ok, %Match{slas: slas}} = SLAs.calculate_match_slas(match, for: :driver)

      assert [
               %MatchSLA{
                 type: :delivery,
                 driver_id: ^driver_id,
                 start_time: delivery_start,
                 end_time: delivery_end
               },
               %MatchSLA{
                 type: :pickup,
                 driver_id: ^driver_id,
                 start_time: pickup_start,
                 end_time: pickup_end
               }
             ] = slas

      assert pickup_start == now
      assert pickup_end == delivery_start
      assert DateTime.compare(delivery_end, delivery_start) == :gt
    end

    test "does not support :types" do
      match = insert(:match, slas: [])

      assert_raise FunctionClauseError, fn ->
        SLAs.calculate_match_slas(match, types: :acceptance)
      end
    end
  end

  describe "complete_match_slas/2" do
    test "sets SLAs completed_at to the current time" do
      match =
        insert(:match,
          slas: [
            build(:match_sla, type: :acceptance, driver: nil, completed_at: nil)
          ]
        )

      now = DateTime.utc_now()

      assert {:ok, %Match{slas: slas}} = SLAs.complete_match_slas(match, types: :acceptance)

      assert [%MatchSLA{type: :acceptance, driver_id: nil, completed_at: completed_at}] = slas

      assert DateTime.diff(completed_at, now, :second) <= 1
    end

    test "can set SLAs completed_at to a specific time" do
      match =
        insert(:match,
          slas: [
            build(:match_sla, type: :acceptance, driver: nil, completed_at: nil)
          ]
        )

      assert {:ok, %Match{slas: slas}} =
               SLAs.complete_match_slas(match, ~U[2020-01-01 00:00:00Z], types: :acceptance)

      assert [
               %MatchSLA{
                 type: :acceptance,
                 driver_id: nil,
                 completed_at: ~U[2020-01-01 00:00:00Z]
               }
             ] = slas
    end
  end

  describe "reset_match_slas/2" do
    test "clears SLAs completed_at times" do
      match =
        insert(:match,
          slas: [
            build(:match_sla,
              type: :acceptance,
              driver: nil,
              completed_at: ~U[2021-01-01 00:00:00Z]
            )
          ]
        )

      assert {:ok, %Match{slas: slas}} = SLAs.reset_match_slas(match, types: :acceptance)

      assert [%MatchSLA{type: :acceptance, driver_id: nil, completed_at: nil}] = slas
    end
  end

  describe "upsert_match_slas/3" do
    defp change_match_slas(sla, _prev_sla) do
      SLAs.change_match_sla(sla, %{
        start_time: ~U[2020-01-01 00:00:00Z],
        end_time: ~U[2020-01-01 12:00:00Z]
      })
    end

    test "updates frayt acceptance, pickup, and delivery slas for: :frayt" do
      %{id: match_id} = match = insert(:match, slas: [])

      assert {:ok, %Match{slas: slas}} =
               SLAs.upsert_match_slas(match, [for: :frayt], &change_match_slas/2)

      assert [
               %MatchSLA{type: :delivery, driver_id: nil, match_id: ^match_id},
               %MatchSLA{type: :pickup, driver_id: nil, match_id: ^match_id},
               %MatchSLA{type: :acceptance, driver_id: nil, match_id: ^match_id}
             ] = slas
    end

    test "updates driver pickup, and delivery slas for: :driver" do
      %{id: driver_id} = driver = insert(:driver)
      match = insert(:match, slas: [], driver: driver)

      assert {:ok, %Match{slas: slas}} =
               SLAs.upsert_match_slas(match, [for: :driver], &change_match_slas/2)

      assert [
               %MatchSLA{type: :delivery, driver_id: ^driver_id},
               %MatchSLA{type: :pickup, driver_id: ^driver_id}
             ] = slas
    end

    test "updates all slas for: :frayt, :driver" do
      %{id: driver_id} = driver = insert(:driver)

      old_time = ~U[2030-02-02 12:00:00Z]
      new_time = ~U[2020-01-01 00:00:00Z]

      match =
        insert(:match,
          slas: [
            build(:match_sla, type: :delivery, driver: driver, start_time: old_time),
            build(:match_sla, type: :pickup, driver: driver, start_time: old_time),
            build(:match_sla, type: :delivery, driver: nil, start_time: old_time),
            build(:match_sla, type: :pickup, driver: nil, start_time: old_time),
            build(:match_sla, type: :acceptance, driver: nil, start_time: old_time)
          ],
          driver: driver
        )

      assert {:ok, %Match{slas: slas}} =
               SLAs.upsert_match_slas(match, [for: [:driver, :frayt]], &change_match_slas/2)

      assert [
               %MatchSLA{type: :delivery, driver_id: ^driver_id, start_time: ^new_time},
               %MatchSLA{type: :pickup, driver_id: ^driver_id, start_time: ^new_time},
               %MatchSLA{type: :delivery, driver_id: nil, start_time: ^new_time},
               %MatchSLA{type: :pickup, driver_id: nil, start_time: ^new_time},
               %MatchSLA{type: :acceptance, driver_id: nil, start_time: ^new_time}
             ] = slas
    end

    test "ignore driver slas for: :driver when match does not have a driver" do
      match = insert(:match, slas: [], driver: nil)

      assert {:ok, %Match{slas: []}} =
               SLAs.upsert_match_slas(match, [for: :driver], &change_match_slas/2)
    end

    test "creates all slas by :types" do
      %{id: driver_id} = driver = insert(:driver)

      match = insert(:match, slas: [], driver: driver)

      assert {:ok, %Match{slas: slas}} =
               SLAs.upsert_match_slas(
                 match,
                 [types: [:acceptance, :pickup, :delivery]],
                 &change_match_slas/2
               )

      assert [
               %MatchSLA{type: :delivery, driver_id: ^driver_id},
               %MatchSLA{type: :pickup, driver_id: ^driver_id},
               %MatchSLA{type: :delivery, driver_id: nil},
               %MatchSLA{type: :pickup, driver_id: nil},
               %MatchSLA{type: :acceptance, driver_id: nil}
             ] = slas
    end

    test "ignore driver slas for :types when match does not have a driver" do
      match = insert(:match, slas: [], driver: nil)

      assert {:ok, %Match{slas: slas}} =
               SLAs.upsert_match_slas(
                 match,
                 [types: [:acceptance, :pickup, :delivery]],
                 &change_match_slas/2
               )

      assert [
               %MatchSLA{type: :delivery, driver_id: nil},
               %MatchSLA{type: :pickup, driver_id: nil},
               %MatchSLA{type: :acceptance, driver_id: nil}
             ] = slas
    end
  end

  describe "build_match_sla/2" do
    @acceptance_default_sla %ContractSLA{type: :acceptance, duration: "60"}
    @acceptance_end_time_sla %ContractSLA{
      type: :acceptance,
      duration_type: :end_time,
      min_duration: "60",
      time: ~T[11:35:00]
    }

    @pickup_default_sla %ContractSLA{type: :pickup, duration: "40"}
    @pickup_end_time_sla %ContractSLA{
      type: :pickup,
      duration_type: :end_time,
      min_duration: "30",
      time: ~T[13:00:00]
    }
    @pickup_duration_before_time_sla %ContractSLA{
      type: :pickup,
      duration_type: :duration_before_time,
      duration: "45",
      min_duration: "25",
      time: ~T[14:00:00]
    }

    @delivery_default_sla %ContractSLA{type: :delivery, duration: "60"}
    @delivery_end_time_sla %ContractSLA{
      type: :delivery,
      duration_type: :end_time,
      min_duration: "20",
      time: ~T[14:00:00]
    }
    @delivery_duration_before_time_sla %ContractSLA{
      type: :delivery,
      duration_type: :duration_before_time,
      duration: "32",
      min_duration: "15",
      time: ~T[15:00:00]
    }

    @delivery_variable_sla %ContractSLA{
      type: :delivery,
      duration:
        "market_pickup_sla_modifier + travel_duration + vehicle_load_time + total_distance + stop_count * stop_delivery_time"
    }

    defp setup_match_slas(match, type, driver_id \\ nil, prev_sla \\ nil) do
      sla =
        build(:match_sla,
          type: type,
          driver_id: driver_id,
          match: %{match | driver_id: driver_id},
          start_time: nil,
          end_time: nil
        )

      prev_sla =
        case prev_sla do
          {prev_type, prev_end_time} ->
            build(:match_sla,
              type: prev_type,
              driver_id: driver_id,
              match: %{match | driver_id: driver_id},
              end_time: prev_end_time
            )

          _ ->
            nil
        end

      %{match | slas: Enum.filter([sla, prev_sla], & &1)}

      {sla, prev_sla}
    end

    defp setup_sla_match(slas, driver, scheduled_time \\ nil, state_transitions \\ []) do
      insert(:match,
        driver: driver,
        contract: insert(:contract, slas: slas),
        scheduled: not is_nil(scheduled_time),
        pickup_at: scheduled_time,
        dropoff_at: scheduled_time,
        state_transitions:
          Enum.map(state_transitions, fn {to_state, inserted_at} ->
            insert(:match_state_transition,
              to: to_state,
              inserted_at: inserted_at
            )
          end)
      )
    end

    test "calculates default frayt acceptance SLA" do
      slas = [@acceptance_default_sla]

      match = setup_sla_match(slas, nil, nil, assigning_driver: ~U[2020-01-01 00:00:00Z])

      {sla, prev_sla} = setup_match_slas(match, :acceptance)

      assert %{
               start_time: ~U[2020-01-01 00:00:00Z],
               end_time: ~U[2020-01-01 01:00:00Z]
             } = SLAs.build_match_sla(sla, prev_sla)
    end

    test "calculates default frayt acceptance SLA for a scheduled Match" do
      slas = [@acceptance_default_sla, @pickup_default_sla]

      match =
        setup_sla_match(slas, nil, ~N[2020-01-01 12:00:00], scheduled: ~U[2020-01-01 00:00:00Z])

      {sla, prev_sla} = setup_match_slas(match, :acceptance)

      assert %{
               start_time: ~U[2020-01-01 00:00:00Z],
               end_time: ~U[2020-01-01 11:20:00Z]
             } = SLAs.build_match_sla(sla, prev_sla)
    end

    test "calculates default frayt acceptance SLA for a scheduled Match with a :end_time pickup SLA" do
      slas = [@acceptance_default_sla, @pickup_end_time_sla]

      match =
        setup_sla_match(slas, nil, ~N[2020-01-01 12:00:00], scheduled: ~U[2020-01-01 00:00:00Z])

      {sla, prev_sla} = setup_match_slas(match, :acceptance)

      assert %{
               start_time: ~U[2020-01-01 00:00:00Z],
               end_time: ~U[2020-01-01 12:00:00Z]
             } = SLAs.build_match_sla(sla, prev_sla)
    end

    test "calculates default frayt acceptance SLA for a scheduled Match with a :duration_before_time pickup SLA" do
      slas = [@acceptance_default_sla, @pickup_duration_before_time_sla]

      match =
        setup_sla_match(slas, nil, ~N[2020-01-01 12:00:00], scheduled: ~U[2020-01-01 00:00:00Z])

      {sla, prev_sla} = setup_match_slas(match, :acceptance)

      assert %{
               start_time: ~U[2020-01-01 00:00:00Z],
               end_time: ~U[2020-01-01 12:00:00Z]
             } = SLAs.build_match_sla(sla, prev_sla)
    end

    test "calculates :end_time frayt acceptance SLA" do
      slas = [@acceptance_end_time_sla]

      match = setup_sla_match(slas, nil, nil, assigning_driver: ~U[2020-01-01 00:00:00Z])

      {sla, prev_sla} = setup_match_slas(match, :acceptance)

      assert %{
               start_time: ~U[2020-01-01 00:00:00Z],
               end_time: ~U[2020-01-01 11:35:00Z]
             } = SLAs.build_match_sla(sla, prev_sla)
    end

    test "calculates :end_time frayt acceptance SLA for a scheduled Match" do
      slas = [@acceptance_end_time_sla]

      match =
        setup_sla_match(slas, nil, ~N[2020-01-01 12:00:00], scheduled: ~U[2020-01-01 00:00:00Z])

      {sla, prev_sla} = setup_match_slas(match, :acceptance)

      assert %{
               start_time: ~U[2020-01-01 00:00:00Z],
               end_time: ~U[2020-01-01 11:35:00Z]
             } = SLAs.build_match_sla(sla, prev_sla)
    end

    test "calculates :end_time frayt acceptance SLA for a scheduled Match on a future date" do
      slas = [@acceptance_end_time_sla]

      match =
        setup_sla_match(slas, nil, ~N[2020-01-01 12:00:00], scheduled: ~U[2019-01-01 00:00:00Z])

      {sla, prev_sla} = setup_match_slas(match, :acceptance)

      assert %{
               start_time: ~U[2019-01-01 00:00:00Z],
               end_time: ~U[2020-01-01 11:35:00Z]
             } = SLAs.build_match_sla(sla, prev_sla)
    end

    test "calculates default frayt + driver pickup SLA" do
      slas = [@pickup_default_sla]
      %{id: driver_id} = driver = insert(:driver)

      match = setup_sla_match(slas, driver, nil, accepted: ~N[2020-01-01 12:00:00])

      {sla, prev_sla} =
        setup_match_slas(match, :pickup, nil, {:acceptance, ~U[2020-01-01 00:00:00Z]})

      assert %{
               type: :pickup,
               start_time: ~U[2020-01-01 00:00:00Z],
               end_time: ~U[2020-01-01 00:40:00Z],
               driver_id: nil
             } = SLAs.build_match_sla(sla, prev_sla)

      {driver_sla, prev_driver_sla} = setup_match_slas(match, :pickup, driver_id)

      assert %{
               type: :pickup,
               start_time: ~U[2020-01-01 12:00:00Z],
               end_time: ~U[2020-01-01 12:40:00Z],
               driver_id: ^driver_id
             } = SLAs.build_match_sla(driver_sla, prev_driver_sla)
    end

    test "calculates default frayt + driver pickup SLA for scheduled match" do
      slas = [@pickup_default_sla]
      %{id: driver_id} = driver = insert(:driver)

      match =
        setup_sla_match(slas, driver, ~N[2020-01-01 13:00:00], accepted: ~N[2020-01-01 12:00:00])

      {sla, prev_sla} =
        setup_match_slas(match, :pickup, nil, {:acceptance, ~U[2020-01-01 00:00:00Z]})

      assert %{
               type: :pickup,
               start_time: ~U[2020-01-01 00:00:00Z],
               end_time: ~U[2020-01-01 13:00:00Z],
               driver_id: nil
             } = SLAs.build_match_sla(sla, prev_sla)

      {driver_sla, prev_driver_sla} = setup_match_slas(match, :pickup, driver_id)

      assert %{
               type: :pickup,
               start_time: ~U[2020-01-01 12:00:00Z],
               end_time: ~U[2020-01-01 13:00:00Z],
               driver_id: ^driver_id
             } = SLAs.build_match_sla(driver_sla, prev_driver_sla)
    end

    test "calculates :duration_before_time frayt + driver pickup SLA" do
      slas = [@pickup_duration_before_time_sla]
      %{id: driver_id} = driver = insert(:driver)

      match = setup_sla_match(slas, driver, nil, accepted: ~N[2020-01-01 12:00:00])

      {sla, prev_sla} =
        setup_match_slas(match, :pickup, nil, {:acceptance, ~U[2020-01-01 00:00:00Z]})

      assert %{
               type: :pickup,
               start_time: ~U[2020-01-01 00:00:00Z],
               end_time: ~U[2020-01-01 13:15:00Z],
               driver_id: nil
             } = SLAs.build_match_sla(sla, prev_sla)

      {driver_sla, prev_driver_sla} = setup_match_slas(match, :pickup, driver_id)

      assert %{
               type: :pickup,
               start_time: ~U[2020-01-01 12:00:00Z],
               end_time: ~U[2020-01-01 13:15:00Z],
               driver_id: ^driver_id
             } = SLAs.build_match_sla(driver_sla, prev_driver_sla)
    end

    test "calculates :duration_before_time frayt + driver pickup SLA for sheduled Match" do
      slas = [@pickup_duration_before_time_sla]
      %{id: driver_id} = driver = insert(:driver)

      match =
        setup_sla_match(slas, driver, ~N[2020-01-01 12:30:00], accepted: ~N[2020-01-01 12:00:00])

      {sla, prev_sla} =
        setup_match_slas(match, :pickup, nil, {:acceptance, ~U[2020-01-01 00:00:00Z]})

      assert %{
               type: :pickup,
               start_time: ~U[2020-01-01 12:30:00Z],
               end_time: ~U[2020-01-01 13:15:00Z],
               driver_id: nil
             } = SLAs.build_match_sla(sla, prev_sla)

      {driver_sla, prev_driver_sla} = setup_match_slas(match, :pickup, driver_id)

      assert %{
               type: :pickup,
               start_time: ~U[2020-01-01 12:00:00Z],
               end_time: ~U[2020-01-01 13:15:00Z],
               driver_id: ^driver_id
             } = SLAs.build_match_sla(driver_sla, prev_driver_sla)
    end

    test "calculates :duration_before_time pickup SLA when start_time is after end time on Match" do
      slas = [@pickup_duration_before_time_sla]
      %{id: driver_id} = driver = insert(:driver)

      match =
        setup_sla_match(slas, driver, ~N[2020-01-01 14:00:00], accepted: ~N[2020-01-01 15:00:00])

      {sla, prev_sla} =
        setup_match_slas(match, :pickup, nil, {:acceptance, ~U[2020-01-01 00:00:00Z]})

      assert %{
               type: :pickup,
               start_time: ~U[2020-01-01 14:00:00Z],
               end_time: ~U[2020-01-01 14:25:00Z],
               driver_id: nil
             } = SLAs.build_match_sla(sla, prev_sla)

      {driver_sla, prev_driver_sla} = setup_match_slas(match, :pickup, driver_id)

      assert %{
               type: :pickup,
               start_time: ~U[2020-01-01 15:00:00Z],
               end_time: ~U[2020-01-01 15:25:00Z],
               driver_id: ^driver_id
             } = SLAs.build_match_sla(driver_sla, prev_driver_sla)
    end

    test "calculates :end_time frayt + driver pickup SLA" do
      slas = [@pickup_end_time_sla]
      %{id: driver_id} = driver = insert(:driver)

      match = setup_sla_match(slas, driver, nil, accepted: ~N[2020-01-01 12:00:00])

      {sla, prev_sla} =
        setup_match_slas(match, :pickup, nil, {:acceptance, ~U[2020-01-01 00:00:00Z]})

      assert %{
               type: :pickup,
               start_time: ~U[2020-01-01 00:00:00Z],
               end_time: ~U[2020-01-01 13:00:00Z],
               driver_id: nil
             } = SLAs.build_match_sla(sla, prev_sla)

      {driver_sla, prev_driver_sla} = setup_match_slas(match, :pickup, driver_id)

      assert %{
               type: :pickup,
               start_time: ~U[2020-01-01 12:00:00Z],
               end_time: ~U[2020-01-01 13:00:00Z],
               driver_id: ^driver_id
             } = SLAs.build_match_sla(driver_sla, prev_driver_sla)
    end

    test "calculates :end_time frayt + driver pickup SLA for sheduled Match" do
      slas = [@pickup_end_time_sla]
      %{id: driver_id} = driver = insert(:driver)

      match =
        setup_sla_match(slas, driver, ~N[2020-01-01 12:30:00], accepted: ~N[2020-01-01 11:00:00])

      {sla, prev_sla} =
        setup_match_slas(match, :pickup, nil, {:acceptance, ~U[2020-01-01 00:00:00Z]})

      assert %{
               type: :pickup,
               start_time: ~U[2020-01-01 12:30:00Z],
               end_time: ~U[2020-01-01 13:00:00Z],
               driver_id: nil
             } = SLAs.build_match_sla(sla, prev_sla)

      {driver_sla, prev_driver_sla} = setup_match_slas(match, :pickup, driver_id)

      assert %{
               type: :pickup,
               start_time: ~U[2020-01-01 11:00:00Z],
               end_time: ~U[2020-01-01 13:00:00Z],
               driver_id: ^driver_id
             } = SLAs.build_match_sla(driver_sla, prev_driver_sla)
    end

    test "calculates :end_time pickup SLA when start_time is after end time on Match" do
      slas = [@pickup_end_time_sla]
      %{id: driver_id} = driver = insert(:driver)

      match =
        setup_sla_match(slas, driver, ~N[2020-01-01 14:00:00], accepted: ~N[2020-01-01 15:00:00])

      {sla, prev_sla} =
        setup_match_slas(match, :pickup, nil, {:acceptance, ~U[2020-01-01 00:00:00Z]})

      assert %{
               type: :pickup,
               start_time: ~U[2020-01-01 14:00:00Z],
               end_time: ~U[2020-01-01 14:30:00Z],
               driver_id: nil
             } = SLAs.build_match_sla(sla, prev_sla)

      {driver_sla, prev_driver_sla} = setup_match_slas(match, :pickup, driver_id)

      assert %{
               type: :pickup,
               start_time: ~U[2020-01-01 15:00:00Z],
               end_time: ~U[2020-01-01 15:30:00Z],
               driver_id: ^driver_id
             } = SLAs.build_match_sla(driver_sla, prev_driver_sla)
    end

    test "calculates default frayt + driver delivery SLA" do
      slas = [@delivery_default_sla]
      %{id: driver_id} = driver = insert(:driver)

      match = setup_sla_match(slas, driver)

      {sla, prev_sla} =
        setup_match_slas(match, :delivery, nil, {:pickup, ~U[2020-01-01 09:00:00Z]})

      assert %{
               type: :delivery,
               start_time: ~U[2020-01-01 09:00:00Z],
               end_time: ~U[2020-01-01 10:00:00Z],
               driver_id: nil
             } = SLAs.build_match_sla(sla, prev_sla)

      {driver_sla, prev_driver_sla} =
        setup_match_slas(match, :delivery, driver_id, {:pickup, ~U[2020-01-01 10:00:00Z]})

      assert %{
               type: :delivery,
               start_time: ~U[2020-01-01 10:00:00Z],
               end_time: ~U[2020-01-01 11:00:00Z],
               driver_id: ^driver_id
             } = SLAs.build_match_sla(driver_sla, prev_driver_sla)
    end

    test "calculates default frayt + driver delivery SLA for scheduled match" do
      slas = [@delivery_default_sla]
      %{id: driver_id} = driver = insert(:driver)

      match = setup_sla_match(slas, driver, ~N[2020-01-01 16:00:00])

      {sla, prev_sla} =
        setup_match_slas(match, :delivery, nil, {:pickup, ~U[2020-01-01 09:00:00Z]})

      assert %{
               type: :delivery,
               start_time: ~U[2020-01-01 09:00:00Z],
               end_time: ~U[2020-01-01 16:00:00Z],
               driver_id: nil
             } = SLAs.build_match_sla(sla, prev_sla)

      {driver_sla, prev_driver_sla} =
        setup_match_slas(match, :delivery, driver_id, {:pickup, ~U[2020-01-01 10:00:00Z]})

      assert %{
               type: :delivery,
               start_time: ~U[2020-01-01 10:00:00Z],
               end_time: ~U[2020-01-01 16:00:00Z],
               driver_id: ^driver_id
             } = SLAs.build_match_sla(driver_sla, prev_driver_sla)
    end

    test "calculates :duration_before_time frayt + driver delivery SLA" do
      slas = [@delivery_duration_before_time_sla]
      %{id: driver_id} = driver = insert(:driver)

      match = setup_sla_match(slas, driver)

      {sla, prev_sla} =
        setup_match_slas(match, :delivery, nil, {:pickup, ~U[2020-01-01 09:00:00Z]})

      assert %{
               type: :delivery,
               start_time: ~U[2020-01-01 09:00:00Z],
               end_time: ~U[2020-01-01 14:28:00Z],
               driver_id: nil
             } = SLAs.build_match_sla(sla, prev_sla)

      {driver_sla, prev_driver_sla} =
        setup_match_slas(match, :delivery, driver_id, {:pickup, ~U[2020-01-01 10:00:00Z]})

      assert %{
               type: :delivery,
               start_time: ~U[2020-01-01 10:00:00Z],
               end_time: ~U[2020-01-01 14:28:00Z],
               driver_id: ^driver_id
             } = SLAs.build_match_sla(driver_sla, prev_driver_sla)
    end

    test "calculates :duration_before_time frayt + driver delivery SLA ignores sheduled time on Match" do
      slas = [@delivery_duration_before_time_sla]
      %{id: driver_id} = driver = insert(:driver)

      match = setup_sla_match(slas, driver, ~N[2020-01-01 17:00:00])

      {sla, prev_sla} =
        setup_match_slas(match, :delivery, nil, {:pickup, ~U[2020-01-01 09:00:00Z]})

      assert %{
               type: :delivery,
               start_time: ~U[2020-01-01 09:00:00Z],
               end_time: ~U[2020-01-01 14:28:00Z],
               driver_id: nil
             } = SLAs.build_match_sla(sla, prev_sla)

      {driver_sla, prev_driver_sla} =
        setup_match_slas(match, :delivery, driver_id, {:pickup, ~U[2020-01-01 10:00:00Z]})

      assert %{
               type: :delivery,
               start_time: ~U[2020-01-01 10:00:00Z],
               end_time: ~U[2020-01-01 14:28:00Z],
               driver_id: ^driver_id
             } = SLAs.build_match_sla(driver_sla, prev_driver_sla)
    end

    test "calculates :end_time frayt + driver delivery SLA" do
      slas = [@delivery_end_time_sla]
      %{id: driver_id} = driver = insert(:driver)

      match = setup_sla_match(slas, driver)

      {sla, prev_sla} =
        setup_match_slas(match, :delivery, nil, {:pickup, ~U[2020-01-01 09:00:00Z]})

      assert %{
               type: :delivery,
               start_time: ~U[2020-01-01 09:00:00Z],
               end_time: ~U[2020-01-01 14:00:00Z],
               driver_id: nil
             } = SLAs.build_match_sla(sla, prev_sla)

      {driver_sla, prev_driver_sla} =
        setup_match_slas(match, :delivery, driver_id, {:pickup, ~U[2020-01-01 10:00:00Z]})

      assert %{
               type: :delivery,
               start_time: ~U[2020-01-01 10:00:00Z],
               end_time: ~U[2020-01-01 14:00:00Z],
               driver_id: ^driver_id
             } = SLAs.build_match_sla(driver_sla, prev_driver_sla)
    end

    test "calculates :end_time frayt + driver delivery SLA ignores sheduled time on Match" do
      slas = [@delivery_end_time_sla]
      %{id: driver_id} = driver = insert(:driver)

      match = setup_sla_match(slas, driver, ~N[2020-01-01 17:00:00])

      {sla, prev_sla} =
        setup_match_slas(match, :delivery, nil, {:pickup, ~U[2020-01-01 09:00:00Z]})

      assert %{
               type: :delivery,
               start_time: ~U[2020-01-01 09:00:00Z],
               end_time: ~U[2020-01-01 14:00:00Z],
               driver_id: nil
             } = SLAs.build_match_sla(sla, prev_sla)

      {driver_sla, prev_driver_sla} =
        setup_match_slas(match, :delivery, driver_id, {:pickup, ~U[2020-01-01 10:00:00Z]})

      assert %{
               type: :delivery,
               start_time: ~U[2020-01-01 10:00:00Z],
               end_time: ~U[2020-01-01 14:00:00Z],
               driver_id: ^driver_id
             } = SLAs.build_match_sla(driver_sla, prev_driver_sla)
    end

    test "calculates a SLA with all variables" do
      c = insert(:contract, slas: [@delivery_variable_sla])

      sla_pickup_modifier = 8
      total_distance = 10
      travel_duration = 15
      stop_count = 1
      stop_delivery_time = 5
      vehicle_load_time = 10

      duration =
        sla_pickup_modifier + travel_duration + vehicle_load_time + total_distance +
          stop_count * stop_delivery_time

      %{id: match_id} =
        m =
        insert(:match,
          vehicle_class: 1,
          contract: c,
          total_distance: total_distance,
          travel_duration: travel_duration * 60,
          market: build(:market, sla_pickup_modifier: sla_pickup_modifier),
          driver: nil,
          slas: []
        )

      start_time = ~U[2020-01-01 00:00:00Z]
      end_time = DateTime.add(start_time, duration * 60)

      pickup_sla = insert(:match_sla, match: m, type: :pickup, end_time: start_time, driver: nil)

      delivery_sla = build(:match_sla, match: m, type: :delivery, start_time: nil, end_time: nil)

      assert %{
               match_id: match_id,
               driver_id: nil,
               type: :delivery,
               start_time: start_time,
               end_time: end_time
             } == SLAs.build_match_sla(delivery_sla, pickup_sla)
    end

    test "calculates a SLA with all variables: stop_count equals # of stops and market modifier default to 0" do
      c = insert(:contract, slas: [@delivery_variable_sla])

      sla_pickup_modifier = 0
      total_distance = 10
      travel_duration = 15
      stop_count = 3
      stop_delivery_time = 5
      vehicle_load_time = 10

      duration =
        sla_pickup_modifier + travel_duration + vehicle_load_time + total_distance +
          stop_count * stop_delivery_time

      %{id: match_id} =
        m =
        insert(:match,
          vehicle_class: 1,
          contract: c,
          total_distance: total_distance,
          travel_duration: travel_duration * 60,
          driver: nil,
          slas: [],
          match_stops: build_list(3, :match_stop)
        )

      start_time = ~U[2020-01-01 00:00:00Z]
      end_time = DateTime.add(start_time, duration * 60)

      pickup_sla = insert(:match_sla, match: m, type: :pickup, end_time: start_time, driver: nil)

      delivery_sla = build(:match_sla, match: m, type: :delivery, start_time: nil, end_time: nil)

      assert %{
               match_id: match_id,
               driver_id: nil,
               type: :delivery,
               start_time: start_time,
               end_time: end_time
             } == SLAs.build_match_sla(delivery_sla, pickup_sla)
    end

    test "uses local Match timezone for :end_time slas" do
      match =
        insert(:match,
          driver: nil,
          contract: insert(:contract, slas: [@delivery_end_time_sla]),
          timezone: "America/New_York"
        )

      {sla, prev_sla} =
        setup_match_slas(match, :delivery, nil, {:pickup, ~U[2020-01-01 07:00:00Z]})

      end_time = DateTime.new!(~D[2020-01-01], ~T[14:00:00], "America/New_York")

      assert %{
               type: :delivery,
               start_time: ~U[2020-01-01 07:00:00Z],
               end_time: ^end_time,
               driver_id: nil
             } = SLAs.build_match_sla(sla, prev_sla)
    end

    test "uses local Match timezone for :duration_before_time slas" do
      match =
        insert(:match,
          driver: nil,
          contract: insert(:contract, slas: [@delivery_duration_before_time_sla]),
          timezone: "America/New_York"
        )

      {sla, prev_sla} =
        setup_match_slas(match, :delivery, nil, {:pickup, ~U[2020-01-01 07:00:00Z]})

      end_time = DateTime.new!(~D[2020-01-01], ~T[14:28:00], "America/New_York")

      assert %{
               type: :delivery,
               start_time: ~U[2020-01-01 07:00:00Z],
               end_time: ^end_time,
               driver_id: nil
             } = SLAs.build_match_sla(sla, prev_sla)
    end

    test "uses default contract slas when no contract" do
      match =
        insert(:match,
          driver: nil,
          contract: nil,
          service_level: 2
        )

      {sla, prev_sla} =
        setup_match_slas(match, :delivery, nil, {:pickup, ~U[2020-01-01 07:00:00Z]})

      assert %{
               type: :delivery,
               start_time: ~U[2020-01-01 07:00:00Z],
               end_time: ~U[2020-01-01 17:00:00Z],
               driver_id: nil
             } = SLAs.build_match_sla(sla, prev_sla)
    end

    test "uses default contract slas contract does not have corresponding slas" do
      match =
        insert(:match,
          driver: nil,
          contract: insert(:contract, slas: []),
          service_level: 2
        )

      {sla, prev_sla} =
        setup_match_slas(match, :delivery, nil, {:pickup, ~U[2020-01-01 07:00:00Z]})

      assert %{
               type: :delivery,
               start_time: ~U[2020-01-01 07:00:00Z],
               end_time: ~U[2020-01-01 17:00:00Z],
               driver_id: nil
             } = SLAs.build_match_sla(sla, prev_sla)
    end
  end
end
