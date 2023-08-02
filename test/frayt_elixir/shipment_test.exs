defmodule FraytElixir.ShipmentTest do
  use FraytElixir.DataCase
  use Bamboo.Test

  alias FraytElixir.Shipment

  alias FraytElixir.Shipment.{
    Match,
    MatchStop,
    MatchFee,
    MatchStateTransition,
    ETA
  }

  alias FraytElixir.Payments.{PaymentTransaction}
  alias FraytElixir.Accounts.{Shipper, Location, Company}

  alias FraytElixir.Repo

  import FraytElixir.Factory
  import FraytElixir.Test.StartMatchSupervisor

  setup :start_match_supervisor

  describe "get_live_stop_state" do
    test "returns pending if no matches are live" do
      match = insert(:picked_up_match)

      assert :pending = Shipment.get_live_stop_state(match)
    end

    test "returns delivered if all stops are complete" do
      match = insert(:completed_match)

      assert :delivered = Shipment.get_live_stop_state(match)
    end

    test "returns the live state if a match stop is in a live state" do
      match = insert(:en_route_to_dropoff_match)

      assert :en_route = Shipment.get_live_stop_state(match)
    end

    test "returns nil if a stop has no match stops" do
      match = insert(:picked_up_match, %{match_stops: []})

      assert nil == Shipment.get_live_stop_state(match)
    end
  end

  describe "get_deprecated_match_state" do
    test "returns picked_up if no match stops have been marked en_route" do
      match = insert(:picked_up_match)

      assert :picked_up == Shipment.get_deprecated_match_state(match)
    end

    test "returns en_route_to_dropoff from a match with a stop marked en_route" do
      match = insert(:en_route_to_dropoff_match)

      assert :en_route_to_dropoff == Shipment.get_deprecated_match_state(match)
    end

    test "returns en_route_to_dropoff if any match stop has been marked delivered or undeliverable if no other stops are live" do
      match = insert(:delivered_match)

      assert :en_route_to_dropoff == Shipment.get_deprecated_match_state(match)
    end

    test "returns arrived_at_dropoff is any stop is in arrived state" do
      match = insert(:arrived_at_dropoff_match)

      assert :arrived_at_dropoff == Shipment.get_deprecated_match_state(match)
    end

    test "returns signed if any stop is in signed state" do
      match = insert(:signed_match)

      assert :signed == Shipment.get_deprecated_match_state(match)
    end

    test "returns delivered if a match is completed" do
      match = insert(:completed_match)

      assert :delivered == Shipment.get_deprecated_match_state(match)
    end

    test "returns the match state if the match state is not picked_up or completed" do
      match = insert(:assigning_driver_match)

      assert :assigning_driver == Shipment.get_deprecated_match_state(match)
    end
  end

  describe "matches" do
    test "get_match!/1 returns the match with given id" do
      match = insert(:match)
      fetched_match = Shipment.get_match!(match.id)
      assert fetched_match.id == match.id
    end

    test "get_match/1 returns the match with given id" do
      match = insert(:match)
      fetched_match = Shipment.get_match(match.id)
      assert fetched_match.id == match.id
    end

    test "get_match/1 returns nil with non existant id" do
      refute Shipment.get_match("0080e749-44ef-4af3-b246-acad32856289")
    end

    test "get_match/1 returns nil with gibberish id" do
      refute Shipment.get_match("fdjashfkas")
    end

    test "get_match preloads and sorts match stops" do
      # not related match stop
      insert(:match_stop)

      match =
        insert(:match,
          match_stops: [
            build(:match_stop, index: 2),
            build(:match_stop, index: 0),
            build(:match_stop, index: 1)
          ]
        )

      assert %Match{
               match_stops: [%MatchStop{index: 0}, %MatchStop{index: 1}, %MatchStop{index: 2}]
             } = Shipment.get_match(match.id)
    end

    test "get_match_stop/1 returns the match with given id" do
      match_stop = insert(:match_stop)
      fetched_match_stop = Shipment.get_match_stop(match_stop.id)
      assert fetched_match_stop.id == match_stop.id
    end

    test "get_match_stop/1 returns nil with gibberish id" do
      refute Shipment.get_match_stop("fdjashfkas")
    end

    test "get_match_stop/1 returns nil with nil" do
      refute Shipment.get_match_stop(nil)
    end

    test "get_match_payment_totals/1 returns correct values with given id" do
      [match1, match2] = insert_list(2, :match)

      insert(:payment_transaction,
        status: "succeeded",
        transaction_type: "capture",
        amount: 123_00,
        match: match1
      )

      insert(:payment_transaction,
        status: "succeeded",
        transaction_type: "transfer",
        amount: 104_00,
        match: match1
      )

      insert(:driver_bonus,
        payment_transaction:
          build(:payment_transaction,
            status: "succeeded",
            transaction_type: "transfer",
            amount: 13_00,
            match: match1
          )
      )

      insert(:payment_transaction,
        status: "succeeded",
        transaction_type: "transfer",
        amount: 63_00,
        match: match2
      )

      insert(:payment_transaction,
        status: "failed",
        transaction_type: "transfer",
        amount: 63_00,
        match: match2
      )

      insert(:payment_transaction,
        status: "succeeded",
        transaction_type: "transfer",
        amount: 63_00,
        match: match2
      )

      insert(:payment_transaction,
        status: "failed",
        transaction_type: "capture",
        amount: 300,
        match: match2
      )

      insert(:payment_transaction,
        status: "succeeded",
        transaction_type: "capture",
        amount: 163_00,
        match: match2
      )

      assert Shipment.get_match_payment_totals(match1.id) == %{
               total_charged: 123_00,
               driver_paid: 117_00,
               total_refunded: 0
             }

      assert Shipment.get_match_payment_totals(match2.id) == %{
               total_charged: 163_00,
               driver_paid: 126_00,
               total_refunded: 0
             }
    end

    test "get_shipper_match/2 returns a shipper's match with given id" do
      shipper = insert(:shipper)
      match = insert(:match, shipper: shipper)
      assert %Match{} = fetched_match = Shipment.get_shipper_match(shipper, match.id)
      assert fetched_match.id == match.id
    end

    test "get_shipper_match/2 returns a shipperless match with given id" do
      shipper = insert(:shipper)
      match = insert(:match, shipper: nil)
      assert %Match{} = fetched_match = Shipment.get_shipper_match(shipper, match.id)
      assert fetched_match.id == match.id
    end

    test "get_shipper_match/2 returns nil when match is not shipper's" do
      shipper = insert(:shipper)
      match = insert(:match)
      refute Shipment.get_shipper_match(shipper, match.id)
    end

    test "get_shipper_match/2 returns nil when gibberish is passed for match id" do
      shipper = insert(:shipper)
      refute Shipment.get_shipper_match(shipper, "fsadfasfd")
    end

    test "get_shipper_match/2 returns nil when nil is passed for shipper" do
      shipper = insert(:shipper)
      match = insert(:match, shipper: shipper)
      refute Shipment.get_shipper_match(nil, match.id)
    end

    test "get_shipper_match/2 returns match when nil is passed for shipper and match does not have shipper" do
      %Match{id: match_id} = match = insert(:match, shipper: nil)
      assert %Match{id: ^match_id} = Shipment.get_shipper_match(nil, match.id)
    end
  end

  describe "distance" do
    test "calculate distance" do
      assert {:ok, 1.7, [1.7], 153} =
               Shipment.calculate_distance([
                 {39.4447149, -83.835747},
                 {39.1332503, -83.6589824}
               ])
    end

    test "sums up multiple stops" do
      assert {:ok, 10.0, [5.0, 5.0], 900} =
               Shipment.calculate_distance([
                 {39.45116874711756, -83.80203187465668},
                 {39.4447149, -83.835747},
                 {39.1332503, -83.6589824}
               ])
    end

    test "convert_to_miles converts a given metric input to a result in miles" do
      assert 10 == Shipment.convert_to_miles(16_093.4)
    end

    test "convert_to_miles returns small distances as a minimum of 0.1 miles" do
      assert 0.1 == Shipment.convert_to_miles(50)
    end
  end

  describe "list_matches/1" do
    @default_args %{
      page: 0,
      per_page: 10,
      order_by: :inserted_at,
      order: :asc,
      query: nil,
      states: nil,
      types: nil,
      company_id: nil,
      contract_id: nil,
      shipper_id: nil,
      driver_id: nil,
      only_mine: nil,
      stops: nil,
      start_date: nil,
      end_date: nil,
      sla: nil
    }

    test "returns matches without a driver" do
      match = insert(:match, driver: nil)

      matches =
        Shipment.list_matches(%{@default_args | query: match.id})
        |> elem(0)
        |> Enum.map(& &1.id)

      assert matches == [match.id]
    end

    test "returns proper set of matches" do
      insert_list(15, :match, state: :assigning_driver, po: "Abe")
      insert_list(5, :match, state: :assigning_driver, po: "Zora")

      matches =
        Shipment.list_matches(%{
          @default_args
          | page: 7,
            per_page: 2,
            order_by: :po
        })
        |> elem(0)

      assert Enum.count(matches) == 2
      assert List.first(matches).po == "Abe"
      assert List.last(matches).po == "Zora"

      matches =
        Shipment.list_matches(%{
          @default_args
          | page: 2,
            per_page: 2,
            order_by: :po,
            query: "Zora"
        })
        |> elem(0)

      assert Enum.count(matches) == 1
      assert List.first(matches).po == "Zora"
    end

    test "can filter by states" do
      insert(:match, state: :pending)
      insert(:match, state: :assigning_driver)
      insert(:match, state: :scheduled)
      insert(:match, state: :accepted)
      insert(:match, state: :en_route_to_pickup)
      insert(:match, state: :picked_up)
      insert(:match, state: :completed)

      matches =
        Shipment.list_matches(@default_args)
        |> elem(0)

      assert Enum.count(matches) == 6

      matches =
        Shipment.list_matches(%{@default_args | states: :active})
        |> elem(0)

      assert Enum.count(matches) == 4
    end

    test "can filter by stops" do
      insert(:match, match_stops: build_match_stops_with_items([:pending]))
      insert(:match, match_stops: build_match_stops_with_items([:pending]))
      insert(:match, match_stops: build_match_stops_with_items([:pending, :pending]))
      insert(:match, match_stops: build_match_stops_with_items([:pending, :pending]))
      insert(:match, match_stops: build_match_stops_with_items([:pending, :pending]))

      matches =
        Shipment.list_matches(@default_args)
        |> elem(0)

      assert Enum.count(matches) == 5

      matches =
        Shipment.list_matches(%{@default_args | stops: :multi})
        |> elem(0)

      assert Enum.count(matches) == 3

      matches =
        Shipment.list_matches(%{@default_args | stops: :single})
        |> elem(0)

      assert Enum.count(matches) == 2
    end

    test "can filter by company" do
      shipper = insert(:shipper_with_location)
      shipper2 = insert(:shipper_with_location, location: shipper.location)

      company = shipper.location.company
      insert(:accepted_match, shipper: shipper)
      insert(:accepted_match, shipper: shipper)
      insert(:accepted_match, shipper: shipper2)
      insert(:accepted_match)

      matches =
        Shipment.list_matches(@default_args)
        |> elem(0)

      assert Enum.count(matches) == 4

      matches =
        Shipment.list_matches(%{@default_args | company_id: company.id})
        |> elem(0)

      assert Enum.count(matches) == 3
    end

    test "can filter by contract" do
      contract = insert(:contract)

      insert(:accepted_match, contract: contract)
      insert(:accepted_match, contract: contract)
      insert(:accepted_match, contract: insert(:contract))
      insert(:accepted_match, contract: nil)

      assert {matches, 1} = Shipment.list_matches(@default_args)

      assert Enum.count(matches) == 4

      assert {matches, 1} = Shipment.list_matches(%{@default_args | contract_id: contract.id})

      assert Enum.count(matches) == 2
    end

    test "can filter by shipper" do
      shipper = insert(:shipper)

      insert(:accepted_match, shipper: shipper)
      insert(:accepted_match, shipper: shipper)
      insert(:accepted_match, shipper: insert(:shipper))
      insert(:accepted_match, shipper: nil)

      assert {matches, 1} = Shipment.list_matches(@default_args)

      assert Enum.count(matches) == 4

      assert {matches, 1} = Shipment.list_matches(%{@default_args | shipper_id: shipper.id})

      assert Enum.count(matches) == 2
    end

    test "can filter by driver" do
      driver = insert(:driver)

      insert(:accepted_match, driver: driver)
      insert(:accepted_match, driver: driver)
      insert(:accepted_match, driver: insert(:driver))
      insert(:accepted_match, driver: nil)

      assert {matches, 1} = Shipment.list_matches(@default_args)

      assert Enum.count(matches) == 4

      assert {matches, 1} = Shipment.list_matches(%{@default_args | driver_id: driver.id})

      assert Enum.count(matches) == 2
    end

    test "query filters properly by date range" do
      insert(:match,
        origin_address: build(:address, city: "Sunnyvale", state: "California"),
        state_transitions: [
          insert(:match_state_transition,
            from: :pending,
            to: :assigning_driver,
            inserted_at: ~N[2020-12-20 11:00:00]
          )
        ]
      )

      insert(:match,
        origin_address: build(:address, city: "Cincinnati", state: "Ohio"),
        state_transitions: [
          insert(:match_state_transition,
            from: :pending,
            to: :assigning_driver,
            inserted_at: ~N[2020-12-22 11:00:00]
          )
        ]
      )

      matches =
        Shipment.list_matches(%{@default_args | page: 0, per_page: 2})
        |> elem(0)

      assert Enum.count(matches) == 2

      matches =
        Shipment.list_matches(%{
          @default_args
          | start_date: "2020-12-20T04:00:00.000Z",
            end_date: "2020-12-21T04:59:59.999Z",
            page: 0,
            per_page: 2
        })
        |> elem(0)

      assert Enum.count(matches) == 1
      assert List.first(matches).origin_address.city == "Sunnyvale"
    end

    test "date range filters scheduled matches based on pickup_at time" do
      insert(:match,
        scheduled: true,
        pickup_at: ~N[2020-12-23 11:00:00],
        origin_address: build(:address, city: "Sunnyvale", state: "California"),
        state_transitions: [
          insert(:match_state_transition,
            from: :pending,
            to: :assigning_driver,
            inserted_at: ~N[2020-12-20 11:00:00]
          )
        ]
      )

      insert(:match,
        origin_address: build(:address, city: "Cincinnati", state: "Ohio"),
        state_transitions: [
          insert(:match_state_transition,
            from: :pending,
            to: :assigning_driver,
            inserted_at: ~N[2020-12-22 11:00:00]
          )
        ]
      )

      matches =
        Shipment.list_matches(%{@default_args | page: 0, per_page: 2})
        |> elem(0)

      assert Enum.count(matches) == 2

      matches =
        Shipment.list_matches(%{
          @default_args
          | start_date: "2020-12-23T04:00:00.000Z",
            end_date: "2020-12-24T04:59:59.999Z",
            page: 0,
            per_page: 2
        })
        |> elem(0)

      assert Enum.count(matches) == 1
      assert List.first(matches).origin_address.city == "Sunnyvale"
    end

    test "can filter matches by date range and other filters together" do
      insert(:match,
        origin_address: build(:address, city: "Sunnyvale", state: "California"),
        state_transitions: [
          insert(:match_state_transition,
            from: :pending,
            to: :assigning_driver,
            inserted_at: ~N[2020-12-20 11:00:00]
          )
        ]
      )

      insert(:completed_match,
        origin_address: build(:address, city: "Cincinnati", state: "Ohio"),
        state_transitions: [
          insert(:match_state_transition,
            from: :pending,
            to: :assigning_driver,
            inserted_at: ~N[2020-12-22 11:00:00]
          )
        ]
      )

      insert(:match,
        origin_address: build(:address, city: "Cincinnati", state: "Ohio"),
        state_transitions: [
          insert(:match_state_transition,
            from: :pending,
            to: :assigning_driver,
            inserted_at: ~N[2020-12-22 12:00:00]
          )
        ]
      )

      matches =
        Shipment.list_matches(%{@default_args | page: 0, per_page: 3})
        |> elem(0)

      assert Enum.count(matches) == 3

      matches =
        Shipment.list_matches(%{
          @default_args
          | start_date: "2020-12-22T04:00:00.000Z",
            end_date: "2020-12-23T04:59:59.999Z",
            page: 0,
            per_page: 3
        })
        |> elem(0)

      assert Enum.count(matches) == 2

      matches =
        Shipment.list_matches(%{
          @default_args
          | start_date: "2020-12-22T04:00:00.000Z",
            end_date: "2020-12-23T04:59:59.999Z",
            states: :complete
        })
        |> elem(0)

      assert Enum.count(matches) == 1
    end

    test "filters by sla" do
      insert(:match,
        state: :accepted,
        slas: [
          insert(:match_sla,
            type: :pickup,
            end_time: DateTime.utc_now() |> DateTime.add(-12 * 60, :second)
          ),
          insert(:match_sla,
            type: :delivery,
            end_time: DateTime.utc_now() |> DateTime.add(20 * 60, :second)
          )
        ]
      )

      insert(:match,
        state: :picked_up,
        slas: [
          insert(:match_sla,
            type: :pickup,
            end_time: DateTime.utc_now() |> DateTime.add(-12 * 60, :second)
          ),
          insert(:match_sla,
            type: :delivery,
            end_time: DateTime.utc_now() |> DateTime.add(20 * 60, :second)
          )
        ]
      )

      insert(:match,
        state: :accepted,
        slas: [
          insert(:match_sla,
            type: :pickup,
            end_time: DateTime.utc_now() |> DateTime.add(10 * 60, :second)
          )
        ]
      )

      insert(:match, slas: [])

      matches =
        Shipment.list_matches(%{@default_args | sla: :caution})
        |> elem(0)

      assert Enum.count(matches) == 2
    end

    test "query filters properly by addresses" do
      insert(:match,
        state: :assigning_driver,
        origin_address: build(:address, city: "Cincinnati", state: "Ohio"),
        match_stops: [
          build(:match_stop, destination_address: build(:address, city: "Houston", state: "Texas"))
        ]
      )

      insert(:match,
        state: :assigning_driver,
        origin_address: build(:address, city: "Sunnyvale", state: "California"),
        match_stops: [
          build(:match_stop,
            destination_address: build(:address, city: "Louisville", state: "Kentucky")
          )
        ]
      )

      matches =
        Shipment.list_matches(@default_args)
        |> elem(0)

      assert Enum.count(matches) == 2

      matches =
        Shipment.list_matches(%{@default_args | query: "Sunnyvale"})
        |> elem(0)

      assert Enum.count(matches) == 1
      assert List.first(matches).origin_address.city == "Sunnyvale"
    end

    test "order_by :service_level orders by level, pickup_time, then dropoff_time" do
      now = DateTime.from_naive!(~N[2030-10-29 11:30:00], "Etc/UTC")
      m5 = insert(:accepted_match, service_level: 2, inserted_at: now)

      m1 =
        insert(:accepted_match,
          pickup_at: ~N[2030-10-30 13:00:00],
          dropoff_at: ~N[2030-10-31 13:00:00],
          service_level: 1,
          inserted_at: DateTime.add(now, 1 * 60)
        )

      m2 =
        insert(:accepted_match,
          pickup_at: ~N[2030-10-30 12:00:00],
          dropoff_at: ~N[2030-10-31 12:00:00],
          service_level: 1,
          inserted_at: DateTime.add(now, 2 * 60)
        )

      m3 =
        insert(:accepted_match,
          pickup_at: ~N[2030-10-30 13:00:00],
          dropoff_at: ~N[2030-10-31 11:00:00],
          service_level: 1,
          inserted_at: DateTime.add(now, 3 * 60)
        )

      m4 =
        insert(:accepted_match,
          pickup_at: ~N[2030-10-30 13:00:00],
          service_level: 1,
          inserted_at: DateTime.add(now, 4 * 60)
        )

      assert Shipment.list_matches(@default_args)
             |> elem(0)
             |> Enum.map(& &1.id) == [m5.id, m1.id, m2.id, m3.id, m4.id]

      assert Shipment.list_matches(%{@default_args | order_by: :service_level})
             |> elem(0)
             |> Enum.map(& &1.id) == [m2.id, m3.id, m1.id, m4.id, m5.id]
    end

    test "order by sla" do
      m1 =
        insert(:assigning_driver_match,
          slas: [insert(:match_sla, type: :acceptance, end_time: ~U[2020-01-01 11:00:00Z])],
          inserted_at: ~N[2020-01-01 00:00:00Z]
        )

      m2 =
        insert(:accepted_match,
          slas: [
            insert(:match_sla, type: :acceptance, end_time: ~U[2020-01-01 12:00:00Z]),
            insert(:match_sla, type: :pickup, end_time: ~U[2020-01-01 13:00:00Z]),
            insert(:match_sla, type: :delivery, end_time: ~U[2020-01-01 14:00:00Z])
          ],
          inserted_at: ~N[2020-01-01 00:00:00Z]
        )

      m3 =
        insert(:arrived_at_pickup_match,
          slas: [
            insert(:match_sla, type: :acceptance, end_time: ~U[2020-01-02 12:00:00Z]),
            insert(:match_sla, type: :pickup, end_time: ~U[2020-01-02 13:00:00Z]),
            insert(:match_sla, type: :delivery, end_time: ~U[2020-01-02 14:00:00Z])
          ],
          inserted_at: ~N[2020-01-01 00:00:00Z]
        )

      m4 =
        insert(:picked_up_match,
          slas: [
            insert(:match_sla, type: :acceptance, end_time: ~U[2020-01-01 01:00:00Z]),
            insert(:match_sla, type: :pickup, end_time: ~U[2020-01-01 02:00:00Z]),
            insert(:match_sla, type: :delivery, end_time: ~U[2020-01-01 03:00:00Z])
          ],
          inserted_at: ~N[2020-01-01 00:00:00Z]
        )

      m5 =
        insert(:completed_match,
          slas: [
            insert(:match_sla, type: :acceptance, end_time: ~U[2020-01-01 21:00:00Z]),
            insert(:match_sla, type: :pickup, end_time: ~U[2020-01-01 22:00:00Z]),
            insert(:match_sla, type: :delivery, end_time: ~U[2020-01-01 23:00:00Z])
          ],
          inserted_at: ~N[2020-01-01 10:00:00Z]
        )

      m6 = insert(:scheduled_match, slas: [], inserted_at: ~N[2020-01-01 00:00:00Z])

      m7 =
        insert(:picked_up_match,
          slas: [
            insert(:match_sla, type: :acceptance, end_time: ~U[2020-01-01 21:00:00Z], driver: nil),
            insert(:match_sla, type: :pickup, end_time: ~U[2020-01-01 22:00:00Z], driver: nil),
            insert(:match_sla, type: :delivery, end_time: ~U[2020-01-01 23:00:00Z], driver: nil),
            insert(:match_sla,
              type: :pickup,
              end_time: ~U[2020-01-01 23:30:00Z],
              driver: insert(:driver)
            ),
            insert(:match_sla,
              type: :delivery,
              end_time: ~U[2020-01-01 23:50:00Z],
              driver: insert(:driver)
            )
          ],
          inserted_at: ~N[2020-01-01 00:00:00Z]
        )

      args = %{@default_args | order_by: :sla}

      assert Shipment.list_matches(args)
             |> elem(0)
             |> Enum.map(& &1.id) == [m4.id, m1.id, m2.id, m7.id, m3.id, m6.id, m5.id]

      assert Shipment.list_matches(%{args | order: :desc})
             |> elem(0)
             |> Enum.map(& &1.id) == [m3.id, m7.id, m2.id, m1.id, m4.id, m5.id, m6.id]
    end
  end

  describe "list_shipper_matches/2" do
    test "returns all matches for shipper" do
      match = insert(:assigning_driver_match)
      assert {matches, 1} = Shipment.list_shipper_matches(match.shipper)
      assert matches |> Enum.map(& &1.id) == [match.id]
    end

    test "for shipper excludes pending matches" do
      shipper = insert(:shipper)
      %Match{id: assigning_driver_match_id} = insert(:assigning_driver_match, shipper: shipper)
      insert(:match, state: :pending, shipper: shipper)

      assert {matches, 1} = Shipment.list_shipper_matches(shipper)

      assert matches |> Enum.map(& &1.id) == [
               assigning_driver_match_id
             ]
    end

    test "returns only matches for shipper" do
      other_shipper = insert(:shipper)
      insert(:match, shipper: other_shipper)

      shipper = insert(:shipper)
      match = insert(:match, shipper: shipper)

      assert {matches, 1} = Shipment.list_shipper_matches(shipper)
      assert matches |> Enum.map(& &1.id) == [match.id]
    end

    test "with per_page and page paginates correctly" do
      shipper = insert(:shipper)

      match = insert(:match, shipper: shipper)
      insert(:match, shipper: shipper)

      assert {matches, 2} =
               Shipment.list_shipper_matches(shipper, %{
                 page: 1,
                 per_page: 1,
                 order_by: :total_distance
               })

      assert matches |> Enum.map(& &1.id) == [match.id]
    end

    test "filters by complete states" do
      shipper = insert(:shipper)

      insert(:match, state: :charged, shipper: shipper)
      insert(:completed_match, shipper: shipper)
      insert(:match, state: :assigning_driver, shipper: shipper)

      assert {matches, 1} =
               Shipment.list_shipper_matches(shipper, %{
                 states: :complete
               })

      assert matches
             |> Enum.map(& &1.state)
             |> Enum.sort() ==
               [
                 :charged,
                 :completed
               ]
    end

    test "filters by all states" do
      shipper = insert(:shipper)

      insert(:match, state: :pending, shipper: shipper)
      insert(:match, state: :charged, shipper: shipper)
      insert(:match, state: :canceled, shipper: shipper)
      insert(:match, state: :scheduled, shipper: shipper)
      insert(:match, state: :assigning_driver, shipper: shipper)

      assert {matches, 1} =
               Shipment.list_shipper_matches(shipper, %{
                 states: :all
               })

      assert matches
             |> Enum.map(& &1.state)
             |> Enum.sort() ==
               [
                 :assigning_driver,
                 :canceled,
                 :charged,
                 :scheduled
               ]
    end

    test "filters by active states" do
      shipper = insert(:shipper)

      insert(:match, state: :assigning_driver, shipper: shipper)
      insert(:match, state: :accepted, shipper: shipper)
      insert(:match, state: :en_route_to_pickup, shipper: shipper)
      insert(:match, state: :arrived_at_pickup, shipper: shipper)
      insert(:match, state: :picked_up, shipper: shipper)
      insert(:en_route_to_dropoff_match, shipper: shipper)
      insert(:arrived_at_dropoff_match, shipper: shipper)
      insert(:signed_match, shipper: shipper)
      insert(:match, state: :canceled, shipper: shipper)

      assert {matches, 1} =
               Shipment.list_shipper_matches(shipper, %{
                 states: :active
               })

      assert [
               :accepted,
               :arrived_at_pickup,
               :assigning_driver,
               :en_route_to_pickup,
               :picked_up,
               :picked_up,
               :picked_up,
               :picked_up
             ] ==
               matches
               |> Enum.map(& &1.state)
               |> Enum.sort()
    end

    test "filters by visible states" do
      shipper = insert(:shipper)

      insert(:match, state: :pending, shipper: shipper)
      insert(:signed_match, shipper: shipper)
      insert(:match, state: :canceled, shipper: shipper)
      assert {matches, 1} = Shipment.list_shipper_matches(shipper)

      assert [:picked_up] ==
               matches
               |> Enum.map(& &1.state)
               |> Enum.sort()
    end

    test "filters by canceled states" do
      shipper = insert(:shipper)

      insert(:match, state: :admin_canceled, shipper: shipper)
      insert(:signed_match, shipper: shipper)
      insert(:match, state: :canceled, shipper: shipper)

      assert {matches, 1} = Shipment.list_shipper_matches(shipper, %{states: :canceled})

      assert matches
             |> Enum.map(& &1.state)
             |> Enum.sort() ==
               [
                 :admin_canceled,
                 :canceled
               ]
    end

    test "filters by inactive states" do
      shipper = insert(:shipper)

      insert(:match, state: :inactive, shipper: shipper)
      insert(:signed_match, shipper: shipper)
      insert(:match, state: :canceled, shipper: shipper)

      assert {matches, 1} = Shipment.list_shipper_matches(shipper, %{states: :inactive})

      assert matches
             |> Enum.map(& &1.state)
             |> Enum.sort() ==
               [
                 :inactive
               ]
    end

    test "filters by scheduled states" do
      shipper = insert(:shipper)

      insert(:signed_match, shipper: shipper)
      insert(:match, state: :scheduled, shipper: shipper)

      assert {matches, 1} = Shipment.list_shipper_matches(shipper, %{states: :scheduled})

      assert matches
             |> Enum.map(& &1.state)
             |> Enum.sort() == [:scheduled]
    end

    test "filters by location for member" do
      location = insert(:location)
      shipper = insert(:shipper, location: location)
      other_shipper = insert(:shipper, location: location)

      insert(:match, state: :scheduled, shipper: shipper)
      insert(:match, state: :assigning_driver, shipper: other_shipper)
      insert(:match, state: :accepted)

      assert {matches, 1} = Shipment.list_shipper_matches(shipper, %{})

      assert matches
             |> Enum.map(& &1.state)
             |> Enum.sort() == [:assigning_driver, :scheduled]
    end

    test "filters by location for company admin" do
      company = insert(:company)
      location = insert(:location, company: company)
      shipper = insert(:shipper, location: location, role: :company_admin)
      other_shipper = insert(:shipper, location: location)
      external_shipper = insert(:shipper, location: insert(:location, company: company))

      insert(:match, state: :scheduled, shipper: shipper)
      insert(:match, state: :assigning_driver, shipper: other_shipper)
      insert(:match, state: :accepted, shipper: external_shipper)
      insert(:match, state: :accepted)

      assert {matches, 1} = Shipment.list_shipper_matches(shipper, %{location_id: location.id})

      assert matches
             |> Enum.map(& &1.state)
             |> Enum.sort() == [:assigning_driver, :scheduled]
    end

    test "filters by shipper for member" do
      location = insert(:location)
      shipper = insert(:shipper, location: location)
      other_shipper = insert(:shipper, location: location)

      insert(:match, state: :scheduled, shipper: shipper)
      insert(:match, state: :assigning_driver, shipper: other_shipper)

      assert {matches, 1} =
               Shipment.list_shipper_matches(shipper, %{shipper_id: other_shipper.id})

      assert matches
             |> Enum.map(& &1.state)
             |> Enum.sort() == [:assigning_driver]
    end

    test "filters by shipper for company admin" do
      location = insert(:location)
      shipper = insert(:shipper, location: location, role: :company_admin)
      other_shipper = insert(:shipper, location: location)

      insert(:match, state: :scheduled, shipper: shipper)
      insert(:match, state: :assigning_driver, shipper: other_shipper)

      assert {matches, 1} =
               Shipment.list_shipper_matches(shipper, %{shipper_id: other_shipper.id})

      assert matches
             |> Enum.map(& &1.state)
             |> Enum.sort() == [:assigning_driver]
    end

    test "does not filter for shippers outside of company for company admin" do
      shipper = insert(:shipper, location: insert(:location), role: :company_admin)
      other_shipper = insert(:shipper, location: insert(:location))

      insert(:match, state: :scheduled, shipper: shipper)
      insert(:match, state: :assigning_driver, shipper: other_shipper)

      assert {[], 0} = Shipment.list_shipper_matches(shipper, %{shipper_id: other_shipper.id})
    end

    test "does not filter for shippers outside of location for location admin" do
      company = insert(:company)

      shipper =
        insert(:shipper, location: insert(:location, company: company), role: :location_admin)

      other_shipper = insert(:shipper, location: insert(:location, company: company))

      insert(:match, state: :scheduled, shipper: shipper)
      insert(:match, state: :assigning_driver, shipper: other_shipper)

      assert {[], 0} = Shipment.list_shipper_matches(shipper, %{shipper_id: other_shipper.id})
    end

    test "with search finds matches by origin, destination, po, identifier and shortcode" do
      shipper = insert(:shipper)

      insert_list(10, :completed_match, shipper: shipper)

      match_origin =
        insert(:completed_match,
          shipper: shipper,
          origin_address: build(:address, city: "north search_string")
        )

      match_po =
        insert(:completed_match,
          shipper: shipper,
          po: "190-search_string-7890"
        )

      match_identifier =
        insert(:completed_match,
          shipper: shipper,
          identifier: "identifier_search_string"
        )

      match_shortcode =
        insert(:completed_match,
          shipper: shipper,
          shortcode: "shortcode_search_string_123"
        )

      assert {matches, 1} =
               Shipment.list_shipper_matches(shipper, %{
                 search: "search_string"
               })

      assert matches
             |> Enum.map(& &1.id)
             |> Enum.sort() ==
               [
                 match_origin.id,
                 match_po.id,
                 match_identifier.id,
                 match_shortcode.id
               ]
               |> Enum.sort()
    end

    test "with invalid page uses default" do
      shipper = insert(:shipper)

      insert_list(20, :match, shipper: shipper)

      assert {results, 2} =
               Shipment.list_shipper_matches(shipper, %{
                 page: "nonsense",
                 order_by: :total_distance,
                 per_page: 2
               })

      assert results |> Enum.count() == 10
    end

    test "with page paginates correctly" do
      shipper = insert(:shipper)

      match = insert(:match, shipper: shipper)

      insert_list(10, :match, shipper: shipper)

      assert {matches, 2} =
               Shipment.list_shipper_matches(shipper, %{page: 1, order_by: :total_distance})

      assert matches |> Enum.map(& &1.id) == [match.id]
    end

    test "orders matches correctly" do
      shipper = insert(:shipper)

      insert_list(2, :match, shipper: shipper)

      %{id: match_id} = insert(:match, shipper: shipper)

      assert {matches, 1} = Shipment.list_shipper_matches(shipper, %{order_by: :total_distance})
      assert [^match_id | _] = matches |> Enum.map(& &1.id)
    end

    test "with :desc order and order_by orders matches correctly" do
      shipper = insert(:shipper)

      insert_list(2, :match, shipper: shipper)

      %{id: match_id} = insert(:match, shipper: shipper)

      assert {matches, 1} =
               Shipment.list_shipper_matches(shipper, %{
                 order: :desc,
                 order_by: :total_distance
               })

      assert [^match_id | _] =
               matches
               |> Enum.map(& &1.id)
    end

    test "with :asc order and order_by orders matches correctly" do
      shipper = insert(:shipper)

      %{id: match_id} = insert(:match, shipper: shipper)

      insert_list(2, :match, shipper: shipper)

      assert {matches, 1} =
               Shipment.list_shipper_matches(shipper, %{order: :asc, order_by: :total_distance})

      assert [^match_id | _] =
               matches
               |> Enum.map(& &1.id)
    end
  end

  describe "update_match_slack_thread" do
    test "updates slack thread id" do
      match = insert(:match, slack_thread_id: nil)
      thread_id = "1231231231.0012000"

      assert {:ok, %Match{slack_thread_id: ^thread_id}} =
               Shipment.update_match_slack_thread(match, thread_id)
    end

    test "updates slack thread id when nil" do
      match = insert(:match, slack_thread_id: "1231231231.0012000")
      assert {:ok, %Match{slack_thread_id: nil}} = Shipment.update_match_slack_thread(match, nil)
    end
  end

  describe "get_current_match_stop" do
    test "get_current_match_stop returns the first match stop incomplete" do
      match =
        insert(
          :match,
          match_stops:
            build_match_stops_with_items([
              :undeliverable,
              :delivered,
              :pending,
              :pending
            ])
        )

      assert %MatchStop{index: 2} = Shipment.get_current_match_stop(match)
    end

    test "get_current_match_stop returns en route match stop" do
      match =
        insert(:match,
          match_stops: build_match_stops_with_items([:delivered, :pending, :en_route])
        )

      assert %MatchStop{index: 2} = Shipment.get_current_match_stop(match)
    end

    test "get_current_match_stop returns nil when all are complete" do
      match =
        insert(:match,
          match_stops: build_match_stops_with_items([:delivered, :undeliverable, :delivered])
        )

      refute Shipment.get_current_match_stop(match)
    end
  end

  describe "recent addresses" do
    @origin "641 Evangeline Rd, Cincinnati, OH 45240"
    @destination "708 Walnut St, Cincinnati, OH 45202"

    defp build_matches(shipper, count \\ 1, origin \\ @origin),
      do:
        insert_list(count, :match,
          shipper: shipper,
          origin_address: build(:address, formatted_address: origin),
          match_stops: [
            build(:match_stop,
              destination_address: build(:address, formatted_address: @destination)
            )
          ]
        )

    test "with no shipper returns empty list" do
      assert [] = Shipment.get_recent_addresses(nil)
    end

    test "recent addresses" do
      shipper = insert(:shipper)

      build_matches(shipper, 2)

      recent_addresses = Shipment.get_recent_addresses(shipper)
      assert Enum.count(recent_addresses) == 2
      assert recent_addresses |> Enum.at(0) == @origin
      assert recent_addresses |> Enum.at(1) == @destination
    end

    test "redundant addresses" do
      shipper = insert(:shipper)

      build_matches(shipper, 2)

      recent_addresses = Shipment.get_recent_addresses(shipper)
      assert Enum.count(recent_addresses) == 2
    end

    test "recent addresses for a different shipper" do
      shipper = insert(:shipper)
      other_shipper = insert(:shipper)

      build_matches(shipper, 2)
      assert Shipment.get_recent_addresses(other_shipper) == []
    end

    test "recent addresses are sorted by usage frequency" do
      shipper = insert(:shipper)

      build_matches(shipper)
      build_matches(shipper, 1, "140 Lynhurst Drive, Crossville, TN 38558")

      recent_addresses = Shipment.get_recent_addresses(shipper)
      assert Enum.count(recent_addresses) == 3
      # destination address is used twice, origin once so destination should come first
      assert recent_addresses |> Enum.at(0) == @destination
    end
  end

  describe "get_match_shortcode/1" do
    test "returns first 8 alphanumeric characters of match id" do
      match = insert(:match, shortcode: nil)
      assert String.match?(Shipment.get_match_shortcode(match), ~r/[0-9A-Z]{8}/)
    end

    test "returns existing shortcode if exists" do
      match = insert(:match, shortcode: "ABC")
      assert "ABC" == Shipment.get_match_shortcode(match)
    end
  end

  describe "list_matches_for_company" do
    test "list_matches_for_company/1 returns all matches for company" do
      company = insert(:company)
      shipper1 = insert(:shipper, location: build(:location, company: company))
      shipper2 = insert(:shipper, location: build(:location, company: company))
      match1 = insert(:match, shipper: shipper1)
      match2 = insert(:match, shipper: shipper2)

      other_company_match = insert(:match, shipper: insert(:shipper_with_location))

      assert match_ids =
               Shipment.list_matches_for_company(company.id, %{
                 limit: 10,
                 offset: 0,
                 order_by: "inserted_at",
                 descending: false
               })
               |> Enum.map(& &1.id)

      assert Enum.count(match_ids) == 2
      assert match1.id in match_ids
      assert match2.id in match_ids
      refute other_company_match.id in match_ids
    end
  end

  describe "allowable_vehicle?" do
    test "exact matches are allowed" do
      car = insert(:vehicle, vehicle_class: Shipment.vehicle_class(:car))
      car_match = insert(:match, vehicle_class: Shipment.vehicle_class(:car))
      assert Shipment.allowable_vehicle?(car_match, [car])
    end

    test "larger vehicles than required by match are allowed" do
      cargo_van = insert(:vehicle, vehicle_class: Shipment.vehicle_class(:cargo_van))
      car_match = insert(:match, vehicle_class: Shipment.vehicle_class(:car))
      assert Shipment.allowable_vehicle?(car_match, [cargo_van])
    end

    test "smaller vehicles than required by match are not allowed" do
      car = insert(:vehicle, vehicle_class: Shipment.vehicle_class(:car))
      cargo_van_match = insert(:match, vehicle_class: Shipment.vehicle_class(:cargo_van))
      refute Shipment.allowable_vehicle?(cargo_van_match, [car])
    end

    test "allowed when any vehicles match" do
      cargo_van_match = insert(:match, vehicle_class: Shipment.vehicle_class(:cargo_van))
      cargo_van = insert(:vehicle, vehicle_class: Shipment.vehicle_class(:cargo_van))
      car = insert(:vehicle, vehicle_class: Shipment.vehicle_class(:car))
      assert Shipment.allowable_vehicle?(cargo_van_match, [car, cargo_van])
    end
  end

  describe "get_company_shipper/1" do
    test "returns shipper" do
      %Company{locations: [%Location{shippers: [%Shipper{id: shipper_id}]}]} =
        company = insert(:company_with_location)

      assert %Shipper{id: ^shipper_id} = Shipment.get_company_shipper(company)
    end

    test "returns shipper when locations are not preloaded" do
      %Company{locations: [%Location{shippers: [%Shipper{id: shipper_id}]}]} =
        company = insert(:company_with_location)

      company = Repo.get(Company, company.id)

      assert %Shipper{id: ^shipper_id} = Shipment.get_company_shipper(company)
    end

    test "when company has no locations" do
      company = insert(:company, locations: [])
      refute Shipment.get_company_shipper(company)
    end

    test "when company is nil" do
      refute Shipment.get_company_shipper(nil)
    end
  end

  describe "shipper_cancel_match/2" do
    test "cancels match" do
      match = insert(:accepted_match)

      assert {:ok,
              %Match{
                state: :canceled,
                state_transitions: [%MatchStateTransition{to: :canceled, notes: "message"} | _]
              }} = Shipment.shipper_cancel_match(match, "message")
    end

    test "cancels match when restricted" do
      match = insert(:assigning_driver_match)

      assert {:ok,
              %Match{
                state: :canceled,
                state_transitions: [%MatchStateTransition{to: :canceled, notes: "message"} | _]
              }} = Shipment.shipper_cancel_match(match, "message", restricted: true)
    end

    test "uses contract to determine allowed cancellation states" do
      match =
        insert(:completed_match,
          contract: insert(:contract, allowed_cancellation_states: [:completed])
        )

      picked_up_match =
        insert(:picked_up_match,
          contract: insert(:contract, allowed_cancellation_states: [:completed])
        )

      assert {:ok,
              %Match{
                state: :canceled
              }} = Shipment.shipper_cancel_match(match, "message", restricted: true)

      assert {:error, :invalid_state, "Match cannot be cancelled in this state"} =
               Shipment.shipper_cancel_match(picked_up_match)
    end

    test "applies cancel charge when contract has matching rule" do
      match =
        insert(:assigning_driver_match,
          amount_charged: 1000,
          driver: nil,
          contract:
            insert(:contract,
              allowed_cancellation_states: [:assigning_driver],
              cancellation_pay_rules: [
                build(:cancellation_pay_rule,
                  cancellation_percent: 0.5,
                  driver_percent: 0.5
                )
              ]
            )
        )

      assert {:ok,
              %Match{
                state: :canceled,
                cancel_charge: 500,
                cancel_charge_driver_pay: nil
              }} = Shipment.shipper_cancel_match(match, "message", restricted: true)
    end

    test "can't cancel match that is picked up" do
      match = insert(:picked_up_match)

      assert {:error, :invalid_state, "A Match cannot be canceled after it is picked up"} =
               Shipment.shipper_cancel_match(match)
    end

    test "can't cancel match that is accepted when restricted" do
      match = insert(:accepted_match)

      assert {:error, :invalid_state, "Match cannot be canceled when driver has accepted."} =
               Shipment.shipper_cancel_match(match, "message", restricted: true)
    end

    test "can't cancel match that is already canceled" do
      match = insert(:canceled_match)

      assert {:error, :invalid_state, "Match has already been canceled"} =
               Shipment.shipper_cancel_match(match)
    end
  end

  describe "match_fees_for/2" do
    test "returns match fees for shipper" do
      %{
        fees: [
          %{id: _fee1_id},
          %{id: fee2_id},
          %{id: _fee3_id},
          %{id: fee4_id}
        ]
      } =
        match =
        insert(:match,
          fees: [
            build(:match_fee, amount: 0, driver_amount: 100),
            build(:match_fee, amount: 100, driver_amount: 0),
            build(:match_fee, amount: 0, driver_amount: 0),
            build(:match_fee, amount: 100, driver_amount: 100)
          ]
        )

      assert [
               %{id: ^fee2_id},
               %{id: ^fee4_id}
             ] = Shipment.match_fees_for(match, :shipper)
    end

    test "returns match fees for driver" do
      %{
        fees: [
          %{id: fee1_id},
          %{id: _fee2_id},
          %{id: _fee3_id},
          %{id: fee4_id}
        ]
      } =
        match =
        insert(:match,
          fees: [
            build(:match_fee, amount: 0, driver_amount: 100),
            build(:match_fee, amount: 100, driver_amount: 0),
            build(:match_fee, amount: 0, driver_amount: 0),
            build(:match_fee, amount: 100, driver_amount: 100)
          ]
        )

      assert [
               %{id: ^fee1_id},
               %{id: ^fee4_id}
             ] = Shipment.match_fees_for(match, :driver)
    end
  end

  describe "find_match_fee" do
    test "finds match fee by type" do
      %{fees: [%{id: fee_id}, _]} =
        match =
        insert(:match,
          fees: [build(:match_fee, type: :driver_tip), build(:match_fee, type: :route_surcharge)]
        )

      assert %MatchFee{id: ^fee_id} = Shipment.find_match_fee(match, :driver_tip)
    end

    test "returns nil when not found" do
      match =
        insert(:match,
          fees: [build(:match_fee, type: :route_surcharge)]
        )

      refute Shipment.find_match_fee(match, :driver_tip)
    end
  end

  describe "get_match_fee_price/3" do
    test "returns fee for shipper and driver" do
      match =
        insert(:match,
          fees: [build(:match_fee, type: :driver_tip, amount: 1000, driver_amount: 500)]
        )

      assert 1000 == Shipment.get_match_fee_price(match, :driver_tip, :shipper)
      assert 500 == Shipment.get_match_fee_price(match, :driver_tip, :driver)
    end

    test "returns nil when not found" do
      match = insert(:match)

      refute Shipment.get_match_fee_price(match, :driver_tip, :shipper)
    end
  end

  describe "admin_cancel_match/3" do
    test "cancels match with cancel charge and driver pay" do
      %PaymentTransaction{match: match} =
        insert(:payment_transaction,
          transaction_type: :authorize,
          status: "succeeded",
          match:
            build(:match,
              amount_charged: 2000,
              driver: build(:driver_with_wallet),
              state: :admin_canceled
            )
        )

      match = Repo.preload(match, :payment_transactions)

      assert {:ok,
              %Match{
                state: :admin_canceled,
                cancel_charge: 1000,
                cancel_charge_driver_pay: 800,
                state_transitions: [last_state_transition | _]
              }} =
               Shipment.admin_cancel_match(match, "some reason", nil, %{
                 cancellation_percent: 0.5,
                 driver_percent: 0.8
               })

      assert %{
               to: :admin_canceled,
               notes: "some reason"
             } = last_state_transition
    end

    test "cancels match w/o cancel charge" do
      %PaymentTransaction{match: match} =
        insert(:payment_transaction,
          transaction_type: :authorize,
          status: "succeeded",
          match:
            build(:match,
              amount_charged: 2000,
              driver: build(:driver_with_wallet),
              state: :admin_canceled
            )
        )

      assert {:ok,
              %Match{
                state: :admin_canceled,
                cancel_charge: nil,
                cancel_charge_driver_pay: nil
              }} = Shipment.admin_cancel_match(match, "some reason")
    end
  end

  describe "most_recent_transition/2" do
    test "gets most recent transition for given match state" do
      %MatchStateTransition{id: mst_id} =
        mst =
        insert(:match_state_transition,
          from: :assigning_driver,
          to: :accepted,
          inserted_at: ~N[2020-12-20 12:20:00]
        )

      match =
        insert(:match,
          state_transitions: [
            insert(:match_state_transition,
              from: :pending,
              to: :assigning_driver,
              inserted_at: ~N[2020-12-20 11:00:00]
            ),
            insert(:match_state_transition,
              from: :assigning_driver,
              to: :accepted,
              inserted_at: ~N[2020-12-20 12:00:00]
            ),
            insert(:match_state_transition,
              from: :accepted,
              to: :assigning_driver,
              inserted_at: ~N[2020-12-20 12:10:00]
            ),
            mst,
            insert(:match_state_transition,
              from: :accepted,
              to: :en_route_to_pickup,
              inserted_at: ~N[2020-12-20 12:21:00]
            )
          ]
        )

      assert %MatchStateTransition{id: ^mst_id, inserted_at: ~N[2020-12-20 12:20:00]} =
               Shipment.most_recent_transition(match, :accepted)
    end

    test "returns nil when it does not exist" do
      match = insert(:match)
      assert Shipment.most_recent_transition(match, :accepted) == nil
    end
  end

  describe "match_transitioned_at" do
    test "returns date of transition" do
      m = insert(:match)

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2019-12-21 12:20:00],
        match: m
      )

      insert(:match_state_transition,
        to: :picked_up,
        inserted_at: ~N[2020-12-20 12:20:00],
        match: m
      )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-21 12:20:00],
        match: m
      )

      insert(:match_state_transition, to: :charged, inserted_at: ~N[2020-12-22 12:20:00], match: m)

      match = Shipment.get_match!(m.id)

      assert ~N[2020-12-21 12:20:00] = Shipment.match_transitioned_at(match, :completed)
    end

    test "returns date of transition when not preloaded" do
      m = insert(:match)

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-21 12:20:00],
        match: m
      )

      match = Repo.get!(Match, m.id)

      assert ~N[2020-12-21 12:20:00] = Shipment.match_transitioned_at(match, :completed)
    end

    test "returns nil when not found" do
      m = insert(:match)

      match = Shipment.get_match!(m.id)

      refute Shipment.match_transitioned_at(match, :completed)
    end
  end

  describe "is_holiday_match/1" do
    test "returns true when Match is on a holiday" do
      match =
        insert(:pending_match,
          scheduled: true,
          pickup_at: ~N[2021-01-01 00:00:00]
        )

      assert Shipment.is_holiday_match(match)
    end

    test "returns false when Match is not on a holiday" do
      match = insert(:pending_match, inserted_at: ~N[2020-01-28 00:00:00])
      refute Shipment.is_holiday_match(match)
    end
  end

  describe "get_match_holidays/1" do
    test "returns holidays" do
      match =
        insert(:pending_match,
          inserted_at: ~N[2020-12-29 00:00:00],
          scheduled: true,
          pickup_at: ~N[2021-01-01 00:00:00]
        )

      assert {:ok,
              [
                %Holidefs.Holiday{
                  name: "New Year's Day"
                }
              ]} = Shipment.get_match_holidays(match)
    end

    test "returns empty list when Match is not on a holiday" do
      match =
        insert(:pending_match,
          inserted_at: ~N[2020-12-29 00:00:00]
        )

      assert {:ok, []} = Shipment.get_match_holidays(match)
    end
  end

  describe "match_departure_time/1" do
    test "returns authorized time" do
      match = insert(:assigning_driver_match)

      insert(:match_state_transition,
        from: :pending,
        to: :assigning_driver,
        inserted_at: ~N[2021-01-01 10:00:00],
        match: match
      )

      assert ~N[2021-01-01 10:00:00] = Shipment.match_departure_time(match)
    end

    test "returns most recent authorized time" do
      match =
        insert(:assigning_driver_match,
          state_transitions: [
            insert(:match_state_transition,
              from: :pending,
              to: :assigning_driver,
              inserted_at: ~N[2021-01-01 10:00:00]
            ),
            insert(:match_state_transition,
              from: :pending,
              to: :assigning_driver,
              inserted_at: ~N[2021-01-01 12:00:00]
            ),
            insert(:match_state_transition,
              from: :pending,
              to: :assigning_driver,
              inserted_at: ~N[2021-01-01 11:00:00]
            )
          ]
        )

      assert ~N[2021-01-01 12:00:00] = Shipment.match_departure_time(match)
    end

    test "returns scheduled pickup time when scheduled" do
      match =
        insert(:pending_match,
          inserted_at: ~N[2020-12-29 00:00:00],
          scheduled: true,
          pickup_at: ~N[2021-01-01 00:00:00],
          dropoff_at: ~N[2021-01-02 00:00:00]
        )

      assert ~U[2021-01-01 00:00:00Z] = Shipment.match_departure_time(match)
    end

    test "returns current time when not authorized or scheduled" do
      match =
        insert(:pending_match,
          inserted_at: ~N[2020-12-29 00:00:00]
        )

      assert match
             |> Shipment.match_departure_time()
             |> NaiveDateTime.diff(NaiveDateTime.utc_now()) >= -1
    end
  end

  describe "match_canceled_transition" do
    test "gets canceled time" do
      match =
        insert(:match,
          state_transitions: [
            insert(:match_state_transition, to: :canceled, inserted_at: ~N[2020-02-01 00:00:00])
          ]
        )

      admin_match =
        insert(:match,
          state_transitions: [
            insert(:match_state_transition,
              to: :admin_canceled,
              inserted_at: ~N[2020-01-01 00:00:00]
            )
          ]
        )

      assert %{inserted_at: ~N[2020-02-01 00:00:00]} = Shipment.match_canceled_transition(match)

      assert %{inserted_at: ~N[2020-01-01 00:00:00]} =
               Shipment.match_canceled_transition(admin_match)
    end

    test "gets latest cancel time regardless of state" do
      match =
        insert(:match,
          state_transitions: [
            insert(:match_state_transition,
              to: :admin_canceled,
              inserted_at: ~N[2020-03-01 00:00:00]
            ),
            insert(:match_state_transition,
              to: :admin_canceled,
              inserted_at: ~N[2020-01-01 00:00:00]
            ),
            insert(:match_state_transition, to: :canceled, inserted_at: ~N[2020-04-01 00:00:00]),
            insert(:match_state_transition, to: :canceled, inserted_at: ~N[2020-02-01 00:00:00])
          ]
        )

      assert %{inserted_at: ~N[2020-01-01 00:00:00]} = Shipment.match_canceled_transition(match)

      assert %{inserted_at: ~N[2020-04-01 00:00:00]} =
               Shipment.match_canceled_transition(match, :desc)
    end

    test "returns nil for no matching transitions" do
      match = insert(:match, state_transitions: [insert(:match_state_transition, to: :completed)])

      refute Shipment.match_canceled_transition(match)
    end
  end

  describe "match_authorized_time" do
    test "get the authorized time for a match" do
      match =
        insert(:match,
          state_transitions: [
            insert(:match_state_transition, to: :pending, inserted_at: ~N[2020-01-01 00:00:00]),
            insert(:match_state_transition,
              to: :assigning_driver,
              inserted_at: ~N[2020-01-03 00:00:00]
            ),
            insert(:match_state_transition,
              to: :assigning_driver,
              inserted_at: ~N[2020-01-04 00:00:00]
            ),
            insert(:match_state_transition,
              to: :assigning_driver,
              inserted_at: ~N[2020-01-02 00:00:00]
            ),
            insert(:match_state_transition, to: :canceled, inserted_at: ~N[2020-01-05 00:00:00])
          ]
        )

      assert ~N[2020-01-02 00:00:00] == Shipment.match_authorized_time(match)
    end

    test "returns nil when not found" do
      match = insert(:match)

      refute Shipment.match_authorized_time(match)
    end
  end

  describe "update_eta" do
    test "/1 creates a new ETA for the given match" do
      driver = insert(:driver, current_location: build(:driver_location))
      %{id: match_id} = match = insert(:match, driver: driver)
      assert {:ok, eta} = Shipment.update_eta(match)
      %ETA{match_id: ^match_id, arrive_at: arrive_at} = eta
      now = DateTime.utc_now()
      arrive_at = DateTime.from_naive!(arrive_at, "Etc/UTC")

      assert DateTime.diff(arrive_at, now, :second) > 0
    end

    test "/1 should return :error when driver location is not preloaded" do
      match = insert(:match, driver: build(:driver))

      assert :error = Shipment.update_eta(match)
    end

    test "/2 creates a new ETA for the given stop" do
      driver = insert(:driver, current_location: build(:driver_location))
      %{match_stops: [stop]} = insert(:match, driver: driver)
      assert {:ok, eta} = Shipment.update_eta(stop, driver)
      now = DateTime.utc_now()
      arrive_at = DateTime.from_naive!(eta.arrive_at, "Etc/UTC")

      assert DateTime.diff(arrive_at, now, :second) > 0
    end

    test "/2 should return :error when driver location is not preloaded" do
      driver = insert(:driver, current_location: nil)
      %{match_stops: [stop]} = insert(:match, driver: driver)

      assert :error = Shipment.update_eta(stop, driver)
    end
  end
end
