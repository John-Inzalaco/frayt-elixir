defmodule FraytElixir.Factory do
  use ExMachina.Ecto, repo: FraytElixir.Repo

  alias Ecto.UUID

  alias FraytElixir.Accounts.{
    Shipper,
    Schedule,
    User,
    Location,
    Company,
    AdminUser,
    ApiAccount,
    AgreementDocument,
    UserAgreement
  }

  alias FraytElixir.Drivers.{
    Driver,
    DriverDocument,
    Vehicle,
    VehicleDocument,
    DriverLocation,
    DriverMetrics,
    HiddenCustomer
  }

  alias FraytElixir.Devices.DriverDevice
  alias FraytElixir.Screenings.BackgroundCheck
  alias FraytElixir.Payments.{CreditCard, DriverBonus, PaymentTransaction}

  alias FraytElixir.AdminSettings.MetricSettings
  alias FraytElixir.Hubspot
  alias FraytElixir.Markets.{Market, MarketZipCode}

  alias FraytElixir.Shipment.{
    BatchStateTransition,
    Contact,
    HiddenMatch,
    Match,
    Address,
    Coupon,
    DeliveryBatch,
    ShipperMatchCoupon,
    MatchStop,
    MatchStopItem,
    MatchStateTransition,
    MatchStopStateTransition,
    MatchTag,
    NotificationBatch,
    SentNotification,
    MatchFee,
    BarcodeReading,
    ETA
  }

  alias FraytElixir.Holistics.HolisticsDashboard

  alias FraytElixir.Notifications.{SentNotification, NotificationBatch}

  alias FraytElixir.Contracts.{Contract, CancellationPayRule, CancellationCode, MarketConfig}
  alias FraytElixir.SLAs.{ContractSLA, MatchSLA}

  alias FraytElixir.{Repo}
  alias FraytElixir.Rating.NpsScore
  alias FraytElixir.Webhooks.WebhookRequest

  def set_driver_default_device(driver, device \\ nil) do
    device = device || insert(:device, driver: driver)

    driver
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:default_device, device)
    |> Repo.update!()
  end

  def holistics_dashboard_factory do
    %HolisticsDashboard{
      secret_key: "SECRET",
      embed_code: "CODE",
      name: "My Dashboard"
    }
  end

  def admin_user_factory do
    %AdminUser{
      name: "Admin User",
      role: "admin",
      disabled: false,
      user: build(:user)
    }
  end

  def network_operator_factory do
    %AdminUser{
      name: "Network Operator",
      role: "network_operator",
      disabled: false,
      slack_id: alphanum_string(8),
      user: build(:user)
    }
  end

  def api_account_factory do
    %ApiAccount{
      client_id: "CLIENT_ID",
      secret: "SECRET"
    }
  end

  def cancellation_code_factory do
    %CancellationCode{
      code: "OTHERS",
      message: "something else happened "
    }
  end

  def api_account_with_company_factory do
    %{api_account_factory() | company: build(:company_with_location)}
  end

  def api_account_without_shipper_factory do
    %{
      api_account_factory()
      | company: build(:company, locations: [build(:location, shippers: [], company: nil)])
    }
  end

  def user_factory(attrs) do
    password = attrs[:password] || "password"

    %User{
      password_reset_code: attrs[:password_reset_code] || nil,
      email: attrs[:email] || Faker.Internet.email(),
      password: password,
      auth_via_bubble: attrs[:auth_via_bubble]
    }
    |> set_password
  end

  def unregistered_user_factory do
    %User{
      email: sequence(:email, &"email2-#{&1}@example.com"),
      password_reset_code: sequence(:password_reset_code, &"ABCDEFG#{&1}")
    }
  end

  defp set_password(user) do
    Map.merge(user, User.hash_password(user.password))
  end

  def barcode_reading_factory do
    %BarcodeReading{
      type: :pickup,
      state: :captured,
      photo: nil,
      barcode: "123barcode456"
    }
  end

  def driver_factory do
    %Driver{
      first_name: Faker.Person.first_name(),
      last_name: Faker.Person.last_name(),
      images: [
        build(:driver_document, type: "license")
      ],
      license_number: sequence(:license_number, &"GHJ123#{&1}"),
      license_state: "OH",
      phone_number: parse_phone("+1513402" <> Kernel.to_string(Enum.random(1_000..9_999))),
      ssn: sequence(:ssn, &"12345000#{&1}"),
      birthdate: "1950-01-01T00:00:00-05:00",
      state: "approved",
      address: build(:address),
      user: build(:user),
      vehicles: [build(:vehicle)],
      metrics: build(:driver_metrics),
      market: build(:market),
      devices: [],
      default_device: nil,
      english_proficiency: :advanced
    }
  end

  def driver_location_factory do
    %DriverLocation{
      driver: build(:driver),
      geo_location: chicago_point(),
      formatted_address: "300 South Federal Street, Chicago, IL 60604"
    }
  end

  def driver_metrics_factory do
    %DriverMetrics{
      rating: 0.0,
      completed_matches: 0,
      rated_matches: 0,
      sla_rating: 0.0,
      fulfillment_rating: 0.0,
      activity_rating: 0.0
    }
  end

  def device_factory do
    %DriverDevice{
      device_uuid: Faker.UUID.v4(),
      device_model: "device_model",
      player_id: "#{UUID.generate()}",
      os: "os",
      os_version: "os_version",
      is_tablet: false,
      is_location_enabled: false,
      driver: nil
    }
  end

  def chris_house_point,
    do: %Geo.Point{
      coordinates: {-84.51019579999999, 39.283527},
      properties: %{},
      srid: nil
    }

  def chris_old_house_point,
    do: %Geo.Point{coordinates: {-84.5360534, 39.21988}, properties: %{}, srid: nil}

  def chicago_point,
    do: %Geo.Point{coordinates: {-87.6297982, 41.8781136}, properties: %{}, srid: nil}

  def london_point,
    do: %Geo.Point{coordinates: {-0.1278, 51.5074}, properties: %{}, srid: nil}

  def gaslight_point,
    do: %Geo.Point{coordinates: {-84.5118912, 39.1043198}, properties: %{}, srid: nil}

  def wilmington_point,
    do: %Geo.Point{coordinates: {-83.8346920, 39.4442974}, properties: %{}, srid: nil}

  def findlay_market_point,
    do: %Geo.Point{coordinates: {-84.5190226, 39.1153633}, properties: %{}, srid: nil}

  def utc_point,
    do: %Geo.Point{coordinates: {51.5074, -0.1278}, properties: %{}, srid: nil}

  def hubspot_account_factory do
    %Hubspot.Account{
      hubspot_id: sequence(:hubspot_id, &(12_345_000 + &1)),
      domain: "domain.hubspot.com",
      refresh_token: "super_duper_valid_refresh_token",
      access_token: "super_duper_valid_access_token",
      expires_at: DateTime.utc_now() |> DateTime.add(6000)
    }
  end

  def unregistered_driver_factory do
    struct!(
      driver_factory(),
      %{
        user: build(:unregistered_user),
        fountain_id: Ecto.UUID.generate()
      }
    )
  end

  def driver_with_wallet_factory do
    struct!(
      driver_factory(),
      %{
        wallet_state: :UNCLAIMED
      }
    )
  end

  def profiled_driver_factory do
    struct!(
      driver_factory(),
      %{
        images: [
          build(:driver_document, type: "license"),
          build(:driver_document, type: "profile")
        ]
      }
    )
  end

  def driver_document_factory do
    %DriverDocument{
      type: "license",
      state: "approved",
      document: %{file_name: "test/drivers-license.jpeg", updated_at: DateTime.utc_now()},
      expires_at: "2030-01-01T23:59:59Z"
    }
  end

  def vehicle_document_factory do
    %VehicleDocument{
      type: "insurance",
      document: %{file_name: "test/drivers-insurance.jpeg", updated_at: DateTime.utc_now()},
      expires_at: "2030-01-01T23:59:59Z"
    }
  end

  def background_check_factory do
    %BackgroundCheck{
      customer_id: "customer_id",
      transaction_id: "transaction_id",
      amount_charged: 3500,
      state: :pending
    }
  end

  def vehicle_factory do
    %Vehicle{
      license_plate: "ABC1234",
      make: "Tesla",
      model: "Cybertruck",
      vehicle_class: 2,
      vin: "34H5G32V54H2345CJ",
      year: 2021,
      images: [
        build(:vehicle_document, type: "passengers_side", state: :approved),
        build(:vehicle_document, type: "drivers_side", state: :approved),
        build(:vehicle_document, type: "cargo_area", state: :approved),
        build(:vehicle_document, type: "front", state: :approved),
        build(:vehicle_document, type: "registration", state: :approved),
        build(:vehicle_document, type: "insurance", state: :approved),
        build(:vehicle_document, type: "back", state: :approved)
      ]
    }
  end

  def vehicle_insurance_expired_factory do
    %Vehicle{
      license_plate: "ABC1234",
      make: "Tesla",
      model: "Cybertruck",
      vehicle_class: 2,
      vin: "34H5G32V54H2345CJ",
      year: 2021
    }
  end

  def car_factory do
    struct!(
      vehicle_factory(),
      %{
        vehicle_class: 1
      }
    )
  end

  def midsize_factory do
    struct!(
      vehicle_factory(),
      %{
        vehicle_class: 2
      }
    )
  end

  def cargo_van_factory do
    struct!(
      vehicle_factory(),
      %{
        vehicle_class: 3
      }
    )
  end

  def box_truck_factory do
    struct!(
      vehicle_factory(),
      %{
        vehicle_class: 4
      }
    )
  end

  def shipper_factory do
    %Shipper{
      first_name: Faker.Person.first_name(),
      last_name: Faker.Person.last_name(),
      phone: Faker.Phone.EnUs.phone() |> String.replace(~r/\D+/, ""),
      one_signal_id: "ABCDEF",
      agreement: true,
      user: build(:user),
      state: "approved",
      address:
        build(:address, address: "708 Walnut St", city: "Cincinnati", state: "OH", zip: "45202")
    }
  end

  def shipper_with_location_factory do
    %Shipper{
      first_name: "Burt",
      last_name: "Macklin",
      agreement: true,
      company: "Gaslight",
      phone: "3214325432",
      state: "approved",
      location: build(:location),
      user: build(:user),
      address:
        build(:address, address: "708 Walnut St", city: "Cincinnati", state: "OH", zip: "45202")
    }
  end

  def shipper_with_location_with_sales_rep_factory do
    %Shipper{
      first_name: "Burt",
      last_name: "Macklin",
      agreement: true,
      company: "Gaslight",
      phone: "3214325432",
      state: "approved",
      location: build(:location_with_sales_rep),
      user: build(:user),
      address:
        build(:address, address: "708 Walnut St", city: "Cincinnati", state: "OH", zip: "45202")
    }
  end

  def shipper_with_location_auto_cancel_factory do
    struct!(
      shipper_with_location_factory(),
      %{
        location: build(:location, company: build(:company, auto_cancel: true))
      }
    )
  end

  def location_factory do
    %Location{
      email: sequence(:email, &"location-#{&1}@example.com"),
      store_number: sequence(:store_number, &"store-#{&1}"),
      location: sequence(:location, &"location-#{&1}"),
      company: build(:company),
      address: build(:address)
    }
  end

  def location_with_sales_rep_factory do
    struct!(
      location_factory(),
      %{
        sales_rep: build(:admin_user, name: "location larry")
      }
    )
  end

  def schedule_factory do
    %Schedule{
      location: build(:location),
      monday: ~T[13:30:00],
      tuesday: ~T[13:30:00],
      wednesday: ~T[13:30:00],
      thursday: ~T[13:30:00],
      friday: ~T[13:30:00],
      saturday: ~T[13:30:00],
      sunday: ~T[13:30:00],
      max_drivers: 10,
      min_drivers: 3,
      sla: 120
    }
  end

  def schedule_with_drivers_factory do
    struct!(
      schedule_factory(),
      %{
        drivers: build_list(2, :driver_with_wallet)
      }
    )
  end

  def company_factory do
    %Company{
      name: sequence(:company_name, &"Company #{&1}"),
      account_billing_enabled: true,
      invoice_period: 15
    }
  end

  def company_with_location_factory do
    struct!(
      company_factory(),
      %{
        locations: [insert(:location, shippers: [insert(:shipper, state: "approved")])]
      }
    )
  end

  def credit_card_factory do
    %CreditCard{
      stripe_card: "visa_12345",
      stripe_token: "tok_1234",
      last4: "4242",
      shipper:
        build(:shipper, %{
          stripe_customer_id: "cus_12345",
          state: "approved",
          location: build(:location, company: build(:company, account_billing_enabled: false))
        })
    }
  end

  def credit_card_with_billing_enabled_true_factory do
    %CreditCard{
      stripe_card: "visa_12345",
      stripe_token: "tok_1234",
      last4: "4242",
      shipper:
        build(:shipper, %{
          stripe_customer_id: "cus_12345",
          state: "approved",
          location: build(:location, company: build(:company, account_billing_enabled: true))
        })
    }
  end

  def hidden_match_factory do
    %HiddenMatch{
      driver: build(:driver_with_wallet),
      match: build(:match),
      type: "driver_cancellation",
      reason: "Too heavy"
    }
  end

  def delivery_batch_factory do
    shipper = insert(:shipper)
    address = build(:address)

    location =
      insert(:location,
        shippers: [shipper],
        address: address,
        schedule: insert(:schedule_with_drivers, location: nil)
      )

    %DeliveryBatch{
      pickup_notes: "pickup notes",
      location: location,
      shipper: shipper,
      address: address,
      po: "1234",
      service_level: 1,
      pickup_at: DateTime.utc_now() |> DateTime.add(60 * 60 * 25),
      match_stops: [build(:match_stop)]
    }
  end

  def delivery_batch_completed_factory do
    batch = delivery_batch_factory()

    struct!(
      batch,
      %{
        state: "routing_complete",
        pickup_at: DateTime.utc_now(),
        matches: [build(:match, schedule: batch.location.schedule)]
      }
    )
  end

  def match_factory do
    %Match{
      total_distance: sequence(:total_distance, &(10 + &1)),
      expected_toll: 0,
      driver_cut: 0.75,
      origin_address: build(:address),
      shipper: build(:shipper),
      driver: build(:driver),
      service_level: 1,
      vehicle_class: 2,
      shortcode: alphanum_string(8),
      scheduled: false,
      state: :assigning_driver,
      po: alphanum_string(3, 20),
      total_volume: 4_608,
      total_weight: 40,
      travel_duration: 0,
      match_stops: [build(:match_stop)],
      driver_fees: 59,
      driver_total_pay: 691,
      amount_charged: 1000,
      contract: nil,
      fees: [
        build(:match_fee, type: :base_fee, amount: 1000, driver_amount: 691)
      ],
      sender: nil,
      tags: [],
      timezone: "UTC",
      unload_method: nil,
      slas: [
        build(:match_sla),
        build(:match_sla, type: :pickup),
        build(:match_sla, type: :delivery)
      ]
    }
  end

  def pending_match_factory do
    struct!(
      match_factory(),
      %{
        state: :pending,
        match_stops: build_match_stops_with_items([:pending, :pending])
      }
    )
  end

  def scheduled_match_factory do
    struct!(
      match_factory(),
      %{
        state: :scheduled,
        scheduled: true,
        pickup_at: DateTime.utc_now() |> DateTime.add(3000, :millisecond)
      }
    )
  end

  def scheduled_assigning_driver_factory do
    struct!(
      scheduled_match_factory(),
      %{
        state: :assigning_driver
      }
    )
  end

  def scheduled_accepted_match_factory do
    struct!(
      scheduled_assigning_driver_factory(),
      %{
        state: :accepted,
        driver: build(:driver)
      }
    )
  end

  def inactive_match_factory do
    struct!(
      match_factory(),
      %{
        state: :inactive,
        amount_charged: 200,
        driver_total_pay: 100,
        slas: []
      }
    )
  end

  def assigning_driver_match_factory do
    %{
      match_factory()
      | driver: nil,
        state: :assigning_driver,
        driver_fees: 1_50,
        driver_total_pay: 36_50,
        payment_transactions: fn match -> [with_payment_transaction(match, :authorize)] end
    }
  end

  def accepted_match_factory do
    struct!(
      assigning_driver_match_factory(),
      %{
        state: :accepted,
        driver: build(:driver_with_wallet)
      }
    )
  end

  def en_route_to_pickup_match_factory do
    factory = accepted_match_factory()

    struct!(
      factory,
      %{
        state: :en_route_to_pickup,
        driver: %{
          factory.driver
          | current_location: build(:driver_location, geo_location: gaslight_point())
        }
      }
    )
  end

  def arrived_at_pickup_match_factory do
    struct!(en_route_to_pickup_match_factory(), %{state: :arrived_at_pickup})
  end

  def picked_up_match_factory do
    struct!(
      arrived_at_pickup_match_factory(),
      %{
        state: :picked_up,
        match_stops: build_match_stops_with_items([:pending, :pending, :pending])
      }
    )
  end

  def en_route_to_dropoff_match_factory do
    struct!(
      picked_up_match_factory(),
      %{
        match_stops: [build(:en_route_match_stop)]
      }
    )
  end

  def arrived_at_dropoff_match_factory do
    struct!(
      picked_up_match_factory(),
      %{
        match_stops: [build(:arrived_at_match_stop)]
      }
    )
  end

  def signed_match_factory do
    struct!(
      picked_up_match_factory(),
      %{
        match_stops: build_match_stops_with_items([:signed, :pending, :pending])
      }
    )
  end

  def delivered_match_factory do
    struct!(
      picked_up_match_factory(),
      %{
        match_stops: [build(:delivered_match_stop)]
      }
    )
  end

  def deprecated_match_factory do
    struct!(
      accepted_match_factory(),
      %{
        state: :delivered,
        match_stops: build_match_stops_with_items([:pending])
      }
    )
  end

  def completed_match_factory do
    struct!(
      en_route_to_dropoff_match_factory(),
      %{
        match_stops: [build(:delivered_match_stop)],
        state: :completed,
        amount_charged: 2000,
        driver: build(:driver_with_wallet)
      }
    )
  end

  def charged_match_factory do
    match = completed_match_factory()

    %{
      match
      | state: :charged,
        amount_charged: 2000,
        payment_transactions: fn match ->
          [
            with_payment_transaction(match, :authorize),
            with_payment_transaction(match, :capture),
            with_payment_transaction(match, :transfer)
          ]
        end
    }
  end

  def canceled_match_factory do
    struct!(
      match_factory(),
      %{
        state: :canceled
      }
    )
  end

  def admin_canceled_match_factory do
    struct!(
      match_factory(),
      %{
        state: :admin_canceled
      }
    )
  end

  def match_stop_factory do
    struct!(
      estimate_match_stop_factory(),
      %{
        items: [build(:match_stop_item)],
        self_recipient: false,
        recipient:
          build(:contact,
            name: Faker.Person.name(),
            email: Faker.Internet.email(),
            phone_number: "+15134020000"
          )
      }
    )
  end

  defp random_code(length), do: Ecto.UUID.generate() |> String.slice(0, length)

  def match_stop_with_item_factory do
    struct!(
      estimate_match_stop_factory(),
      %{
        items: [build(:match_stop_item)],
        self_recipient: false,
        recipient:
          insert(:contact,
            name: "John Doe",
            email: "john#{random_code(8)}@doe.com",
            phone_number: "+15134020000"
          )
      }
    )
  end

  def build_match_stops_with_items(states \\ []) do
    0..(Enum.count(states) - 1)
    |> Enum.zip(states)
    |> Enum.map(fn {index, state} ->
      build(:match_stop, %{state: state, index: index})
    end)
  end

  def pending_match_stop_factory do
    struct!(match_stop_factory())
  end

  def en_route_match_stop_factory do
    struct!(match_stop_factory(), %{
      state: :en_route
    })
  end

  def arrived_at_match_stop_factory do
    struct!(match_stop_factory(), %{state: :arrived})
  end

  def signed_match_stop_factory do
    struct!(match_stop_factory(), %{state: :signed})
  end

  def delivered_match_stop_factory do
    struct!(match_stop_factory(), %{state: :delivered})
  end

  def undeliverable_match_stop_factory do
    struct!(match_stop_factory(), %{state: :undeliverable})
  end

  def match_stop_item_factory do
    %MatchStopItem{
      width: 2.0,
      height: 24.0,
      length: 24.0,
      pieces: 4,
      weight: 10.0,
      volume: 1152,
      description: "Car Tire",
      external_id: "12345678",
      type: :item
    }
  end

  def match_stop_item_with_barcode_factory do
    struct!(
      match_stop_item_factory(),
      %{
        barcode: "123barcode456"
      }
    )
  end

  def match_stop_item_with_required_barcodes_factory do
    struct!(
      match_stop_item_factory(),
      %{
        barcode: "123barcode456",
        barcode_pickup_required: true,
        barcode_delivery_required: true
      }
    )
  end

  def estimate_match_stop_item_factory do
    %MatchStopItem{
      weight: 10
    }
  end

  def estimate_factory do
    %Match{
      total_distance: sequence(:total_distance, &(10 + &1)),
      origin_address: build(:address),
      service_level: 1,
      vehicle_class: 2,
      shortcode: "ABCD1234",
      scheduled: false,
      state: "pending",
      match_stops: [build(:estimate_match_stop)],
      fees: [
        build(:match_fee, amount: 1000, driver_amount: 750)
      ],
      tags: []
    }
  end

  def webhook_request_factory do
    %WebhookRequest{
      payload: %{},
      webhook_url: "http://www.foo.com",
      sent_at: DateTime.utc_now()
    }
  end

  def estimate_match_stop_factory do
    %MatchStop{
      index: sequence(:stop_index, & &1),
      destination_address: build(:address),
      destination_photo_required: false,
      state: :pending,
      distance: 5.0,
      radial_distance: 5.0,
      items: [build(:estimate_match_stop_item)]
    }
  end

  def over_50_base_price_match_factory do
    struct!(
      pending_match_factory(),
      %{
        fees: [
          build(:match_fee, type: :base_fee, amount: 8000, driver_amount: 6000)
        ],
        match_stops: [build(:match_stop, items: [build(:match_stop_item)])]
      }
    )
  end

  def with_transitions(records) when is_list(records),
    do: Enum.map(records, &with_transitions(&1))

  def with_transitions(%Match{} = match) do
    transitions = match_state_transition_through_to(match.state, match)

    stops = with_transitions(match.match_stops)

    %{match | state_transitions: transitions, match_stops: stops}
  end

  def with_transitions(%MatchStop{} = stop) do
    transitions = match_stop_state_transition_through_to(stop.state, stop)
    %{stop | state_transitions: transitions}
  end

  def match_state_transition_through_to(final_state, match \\ nil) do
    match = if match, do: match, else: insert(:match, state: final_state)
    now = DateTime.utc_now()

    final_state
    |> list_of_match_transition_states_needed()
    |> Enum.with_index()
    |> Enum.reduce(
      [],
      &(&2 ++
          [
            insert(:match_state_transition,
              from:
                if Enum.count(&2) > 0 do
                  List.last(&2).to
                else
                  "pending"
                end,
              to: elem(&1, 0),
              match: match,
              inserted_at: DateTime.add(now, 30 * elem(&1, 1))
            )
          ])
    )
  end

  def match_stop_state_transition_through_to(final_state, match_stop \\ nil) do
    match_stop = if match_stop, do: match_stop, else: insert(:match_stop, state: final_state)

    now = DateTime.utc_now()

    final_state
    |> list_of_match_stop_transition_states_needed()
    |> Enum.with_index()
    |> Enum.reduce(
      [],
      &(&2 ++
          [
            insert(:match_stop_state_transition,
              from:
                if Enum.count(&2) > 0 do
                  List.last(&2).to
                else
                  "pending"
                end,
              to: elem(&1, 0),
              match_stop: match_stop,
              inserted_at: DateTime.add(now, 30 * elem(&1, 1))
            )
          ])
    )
  end

  def list_of_match_transition_states_needed(final_state) do
    transition_states =
      FraytElixir.Shipment.MatchState.all_indexes()
      |> Map.drop([
        :inactive,
        :admin_canceled,
        :canceled,
        :pending,
        :driver_canceled,
        :unable_to_pickup
      ])

    final_state_index = Map.get(transition_states, final_state)

    transition_states
    |> Map.drop([
      :inactive,
      :admin_canceled,
      :canceled,
      :pending,
      :driver_canceled,
      :unable_to_pickup
    ])
    |> Enum.sort_by(fn {_k, v} -> v end)
    |> Enum.filter(&(elem(&1, 1) <= final_state_index))
    |> Enum.map(&elem(&1, 0))
  end

  def list_of_match_stop_transition_states_needed(:undeliverable = final_state) do
    FraytElixir.Shipment.MatchStopState.all_indexes()
    |> Map.drop([:signed, :delivered])
    |> get_list_of_match_stop_transition_states(final_state)
  end

  def list_of_match_stop_transition_states_needed(final_state) do
    FraytElixir.Shipment.MatchStopState.all_indexes()
    |> get_list_of_match_stop_transition_states(final_state)
  end

  defp get_list_of_match_stop_transition_states(transition_states, final_state) do
    final_state_index = Map.get(transition_states, final_state)

    transition_states
    |> Enum.sort_by(fn {_k, v} -> v end)
    |> Enum.filter(&(elem(&1, 1) <= final_state_index))
    |> Enum.map(&elem(&1, 0))
  end

  def match_state_transition_factory do
    %MatchStateTransition{
      from: :pending,
      to: :assigning_driver,
      match: build(:match, state: :assigning_driver)
    }
  end

  def batch_state_transition_factory do
    %BatchStateTransition{
      from: :pending,
      to: :routing,
      batch: build(:delivery_batch, state: :routing)
    }
  end

  def assigning_driver_match_state_transition_factory do
    %MatchStateTransition{
      from: :pending,
      to: :assigning_driver,
      match: build(:match, state: :assigning_driver)
    }
  end

  def accepted_match_state_transition_factory do
    %MatchStateTransition{
      from: :assigning_driver,
      to: :accepted,
      match:
        build(:match,
          state: :accepted,
          driver: build(:driver),
          origin_address: build(:address, geo_location: findlay_market_point())
        ),
      inserted_at: sequence(:mst_inserted_at, &(DateTime.utc_now() |> DateTime.add(-&1)))
    }
  end

  def completed_match_state_transition_factory do
    %MatchStateTransition{
      from: :picked_up,
      to: :completed,
      match: build(:completed_match)
    }
  end

  def match_stop_state_transition_factory do
    %MatchStopStateTransition{
      from: :pending,
      to: :pending,
      match_stop: build(:match_stop)
    }
  end

  def deprecated_match_state_transition_factory do
    %MatchStateTransition{
      from: :signed,
      to: :delivered,
      notes: "Test to see if these migrate",
      match: build(:deprecated_match)
    }
  end

  def arrived_at_match_stop_transition_factory do
    %MatchStopStateTransition{
      from: :pending,
      to: :arrived,
      match_stop: build(:arrived_at_match_stop)
    }
  end

  def signed_match_stop_transition_factory do
    %MatchStopStateTransition{
      from: :arrived,
      to: :signed,
      match_stop: build(:signed_match_stop)
    }
  end

  def delivered_match_stop_transition_factory do
    %MatchStopStateTransition{
      from: :signed,
      to: :delivered,
      match_stop: build(:delivered_match_stop)
    }
  end

  def undeliverable_match_stop_transition_factory do
    %MatchStopStateTransition{
      from: :arrived,
      to: :undeliverable,
      match_stop: build(:undeliverable_match_stop)
    }
  end

  def address_factory do
    %Address{
      address: "708 Walnut Street",
      geo_location: gaslight_point(),
      city: "Cincinnati",
      state: "Ohio",
      state_code: "OH",
      zip: "45202",
      neighborhood: "Central Business District",
      county: "Hamilton County",
      formatted_address: "708 Walnut St #500, Cincinnati, OH 45202, USA"
    }
  end

  def utc_address_factory do
    %Address{
      address: "294 Lewisham Road",
      geo_location: utc_point(),
      city: "London",
      state: nil,
      state_code: nil,
      zip: "SE13 7PA",
      neighborhood: "Greenwhich",
      county: "London County",
      country: "England",
      country_code: "EN",
      formatted_address: "294 Lewisham Road, London SE13 7PA, EN"
    }
  end

  def coupon_factory do
    %Coupon{
      code: sequence(:coupon_code, &"Coupon #{&1}"),
      percentage: 25
    }
  end

  def small_coupon_factory do
    struct!(
      coupon_factory(),
      %{
        code: "10OFF",
        percentage: 10
      }
    )
  end

  def large_coupon_factory do
    struct!(
      coupon_factory(),
      %{
        code: "30OFF",
        percentage: 30
      }
    )
  end

  def shipper_match_coupon_factory do
    %ShipperMatchCoupon{
      shipper: build(:shipper),
      coupon: build(:coupon)
    }
  end

  def payment_transaction_factory do
    %{
      orphan_payment_transaction_factory()
      | match: build(:match)
    }
  end

  def orphan_payment_transaction_factory do
    %PaymentTransaction{
      payment_provider_response: "{\"message\": \"payment ready\"}",
      status: "ready",
      external_id: sequence(:transaction_id, &"transaction-id-#{&1}"),
      transaction_reason: :charge
    }
  end

  def with_payment_transaction(match, transaction_type, attrs \\ [])

  def with_payment_transaction(match, :transfer, attrs) do
    attrs =
      [
        transaction_type: :transfer,
        external_id: match.id,
        amount: match.driver_total_pay
      ] ++
        attrs

    with_payment_transaction(match, :authorize, attrs)
  end

  def with_payment_transaction(match, transaction_type, attrs) do
    build(
      :orphan_payment_transaction,
      [
        external_id: sequence(:stripe_id, &"ch_0000#{&1}"),
        amount: match.amount_charged,
        transaction_reason: :charge,
        transaction_type: transaction_type,
        status: "succeeded",
        payment_provider_response: fn pt -> build_payment_provider_response(pt, match) end
      ] ++ attrs
    )
  end

  defp build_payment_provider_response(
         %PaymentTransaction{
           inserted_at: inserted_at,
           amount: amount,
           transaction_type: :transfer
         },
         match
       ) do
    time_created =
      (inserted_at || DateTime.utc_now()) |> DateTime.truncate(:second) |> DateTime.to_iso8601()

    Jason.encode!(%{
      "amount" => amount,
      "description" => "driver payout for Match #{match.shortcode}",
      "employee_group" => nil,
      "employee_id" => match.driver_id,
      "external_id" => match.id,
      "metadata" => nil,
      "reason_code" => nil,
      "status" => "COMPLETED",
      "status_reason" => nil,
      "time_created" => time_created,
      "time_modified" => nil,
      "type" => "DEPOSIT"
    })
  end

  defp build_payment_provider_response(
         %PaymentTransaction{
           amount: amount,
           transaction_type: type
         },
         match
       )
       when type in [:authorize, :capture] do
    Jason.encode!(%{
      "amount" => amount,
      "amount_refunded" => 0,
      "payment_intent" => nil,
      "application_fee_amount" => match.driver_fees,
      "dispute" => nil,
      "status" => "succeeded"
    })
  end

  def driver_bonus_factory do
    %DriverBonus{
      notes: "some notes",
      driver: build(:driver),
      payment_transaction: build(:payment_transaction, amount: 1200, transaction_type: :transfer)
    }
  end

  def matchless_driver_bonus_factory do
    %DriverBonus{
      notes: "some notes",
      driver: build(:driver),
      payment_transaction:
        build(:payment_transaction, amount: 1200, match: nil, transaction_type: :transfer)
    }
  end

  def market_factory do
    %Market{
      name: "Cincinnati",
      region: "OH",
      markup: 1.0
    }
  end

  def market_zip_code_factory do
    %MarketZipCode{
      zip: "45202"
    }
  end

  def with_zipcodes(%Market{} = market, zip_codes) do
    zips = Enum.map(zip_codes, &insert(:market_zip_code, zip: &1, market: market))

    %{market | zip_codes: zips}
  end

  def match_tag_factory do
    %MatchTag{
      name: :new
    }
  end

  def match_fee_factory do
    %MatchFee{
      type: :holiday_fee,
      description: "A fee",
      amount: 100,
      driver_amount: 75
    }
  end

  def match_sla_factory do
    %MatchSLA{
      type: :acceptance,
      start_time: DateTime.utc_now(),
      end_time: DateTime.utc_now() |> DateTime.add(10 * 60, :second)
    }
  end

  def eta_factory do
    %ETA{
      match: build(:match),
      arrive_at: DateTime.utc_now() |> DateTime.add(30 * 60, :second)
    }
  end

  def metric_settings_factory do
    %MetricSettings{
      fulfillment_goal: 50
    }
  end

  def hidden_customer_factory do
    %HiddenCustomer{
      driver: build(:driver),
      shipper: nil,
      company: nil
    }
  end

  def notification_batch_factory do
    %NotificationBatch{
      match: insert(:assigning_driver_match),
      admin_user: insert(:network_operator),
      sent_notifications: fn batch ->
        [
          build(:sent_notification,
            match: batch.match,
            notification_type: :sms,
            driver: insert(:driver)
          )
        ]
      end
    }
  end

  def sent_notification_factory do
    driver = build(:driver)

    %SentNotification{
      match: build(:match),
      driver: driver,
      notification_type: :sms,
      phone_number: ExPhoneNumber.format(driver.phone_number, :e164)
    }
  end

  def contact_factory do
    %Contact{
      name: "John Smith",
      email: sequence(:email, &"contact-#{&1}@example.com"),
      phone_number: parse_phone("+1513401" <> Kernel.to_string(Enum.random(1_000..9_999))),
      notify: true
    }
  end

  def agreement_document_factory do
    %AgreementDocument{
      title: "EULA",
      state: :published,
      type: :eula,
      user_types: [:shipper],
      content: "<p>Content</p>",
      parent_document: nil
    }
  end

  def user_agreement_factory do
    %UserAgreement{
      agreed: true,
      document: build(:agreement_document),
      user: build(:user, shipper: build(:shipper))
    }
  end

  def contract_factory do
    %Contract{
      name: "ATD",
      contract_key: "atd",
      pricing_contract: :atd,
      active_matches: 0,
      active_match_factor: :delivery_duration,
      active_match_duration: nil,
      company: build(:company)
    }
  end

  def contract_sla_factory do
    %ContractSLA{
      type: :acceptance,
      contract: build(:contract),
      duration: "total_distance/(travel_duration * stop_count)"
    }
  end

  def cancellation_pay_rule_factory do
    %CancellationPayRule{}
  end

  def nps_score_factory do
    shipper = insert(:shipper)

    %NpsScore{
      user: shipper.user,
      user_type: :shipper
    }
  end

  defp parse_phone(number) do
    {:ok, phone_number} = ExPhoneNumber.parse(number, "")
    phone_number
  end

  def alphanum_string(length) do
    string =
      Faker.UUID.v4()
      |> String.replace("-", "")
      |> String.slice(0..(length - 1))
      |> String.upcase()

    case String.length(string) do
      ^length ->
        string

      str_length ->
        raise ArgumentError, "`length` cannot be greater than #{str_length}"
    end
  end

  def alphanum_string(from, to),
    do:
      Faker.random_between(from, to)
      |> alphanum_string()

  def market_config_factory() do
    %MarketConfig{
      contract: build(:contract),
      market: build(:market),
      multiplier: 1
    }
  end
end
