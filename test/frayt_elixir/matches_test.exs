defmodule FraytElixir.MatchesTest do
  use FraytElixir.DataCase
  use Bamboo.Test

  alias FraytElixir.{Matches, Repo}
  alias FraytElixir.Shipment.{Match, MatchStop, MatchFee, MatchStopItem, Address, Contact}
  alias FraytElixir.Payments.PaymentTransaction
  alias Ecto.{Multi, Changeset}
  alias ExPhoneNumber.Model.PhoneNumber
  alias FraytElixir.Test.FakeSlack
  alias FraytElixir.Shipment
  import FraytElixir.Factory
  import FraytElixir.Test.StartMatchSupervisor
  import FraytElixir.Test.WebhookHelper

  setup do
    start_match_webhook_sender(self())
  end

  setup :start_match_supervisor

  @dash 1
  @same_day 2

  describe "retrieve_distance" do
    test "returns distance from google distance matrix" do
      %{match_stops: [%{id: stop_id}]} = match = insert(:match)

      assert {:ok,
              %{
                total_distance: 5.0,
                match_stops: [
                  %{id: ^stop_id, distance: 5.0}
                ]
              }} = Matches.retrieve_distance(match)
    end

    test "returns distance from google distance matrix for multiple stops" do
      %{match_stops: [%{id: stop3_id}, %{id: stop1_id}, %{id: stop2_id}]} =
        match =
        insert(:match,
          match_stops: [
            build(:match_stop, index: 2),
            build(:match_stop, index: 0),
            build(:match_stop, index: 1)
          ]
        )

      assert {:ok,
              %{
                total_distance: 15.0,
                match_stops: [
                  %{id: ^stop1_id, distance: 5.0},
                  %{id: ^stop2_id, distance: 5.0},
                  %{id: ^stop3_id, distance: 5.0}
                ]
              }} = Matches.retrieve_distance(match)
    end

    test "does not return error for more than 10 stops" do
      match =
        insert(:match,
          match_stops: [
            build(:match_stop, index: 2),
            build(:match_stop, index: 0),
            build(:match_stop, index: 1),
            build(:match_stop, index: 3),
            build(:match_stop, index: 4),
            build(:match_stop, index: 5),
            build(:match_stop, index: 6),
            build(:match_stop, index: 7),
            build(:match_stop, index: 8),
            build(:match_stop, index: 9),
            build(:match_stop, index: 10)
          ]
        )

      assert {:ok,
              %{
                total_distance: _,
                match_stops: _
              }} = Matches.retrieve_distance(match)
    end
  end

  describe "optimize_stops" do
    test "Optimized stops can't be reoptimized" do
      match = insert(:match, optimized_stops: true)

      {:error, "These routes have already been optimized."} = Matches.optimize_stops(match)
    end

    test "Can't re-optimize a match with more than 11 stops" do
      match =
        insert(:match,
          optimized_stops: false,
          match_stops: Enum.map(0..49, &build(:match_stop, index: &1))
        )

      {:error, "You can't optimize more than 49 stops"} = Matches.optimize_stops(match)
    end

    test "Non optimized stops returns total distance and travel duration" do
      %{match_stops: [%{id: stop0_id}, %{id: stop1_id}, %{id: stop2_id}]} =
        match =
        insert(:match,
          optimized_stops: false,
          match_stops: [
            build(:match_stop,
              index: 0,
              destination_address:
                build(:address, geo_location: %Geo.Point{coordinates: {-84.5118912, 40.1043198}})
            ),
            build(:match_stop,
              index: 1,
              destination_address:
                build(:address, geo_location: %Geo.Point{coordinates: {-84.5118912, 39.1043198}})
            ),
            build(:match_stop,
              index: 2,
              destination_address:
                build(:address, geo_location: %Geo.Point{coordinates: {-84.5118912, 41.1043198}})
            )
          ]
        )

      assert {:ok,
              %{
                match_stops: stops,
                optimized_stops: true,
                total_distance: _,
                travel_duration: _
              }} = Matches.optimize_stops(match)

      assert [
               %{id: ^stop1_id, index: 0},
               %{id: ^stop0_id, index: 1},
               %{id: ^stop2_id, index: 2}
             ] = stops |> Enum.sort_by(& &1.index)
    end
  end

  describe "get_distance_metrics" do
    test "No distance calc is required when optimize and changed_addrs param are false" do
      match =
        insert(:match,
          optimized_stops: false,
          match_stops: [
            build(:match_stop, index: 2),
            build(:match_stop, index: 0),
            build(:match_stop, index: 1)
          ]
        )

      changed_addresses = false
      attrs = %{optimize: false}

      assert {:ok, %{}} = Matches.get_distance_metrics(match, attrs, changed_addresses)
    end

    test "Does not optimize whether optimize or changed_addrs param are false" do
      match =
        insert(:match,
          optimized_stops: false,
          match_stops: [
            build(:match_stop, index: 2),
            build(:match_stop, index: 0),
            build(:match_stop, index: 1)
          ]
        )

      changed_addresses = true
      attrs = %{optimize: false}

      assert {:ok,
              %{
                match_stops: _,
                optimized_stops: false,
                total_distance: 15.0,
                travel_duration: 900
              }} = Matches.get_distance_metrics(match, attrs, changed_addresses)
    end

    test "Optimize only when optimize param is true and addrs has been changed" do
      match =
        insert(:match,
          optimized_stops: false,
          match_stops: [
            build(:match_stop, index: 2),
            build(:match_stop, index: 0),
            build(:match_stop, index: 1)
          ]
        )

      changed_addresses = true
      attrs = %{optimize: true}

      assert {:ok,
              %{
                match_stops: _,
                optimized_stops: true,
                total_distance: 5.0,
                travel_duration: 2400
              }} = Matches.get_distance_metrics(match, attrs, changed_addresses)
    end

    test "Does not optimize more than 11 stops even when optimize param is true and addrs has been changed" do
      match =
        insert(:match,
          optimized_stops: false,
          match_stops: Enum.map(0..49, &build(:match_stop, index: &1))
        )

      changed_addresses = true
      attrs = %{optimize: true}

      {:error, "You can't optimize more than 49 stops"} =
        Matches.get_distance_metrics(match, attrs, changed_addresses)
    end
  end

  describe "calculate_total_stop_sizes" do
    test "stop returns total volume and weight" do
      stop =
        insert(:match_stop,
          items: [
            build(:match_stop_item,
              weight: 100,
              volume: 200,
              pieces: 4,
              width: 10,
              length: 11,
              height: 12
            ),
            build(:match_stop_item,
              weight: 50,
              volume: 120,
              pieces: 1,
              width: 13,
              length: 14,
              height: 15
            )
          ]
        )

      assert %{total_volume: 920, total_weight: 450.0, longest_dimension: 15.0} =
               Matches.calculate_total_stop_sizes(stop)
    end
  end

  describe "calculate_total_sizes" do
    test "single stop match returns total volume and weight" do
      m =
        insert(:pending_match,
          match_stops: [
            build(:match_stop,
              items: [
                build(:match_stop_item,
                  weight: 100,
                  volume: 200,
                  pieces: 4,
                  width: 10,
                  length: 10,
                  height: 10
                ),
                build(:match_stop_item,
                  weight: 50,
                  volume: 120,
                  pieces: 1,
                  width: 20,
                  length: 25,
                  height: 20
                )
              ]
            )
          ]
        )

      assert %{total_volume: 920, total_weight: 450.0, longest_dimension: 25.0} =
               Matches.calculate_total_sizes(m)
    end

    test "multi stop match returns total volume and weight" do
      m =
        insert(:pending_match,
          match_stops: [
            build(:match_stop,
              items: [
                build(:match_stop_item,
                  weight: 100,
                  volume: 200,
                  pieces: 4,
                  width: 20,
                  length: 25,
                  height: 20
                ),
                build(:match_stop_item,
                  weight: 50,
                  volume: 120,
                  pieces: 1,
                  width: 20,
                  length: 25,
                  height: 20
                )
              ]
            ),
            build(:match_stop,
              items: [
                build(:match_stop_item,
                  weight: 20,
                  volume: 120,
                  pieces: 2,
                  width: 20,
                  length: 25,
                  height: 20
                ),
                build(:match_stop_item,
                  weight: 6,
                  volume: 50,
                  pieces: 3,
                  width: 30,
                  length: 25,
                  height: 20
                )
              ]
            )
          ]
        )

      assert %{total_volume: 1310, total_weight: 508.0, longest_dimension: 30.0} =
               Matches.calculate_total_sizes(m)
    end

    test "ignores stops that don't require unload when load_only is true" do
      m =
        insert(:pending_match,
          match_stops: [
            build(:match_stop,
              has_load_fee: true,
              items: [
                build(:match_stop_item, weight: 100, volume: 200, pieces: 4, width: 10000.0),
                build(:match_stop_item, weight: 50, volume: 120, pieces: 1)
              ]
            ),
            build(:match_stop,
              has_load_fee: false,
              items: [
                build(:match_stop_item, weight: 20, volume: 120, pieces: 2, width: 20000),
                build(:match_stop_item, weight: 6, volume: 50, pieces: 3)
              ]
            )
          ]
        )

      assert %{total_volume: 920, total_weight: 450.0, longest_dimension: 10000.0} =
               Matches.calculate_total_sizes(m, true)
    end
  end

  describe "convert_attrs_to_multi_stop" do
    @with_item_attrs %{
      origin_address: "863 Dawsonville Hwy, Gainesville, GA 30501",
      destination_address: "708 Walnut St, Cincinnati, OH 45202",
      service_level: @dash,
      sender: %{
        name: "John Smith",
        email: "john@smith.com",
        phone_number: "+15131800000",
        notify: false
      },
      self_sender: false,
      items: [
        %{
          width: 1,
          length: 2,
          height: 3,
          weight: 30,
          volume: 3,
          pieces: 3,
          description: "Gold Bar"
        }
      ],
      network_operator_id: "id",
      autoselect_vehicle_class: true,
      identifier: "identify",
      vehicle_class: 3,
      has_load_fee: true,
      needs_pallet_jack: false,
      pickup_notes: "pickup",
      delivery_notes: "delivery",
      admin_notes: "admin notes",
      po: "po",
      recipient_name: "rname",
      recipient_phone: "rphone",
      recipient_email: "remail",
      notify_recipient: false,
      self_recipient: false,
      pickup_at: ~N[2020-01-01 00:00:00],
      dropoff_at: ~N[2020-01-02 00:00:00],
      match_stop_identifier: "identify",
      contract: "contract",
      tip: 1000,
      coupon: "coupon",
      scheduled: false,
      unload_method: :lift_gate
    }

    @without_item_attrs @with_item_attrs
                        |> Map.drop([:items, :has_load_fee, :delivery_notes])
                        |> Map.merge(%{
                          length: 2,
                          width: 1,
                          height: 3,
                          weight: 30,
                          pieces: 3,
                          volume: 3,
                          description: "Gold Bar",
                          load_unload: true,
                          dropoff_notes: "delivery"
                        })

    @deprecated_api_attrs @without_item_attrs
                          |> Map.drop([
                            :length,
                            :width,
                            :height,
                            :load_unload,
                            :po,
                            :pickup_at,
                            :scheduled,
                            :dropoff_at,
                            :coupon
                          ])
                          |> Map.merge(%{
                            code: "coupon",
                            load_fee: true,
                            dimensions_length: 2,
                            dimensions_width: 1,
                            dimensions_height: 3,
                            scheduling: false,
                            job_number: "po",
                            scheduled_pickup: ~N[2020-01-01 00:00:00],
                            scheduled_dropoff: ~N[2020-01-02 00:00:00]
                          })

    defp assert_formatted(result) do
      assert %{
               contract: "contract",
               origin_address: "863 Dawsonville Hwy, Gainesville, GA 30501",
               vehicle_class: 3,
               service_level: @dash,
               pickup_at: ~N[2020-01-01 00:00:00],
               dropoff_at: ~N[2020-01-02 00:00:00],
               pickup_notes: "pickup",
               admin_notes: "admin notes",
               po: "po",
               identifier: "identify",
               scheduled: false,
               coupon_code: "coupon",
               autoselect_vehicle_class: true,
               network_operator_id: "id",
               unload_method: :lift_gate,
               sender: %{
                 name: "John Smith",
                 email: "john@smith.com",
                 phone_number: "+15131800000",
                 notify: false
               },
               self_sender: false,
               stops: [
                 %{
                   identifier: "identify",
                   destination_address: "708 Walnut St, Cincinnati, OH 45202",
                   recipient: %{
                     name: "rname",
                     email: "remail",
                     phone_number: "rphone",
                     notify: false
                   },
                   self_recipient: false,
                   tip_price: 1000,
                   has_load_fee: true,
                   needs_pallet_jack: false,
                   delivery_notes: "delivery",
                   items: [
                     %{
                       width: 1,
                       length: 2,
                       height: 3,
                       weight: 30,
                       pieces: 3,
                       volume: 3,
                       description: "Gold Bar"
                     }
                   ]
                 }
               ]
             } == result
    end

    test "converts deprecated match api attrs" do
      Matches.convert_attrs_to_multi_stop(@deprecated_api_attrs) |> assert_formatted
    end

    test "converts w/o item attrs" do
      Matches.convert_attrs_to_multi_stop(@without_item_attrs) |> assert_formatted
    end

    test "converts with item attrs" do
      Matches.convert_attrs_to_multi_stop(@with_item_attrs) |> assert_formatted
    end

    test "ignores items when there are none" do
      assert %{stops: [stop]} =
               Matches.convert_attrs_to_multi_stop(@with_item_attrs |> Map.delete(:items))

      refute Map.has_key?(stop, :items)
    end

    test "ignores stops when there are none" do
      assert %{origin_address: "origin address"} ==
               Matches.convert_attrs_to_multi_stop(%{origin_address: "origin address"})
    end

    test "doesn't replace stop or single item when match is passed" do
      %{match_stops: [%MatchStop{id: stop_id, items: [%MatchStopItem{id: item_id}]}]} =
        match =
        insert(:match,
          match_stops: [build(:match_stop, items: [build(:match_stop_item)])]
        )

      assert %{stops: [%{id: ^stop_id, items: [%{id: ^item_id, description: "Gold Bar"}]}]} =
               Matches.convert_attrs_to_multi_stop(@without_item_attrs, match)
    end

    test "converts with no recipient contact info" do
      stop = build(:estimate_match_stop, self_recipient: true, recipient: nil)
      match = insert(:estimate, match_stops: [stop])

      assert %{stops: [%{recipient: %{notify: false, name: "joe"}}]} =
               Matches.convert_attrs_to_multi_stop(%{recipient_name: "joe"}, match)

      assert %{stops: [%{recipient: %{notify: false, name: "joe", email: nil}}]} =
               Matches.convert_attrs_to_multi_stop(%{recipient_name: "joe", email: nil}, match)

      assert %{stops: [%{recipient: %{notify: true, name: "joe", email: nil, phone_number: 123}}]} =
               Matches.convert_attrs_to_multi_stop(
                 %{recipient_name: "joe", email: nil, phone_number: 123},
                 match
               )
    end
  end

  @valid_attrs %{
    origin_address: "863 Dawsonville Hwy, Gainesville, GA 30501",
    vehicle_class: 3,
    service_level: @dash,
    alert_headline: "alert",
    scheduled: false,
    pickup_at: nil,
    dropoff_at: nil,
    pickup_notes: "notes for pickup",
    po: "12345",
    admin_notes: "admin notes",
    identifier: "identify",
    unload_method: nil,
    sender: %{
      name: "john smith",
      email: "johnsmith@test.com",
      phone_number: "+15134020000",
      notify: false
    },
    self_sender: false,
    stops: [
      %{
        destination_address: "708 Walnut St, Cincinnati, OH 45202",
        identifier: "identify",
        recipient: %{
          name: "John Smith",
          email: "jsmith@example.com",
          phone_number: "+15134020001",
          notify: true
        },
        self_recipient: false,
        tip_price: 1000,
        has_load_fee: true,
        delivery_notes: "notes about delivery",
        items: [
          %{
            width: 1,
            length: 2,
            height: 3,
            weight: 30,
            pieces: 3,
            description: "Gold Bar"
          },
          %{
            width: 1,
            length: 2,
            height: 3,
            pieces: 10,
            weight: 20,
            description: "Silver Bar"
          }
        ],
        po: "PO for this match_stop"
      }
    ]
  }

  @valid_multi_attrs @valid_attrs
                     |> Map.put(
                       :stops,
                       @valid_attrs[:stops] ++
                         [
                           %{
                             destination_address: "708 Walnut St, Cincinnati, OH 45202",
                             identifier: "identify",
                             recipient: %{
                               name: "John Smith",
                               email: "jsmith@example.com",
                               phone_number: "+15134020002",
                               notify: true
                             },
                             self_recipient: false,
                             tip_price: 1500,
                             has_load_fee: true,
                             delivery_notes: "other notes about delivery",
                             items: [
                               %{
                                 width: 1,
                                 length: 2,
                                 height: 3,
                                 weight: 30,
                                 pieces: 3,
                                 description: "Gold Bar"
                               }
                             ]
                           }
                         ]
                     )

  @scheduled_attrs @valid_attrs
                   |> Map.merge(%{
                     scheduled: true,
                     pickup_at: ~U[2030-02-01 00:00:00.000000Z],
                     dropoff_at: ~U[2030-02-02 00:00:00.000000Z]
                   })

  @min_attrs %{
    origin_address: "863 Dawsonville Hwy, Gainesville, GA 30501",
    service_level: @dash,
    vehicle_class: 2,
    stops: [
      %{
        destination_address: "708 Walnut St, Cincinnati, OH 45202"
      }
    ]
  }

  test "still creates scheduled match when pickup_at is on a Sunday, because it's Saturday in the timezone it's in" do
    assert {:ok,
            %Match{
              scheduled: true,
              pickup_at: ~U[2030-11-24 03:00:00Z]
            }} =
             Matches.create_estimate(
               @valid_attrs
               |> Map.merge(%{scheduled: true, pickup_at: ~U[2030-11-24 03:00:00Z]})
             )
  end

  describe "duplicate_match" do
    test "duplicates a match" do
      %{id: market_id} =
        insert(:market,
          markup: 1.0,
          has_box_trucks: true,
          zip_codes: [insert(:market_zip_code, zip: "30501")]
        )

      shipper = insert(:shipper_with_location)

      %{id: contract_id} =
        contract =
        insert(:contract, company: shipper.location.company, pricing_contract: :default)

      %{
        shipper_id: shipper_id,
        sender_id: sender_id,
        origin_address_id: origin_address_id,
        match_stops: [
          orig_stop = %{
            recipient_id: recipient_id,
            destination_address_id: destination_address_id,
            items: [orig_item]
          }
        ]
      } =
        orig_match =
        insert(:match,
          shipper: shipper,
          pickup_at: ~N[2030-01-01 11:00:00],
          dropoff_at: ~N[2031-01-01 12:00:00],
          scheduled: true,
          state: :assigning_driver,
          expected_toll: 1000,
          amount_charged: 100,
          driver_total_pay: 100,
          driver_fees: 10,
          price_discount: 900,
          vehicle_class: 4,
          service_level: @dash,
          total_distance: 5.6,
          markup: 1.2,
          market: insert(:market),
          manual_price: true,
          pickup_notes: "my notes",
          admin_notes: "specific notes",
          identifier: "specific id",
          po: "specific po",
          origin_photo: %{file_name: "origin_photo.png", updated_at: DateTime.utc_now()},
          origin_photo_required: true,
          bill_of_lading_photo: %{file_name: "bill_of_lading.png", updated_at: DateTime.utc_now()},
          bill_of_lading_required: true,
          contract: contract,
          driver_cut: 0.9,
          total_weight: 36,
          total_volume: 12,
          travel_duration: 1234,
          unload_method: :dock_to_dock,
          self_sender: false,
          slack_thread_id: "1234",
          cancel_charge: 1200,
          cancel_charge_driver_pay: 1000,
          cancel_reason: "my reason",
          rating: 4,
          rating_reason: "your reason",
          timezone: "EST",
          optimized_stops: true,
          driver: insert(:driver),
          origin_address: insert(:address, zip: "30501"),
          network_operator: insert(:network_operator),
          schedule: insert(:schedule),
          delivery_batch: insert(:delivery_batch),
          shipper_match_coupon: insert(:shipper_match_coupon),
          coupon: insert(:coupon),
          notification_batches: [insert(:notification_batch)],
          fees: [insert(:match_fee, amount: 100, driver_amount: 100)],
          slas: [insert(:match_sla)],
          hidden_matches: [insert(:hidden_match)],
          payment_transactions: [insert(:payment_transaction)],
          state_transitions: [insert(:match_state_transition, to: :completed)],
          tags: [insert(:match_tag)],
          sender: insert(:contact),
          match_stops: [
            build(:match_stop,
              recipient: insert(:contact),
              state: :delivered,
              dropoff_by: ~N[2031-01-01 00:00:00],
              identifier: "test",
              distance: 5.6,
              has_load_fee: false,
              needs_pallet_jack: true,
              tip_price: 10_00,
              self_recipient: false,
              index: 1,
              signature_name: "john",
              signature_photo: %{file_name: "signature_photo.png", updated_at: DateTime.utc_now()},
              destination_photo: %{
                file_name: "destination_photo.png",
                updated_at: DateTime.utc_now()
              },
              delivery_notes: "my notes",
              destination_photo_required: true,
              signature_required: false,
              destination_address: insert(:address),
              delivery_batch: insert(:delivery_batch),
              state_transitions: [insert(:match_stop_state_transition, to: :delivered)],
              items: [
                build(:match_stop_item,
                  width: 1,
                  length: 2,
                  height: 3,
                  volume: 4,
                  pieces: 5,
                  weight: 6,
                  description: "test",
                  type: :pallet,
                  external_id: "test2",
                  barcode: "12345",
                  barcode_pickup_required: true,
                  barcode_delivery_required: true,
                  barcode_readings: [build(:barcode_reading)],
                  declared_value: 1000
                )
              ]
            )
          ]
        )

      assert {:ok, match} =
               Matches.duplicate_match(orig_match, %{admin: insert(:admin_user)}, :inactive)

      stop = List.first(match.match_stops)
      item = List.first(stop.items)

      assert match.shortcode != orig_match.shortcode
      assert match.id != orig_match.id
      assert stop.match_id != orig_match.id
      assert stop.id != orig_stop.id
      assert item.match_stop_id != orig_stop.id
      assert item.id != orig_item.id

      assert %MatchStopItem{
               width: 48.0,
               length: 48.0,
               height: 40.0,
               volume: 92_160,
               pieces: 5,
               weight: 6.0,
               description: "test",
               type: :pallet,
               external_id: nil,
               barcode: "12345",
               barcode_pickup_required: true,
               barcode_delivery_required: true,
               barcode_readings: [],
               declared_value: 1000
             } = item |> Repo.preload(:barcode_readings)

      assert %MatchStop{
               recipient_id: ^recipient_id,
               state: :pending,
               dropoff_by: nil,
               identifier: nil,
               distance: 5.0,
               has_load_fee: false,
               needs_pallet_jack: true,
               tip_price: 0,
               self_recipient: false,
               index: 1,
               signature_name: nil,
               signature_photo: nil,
               destination_photo: nil,
               delivery_notes: "my notes",
               destination_photo_required: true,
               signature_required: false,
               destination_address_id: ^destination_address_id,
               delivery_batch: nil,
               state_transitions: []
             } = stop |> Repo.preload([:state_transitions, :delivery_batch])

      assert %Match{
               shipper_id: ^shipper_id,
               sender_id: ^sender_id,
               market_id: ^market_id,
               pickup_at: nil,
               dropoff_at: nil,
               scheduled: false,
               state: :inactive,
               expected_toll: 0,
               amount_charged: 215_00,
               driver_total_pay: 172_00,
               driver_fees: 0,
               price_discount: 0,
               vehicle_class: 4,
               service_level: @dash,
               total_distance: 5.0,
               markup: 1.0,
               manual_price: false,
               pickup_notes: "my notes",
               admin_notes: nil,
               identifier: nil,
               po: "specific po",
               origin_photo: nil,
               origin_photo_required: true,
               bill_of_lading_photo: nil,
               bill_of_lading_required: true,
               contract_id: ^contract_id,
               driver_cut: 0.8,
               total_weight: 30,
               total_volume: 460_800,
               travel_duration: 450,
               unload_method: :dock_to_dock,
               self_sender: false,
               slack_thread_id: nil,
               cancel_charge: nil,
               cancel_charge_driver_pay: nil,
               cancel_reason: nil,
               rating: nil,
               rating_reason: nil,
               timezone: "America/New_York",
               optimized_stops: false,
               driver_id: nil,
               origin_address_id: ^origin_address_id,
               network_operator: nil,
               schedule: nil,
               delivery_batch: nil,
               shipper_match_coupon: nil,
               coupon: nil,
               notification_batches: [],
               fees: [
                 %MatchFee{type: :base_fee, amount: 215_00, driver_amount: 172_00}
               ],
               slas: [],
               hidden_matches: [],
               payment_transactions: [],
               state_transitions: [],
               tags: []
             } = match |> Repo.preload([:delivery_batch, :hidden_matches, :schedule])
    end

    test "can override attrs" do
      card = insert(:credit_card)

      orig_match =
        %{match_stops: [orig_stop = %{items: [orig_item]}]} =
        insert(:match,
          shipper: card.shipper,
          po: "po1",
          match_stops: [
            build(:match_stop,
              delivery_notes: "notes",
              items: [build(:match_stop_item, description: "balloon")]
            )
          ]
        )

      attrs = %{
        po: "po2",
        stops: [
          %{
            id: orig_stop.id,
            delivery_notes: "my notes",
            items: [%{id: orig_item.id, description: "my balloons"}]
          }
        ]
      }

      assert {:ok, match} = Matches.duplicate_match(orig_match, attrs)

      stop = List.first(match.match_stops)
      item = List.first(stop.items)

      assert match.shortcode != orig_match.shortcode
      assert match.id != orig_match.id
      assert stop.match_id != orig_match.id
      assert stop.id != orig_stop.id
      assert item.match_stop_id != orig_stop.id
      assert item.id != orig_item.id

      assert %Match{
        po: "po2",
        match_stops: [
          %MatchStop{
            delivery_notes: "my notes",
            items: [%MatchStopItem{description: "my balloons"}]
          }
        ]
      }
    end

    test "handles errors" do
      match =
        insert(:match, vehicle_class: 4, shipper: build(:shipper, location: build(:location)))

      assert {:error, :update_match, %Changeset{}, _} = Matches.duplicate_match(match)
    end
  end

  describe "create_estimate" do
    defp pallet_jack_attrs(attrs \\ %{}, stop_attrs \\ %{}, item_attrs \\ %{}) do
      stop =
        @valid_attrs[:stops]
        |> List.first()

      %{
        @valid_attrs
        | service_level: @dash,
          vehicle_class: 4,
          unload_method: :lift_gate,
          scheduled: true,
          pickup_at: ~N[2030-01-03 11:00:00],
          stops: [
            stop
            |> Map.put(:needs_pallet_jack, true)
            |> Map.put(:has_load_fee, false)
            |> Map.put(:items, [
              stop.items
              |> List.first()
              |> Map.put(:type, :pallet)
              |> Map.merge(item_attrs)
            ])
            |> Map.merge(stop_attrs)
          ]
      }
      |> Map.merge(attrs)
    end

    test "creates estimate" do
      %{id: market_id} =
        insert(:market, markup: 2.0, zip_codes: [insert(:market_zip_code, zip: "30501")])

      assert {:ok,
              %Match{
                id: id,
                total_distance: 1.7,
                total_weight: 290,
                expected_toll: 0,
                driver_cut: 0.72,
                total_volume: 78,
                state: :pending,
                origin_address: %Address{zip: "30501"},
                vehicle_class: 3,
                service_level: @dash,
                scheduled: false,
                pickup_at: nil,
                dropoff_at: nil,
                markup: 2.0,
                market_id: ^market_id,
                manual_price: false,
                pickup_notes: "notes for pickup",
                po: "12345",
                admin_notes: "admin notes",
                shortcode: shortcode,
                identifier: "identify",
                origin_photo_required: false,
                contract: nil,
                shipper_id: nil,
                network_operator_id: nil,
                schedule_id: nil,
                unload_method: nil,
                sender: %Contact{
                  name: "john smith",
                  phone_number: %PhoneNumber{national_number: 513_402_0000, country_code: 1},
                  notify: false,
                  email: "johnsmith@test.com"
                },
                self_sender: false,
                fees: fees,
                match_stops: [
                  %MatchStop{
                    distance: 1.7,
                    radial_distance: 284.8,
                    match_id: match_id,
                    state: :pending,
                    identifier: "identify",
                    recipient: %Contact{
                      name: "John Smith",
                      phone_number: %PhoneNumber{national_number: 513_402_0001, country_code: 1},
                      notify: true,
                      email: "jsmith@example.com"
                    },
                    self_recipient: false,
                    tip_price: 1000,
                    has_load_fee: true,
                    index: 0,
                    delivery_notes: "notes about delivery",
                    destination_photo_required: false,
                    dropoff_by: nil,
                    destination_address: %Address{
                      zip: "45202"
                    },
                    items: items,
                    po: "PO for this match_stop"
                  }
                ]
              }} = Matches.create_estimate(@valid_attrs)

      assert [
               %MatchFee{type: :base_fee, amount: 117_58, driver_amount: 79_92},
               %MatchFee{type: :driver_tip, amount: 10_00, driver_amount: 10_00},
               %MatchFee{type: :load_fee, amount: 24_99, driver_amount: 18_74}
             ] = Enum.sort_by(fees, & &1.type)

      assert [
               %MatchStopItem{
                 width: 1.0,
                 length: 2.0,
                 height: 3.0,
                 pieces: 3,
                 weight: 30.0,
                 volume: 6,
                 description: "Gold Bar"
               },
               %MatchStopItem{
                 width: 1.0,
                 length: 2.0,
                 height: 3.0,
                 pieces: 10,
                 weight: 20.0,
                 volume: 6,
                 description: "Silver Bar"
               }
             ] = Enum.sort_by(items, & &1.description)

      assert id =~ String.downcase(shortcode)

      assert match_id == id
    end

    test "creates estimate with no market" do
      assert {:ok, %Match{markup: 1.0, market_id: nil}} = Matches.create_estimate(@valid_attrs)
    end

    test "creates multi stop matches" do
      assert {:ok,
              %Match{
                total_distance: 10.0,
                total_weight: 380,
                expected_toll: 0,
                total_volume: 96,
                manual_price: false,
                match_stops: [
                  %MatchStop{
                    distance: 5.0,
                    radial_distance: 284.8,
                    tip_price: 1000,
                    has_load_fee: true,
                    index: 0,
                    destination_address: %Address{
                      zip: "45202"
                    },
                    items: [_, _]
                  },
                  %MatchStop{
                    distance: 5.0,
                    radial_distance: 284.8,
                    tip_price: 1500,
                    has_load_fee: true,
                    index: 1,
                    destination_address: %Address{
                      zip: "45202"
                    },
                    items: [_]
                  }
                ]
              }} = Matches.create_estimate(@valid_multi_attrs)
    end

    test "creates estimates with minimal attrs" do
      assert {:ok,
              %Match{
                total_distance: 1.7,
                total_weight: 0,
                expected_toll: 0,
                total_volume: 0,
                manual_price: false,
                origin_address: %Address{
                  zip: "30501"
                },
                fees: [
                  %MatchFee{type: :base_fee, amount: 3884, driver_amount: 2653}
                ],
                match_stops: [
                  %MatchStop{
                    distance: 1.7,
                    tip_price: 0,
                    has_load_fee: false,
                    index: 0,
                    destination_address: %Address{
                      zip: "45202"
                    },
                    items: []
                  }
                ]
              }} = Matches.create_estimate(@min_attrs)
    end

    test "creates matches with existing stop and origin_address" do
      %{id: stop_id} = match_stop = insert(:match_stop, has_load_fee: true, index: 1)
      %{id: address_id} = address = insert(:address, zip: "12345")

      assert {:ok,
              %Match{
                id: id,
                total_distance: 5.0,
                total_weight: 40,
                total_volume: 4608,
                manual_price: false,
                origin_address: %Address{id: ^address_id},
                match_stops: [
                  %MatchStop{
                    id: ^stop_id,
                    match_id: match_id,
                    distance: 5.0,
                    tip_price: 0,
                    has_load_fee: true,
                    index: 1,
                    destination_address: %Address{
                      zip: "45202"
                    },
                    items: [_]
                  }
                ]
              }} =
               Matches.create_estimate(%{
                 @valid_attrs
                 | stops: [match_stop],
                   origin_address: address
               })

      assert match_id == id
    end

    test "creates scheduled estimate" do
      assert {:ok,
              %Match{
                scheduled: true,
                pickup_at: ~U[2030-02-01 00:00:00Z],
                dropoff_at: ~U[2030-02-02 00:00:00Z]
              }} = Matches.create_estimate(@scheduled_attrs)
    end

    # ignore while OneRail is providing fix
    @tag :skip
    test "fails when scheduled within 60 minutes of pickup" do
      pickup_time = DateTime.utc_now() |> DateTime.add(3500, :second)

      assert {:error, :update_match, %Ecto.Changeset{errors: [pickup_at: _]}, _} =
               Matches.create_estimate(@valid_attrs |> Map.put(:pickup_at, pickup_time))
    end

    test "auto configures dropoff_at" do
      now = Timex.now()

      two_hours_from_now = now |> Timex.shift(hours: 2) |> DateTime.truncate(:second)

      shipper = insert(:shipper_with_location)

      insert(:contract,
        company: shipper.location.company,
        contract_key: "sherwin",
        pricing_contract: :sherwin
      )

      six_hours_from_now =
        now
        |> Timex.shift(hours: 6)
        |> DateTime.truncate(:second)

      assert {:ok, %Match{dropoff_at: dropoff_at, pickup_at: pickup_at, scheduled: true}} =
               Matches.create_estimate(
                 @valid_attrs
                 |> Map.put(:contract, "sherwin")
                 |> Map.put(:pickup_at, two_hours_from_now),
                 shipper
               )

      assert 1 >= pickup_at |> DateTime.truncate(:second) |> Timex.compare(two_hours_from_now)

      assert 1 >=
               dropoff_at
               |> DateTime.truncate(:second)
               |> Timex.compare(six_hours_from_now)
    end

    test "maybe_auto_configure_dropoff_at for match without pickup_at sets pickup_at to an hour from now and dropoff_at four hours from now" do
      now = Timex.now()

      shipper = insert(:shipper_with_location)

      insert(:contract,
        company: shipper.location.company,
        contract_key: "sherwin",
        pricing_contract: :sherwin
      )

      four_hours_from_now =
        now
        |> Timex.shift(hours: 4)
        |> DateTime.truncate(:second)

      assert {:ok, %Match{dropoff_at: dropoff_at, pickup_at: pickup_at, scheduled: true}} =
               Matches.create_estimate(
                 @valid_attrs
                 |> Map.put(:contract, "sherwin"),
                 shipper
               )

      assert 1 >=
               pickup_at
               |> DateTime.truncate(:second)
               |> Timex.compare(now |> Timex.shift(hours: 1) |> DateTime.truncate(:second))

      assert 1 >=
               dropoff_at
               |> DateTime.truncate(:second)
               |> Timex.compare(four_hours_from_now)
    end

    test "does not auto configure dropoff_at for contract that does not support it" do
      now = Timex.now()

      shipper = insert(:shipper_with_location)

      insert(:contract,
        company: shipper.location.company,
        contract_key: "tbc",
        pricing_contract: :tbc
      )

      assert {:ok, %Match{dropoff_at: dropoff_at}} =
               Matches.create_estimate(
                 @valid_attrs
                 |> Map.put(:contract, "tbc")
                 |> Map.put(:scheduled, true)
                 |> Map.put(:pickup_at, now),
                 shipper
               )

      assert nil == dropoff_at
    end

    @tag :skip
    test "fails when  scheduled within 60 minutes of dropoff" do
      dropoff_time = DateTime.utc_now() |> DateTime.add(3500, :second)

      assert {:error, :update_match, %Ecto.Changeset{errors: [dropoff_at: _]}, _} =
               Matches.create_estimate(@valid_attrs |> Map.put(:dropoff_at, dropoff_time))
    end

    test "creates estimate with box truck in a market that supports box trucks" do
      insert(:market_zip_code,
        zip: "30501",
        market: build(:market, markup: 2.0, has_box_trucks: true)
      )

      assert {:ok, %Match{bill_of_lading_required: true, vehicle_class: 4}} =
               Matches.create_estimate(
                 @valid_attrs
                 |> Map.merge(%{
                   service_level: 1,
                   vehicle_class: 4,
                   unload_method: :dock_to_dock,
                   scheduled: true,
                   pickup_at: ~N[2030-01-03 11:00:00]
                 })
               )
    end

    test "fails when box truck is selected for a market that does not support it" do
      assert {:error, :calculate_match_metrics,
              %Ecto.Changeset{
                errors: [
                  vehicle_class: {"box trucks are not supported in this market", _}
                ]
              },
              _} =
               Matches.create_estimate(
                 @valid_attrs
                 |> Map.put(:vehicle_class, 4)
                 |> Map.put(:unload_method, :dock_to_dock)
               )
    end

    test "creates estimate with box truck that has a lift gate and pallet jack" do
      insert(:market_zip_code,
        zip: "30501",
        market: build(:market, markup: 2.0, has_box_trucks: true)
      )

      assert {:ok,
              %{
                bill_of_lading_required: true,
                vehicle_class: 4,
                unload_method: :lift_gate,
                match_stops: [%MatchStop{needs_pallet_jack: true}]
              }} = Matches.create_estimate(pallet_jack_attrs())
    end

    test "force pallet jack and dimensions when creating estimate with lift gate and pallets" do
      insert(:market_zip_code,
        zip: "30501",
        market: build(:market, markup: 2.0, has_box_trucks: true)
      )

      assert {:ok,
              %{
                bill_of_lading_required: true,
                vehicle_class: 4,
                unload_method: :lift_gate,
                match_stops: [
                  %MatchStop{
                    needs_pallet_jack: true,
                    items: [
                      %MatchStopItem{width: 48.0, length: 48.0, height: 40.0, type: :pallet}
                    ]
                  }
                ]
              }} =
               Matches.create_estimate(
                 pallet_jack_attrs(%{}, %{needs_pallet_jack: false}, %{
                   width: 1,
                   length: 1,
                   height: 1
                 })
               )
    end

    test "fails when creating estimate with pallet jack and no pallets" do
      insert(:market_zip_code,
        zip: "30501",
        market: build(:market, markup: 2.0, has_box_trucks: true)
      )

      assert {:error, :match_overrides,
              %Changeset{
                changes: %{
                  match_stops: [
                    %Changeset{
                      errors: errors
                    }
                  ]
                }
              }, _} = Matches.create_estimate(pallet_jack_attrs(%{}, %{}, %{type: :item}))

      assert [
               needs_pallet_jack:
                 {"is only available for pallets", [validation: :valid_pallet_jack]}
             ] = errors
    end

    test "fails when creating estimate with cargo van and a lift gate" do
      insert(:market_zip_code,
        zip: "30501",
        market: build(:market, markup: 2.0, has_box_trucks: true)
      )

      assert {:error, :match_overrides, changeset, _} =
               Matches.create_estimate(pallet_jack_attrs(%{vehicle_class: 3, unload_method: nil}))

      assert %Changeset{
               changes: %{
                 match_stops: [
                   %Changeset{
                     errors: [
                       needs_pallet_jack:
                         {"is only available for box trucks", [validation: :valid_pallet_jack]}
                     ]
                   }
                 ]
               }
             } = changeset
    end

    test "fails when creating estimate with cargo van and a pallet jack" do
      insert(:market_zip_code,
        zip: "30501",
        market: build(:market, markup: 2.0, has_box_trucks: true)
      )

      assert {:error, :update_match,
              %Changeset{
                errors: [
                  unload_method:
                    {"not applicable for chosen vehicle class",
                     [validation: :allowed_unload_method]}
                ]
              },
              _} =
               Matches.create_estimate(
                 @valid_attrs
                 |> Map.put(:vehicle_class, 3)
                 |> Map.put(:unload_method, :lift_gate)
               )
    end

    test "fails when creating estimate with load/unload and no items" do
      insert(:market_zip_code,
        zip: "30501",
        market: build(:market, markup: 2.0, has_box_trucks: true)
      )

      assert {:error, :match_overrides,
              %Changeset{
                changes: %{
                  match_stops: [
                    %Changeset{
                      errors: errors
                    }
                  ]
                }
              }, _} = Matches.create_estimate(pallet_jack_attrs(%{}, %{has_load_fee: true}))

      assert [
               has_load_fee: {"is only available for items", [validation: :valid_load_unload]}
             ] = errors
    end

    test "fails when scheduled is true and pickup_at is nil" do
      assert {:error, :calculate_match_metrics,
              %Changeset{errors: [pickup_at: {_, [validation: :required]}]},
              _} =
               Matches.create_estimate(
                 @scheduled_attrs
                 |> Map.put(:pickup_at, nil)
                 |> Map.put(:scheduled, true)
               )
    end

    test "applies coupon without applying discount" do
      %{id: coupon_id} = insert(:small_coupon)

      assert {:ok,
              %Match{
                fees: [
                  %MatchFee{type: :base_fee, amount: 5879} | _
                ],
                coupon: %{id: ^coupon_id}
              }} = Matches.create_estimate(@valid_attrs |> Map.put(:coupon_code, "10OFF"))
    end

    test "creates estimate with contract key" do
      shipper = insert(:shipper_with_location)

      %{id: contract_id} =
        insert(:contract,
          pricing_contract: :menards_in_store,
          contract_key: "menards_in_store",
          company: shipper.location.company
        )

      assert {:ok,
              %Match{
                contract_id: ^contract_id,
                fees: [
                  %MatchFee{type: :base_fee, amount: 6900, driver_amount: 5175},
                  %MatchFee{type: :driver_tip, amount: 1000, driver_amount: 1000}
                ],
                driver_cut: 0.75
              }} =
               Matches.create_estimate(
                 @valid_attrs |> Map.put(:contract, "menards_in_store"),
                 shipper
               )
    end

    test "creates estimate with contract id" do
      shipper = insert(:shipper_with_location)

      %{id: contract_id} =
        insert(:contract,
          pricing_contract: :menards_in_store,
          company: shipper.location.company
        )

      assert {:ok,
              %Match{
                contract_id: ^contract_id,
                fees: [
                  %MatchFee{type: :base_fee, amount: 6900, driver_amount: 5175},
                  %MatchFee{type: :driver_tip, amount: 1000, driver_amount: 1000}
                ],
                driver_cut: 0.75
              }} =
               Matches.create_estimate(
                 @valid_attrs |> Map.put(:contract_id, contract_id),
                 shipper
               )
    end

    #  TODO: DEM-421 5/27/22 Once OR has fixed the contracts on their end, reneable this
    @tag :skip
    test "fails when no shipper" do
      insert(:contract, pricing_contract: :menards_in_store, contract_key: "menards_in_store")

      assert {:error, :update_match, %Changeset{errors: [contract_id: {"is invalid", []}]}, _} =
               Matches.create_estimate(@valid_attrs |> Map.put(:contract, "menards_in_store"))
    end

    test "fails for invalid contract" do
      shipper = insert(:shipper_with_location)

      insert(:contract, pricing_contract: :menards_in_store, contract_key: "menards_in_store")

      assert {:error, :update_match, %Changeset{errors: [contract_id: {"is invalid", []}]}, _} =
               Matches.create_estimate(
                 @valid_attrs |> Map.put(:contract_id, shipper.id),
                 shipper
               )

      #  TODO: DEM-421 5/27/22 Once OR has fixed the contracts on their end, reneable this

      # assert {:error, :update_match, %Changeset{errors: [contract_id: {"is invalid", []}]}, _} =
      #          Matches.create_estimate(
      #            @valid_attrs |> Map.put(:contract, "menards_in_store"),
      #            shipper
      #          )
    end

    test "creates estimate with origin_place_id" do
      assert {:ok, %Match{origin_address: %Address{zip: "45231"}}} =
               Matches.create_estimate(
                 @valid_attrs
                 |> Map.put(:origin_place_id, "ChIJE0DHwm5LQIgRNhhS8Fl6AS8")
               )
    end

    test "automatically selects vehicle" do
      assert {:ok, %Match{vehicle_class: 2, total_weight: 290, total_volume: 78}} =
               Matches.create_estimate(
                 @valid_attrs
                 |> Map.put(:autoselect_vehicle_class, true)
                 |> Map.delete(:vehicle_class)
               )
    end

    test "overrides vehicle class automatically when strict" do
      shipper = insert(:shipper)
      # we need to ensure that the user is properly preloaded
      shipper = Repo.get(FraytElixir.Accounts.Shipper, shipper.id)

      FunWithFlags.enable(:strict_autoselect_vehicle_class)

      assert {:ok, %Match{vehicle_class: 2, total_weight: 290, total_volume: 78}} =
               Matches.create_estimate(
                 @valid_attrs
                 |> Map.put(:autoselect_vehicle_class, true)
                 |> Map.put(:vehicle_class, 3),
                 shipper
               )
    end

    test "automatically selects vehicle with volume" do
      stop = %{
        (@valid_attrs[:stops]
         |> List.first())
        | items: [
            %{
              width: 12,
              length: 12,
              height: 12,
              weight: 1,
              pieces: 30,
              description: "Balloon"
            }
          ]
      }

      assert {:ok, %Match{vehicle_class: 2, total_weight: 30, total_volume: 51_840}} =
               Matches.create_estimate(
                 @valid_attrs
                 |> Map.put(:autoselect_vehicle_class, true)
                 |> Map.delete(:vehicle_class)
                 |> Map.put(:stops, [stop])
               )
    end

    test "automatically sets vehicle to nil when volume is too big" do
      stop = %{
        (@valid_attrs[:stops]
         |> List.first())
        | items: [
            %{
              width: 12,
              length: 120,
              height: 120,
              weight: 1,
              pieces: 30,
              description: "Balloon"
            }
          ]
      }

      assert {:error, :calculate_match_metrics,
              %Changeset{errors: [vehicle_class: {_, [validation: :required]}]},
              _} =
               Matches.create_estimate(
                 @valid_attrs
                 |> Map.put(:autoselect_vehicle_class, true)
                 |> Map.delete(:vehicle_class)
                 |> Map.put(:stops, [stop])
               )
    end

    test "applies company settings" do
      %{locations: [%{shippers: [shipper]}]} =
        insert(:company_with_location,
          origin_photo_required: true,
          destination_photo_required: true
        )

      assert {:ok,
              %Match{
                origin_photo_required: true,
                match_stops: [%MatchStop{destination_photo_required: true}]
              }} = Matches.create_estimate(@valid_attrs, shipper)
    end

    test "fails when too much cargo" do
      %{locations: [%{shippers: [shipper]}]} =
        insert(:company_with_location, autoselect_vehicle_class: true)

      match_attrs = %{
        shipper: shipper,
        origin_address: "708 Walnut St Cincinnati OH 45202",
        service_level: @dash,
        stops: [
          %{
            destination_address: "641 Evangeline Rd Cincinnati OH 45240",
            items: [
              %{
                height: 50,
                length: 50,
                width: 50,
                weight: 25,
                pieces: 80
              }
            ]
          }
        ]
      }

      assert {:error, :calculate_match_metrics,
              %Changeset{
                errors: [vehicle_class: {"can't be blank", [validation: :required]}]
              }, _data} = Matches.create_estimate(match_attrs)
    end

    test "fails when same day is placed with more than 10 stops / more than 150 mi" do
      params = %{
        pickup_at: ~N[2030-03-18 11:30:00],
        service_level: @same_day,
        origin_address: "this adddress",
        vehicle_class: 1,
        match_stops: build_match_stops_with_items(List.duplicate(:pending, 31))
      }

      assert {:error, :calculate_match_metrics,
              %Changeset{
                errors: [
                  match_stops:
                    {"must be 10 or less for a Same Day Match",
                     [count: 10, validation: :assoc_length, kind: :max]},
                  match_stops:
                    {"cannot be further than 150 miles for a Same Day Match",
                     [validation: :same_day_distance]}
                ]
              }, _} = Matches.create_estimate(params)
    end

    test "creates estimate when same day is placed with total distance below 30 miles" do
      params =
        @valid_attrs
        |> Map.merge(%{
          scheduled: true,
          pickup_at: ~N[2030-03-18 11:30:00],
          service_level: @same_day,
          match_stops: [
            %{
              destination_address: "641 Evangeline Rd Cincinnati OH 45240",
              items: [
                %{
                  height: 10,
                  length: 10,
                  width: 10,
                  weight: 25,
                  pieces: 1,
                  volume: 1
                }
              ]
            }
          ]
        })

      assert {:ok, %Match{total_distance: total_distance}} = Matches.create_estimate(params)
      assert total_distance < 30
    end

    test "fails when declared value exceed $10,000 on a single stop" do
      %{locations: [%{shippers: [shipper]}]} =
        insert(:company_with_location, autoselect_vehicle_class: true)

      match_attrs = %{
        shipper: shipper,
        origin_address: "708 Walnut St Cincinnati OH 45202",
        service_level: @dash,
        stops: [
          %{
            destination_address: "641 Evangeline Rd Cincinnati OH 45240",
            items: [
              %{
                height: 50,
                length: 50,
                width: 50,
                weight: 25,
                pieces: 80,
                declared_value: 5_000_00
              },
              %{
                height: 50,
                length: 50,
                width: 50,
                weight: 25,
                pieces: 80,
                declared_value: 5_001_00
              }
            ]
          }
        ]
      }

      assert {:error, :update_match,
              %Changeset{
                errors: [
                  match_stops:
                    {"We can insure up to $10,000. If you need additional coverage contact our sales team.",
                     []}
                ]
              }, _data} = Matches.create_estimate(match_attrs)
    end

    test "fails when declared values exceed $10,000 on a multiple stops" do
      %{locations: [%{shippers: [shipper]}]} =
        insert(:company_with_location, autoselect_vehicle_class: true)

      match_attrs = %{
        shipper: shipper,
        origin_address: "708 Walnut St Cincinnati OH 45202",
        service_level: @dash,
        stops: [
          %{
            destination_address: "641 Evangeline Rd Cincinnati OH 45240",
            items: [
              %{
                height: 50,
                length: 50,
                width: 50,
                weight: 25,
                pieces: 80,
                declared_value: 5_000_00
              }
            ]
          },
          %{
            destination_address: "750 Evangeline Rd Cincinnati OH 45240",
            items: [
              %{
                height: 50,
                length: 50,
                width: 50,
                weight: 25,
                pieces: 80,
                declared_value: 5_001_00
              }
            ]
          }
        ]
      }

      assert {:error, :update_match,
              %Changeset{
                errors: [
                  match_stops:
                    {"We can insure up to $10,000. If you need additional coverage contact our sales team.",
                     []}
                ]
              }, _data} = Matches.create_estimate(match_attrs)
    end

    test "success when declared value does not exceed $10,000" do
      %{locations: [%{shippers: [shipper]}]} =
        insert(:company_with_location, autoselect_vehicle_class: true)

      match_attrs = %{
        shipper: shipper,
        origin_address: "708 Walnut St Cincinnati OH 45202",
        service_level: @dash,
        stops: [
          %{
            destination_address: "641 Evangeline Rd Cincinnati OH 45240",
            items: [
              %{
                height: 50,
                length: 50,
                width: 50,
                weight: 25,
                pieces: 80,
                declared_value: 5_000_00
              }
            ]
          }
        ]
      }

      match_attrs =
        match_attrs
        |> Map.put(:vehicle_class, 2)

      assert {:ok, _changeset} = Matches.create_estimate(match_attrs)
    end
  end

  describe "update_estimate" do
    test "updates an estimate" do
      card = insert(:credit_card)

      assert {:ok, %{match_stops: [stop]} = match} =
               Matches.create_estimate(@valid_attrs, card.shipper)

      assert {:ok, match} =
               Matches.update_estimate(match, %{
                 stops: [
                   %{
                     destination_address: "641 Evangeline Rd Cincinnati OH 45240",
                     id: stop.id,
                     has_load_fee: false,
                     items:
                       Enum.map(stop.items, fn item ->
                         %{id: item.id, weight: 60, height: 10}
                       end),
                     po: "updated po"
                   }
                 ]
               })

      assert %Match{
               total_weight: 780,
               total_volume: 260,
               expected_toll: 0,
               markup: 1.0,
               total_distance: 1.7,
               state: :pending,
               fees: fees,
               match_stops: [
                 %{
                   destination_address: %Address{
                     formatted_address: "641 Evangeline Rd Cincinnati OH 45240"
                   },
                   has_load_fee: false,
                   items: [
                     %MatchStopItem{
                       width: 1.0,
                       length: 2.0,
                       height: 10.0,
                       pieces: 3,
                       weight: 60.0,
                       volume: 20,
                       description: "Gold Bar"
                     },
                     %MatchStopItem{
                       width: 1.0,
                       length: 2.0,
                       height: 10.0,
                       pieces: 10,
                       weight: 60.0,
                       volume: 20,
                       description: "Silver Bar"
                     }
                   ],
                   po: "updated po"
                 }
                 | _
               ]
             } = match

      fees = fees |> Enum.sort()

      [
        %{type: :base_fee, amount: 5879, driver_amount: 4002},
        %{type: :driver_tip, amount: 1000, driver_amount: 1000}
      ]
      |> Enum.sort()
      |> Enum.with_index()
      |> Enum.each(fn {expected_fee, index} ->
        %{type: type, amount: amount, driver_amount: driver_amount} = fees |> Enum.at(index)

        assert %{type: ^type, amount: ^amount, driver_amount: ^driver_amount} = expected_fee
      end)
    end

    test "doesn't update distance when address isn't changed" do
      %{match_stops: [stop]} =
        match =
        insert(:pending_match,
          total_distance: 1000,
          match_stops: [insert(:match_stop, distance: 1000, radial_distance: 1000)]
        )

      assert {:ok,
              %Match{
                total_distance: 1000.0,
                match_stops: [
                  %MatchStop{distance: 1000.0, radial_distance: 1000.0, has_load_fee: true}
                ]
              }} =
               Matches.update_estimate(
                 match,
                 %{stops: [%{id: stop.id, has_load_fee: true}]}
               )
    end

    test "updates the distance when origin address has changed" do
      match =
        insert(:pending_match,
          total_distance: 100_000,
          match_stops: [insert(:match_stop, distance: 100_000, radial_distance: 10_000)]
        )

      assert {:ok,
              %Match{
                total_distance: 5.0,
                match_stops: [%MatchStop{distance: 5.0, radial_distance: 0.0}]
              }} =
               Matches.update_estimate(match, %{origin_address: "62 Gallup St. Wilmington OH"})
    end

    test "updates the distance when stop address is changed" do
      %{match_stops: [stop]} =
        match =
        insert(:pending_match,
          total_distance: 100_000,
          match_stops: [insert(:match_stop, distance: 100_000, radial_distance: 10_000)]
        )

      assert {:ok,
              %Match{
                total_distance: 5.0,
                match_stops: [%MatchStop{distance: 5.0, radial_distance: 0.0}]
              }} =
               Matches.update_estimate(match, %{
                 stops: [%{id: stop.id, destination_address: "62 Gallup St. Wilmington OH"}]
               })
    end

    test "updates the distance when stop is added" do
      %{match_stops: [stop]} =
        match =
        insert(:pending_match,
          total_distance: 100_000,
          match_stops: [insert(:match_stop, distance: 100_000, radial_distance: 10_000)]
        )

      assert {:ok,
              %Match{
                total_distance: 10.0,
                match_stops: [
                  %MatchStop{distance: 5.0, radial_distance: 0.0},
                  %MatchStop{distance: 5.0, radial_distance: 0.0}
                ]
              }} =
               Matches.update_estimate(match, %{
                 stops: [
                   %{id: stop.id},
                   %{destination_address: "62 Gallup St. Wilmington OH", index: stop.index + 1}
                 ]
               })
    end

    test "fails when scheduled on christmas day" do
      match = insert(:pending_match, scheduled: true)

      assert {:error, :calculate_match_metrics,
              %Changeset{
                errors: [
                  dropoff_at: {_, [validation: :not_a_holiday, holiday: "Christmas Day"]},
                  pickup_at: {_, [validation: :not_a_holiday, holiday: "Christmas Day"]}
                ]
              },
              _} =
               Matches.update_estimate(match, %{
                 pickup_at: ~N[2030-12-25 10:00:00],
                 dropoff_at: ~N[2030-12-25 12:00:00]
               })
    end

    test "fails when not pending" do
      match = insert(:accepted_match)

      assert {:error, :invalid_state} = Matches.update_estimate(match, %{})
    end
  end

  describe "update_and_authorize_match" do
    test "updates and authorizes an estimate" do
      card = insert(:credit_card)

      assert {:ok, %{match_stops: [stop]} = match} =
               Matches.create_estimate(@valid_attrs, card.shipper)

      assert {:ok, match} =
               Matches.update_and_authorize_match(match, %{
                 stops: [
                   %{
                     destination_address: "641 Evangeline Rd Cincinnati OH 45240",
                     id: stop.id,
                     has_load_fee: false,
                     items:
                       Enum.map(stop.items, fn item ->
                         %{id: item.id, weight: 60, height: 10}
                       end)
                   }
                 ]
               })

      assert %Match{
               total_weight: 780,
               total_volume: 260,
               driver_cut: 0.72,
               markup: 1.0,
               total_distance: 1.7,
               amount_charged: 6879,
               driver_total_pay: 5002,
               tags: [%{name: :new}],
               state: :assigning_driver,
               match_stops: [
                 %{
                   destination_address: %Address{
                     formatted_address: "641 Evangeline Rd Cincinnati OH 45240"
                   },
                   has_load_fee: false,
                   items: items
                 }
                 | _
               ]
             } = match

      assert %{payment_transactions: [%{status: "succeeded"}]} =
               match |> Repo.preload(:payment_transactions)

      assert [
               %MatchStopItem{
                 width: 1.0,
                 length: 2.0,
                 height: 10.0,
                 pieces: 3,
                 weight: 60.0,
                 volume: 20,
                 description: "Gold Bar"
               },
               %MatchStopItem{
                 width: 1.0,
                 length: 2.0,
                 height: 10.0,
                 pieces: 10,
                 weight: 60.0,
                 volume: 20,
                 description: "Silver Bar"
               }
             ] = Enum.sort_by(items, & &1.description)
    end

    test "can unschedule a match" do
      card = insert(:credit_card, shipper: build(:shipper, location: build(:location)))

      assert {:ok, %Match{scheduled: true, state: :pending} = match} =
               Matches.create_estimate(@scheduled_attrs)

      assert {:ok, %Match{scheduled: false, state: :assigning_driver, match_stops: [_]}} =
               Matches.update_and_authorize_match(match, %{scheduled: false}, card.shipper)
    end

    test "fails when not in charged state" do
      match = insert(:charged_match)

      assert {:error, :invalid_state} = Matches.update_and_authorize_match(match, %{})
    end

    test "updates estimate when same day is scheduled before noon" do
      match =
        insert(:pending_match,
          service_level: @same_day,
          scheduled: true,
          pickup_at: ~N[2030-03-16 16:30:00],
          total_distance: 20
        )

      assert {:ok, %Match{scheduled: true}} =
               Matches.update_estimate(match, %{
                 pickup_at: ~N[2030-03-16 11:30:00]
               })
    end

    test "fails when same day is scheduled for pickup after noon" do
      match =
        insert(:pending_match,
          service_level: @same_day,
          total_distance: 20,
          scheduled: false,
          inserted_at: ~N[2030-03-18 09:00:00],
          origin_address: insert(:utc_address)
        )

      assert {:error, :calculate_match_metrics,
              %Changeset{
                errors: [
                  pickup_at: {"cannot be after 12:00PM for this service level", _}
                ]
              },
              _} =
               Matches.update_estimate(match, %{
                 scheduled: true,
                 pickup_at: ~N[2030-03-18 17:30:00]
               })
    end
  end

  describe "create_match" do
    test "creates a match and charges" do
      insert(:market_zip_code, zip: "30501", market: build(:market, markup: 2.0))
      card = insert(:credit_card)

      assert {:ok, match} = Matches.create_match(@valid_attrs, card.shipper)

      assert %Match{
               payment_transactions: [%{status: "succeeded"}],
               expected_toll: 0,
               driver_cut: 0.72,
               markup: 2.0,
               driver_total_pay: 108_66,
               amount_charged: 152_57,
               driver_fees: 4_73,
               price_discount: 0,
               fees: [
                 %MatchFee{type: :base_fee, amount: 117_58, driver_amount: 79_92},
                 %MatchFee{type: :driver_tip, amount: 10_00, driver_amount: 10_00},
                 %MatchFee{type: :load_fee, amount: 24_99, driver_amount: 18_74}
               ],
               tags: [%{name: :new}],
               state: :assigning_driver
             } = match |> Repo.preload(:payment_transactions)
    end

    test "creates match with account billing" do
      %{id: shipper_id} =
        shipper =
        insert(:shipper,
          location:
            insert(:location,
              company:
                insert(:company,
                  api_account: insert(:api_account),
                  account_billing_enabled: true
                )
            )
        )

      assert {:ok, %Match{driver_fees: 0, shipper_id: ^shipper_id}} =
               Matches.create_match(@valid_attrs, shipper)
    end

    test "authorize match for shipper with exising charged match does not add :new tag" do
      card = insert(:credit_card, shipper: build(:shipper, location: build(:location)))
      insert(:charged_match, shipper: card.shipper)
      assert {:ok, %{tags: []}} = Matches.create_match(@valid_attrs, card.shipper)
    end

    test "authorize match with bad card" do
      card = insert(:credit_card, stripe_card: "bad_card")

      assert {:error, :authorize_match, %Stripe.Error{extra: extra}, _} =
               Matches.create_match(@valid_attrs, card.shipper)

      assert %{
               card_code: :card_declined,
               decline_code: "generic_decline"
             } = extra
    end

    test "authorize match with coupon that's already been applied" do
      coupon = insert(:small_coupon, use_limit: 1)
      card = insert(:credit_card)

      attrs = @valid_attrs |> Map.put(:coupon_code, coupon.code)

      assert {:ok, _} = Matches.create_match(attrs, card.shipper)

      assert {:error, :update_match_coupon,
              %Ecto.Changeset{changes: %{shipper_match_coupon: changeset}},
              _} = Matches.create_match(attrs, card.shipper)

      assert {"code has already been used", _} = changeset.errors[:coupon_id]
    end

    test "authorize match when scheduled in 24 hours" do
      card = insert(:credit_card)
      tomorrow = DateTime.utc_now() |> DateTime.add(25 * 3600)

      attrs = @scheduled_attrs |> Map.put(:pickup_at, tomorrow)
      assert {:ok, %Match{state: :scheduled}} = Matches.create_match(attrs, card.shipper)
    end

    test "authorize match with a company billed by invoice" do
      invoiceable_shipper = insert(:shipper_with_location, state: :approved)

      assert {:ok, _} = Matches.create_match(@valid_attrs, invoiceable_shipper)
    end

    test "applies coupon with discount" do
      insert(:market_zip_code,
        zip: "30501",
        market: build(:market, markup: 2.0, calculate_tolls: true)
      )

      card = insert(:credit_card)
      %{id: coupon_id, code: code} = insert(:small_coupon)
      attrs = Map.put(@valid_attrs, :coupon_code, code)
      match = Matches.create_match(attrs, card.shipper)

      assert {:ok,
              %Match{
                expected_toll: 18_30,
                driver_cut: 0.72,
                markup: 2.0,
                driver_total_pay: 126_43,
                amount_charged: 154_79,
                driver_fees: 526,
                price_discount: 16_09,
                coupon: %{id: ^coupon_id},
                fees: [
                  %MatchFee{type: :base_fee, amount: 117_58, driver_amount: 79_39},
                  %MatchFee{type: :driver_tip, amount: 10_00, driver_amount: 10_00},
                  %MatchFee{type: :load_fee, amount: 24_99, driver_amount: 18_74},
                  %MatchFee{type: :toll_fees, amount: 18_30, driver_amount: 18_30}
                ]
              }} = match
    end

    test "calculates tolls for toll markets" do
      card = insert(:credit_card)

      %{id: market_id} =
        insert(:market, calculate_tolls: true, zip_codes: [insert(:market_zip_code, zip: "30501")])

      assert {:ok,
              %Match{
                expected_toll: 1830,
                fees: fees,
                market_id: ^market_id
              }} = Matches.create_match(@valid_attrs, card.shipper)

      assert %MatchFee{amount: 1830, driver_amount: 1830} =
               Enum.find(fees, &(&1.type == :toll_fees))
    end

    test "does not calculate tolls with no market" do
      card = insert(:credit_card)

      assert {:ok, %Match{expected_toll: 0, fees: fees}} =
               Matches.create_match(@valid_attrs, card.shipper)

      refute Enum.find(fees, &(&1.type == :toll_fees))
    end

    test "fails with no shipper" do
      assert {:error, :authorize_match,
              %Ecto.Changeset{
                errors: [
                  shipper: {"Your account is still pending approval.", []},
                  shipper_id: {"can't be blank", [validation: :required]}
                ]
              }, _data} = Matches.create_match(@valid_attrs, nil)
    end

    test "sends message to payments channel if a match with a $1000> charge is created" do
      card = insert(:credit_card)

      attrs =
        @valid_attrs
        |> Map.put(
          :stops,
          [
            %{
              destination_address: "708 Walnut St, Cincinnati, OH 45202",
              identifier: "identify",
              recipient: %{
                name: "John Smith",
                email: "jsmith@example.com",
                phone_number: "+15134020002",
                notify: true
              },
              self_recipient: false,
              tip_price: 100_000,
              has_load_fee: true,
              delivery_notes: "other notes about delivery",
              items: [
                %{
                  width: 1,
                  length: 2,
                  height: 3,
                  weight: 30,
                  pieces: 3,
                  description: "Gold Bar"
                }
              ]
            }
          ]
        )

      assert {:ok, match} = Matches.create_match(attrs, card.shipper)

      assert %Match{
               payment_transactions: [%{status: "succeeded"}],
               amount_charged: 1_058_79,
               tags: [%{name: :new}],
               state: :assigning_driver
             } = match |> Repo.preload(:payment_transactions)

      assert messages = FakeSlack.get_messages("#payments-test")

      assert Enum.any?(messages, fn {_, message} ->
               String.contains?(message, match.shortcode) and
                 String.contains?(message, match.shipper.first_name) and
                 String.contains?(message, "$1058.79")
             end)
    end

    test "does not send message to payments channel if a match with a $1000< charge is created" do
      card = insert(:credit_card)

      assert {:ok, match} =
               Matches.create_match(
                 @valid_attrs
                 |> Map.put(:origin_address, "1311 Vine Street, Cincinnati, OH 45202"),
                 card.shipper
               )

      assert %Match{
               payment_transactions: [%{status: "succeeded"}],
               tags: [%{name: :new}],
               state: :assigning_driver
             } = match |> Repo.preload(:payment_transactions)

      assert messages = FakeSlack.get_messages("#payments-test")

      assert Enum.all?(messages, fn {_, message} ->
               not String.contains?(message, match.shortcode)
             end)
    end

    test "bypasses same day validation and creates >30 mile match when same day is placed after noon by an admin" do
      admin = insert(:admin_user)

      %{shipper: shipper} =
        insert(:credit_card, shipper: build(:shipper, location: build(:location)))

      params =
        @valid_attrs
        |> Map.merge(%{
          scheduled: true,
          pickup_at: ~N[2030-03-18 16:30:00],
          service_level: @same_day
        })

      assert {:ok, %Match{total_distance: total_distance}} =
               Matches.create_match(params, shipper, admin)

      assert total_distance < 30
    end

    test "fallback to default contract when company doesn't have default contract defined" do
      shipper =
        insert(:shipper,
          location:
            insert(:location,
              company:
                insert(:company,
                  account_billing_enabled: true,
                  default_contract_id: nil
                )
            )
        )

      assert {:ok, %Match{contract_id: nil}} = Matches.create_match(@valid_attrs, shipper)
    end

    test "a match is created using the company default contract defined" do
      company = insert(:company, account_billing_enabled: true)

      %{id: contract_id} = contract = insert(:contract, company: company)

      company = %{company | default_contract: contract, default_contract_id: contract_id}

      shipper =
        insert(:shipper,
          location:
            insert(:location,
              company: company
            )
        )

      assert {:ok, %Match{contract_id: ^contract_id}} =
               Matches.create_match(@valid_attrs, shipper)
    end

    test "should succeed when signature type is photo and the instructions are provided" do
      card = insert(:credit_card)
      %{stops: [stop]} = @valid_attrs
      instructions = "signature instructions test"

      match_stop =
        Map.put(stop, :signature_type, :photo)
        |> Map.put(:signature_instructions, instructions)

      assert {:ok, %{match_stops: [stop]}} =
               @valid_attrs
               |> Map.put(:stops, [match_stop])
               |> Matches.create_match(card.shipper)

      assert %{
               signature_type: :photo,
               signature_instructions: ^instructions
             } = stop
    end

    test "should succeed when signature type is electronic whether the instructions are or not provided" do
      card = insert(:credit_card)
      %{stops: [stop]} = @valid_attrs
      instructions = "signature instructions test"

      match_stop =
        stop
        |> Map.put(:signature_type, :electronic)
        |> Map.put(:signature_instructions, instructions)

      assert {:ok, %{match_stops: [stop]}} =
               @valid_attrs
               |> Map.put(:stops, [match_stop])
               |> Matches.create_match(card.shipper)

      assert %{
               signature_type: :electronic,
               signature_instructions: ^instructions
             } = stop
    end

    test "signature instructions are required when signature type is a photo" do
      card = insert(:credit_card)
      %{stops: [stop]} = @valid_attrs
      stop = Map.put(stop, :signature_type, :photo)

      assert {:error, :update_match, err, _} =
               @valid_attrs
               |> Map.put(:stops, [stop])
               |> Matches.create_match(card.shipper)

      assert %Ecto.Changeset{changes: %{match_stops: [changeset]}} = err

      assert %Ecto.Changeset{
               errors: [
                 signature_instructions:
                   {"can't be blank for signature type", [validation: :required]}
               ]
             } = changeset
    end

    test ":electronic is set by default when no signature type is provided" do
      card = insert(:credit_card)

      assert {:ok, %{match_stops: [stop]}} =
               @valid_attrs
               |> Matches.create_match(card.shipper)

      assert %{signature_type: :electronic} = stop
    end

    test "signature instructions are not required when the signature type is
    electronic" do
      card = insert(:credit_card)
      %{stops: [stop]} = @valid_attrs
      stop = Map.put(stop, :signature_type, :electronic)

      assert {:ok, %{match_stops: [stop]}} =
               @valid_attrs
               |> Map.put(:stops, [stop])
               |> Matches.create_match(card.shipper)

      assert %{signature_instructions: nil} = stop
    end

    test "admin should be able to schedule match where pickup is greater than 7 days" do
      insert(:market_zip_code, zip: "30501", market: build(:market, markup: 2.0))
      admin = insert(:admin_user)
      card = insert(:credit_card, shipper: build(:shipper, location: build(:location)))

      attrs =
        @valid_attrs
        |> Map.merge(%{
          pickup_at: DateTime.add(DateTime.utc_now(), 904_800, :second),
          dropoff_at: ~U[2030-02-02 00:00:00.000000Z]
        })

      assert {:ok, _match} = Matches.create_match(attrs, card.shipper, admin)
    end

    test "shipper who are non net term user should not be allowed to create match greater than 7 days" do
      insert(:market_zip_code, zip: "30501", market: build(:market, markup: 2.0))
      card = insert(:credit_card)

      attrs =
        @valid_attrs
        |> Map.merge(%{
          pickup_at: DateTime.add(DateTime.utc_now(), 904_800, :second),
          dropoff_at: ~U[2030-02-02 00:00:00.000000Z]
        })

      assert {
               :error,
               :calculate_match_metrics,
               %Ecto.Changeset{
                 errors: [
                   pickup_at:
                     {_,
                      [
                        {:time, _},
                        {:validation, :date_time},
                        {:kind, :less_than}
                      ]}
                 ]
               },
               _match
             } = Matches.create_match(attrs, card.shipper)
    end

    test "shipper who are non net term user should be allowed to create match less than 7 days" do
      insert(:market_zip_code, zip: "30501", market: build(:market, markup: 2.0))
      card = insert(:credit_card)

      attrs =
        @valid_attrs
        |> Map.merge(%{
          pickup_at: DateTime.add(DateTime.utc_now(), 104_800, :second),
          dropoff_at: ~U[2030-02-02 00:00:00.000000Z]
        })

      assert {
               :ok,
               _match
             } = Matches.create_match(attrs, card.shipper)
    end

    test "shipper who are net term user should be able to create match greater than 7 days" do
      insert(:market_zip_code, zip: "30501", market: build(:market, markup: 2.0))
      card = insert(:credit_card_with_billing_enabled_true)

      attrs =
        @valid_attrs
        |> Map.merge(%{
          pickup_at: DateTime.add(DateTime.utc_now(), 904_800, :second),
          dropoff_at: ~U[2030-02-02 00:00:00.000000Z]
        })

      assert {:ok, _match} = Matches.create_match(attrs, card.shipper)
    end
  end

  describe "update_match" do
    test "creates a match and charges" do
      %{match_stops: [stop]} =
        match =
        insert(:assigning_driver_match,
          total_distance: 1.9,
          travel_duration: 171,
          total_volume: 12,
          total_weight: 10,
          fees: [],
          expected_toll: 1830,
          driver_cut: 0.5,
          driver_total_pay: 1000,
          fees: [
            build(:match_fee, type: :base_fee, amount: 3699, driver_amount: 2359),
            build(:match_fee, type: :toll_fees, amount: 1830, driver_amount: 1830),
            build(:match_fee, type: :driver_tip, amount: 500, driver_amount: 500)
          ],
          match_stops: [
            build(:match_stop,
              index: 0,
              items: [
                build(:match_stop_item,
                  width: 2,
                  length: 1,
                  height: 3,
                  pieces: 1,
                  weight: 2,
                  description: "a"
                ),
                build(:match_stop_item,
                  width: 2,
                  length: 1,
                  height: 3,
                  pieces: 1,
                  weight: 8,
                  description: "b"
                )
              ]
            )
          ]
        )

      assert {:ok, match} =
               Matches.update_match(match, %{
                 stops: [
                   %{
                     destination_address: "641 Evangeline Rd Cincinnati OH 45240",
                     id: stop.id,
                     has_load_fee: true,
                     items:
                       Enum.map(stop.items, fn item ->
                         %{id: item.id, weight: 200, height: 10}
                       end)
                   }
                 ]
               })

      assert %Match{
               total_weight: 400,
               total_volume: 40,
               fees: fees,
               expected_toll: 18_30,
               driver_cut: 0.72,
               markup: 1.0,
               total_distance: 5.0,
               travel_duration: 450,
               driver_total_pay: 44_54,
               amount_charged: 63_83,
               driver_fees: 2_16,
               price_discount: 0,
               state: :assigning_driver,
               match_stops: [
                 %{
                   destination_address: %Address{
                     formatted_address: "641 Evangeline Rd Cincinnati OH 45240"
                   },
                   has_load_fee: true,
                   items: items
                 }
                 | _
               ]
             } = match

      assert [
               %MatchFee{type: :base_fee, amount: 3884, driver_amount: 2580},
               %MatchFee{type: :load_fee, amount: 2499, driver_amount: 1874}
             ] = Enum.sort_by(fees, & &1.type)

      assert [
               %MatchStopItem{
                 width: 2.0,
                 length: 1.0,
                 height: 10.0,
                 pieces: 1,
                 weight: 200.0,
                 volume: 20
               },
               %MatchStopItem{
                 width: 2.0,
                 length: 1.0,
                 height: 10.0,
                 pieces: 1,
                 weight: 200.0,
                 volume: 20
               }
             ] = Enum.sort_by(items, & &1.description)
    end

    test "updates tolls" do
      match =
        insert(:match,
          fees: [build(:match_fee, type: :toll_fees, amount: 1000)],
          expected_toll: 1000,
          origin_address: build(:address, zip: "45133"),
          market: nil
        )

      insert(:market, calculate_tolls: true, zip_codes: [insert(:market_zip_code, zip: "30501")])

      assert {:ok, %Match{expected_toll: 18_30, fees: fees}} =
               Matches.update_match(match, @valid_attrs)

      assert %MatchFee{amount: 18_30} = Enum.find(fees, &(&1.type == :toll_fees))
    end

    test "does not update tolls when address does not change" do
      market =
        insert(:market, calculate_tolls: true, zip_codes: [insert(:market_zip_code, zip: "30501")])

      match =
        insert(:match,
          fees: [build(:match_fee, type: :toll_fees, amount: 1000)],
          origin_address: build(:address, zip: "30501"),
          expected_toll: 1000,
          market: market
        )

      assert {:ok, %Match{expected_toll: 1000, fees: fees}} = Matches.update_match(match, %{})

      assert %MatchFee{amount: 1000} = Enum.find(fees, &(&1.type == :toll_fees))
    end

    test "doesn't update pricing when manual price is true" do
      card = insert(:credit_card)
      assert {:ok, match} = Matches.create_match(@valid_attrs, card.shipper)
      assert {:ok, match} = match |> Matches.update_match_price(%{manual_price: true})

      assert {:ok,
              %Match{
                fees: [
                  %MatchFee{type: :base_fee, amount: 5879, driver_amount: 3930},
                  %MatchFee{type: :driver_tip, amount: 1000, driver_amount: 1000},
                  %MatchFee{type: :load_fee, amount: 2499, driver_amount: 1874}
                ],
                expected_toll: 0,
                driver_cut: 0.72,
                driver_total_pay: 68_04,
                amount_charged: 93_78,
                driver_fees: 3_02,
                price_discount: 0,
                vehicle_class: 1,
                manual_price: true
              }} = Matches.update_match(match, %{vehicle_class: 1})
    end

    test "doesn't update pricing when charged or canceled" do
      card = insert(:credit_card)

      assert {:ok, match} = Matches.create_match(@valid_attrs, card.shipper)

      assert {:ok, match} = match |> Match.changeset(%{state: :charged}) |> Repo.update()

      assert {:ok,
              %Match{
                driver_total_pay: 68_04,
                amount_charged: 93_78,
                vehicle_class: 1,
                manual_price: false
              }} = Matches.update_match(match, %{vehicle_class: 1})
    end

    test "doesn't update pricing when charged" do
      card = insert(:credit_card, shipper: build(:shipper, location: build(:location)))
      driver = insert(:driver_with_wallet)

      assert {:ok, match} = Matches.create_match(@valid_attrs, card.shipper)

      assert {:ok, match} =
               match
               |> Match.changeset(%{state: :charged, driver_id: driver.id})
               |> Repo.update()

      %{
        driver_total_pay: prev_driver_total_pay,
        amount_charged: prev_amount_charged
      } = match

      assert {:ok,
              %Match{
                driver_total_pay: ^prev_driver_total_pay,
                amount_charged: ^prev_amount_charged,
                vehicle_class: 1,
                manual_price: false
              }} = Matches.update_match(match, %{vehicle_class: 1})
    end

    test "activates scheduled match if within 18 hours of pickup" do
      card = insert(:credit_card, shipper: build(:shipper, location: build(:location)))

      assert {:ok, %Match{state: :scheduled} = match} =
               Matches.create_match(@scheduled_attrs, card.shipper)

      assert {:ok,
              %Match{
                state: :assigning_driver
              }} = Matches.update_match(match, %{pickup_at: DateTime.utc_now()})
    end

    test "updates stop indexes" do
      card = insert(:credit_card)

      assert {:ok,
              %Match{match_stops: [%{id: stop1_id, index: 0}, %{id: stop2_id, index: 1}]} = match} =
               Matches.create_match(@valid_multi_attrs, card.shipper)

      assert {:ok, %Match{match_stops: stops}} =
               Matches.update_match(match, %{
                 stops: [%{id: stop1_id, index: 1}, %{id: stop2_id, index: 0}]
               })

      assert [
               %MatchStop{id: ^stop2_id, index: 0},
               %MatchStop{id: ^stop1_id, index: 1}
             ] = stops
    end

    test "fails when pending" do
      match = insert(:pending_match)

      assert {:error, :invalid_state} = Matches.update_match(match, %{})
    end

    test "Optimized stops aren't reoptimized but success update" do
      %{
        match_stops: [
          %{id: stop0_id, index: stop0_index},
          %{id: stop1_id, index: stop1_index},
          %{id: stop2_id, index: stop2_index}
        ]
      } =
        match =
        insert(:match,
          optimized_stops: true,
          match_stops: [
            build(:match_stop,
              index: 0,
              destination_address:
                build(:address, geo_location: %Geo.Point{coordinates: {-84.5118912, 40.1043198}})
            ),
            build(:match_stop,
              index: 1,
              destination_address:
                build(:address, geo_location: %Geo.Point{coordinates: {-84.5118912, 39.1043198}})
            ),
            build(:match_stop,
              index: 2,
              destination_address:
                build(:address, geo_location: %Geo.Point{coordinates: {-84.5118912, 41.1043198}})
            )
          ]
        )

      assert {:ok, %{match_stops: stops} = _match} =
               Matches.update_match(match, %{optimize: true})

      assert [
               %{id: ^stop0_id, index: ^stop0_index},
               %{id: ^stop1_id, index: ^stop1_index},
               %{id: ^stop2_id, index: ^stop2_index}
             ] = stops |> Enum.sort_by(& &1.index)
    end

    test "Index are optimized when optimize param is set true" do
      %{match_stops: [%{id: stop0_id}, %{id: stop1_id}, %{id: stop2_id}]} =
        match =
        insert(:match,
          optimized_stops: false,
          match_stops: [
            build(:match_stop,
              index: 0,
              destination_address:
                build(:address, geo_location: %Geo.Point{coordinates: {-84.5118912, 40.1043198}})
            ),
            build(:match_stop,
              index: 1,
              destination_address:
                build(:address, geo_location: %Geo.Point{coordinates: {-84.5118912, 39.1043198}})
            ),
            build(:match_stop,
              index: 2,
              destination_address:
                build(:address, geo_location: %Geo.Point{coordinates: {-84.5118912, 41.1043198}})
            )
          ]
        )

      assert {:ok, %{match_stops: stops} = _match} =
               Matches.update_match(match, %{optimize: true})

      assert [
               %{id: ^stop1_id, index: 0},
               %{id: ^stop0_id, index: 1},
               %{id: ^stop2_id, index: 2}
             ] = stops |> Enum.sort_by(& &1.index)
    end

    test "Unoptimized stops aren't optimized when optimize param is set false" do
      %{
        match_stops: [
          %{id: stop0_id, index: stop0_index},
          %{id: stop1_id, index: stop1_index},
          %{id: stop2_id, index: stop2_index}
        ]
      } =
        match =
        insert(:match,
          optimized_stops: false,
          match_stops: [
            build(:match_stop,
              index: 0,
              destination_address:
                build(:address, geo_location: %Geo.Point{coordinates: {-84.5118912, 40.1043198}})
            ),
            build(:match_stop,
              index: 1,
              destination_address:
                build(:address, geo_location: %Geo.Point{coordinates: {-84.5118912, 39.1043198}})
            ),
            build(:match_stop,
              index: 2,
              destination_address:
                build(:address, geo_location: %Geo.Point{coordinates: {-84.5118912, 41.1043198}})
            )
          ]
        )

      assert {:ok, %{match_stops: stops} = _match} =
               Matches.update_match(match, %{optimize: false})

      assert [
               %{id: ^stop0_id, index: ^stop0_index},
               %{id: ^stop1_id, index: ^stop1_index},
               %{id: ^stop2_id, index: ^stop2_index}
             ] = stops |> Enum.sort_by(& &1.index)
    end

    test "Unoptimized stops aren't optimized when more than 11 stops" do
      match =
        insert(:match,
          optimized_stops: false,
          match_stops: Enum.map(0..49, &build(:match_stop, index: &1))
        )

      assert {:error, :calculate_match_metrics, _changeset, _} =
               Matches.update_match(match, %{optimize: true})
    end

    test "updates platform and preferred_driver_id" do
      %{id: driver_id} = insert(:driver)

      match =
        insert(:assigning_driver_match,
          platform: :deliver_pro,
          preferred_driver_id: driver_id
        )

      update_params = %{platform: "marketplace", preferred_driver_id: nil}

      assert {:ok, %{platform: :marketplace, preferred_driver_id: nil}} =
               Matches.update_match(match, update_params)
    end

    test "notifies original preferred driver if preferred driver is updated" do
      %{id: driver_id} = driver = insert(:driver)

      set_driver_default_device(driver)

      match =
        insert(:assigning_driver_match,
          platform: :deliver_pro,
          preferred_driver_id: driver_id
        )

      update_params = %{preferred_driver_id: nil}

      assert {:ok, %{preferred_driver_id: nil}} = Matches.update_match(match, update_params)

      query =
        from(sent in FraytElixir.Notifications.SentNotification, where: sent.match_id == ^match.id)

      assert [%{driver_id: ^driver_id}] = Repo.all(query)
    end

    test "restarts match driver notifier when a match is converted from deliver pro preferred driver to marketplace" do
      gaslight_address = build(:address, geo_location: gaslight_point())

      match =
        insert(:assigning_driver_match, platform: :deliver_pro, origin_address: gaslight_address)

      driver_location_within_5_miles =
        insert(:driver_location, geo_location: findlay_market_point())

      %{id: driver_id} = driver = set_driver_default_device(driver_location_within_5_miles.driver)

      FraytElixir.Drivers.update_current_location(driver, findlay_market_point())

      update_params = %{platform: :marketplace}

      assert {:ok, %{platform: :marketplace}} = Matches.update_match(match, update_params)

      assert not is_nil(GenServer.whereis({:global, "match_notify_drivers:#{match.id}"}))

      :timer.sleep(200)

      query =
        from(sent in FraytElixir.Notifications.SentNotification, where: sent.match_id == ^match.id)

      assert [%{driver_id: ^driver_id}] = Repo.all(query)
    end

    test "returns error if attempting to switch from marketplace to deliver_pro" do
      match = insert(:assigning_driver_match, platform: :marketplace)

      assert {:error, :update_match,
              %Changeset{
                errors: [platform: {"invalid platform change", []}]
              }, _} = Matches.update_match(match, %{platform: "deliver_pro"})
    end

    test "returns error if attempting to update the preferred driver for an accepted match" do
      match = insert(:accepted_match, platform: :deliver_pro)

      %{id: new_driver_id} = insert(:driver)

      assert {:error, :update_match,
              %Changeset{
                errors: [preferred_driver_id: {"unable to update preferred driver", []}]
              }, _} = Matches.update_match(match, %{preferred_driver_id: new_driver_id})
    end

    test "returns error if attempting to update the platform for an accepted match" do
      match = insert(:accepted_match, platform: :deliver_pro)

      assert {:error, :update_match,
              %Changeset{
                errors: [platform: {"can not change platform for accepted match", []}]
              }, _} = Matches.update_match(match, %{platform: "marketplace"})
    end
  end

  describe "update_or_insert_stop" do
    test "updates correct stop" do
      card = insert(:credit_card)

      assert {:ok,
              %Match{
                id: match_id,
                match_stops: [
                  %MatchStop{id: other_stop_id},
                  %MatchStop{id: stop_id, items: [%MatchStopItem{id: item_id}]}
                ]
              } = match} = Matches.create_match(@valid_multi_attrs, card.shipper)

      assert {:ok,
              %Match{
                id: ^match_id,
                match_stops: [
                  %MatchStop{id: ^other_stop_id},
                  %MatchStop{
                    id: ^stop_id,
                    destination_address: %Address{
                      formatted_address: "1311 Vine St. Cincinnati, OH 45202"
                    },
                    items: [
                      %MatchStopItem{id: ^item_id, pieces: 1, description: "Arkenstone"},
                      %MatchStopItem{
                        description: "The One Ring",
                        width: 2.0,
                        length: 2.0,
                        height: 1.0,
                        weight: 30.0,
                        pieces: 1
                      }
                    ]
                  }
                ]
              }} =
               Matches.update_or_insert_stop(match, stop_id, %{
                 destination_address: "1311 Vine St. Cincinnati, OH 45202",
                 items: [
                   %{
                     id: item_id,
                     description: "Arkenstone",
                     pieces: 1
                   },
                   %{
                     description: "The One Ring",
                     width: 2,
                     length: 2,
                     height: 1,
                     weight: 30,
                     pieces: 1
                   }
                 ]
               })
    end

    test "inserts a stop when id is empty" do
      card = insert(:credit_card)

      assert {:ok,
              %Match{
                id: match_id,
                match_stops: [
                  %MatchStop{id: stop1_id},
                  %MatchStop{id: stop2_id}
                ]
              } = match} = Matches.create_match(@valid_multi_attrs, card.shipper)

      assert {:ok,
              %Match{
                id: ^match_id,
                match_stops: [
                  %MatchStop{id: ^stop1_id},
                  %MatchStop{id: ^stop2_id},
                  %MatchStop{
                    destination_address: %Address{
                      formatted_address: "1311 Vine St. Cincinnati, OH 45202"
                    },
                    items: [
                      %MatchStopItem{
                        description: "The One Ring",
                        width: 2.0,
                        length: 2.0,
                        height: 1.0,
                        weight: 30.0,
                        pieces: 1
                      }
                    ]
                  }
                ]
              }} =
               Matches.update_or_insert_stop(match, "", %{
                 destination_address: "1311 Vine St. Cincinnati, OH 45202",
                 items: [
                   %{
                     description: "The One Ring",
                     width: 2,
                     length: 2,
                     height: 1,
                     weight: 30,
                     pieces: 1
                   }
                 ]
               })
    end
  end

  describe "delete_stop/2" do
    test "deletes stop and recalculates index" do
      assert %{match_stops: [%{id: stop_id}, %{id: remaining_stop_id, index: 1}]} =
               match =
               insert(:match, match_stops: build_match_stops_with_items([:pending, :pending]))

      assert {:ok, %Match{match_stops: [%MatchStop{id: ^remaining_stop_id, index: 0}]}} =
               Matches.delete_stop(match, stop_id)
    end

    test "returns error when deleting only stop" do
      %{match_stops: [%{id: stop_id}]} = match = insert(:match, match_stops: [build(:match_stop)])

      assert {:error, :update_match,
              %Changeset{
                errors: [match_stops: {_, [count: 1, validation: :assoc_length, kind: :min]}]
              }, _} = Matches.delete_stop(match, stop_id)
    end
  end

  describe "update_match_price" do
    test "sets manual pricing" do
      card = insert(:credit_card)

      assert {:ok, match} = Matches.create_match(@valid_attrs, card.shipper)

      assert {:ok,
              %Match{
                fees: [
                  %MatchFee{type: :base_fee, amount: 1000, driver_amount: 850},
                  %MatchFee{type: :driver_tip, amount: 1000, driver_amount: 1000},
                  %MatchFee{type: :load_fee, amount: 2499, driver_amount: 1874},
                  %MatchFee{type: :toll_fees, amount: 1900, driver_amount: 1900}
                ],
                expected_toll: 0,
                driver_cut: 0.72,
                driver_total_pay: 56_24,
                amount_charged: 63_99,
                driver_fees: 2_16,
                price_discount: 0,
                manual_price: true
              }} =
               Matches.update_match_price(match, %{
                 manual_price: true,
                 fees: [
                   %{type: :base_fee, amount: 1000, driver_amount: 850},
                   %{type: :driver_tip, amount: 1000, driver_amount: 1000},
                   %{type: :load_fee, amount: 2499, driver_amount: 1874},
                   %{type: :toll_fees, amount: 1900, driver_amount: 1900}
                 ]
               })
    end

    test "recalculates pricing when manual pricing is false" do
      match =
        insert(:match,
          fees: [build(:match_fee, type: :base_fee, amount: 1000, driver_amount: 800)],
          match_stops: [build(:match_stop, index: 0)]
        )

      assert {:ok,
              %Match{
                driver_cut: 0.72,
                driver_total_pay: 26_53,
                amount_charged: 38_84,
                driver_fees: 1_43,
                price_discount: 0,
                manual_price: false,
                fees: [
                  %MatchFee{type: :base_fee, amount: 3884, driver_amount: 26_53}
                ]
              }} =
               Matches.update_match_price(match, %{
                 manual_price: false,
                 fees: [
                   %{type: :base_fee, amount: 1000, driver_amount: 750}
                 ]
               })
    end

    test "doesn't recalculate pricing when manual pricing is true and no fees are provided" do
      match =
        insert(:match,
          manual_price: true,
          fees: [
            build(:match_fee, type: :base_fee, amount: 1000, driver_amount: 800),
            build(:match_fee, type: :load_fee, amount: 2000, driver_amount: 1000)
          ],
          match_stops: [build(:match_stop, index: 0)]
        )

      assert {:ok,
              %Match{
                driver_cut: 0.75,
                driver_total_pay: 18_00,
                amount_charged: 30_00,
                driver_fees: 117,
                price_discount: 0,
                manual_price: true,
                fees: [
                  %MatchFee{type: :base_fee, amount: 10_00, driver_amount: 8_00},
                  %MatchFee{type: :load_fee, amount: 20_00, driver_amount: 10_00}
                ]
              }} = Matches.update_match_price(match)
    end

    test "applies coupon when manual pricing is true" do
      match =
        insert(:match,
          price_discount: 0,
          fees: [
            build(:match_fee, type: :base_fee, amount: 1999, driver_amount: 1500)
          ]
        )

      %{id: coupon_id} = insert(:small_coupon)

      assert {:ok,
              %Match{
                driver_total_pay: 8_50,
                driver_fees: 59,
                amount_charged: 9_00,
                price_discount: 100,
                manual_price: true,
                fees: [
                  %MatchFee{type: :base_fee, amount: 1000, driver_amount: 850}
                ],
                coupon: %{id: ^coupon_id}
              }} =
               Matches.update_match_price(match, %{
                 manual_price: true,
                 coupon_code: "10OFF",
                 fees: [
                   %{type: :base_fee, amount: 1000, driver_amount: 850}
                 ]
               })
    end

    test "removes coupon" do
      match =
        insert(:match,
          price_discount: 100,
          fees: [
            build(:match_fee, amount: 1999, driver_amount: 1500)
          ]
        )

      insert(:shipper_match_coupon, match: match, shipper: match.shipper)

      match = match |> Repo.preload(:shipper_match_coupon, force: true)

      assert {:ok,
              %Match{
                driver_total_pay: 8_50,
                driver_fees: 59,
                amount_charged: 10_00,
                price_discount: 0,
                manual_price: true,
                shipper_match_coupon: nil,
                fees: [
                  %MatchFee{type: :base_fee, amount: 1000, driver_amount: 850}
                ]
              }} =
               Matches.update_match_price(match, %{
                 manual_price: true,
                 coupon_code: "",
                 fees: [
                   %{type: :base_fee, amount: 1000, driver_amount: 850}
                 ]
               })
    end

    test "fails when passing missing base fee" do
      match = insert(:match)

      assert {:error, :calculate_match_pricing,
              %Changeset{
                errors: [
                  fees:
                    {_, [count: 1, validation: :assoc_length, kind: :min, fee_type: :base_fee]}
                ]
              },
              %{}} =
               Matches.update_match_price(match, %{
                 manual_price: true,
                 fees: []
               })
    end

    test "fails when match is canceled, charged or pending" do
      match = insert(:pending_match)

      assert {:error, :invalid_state} = Matches.update_match_price(match, %{manual_price: true})
    end
  end

  describe "match_changes" do
    test "recalculates metrics, pricing, and charges" do
      match =
        insert(:match,
          amount_charged: 10_00,
          total_weight: 999,
          origin_address: nil,
          fees: [
            build(:match_fee, amount: 100_00)
          ],
          match_stops: [build(:match_stop, index: 0)],
          market: nil
        )

      assert {:ok,
              %{
                calculate_match_payout: %Match{
                  fees: [
                    %MatchFee{type: :base_fee, amount: 38_84}
                  ],
                  amount_charged: 38_84,
                  total_weight: 40
                }
              }} =
               Multi.new()
               |> Multi.run(:match, fn _, _ ->
                 {:ok, match}
               end)
               |> Matches.match_changes(%{origin_address: "16 Gallup St. Wilmington, OH 45177"})
               |> Repo.transaction()
    end
  end

  describe "create_batch_match_changes" do
    test "create batch match with index" do
      shipper = insert(:shipper, location: build(:location))

      assert {:ok,
              %{
                "match_2" => _,
                "validate_match_2" => %Match{}
              }} =
               Multi.new()
               |> Matches.create_batch_match_changes(@valid_attrs, shipper, 2)
               |> Repo.transaction()
    end
  end

  describe "apply_cancel_charge" do
    test "apply cancel charge with driver cut" do
      match = insert(:match, state: :admin_canceled, cancel_charge: nil, amount_charged: 1000)

      assert {:ok,
              %Match{state: :admin_canceled, cancel_charge: 500, cancel_charge_driver_pay: 400}} =
               Matches.apply_cancel_charge(match, %{
                 cancellation_percent: 0.5,
                 driver_percent: 0.8
               })
    end

    test "apply cancel charge without driver cut" do
      match = insert(:match, state: :admin_canceled, cancel_charge: nil, amount_charged: 1000)

      assert {:ok,
              %Match{state: :admin_canceled, cancel_charge: 500, cancel_charge_driver_pay: 0}} =
               Matches.apply_cancel_charge(match, %{cancellation_percent: 0.5})
    end

    test "charges and transfers cancel charge if one is set" do
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

      assert {:ok, %Match{state: :admin_canceled, id: match_id}} =
               Matches.apply_cancel_charge(match, %{
                 cancellation_percent: 0.5,
                 driver_percent: 0.8
               })

      payment_transactions =
        FraytElixir.Repo.all(from(p in PaymentTransaction, where: p.match_id == ^match_id))

      assert payment_transactions |> Enum.map(& &1.transaction_type) |> Enum.sort() == [
               :authorize
             ]
    end

    test "only charges cancel charge if match has no driver" do
      %PaymentTransaction{match: match} =
        insert(:payment_transaction,
          transaction_type: :authorize,
          status: "succeeded",
          match:
            build(:match,
              amount_charged: 2000,
              driver: nil,
              state: :admin_canceled
            )
        )

      match = Repo.preload(match, :payment_transactions)

      assert {:ok, %Match{id: match_id, state: :admin_canceled}} =
               Matches.apply_cancel_charge(match, %{
                 cancellation_percent: 0.5,
                 driver_percent: 0.8
               })

      payment_transactions =
        FraytElixir.Repo.all(from(p in PaymentTransaction, where: p.match_id == ^match_id))

      assert payment_transactions |> Enum.map(& &1.transaction_type) |> Enum.sort() == [
               :authorize
             ]
    end

    test "charges and transfers cancel charge if one is set for an account billing customer" do
      %PaymentTransaction{match: match} =
        insert(:payment_transaction,
          transaction_type: :authorize,
          status: "succeeded",
          match:
            build(:match,
              amount_charged: 2000,
              shipper:
                build(:shipper,
                  location:
                    build(:location, company: build(:company, account_billing_enabled: true))
                ),
              driver: build(:driver_with_wallet),
              state: :admin_canceled
            )
        )

      match = Repo.preload(match, :payment_transactions)

      assert {:ok, %Match{id: match_id, state: :admin_canceled}} =
               Matches.apply_cancel_charge(match, %{
                 cancellation_percent: 0.5,
                 driver_percent: 0.75
               })

      payment_transactions =
        FraytElixir.Repo.all(from(p in PaymentTransaction, where: p.match_id == ^match_id))

      assert payment_transactions |> Enum.map(& &1.transaction_type) |> Enum.sort() == [
               :authorize
             ]
    end

    test "no cancellation charge when none is provided" do
      %PaymentTransaction{match: match} =
        insert(:payment_transaction,
          transaction_type: :authorize,
          status: "succeeded",
          match: build(:match, state: :admin_canceled)
        )

      assert {:ok,
              %Match{
                cancel_charge: nil,
                cancel_charge_driver_pay: nil
              }} = Matches.apply_cancel_charge(match)
    end

    test "applies contract cancellation pay rule when no cancel charge" do
      %PaymentTransaction{match: match} =
        insert(:payment_transaction,
          transaction_type: :authorize,
          status: "succeeded",
          match:
            build(:match,
              amount_charged: 2000,
              contract:
                insert(:contract,
                  cancellation_pay_rules: [
                    build(:cancellation_pay_rule,
                      restrict_states: true,
                      in_states: [:assigning_driver],
                      cancellation_percent: 0.5,
                      driver_percent: 0.5
                    )
                  ]
                ),
              driver: build(:driver_with_wallet),
              state: :admin_canceled,
              state_transitions: [
                insert(:match_state_transition, from: :assigning_driver, to: :admin_canceled)
              ]
            )
        )

      match = Repo.preload(match, :payment_transactions)

      assert {:ok,
              %Match{
                cancel_charge: 1000,
                cancel_charge_driver_pay: 500
              }} = Matches.apply_cancel_charge(match)

      assert {:ok,
              %Match{
                cancel_charge: 1500,
                cancel_charge_driver_pay: 1125
              }} =
               Matches.apply_cancel_charge(match, %{
                 cancellation_percent: 0.75,
                 driver_percent: 0.75
               })
    end
  end

  describe "build_stops" do
    @valid_attrs %{
      stops: [
        %{
          has_load_fee: false,
          destination_address: "863 Dawsonville Hwy, Gainesville, GA 30501",
          items: [
            %{
              width: 10,
              length: 2,
              height: 5,
              weight: 10,
              pieces: 3
            }
          ]
        },
        %{
          has_load_fee: true,
          destination_address: "641 Evangeline Rd Cincinnati OH 45240",
          items: [
            %{
              width: 5,
              length: 2,
              height: 5,
              weight: 10,
              pieces: 3
            }
          ]
        }
      ]
    }

    test "calculates volume and applies company settings" do
      assert %{
               match_stops: [
                 %{
                   has_load_fee: false,
                   destination_address: "863 Dawsonville Hwy, Gainesville, GA 30501",
                   index: 0,
                   destination_photo_required: true,
                   items: [
                     %{
                       width: 10,
                       length: 2,
                       height: 5,
                       weight: 10,
                       pieces: 3,
                       volume: 100
                     }
                   ],
                   signature_required: true
                 },
                 %{
                   has_load_fee: true,
                   destination_address: "641 Evangeline Rd Cincinnati OH 45240",
                   destination_photo_required: true,
                   index: 1,
                   items: [
                     %{
                       width: 5,
                       length: 2,
                       height: 5,
                       weight: 10,
                       pieces: 3,
                       volume: 50
                     }
                   ],
                   signature_required: true
                 }
               ]
             } ==
               Matches.build_stops(@valid_attrs, [], %{
                 destination_photo_required: true,
                 signature_required: true
               })
    end
  end

  describe "get_en_route_matches/0" do
    test "gets only en route matches" do
      m1 = insert(:match, state: :en_route_to_pickup)
      m2 = insert(:match, state: :en_route_to_return)
      m3 = insert(:match, state: :picked_up, match_stops: [build(:match_stop, state: :en_route)])

      insert(:match,
        state: :arrived_at_pickup,
        match_stops: [build(:match_stop, state: :en_route)]
      )

      insert(:match, state: :picked_up, match_stops: [build(:match_stop, state: :arrived)])
      insert(:match, state: :picked_up)
      insert(:match, state: :arrived_at_pickup)
      insert(:match, state: :arrived_at_return)
      insert(:match, state: :accepted)
      insert(:match, state: :completed)

      matches = Matches.get_en_route_matches()

      Enum.each(matches, fn m -> assert m.id in [m1.id, m2.id, m3.id] end)
    end
  end

  describe "Post-Delivery update: A charged match" do
    test "Where amount_charged or total_driver_pay has changed should be transitioned back to the :completed" do
      %{shipper: shipper} = insert(:credit_card)

      match =
        %Match{
          match_stops: [
            %MatchStop{
              id: stop_id,
              items: [
                %{
                  id: item_id
                }
              ]
            }
          ]
        } =
        insert(:pending_match,
          match_stops: build_match_stops_with_items([:signed]),
          fees: [
            build(:match_fee, type: :base_fee, amount: 1500)
          ],
          amount_charged: 1500,
          shipper: shipper,
          vehicle_class: 1,
          service_level: 1
        )
        |> Repo.preload(shipper: :credit_card)

      {:ok, authorized_match} = Matches.update_and_authorize_match(match)

      assert authorized_match.amount_charged == 2834

      {:ok, match} = Matches.update_match(authorized_match, %{state: :charged})

      {:ok, updated_match} =
        Matches.update_match(match, %{
          match_stops: [
            %{
              id: stop_id,
              has_load_fee: true,
              items: [
                %{
                  id: item_id,
                  weight: 500
                }
              ]
            }
          ],
          fees: [
            %{type: :base_fee, amount: 2500, description: "A fee", driver_amount: 75}
          ]
        })

      assert %{state: :completed} = updated_match
    end

    test "If an error occurs during the process, the match does not change :completed state." do
      %{shipper: shipper} = insert(:credit_card)

      match =
        insert(:pending_match,
          match_stops: build_match_stops_with_items([:signed]),
          fees: [
            build(:match_fee, type: :base_fee, amount: 1500)
          ],
          amount_charged: 1500,
          shipper: shipper,
          vehicle_class: 1,
          service_level: 1
        )
        |> Repo.preload(shipper: :credit_card)

      {:ok, authorized_match} = Matches.update_and_authorize_match(match)

      assert authorized_match.amount_charged == 2834

      {:ok, match} = Matches.update_match(authorized_match, %{state: :charged})

      assert {:error, _multi_op_name, _cs, _changes} =
               Matches.update_match(match, %{
                 fees: [
                   %{type: :base_fee, amount: 2500, description: "A fee", driver_amount: 75},
                   %{
                     type: :INVALID_FEE,
                     amount: 0,
                     description: "An invalid fee",
                     driver_amount: 0
                   }
                 ]
               })

      assert %{state: :charged} = Shipment.get_match(match.id)
    end
  end
end
