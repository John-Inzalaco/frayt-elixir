defmodule FraytElixirWeb.Internal.V2x1.DriverMatchViewTest do
  use FraytElixirWeb.ConnCase, async: true
  alias FraytElixirWeb.Internal.V2x1.DriverMatchView
  alias FraytElixir.Shipment.{Match, MatchStop, Contact}
  alias FraytElixir.Accounts.{Shipper, User}
  alias FraytElixir.Drivers.Driver

  import FraytElixir.Factory
  import FraytElixirWeb.DisplayFunctions

  test "render match" do
    %{formatted_address: formatted_origin_address} =
      origin_address = insert(:address, geo_location: chris_house_point())

    driver = insert(:driver)

    %Match{
      id: id,
      po: po,
      state: state,
      shortcode: shortcode,
      driver_id: driver_id,
      total_distance: distance,
      match_stops: [
        %MatchStop{id: stop_id}
      ],
      shipper: %Shipper{
        first_name: first_name,
        last_name: last_name,
        phone: shipper_phone,
        location: %{company: %{name: company_name}}
      },
      driver: %Driver{
        user: %User{
          email: driver_email
        }
      },
      sender: %Contact{
        id: sender_id
      },
      self_sender: self_sender,
      driver_total_pay: driver_total_pay,
      dropoff_at: dropoff_at,
      pickup_at: pickup_at,
      inserted_at: inserted_at,
      total_volume: total_volume,
      total_weight: total_weight,
      platform: platform,
      preferred_driver_id: preferred_driver_id
    } =
      match =
      insert(:match,
        origin_address: origin_address,
        driver_total_pay: 1000,
        origin_photo: %{file_name: "origin_photo.png", updated_at: DateTime.utc_now()},
        sender: insert(:contact),
        bill_of_lading_photo: %{
          file_name: "bill_of_lading_photo.png",
          updated_at: DateTime.utc_now()
        },
        match_stops: [build(:match_stop)],
        fees: [
          build(:match_fee,
            type: :lift_gate_fee,
            description: "Lift gate",
            amount: 100_00,
            driver_amount: 80_00
          )
        ],
        slas: [
          build(:match_sla, type: :pickup, driver: driver),
          build(:match_sla, type: :delivery, driver: driver)
        ],
        self_sender: false,
        unload_method: :lift_gate,
        vehicle_class: 2,
        service_level: 2,
        driver: driver,
        shipper: build(:shipper_with_location)
      )

    shipper_name = "#{first_name} #{last_name}"
    driver_total_pay = driver_total_pay |> cents_to_dollars()

    assert %{
             "id" => ^id,
             "po" => ^po,
             "state" => ^state,
             "shortcode" => ^shortcode,
             "driver_id" => ^driver_id,
             "driver_email" => ^driver_email,
             "rating" => nil,
             "scheduled" => false,
             "origin_photo_required" => nil,
             "pickup_notes" => nil,
             "origin_address" => %{
               formatted_address: ^formatted_origin_address
             },
             "origin_photo" => "some_url",
             "service_level" => 2,
             "vehicle_class" => "Midsize",
             "vehicle_class_id" => 2,
             "shipper" => %{
               "name" => ^shipper_name,
               "phone" => ^shipper_phone,
               "company" => ^company_name
             },
             "sender" => %{id: ^sender_id},
             "self_sender" => ^self_sender,
             "cancel_reason" => nil,
             "total_weight" => ^total_weight,
             "total_volume" => ^total_volume,
             "distance" => ^distance,
             "driver_total_pay" => ^driver_total_pay,
             "pickup_at" => ^pickup_at,
             "completed_at" => nil,
             "dropoff_at" => ^dropoff_at,
             "created_at" => ^inserted_at,
             "bill_of_lading_photo" => "some_url",
             "unload_method" => :lift_gate,
             "stops" => [%{id: ^stop_id}],
             "fees" => [
               %{
                 type: :lift_gate_fee,
                 amount: 80_00,
                 description: "Lift gate"
               }
             ],
             "slas" => [
               %{type: :pickup, start_time: _, end_time: _, completed_at: _},
               %{type: :delivery, start_time: _, end_time: _, completed_at: _}
             ],
             "platform" => ^platform,
             "preferred_driver_id" => ^preferred_driver_id
           } = DriverMatchView.render("match.json", %{driver_match: match})
  end

  test "render matches" do
    [%Match{id: id} | _] = matches = insert_list(3, :match)
    rendered_matches = DriverMatchView.render("index.json", %{matches: matches})
    assert %{response: %{count: 3, results: [rendered_match | _]}} = rendered_matches
    assert %{"id" => ^id} = rendered_match
  end

  test "render show match" do
    %Match{id: id} = match = insert(:match)

    assert %{response: rendered_match} =
             DriverMatchView.render("show.json", %{driver_match: match})

    assert rendered_match["id"] == id
  end
end
