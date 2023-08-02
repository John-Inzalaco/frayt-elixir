defmodule FraytElixirWeb.DisplayFunctionsTest do
  use FraytElixirWeb.ConnCase, async: true
  import FraytElixirWeb.DisplayFunctions
  import FraytElixir.Factory
  alias FraytElixir.Accounts.{AdminUser, User}
  alias FraytElixir.Shipment.{Match, MatchStopItem}
  alias FraytElixir.Drivers
  alias FraytElixir.Drivers.Vehicle
  alias FraytElixir.{Shipment, Repo}

  test "account_billing_company/1" do
    company = insert(:company, account_billing_enabled: false)
    company_with_billing = insert(:company, account_billing_enabled: true)
    company_with_no_name = insert(:company, name: nil, account_billing_enabled: true)

    assert account_billing_company(%{
             account_billing_enabled: false,
             invoice_period: nil,
             name: nil,
             sales_rep: nil
           }) == nil

    assert account_billing_company(company) == nil
    assert account_billing_company(company_with_no_name) == nil
    assert account_billing_company(company_with_billing) == company_with_billing.name
  end

  test "display_ssn/1" do
    assert display_ssn("987654345") == "***-**-4345"
    assert display_ssn("987654345", :edit) == "987-65-4345"
    assert display_ssn(nil) == "-"
    assert display_ssn("") == "-"
    assert display_ssn("987654566789") == "987654566789"
    assert display_ssn("garbage") == "garbage"
    assert display_ssn(234_564_234) == "-"
  end

  test "display_vehicles/1" do
    assert display_vehicles([]) == "-"
    assert display_vehicles([%Vehicle{vehicle_class: 2}]) == "Midsize"
    assert display_vehicles(%Vehicle{vehicle_class: 2}) == "Midsize"
    assert display_vehicles([%{vehicle_class: 4}]) == "Box Truck"

    assert display_vehicles([%Vehicle{vehicle_class: 2}, %Vehicle{vehicle_class: 1}]) ==
             "Car, Midsize"
  end

  test "display_vehicles/2" do
    assert display_vehicles([], :mobile) == "-"

    assert display_vehicles([%{vehicle_class: 2}, %{vehicle_class: 1}], :mobile) == [
             safe: [
               60,
               "li",
               [[32, "class", 61, 34, "list--circle", 34]],
               62,
               "Car",
               60,
               47,
               "li",
               62
             ],
             safe: [
               60,
               "li",
               [[32, "class", 61, 34, "list--circle", 34]],
               62,
               "Midsize",
               60,
               47,
               "li",
               62
             ]
           ]
  end

  test "vehicle_class/1" do
    assert vehicle_class(1) == "Car"
    assert vehicle_class(2) == "Midsize"
    assert vehicle_class(3) == "Cargo Van"
    assert vehicle_class(4) == "Box Truck"
  end

  test "display_inches/1" do
    assert display_inches(nil) == "-"
    assert display_inches(36) == "36\""
  end

  test "display_lbs/1" do
    assert display_lbs(nil) == "-"
    assert display_lbs(46) == "46 lbs"
  end

  test "display_shipper_phone" do
    assert display_shipper_phone("12345678909") == "(234)567-8909"
    assert display_shipper_phone("2345678909") == "(234)567-8909"
    assert display_shipper_phone("123456789098") == "123456789098"
    assert display_shipper_phone(nil) == "-"
  end

  test "display_phone" do
    {:ok, phone} = ExPhoneNumber.parse("+19372017065", "")
    assert display_phone(phone, :national) == "(937) 201-7065"
    assert display_phone(phone) == "+1 937-201-7065"
    assert display_phone(nil) == "-"
  end

  test "format_phone" do
    {:ok, phone} = ExPhoneNumber.parse("+19372017065", "")
    assert format_phone(phone) == "+1 937-201-7065"
    assert format_phone("123") == "123"
    assert format_phone(nil) == nil
  end

  test "title_case" do
    assert title_case("this is a test") == "This Is a Test"
    assert title_case(:this_is_a_test) == "This Is a Test"
    assert title_case("district of columbia") == "District of Columbia"
    assert title_case("this_is a_test") == "This Is a Test"
  end

  test "display_date" do
    assert display_date(~N[2000-01-01 23:00:07], "UTC") == "01/01/2000"
    assert display_date(~N[2000-10-21 23:00:07], "UTC") == "10/21/2000"
    assert display_date_utc(~N[2000-10-21 23:00:07]) == "10/21/2000"
    assert display_date(~D[2000-01-01]) == "01/01/2000"
    assert display_date(~D[2000-10-21]) == "10/21/2000"
    assert display_date(nil, "UTC") == "-"
    assert display_date(nil) == "-"
    assert display_date("wutcha", "UTC") == "-"
    assert display_date_long(nil, "UTC") == "-"
  end

  test "display_date_time" do
    assert display_date_time(
             %{year: 2000, month: 1, day: 1, hour: 18, minute: 0, second: 0},
             "UTC"
           ) ==
             "01/01/2000 06:00:00 PM UTC"

    assert display_date_time_utc(%{year: 2000, month: 1, day: 1, hour: 18, minute: 0, second: 0}) ==
             "01/01/2000 06:00:00 PM UTC"

    assert display_date_time(
             %{year: 2000, month: 10, day: 21, hour: 9, minute: 0, second: 0},
             "UTC"
           ) ==
             "10/21/2000 09:00:00 AM UTC"

    assert display_date_time(
             %{year: 2000, month: 10, day: 20, hour: 21, minute: 0, second: 0},
             "UTC"
           ) ==
             "10/20/2000 09:00:00 PM UTC"

    assert display_date_time(
             %{year: 2000, month: 10, day: 21, hour: 6, minute: 3, second: 0},
             "UTC"
           ) ==
             "10/21/2000 06:03:00 AM UTC"

    assert display_date_time(
             %{year: 2000, month: 10, day: 21, hour: 8, minute: 25, second: 0},
             "UTC"
           ) ==
             "10/21/2000 08:25:00 AM UTC"

    assert display_date_time(
             %{year: 2000, month: 10, day: 20, hour: 8, minute: 20, second: 0},
             "UTC"
           ) ==
             "10/20/2000 08:20:00 AM UTC"

    assert display_date_time(
             %{year: 2000, month: 10, day: 21, hour: 0, minute: 20, second: 0},
             "UTC"
           ) ==
             "10/21/2000 12:20:00 AM UTC"

    assert display_date_time(nil, "UTC") == "-"

    assert display_date_time(
             ~N[2000-10-21 00:20:12],
             "America/New_York"
           ) ==
             "10/20/2000 08:20:12 PM EDT"

    assert display_date_time(
             ~N[2000-10-21 00:20:12],
             ""
           ) ==
             "10/21/2000 12:20:12 AM UTC"

    assert display_date_time(
             ~N[2000-10-21 00:20:12],
             nil
           ) ==
             "10/21/2000 12:20:12 AM UTC"

    assert display_date_time(
             ~N[2000-10-21 00:20:12],
             "garbage"
           ) ==
             "10/21/2000 12:20:12 AM UTC"
  end

  test "title_cased_attribute" do
    assert title_cased_attribute(:vehicle_classes) == %{
             1 => "Car",
             2 => "Midsize",
             3 => "Cargo Van",
             4 => "Box Truck"
           }

    assert title_cased_attribute(:service_levels) == %{1 => "Dash", 2 => "Same Day"}
  end

  test "display_state/1" do
    assert display_state("Georgia") == "GA"
    assert display_state("Ohio") == "OH"
    assert display_state("ohio") == "OH"
    assert display_state("south dakota") == "SD"
    assert display_state("Oho") == "Oho"
  end

  test "display_price/1" do
    assert display_price(nil) == "0.00"
    assert display_price(300) == "3.00"
    assert display_price(310) == "3.10"
    assert display_price(312) == "3.12"
    assert display_price(nil, "N/A") == "N/A"
  end

  test "pluralize/1" do
    assert pluralize([1, 2, 3]) == "s"
    assert pluralize([1]) == ""
    assert pluralize([]) == "s"
  end

  test "display_address/1" do
    assert display_address(%{
             address: "123 Somewhere Lane",
             city: "Cincinnati",
             state: "Ohio",
             zip: "45202"
           }) == "123 Somewhere Lane, Cincinnati, OH 45202"

    assert display_address(%{
             address: nil,
             city: "Cincinnati",
             state: "Ohio",
             zip: "45202"
           }) == "Cincinnati, OH 45202"

    assert display_address(%{
             address: "123 Somewhere Lane",
             city: nil,
             state: "Ohio",
             zip: "45202"
           }) == "123 Somewhere Lane, OH 45202"

    assert display_address(%{
             address: nil,
             city: nil,
             state: "Ohio",
             zip: "45202"
           }) == "OH 45202"

    assert display_address(%{
             address: "123 Somewhere Lane",
             city: "Cincinnati",
             state: nil,
             zip: nil
           }) == "123 Somewhere Lane, Cincinnati"

    assert display_address(%{
             address: "123 Somewhere Lane",
             city: "Cincinnati",
             state: "Ohio",
             zip: nil
           }) == "123 Somewhere Lane, Cincinnati, OH "

    assert display_address(%{
             address: "123 Somewhere Lane",
             city: "Cincinnati",
             state: nil,
             zip: "45202"
           }) == "123 Somewhere Lane, Cincinnati,  45202"

    assert display_address(%{
             address: "123 Somewhere Lane",
             city: nil,
             state: nil,
             zip: "45202"
           }) == "123 Somewhere Lane,  45202"

    assert display_address(%{
             address: "123 Somewhere Lane",
             city: nil,
             state: nil,
             zip: nil
           }) == "123 Somewhere Lane"

    assert display_address(%{
             address: nil,
             city: "Cincinnati",
             state: nil,
             zip: "45202"
           }) == "Cincinnati,  45202"

    assert display_address(%{
             address: nil,
             city: "Cincinnati",
             state: nil,
             zip: nil
           }) == "Cincinnati"

    assert display_address(%{
             address: nil,
             city: nil,
             state: nil,
             zip: nil
           }) == "-"

    assert display_address(nil) == "-"
  end

  test "display_city_state/1" do
    assert display_city_state(%{
             city: "Cincinnati",
             state: "Ohio"
           }) == "Cincinnati, OH"

    assert display_city_state(%{
             city: nil,
             state: "Ohio"
           }) == "OH"

    assert display_city_state(%{
             city: "Cincinnati",
             state: nil
           }) == "Cincinnati"

    assert display_city_state(%{
             city: nil,
             state: nil
           }) == nil
  end

  test "display_stage/1" do
    assert display_stage(:canceled) == "Shipper Canceled"
    assert display_stage(:admin_canceled) == "Admin Canceled"
    assert display_stage(:complete) == "Match Complete"
    assert display_stage(:assigning_driver) == "Assigning Driver"
  end

  test "email_link/1" do
    assert email_link("test@email.com") == "mailto:test@email.com"
  end

  test "shipper_phone_link/1" do
    assert shipper_phone_link("2345678765") == "tel:+12345678765"
    assert shipper_phone_link("23456787653") == "tel:23456787653"
    assert shipper_phone_link("13456787653") == "tel:+13456787653"
    assert shipper_phone_link("134567876532") == "tel:134567876532"
  end

  test "phone_link/1" do
    {:ok, phone} = ExPhoneNumber.parse("+19372017065", "")
    assert phone_link(phone) == "tel:+1-937-201-7065"
    assert phone_link(nil) == nil
  end

  test "display_user_info/2" do
    assert display_user_info(nil, :name) == "-"
    assert display_user_info(nil, :phone) == ""
    assert display_user_info(%{phone: "2345678765"}, :phone) == "(234)567-8765"
    assert display_user_info(%{phone: "2345678765"}, :phone_link) == "tel:+12345678765"
    assert display_user_info(%{phone: "23456787653"}, :phone_link) == "tel:23456787653"
    assert display_user_info(%{phone: "13456787653"}, :phone_link) == "tel:+13456787653"
    assert display_user_info(%{phone: "134567876532"}, :phone_link) == "tel:134567876532"

    assert display_user_info(
             %{phone_number: "+151356787653" |> ExPhoneNumber.parse("") |> elem(1)},
             :phone_link
           ) == "tel:+1-51356787653"

    assert display_user_info(%{first_name: "Alex", last_name: "Smith"}, :name) == "Alex Smith"
    assert display_user_info(%{user: %{email: "test@email.com"}}, :email) == "test@email.com"

    assert display_user_info(%{user: %{email: "test@email.com"}}, :email_link) ==
             "mailto:test@email.com"
  end

  test "display short name" do
    assert short_name(%{first_name: "Bob", last_name: "Jones"}) == "Bob J."
  end

  test "display_time_between" do
    assert display_time_between(361) == "00:06:01"
    assert display_time_between(7260) == "02:01:00"
    assert display_time_between(nil) == ""
    assert display_time_between(240) == "00:04:00"
    assert display_time_between("something else") == ""
  end

  test "display_revenue/1" do
    assert display_revenue(123_00) == "123.00"
    assert display_revenue(1_234_00) == "1,234.00"
    assert display_revenue(20_000_000_00) == "20,000,000.00"
    assert display_revenue(21_432_857_02) == "21,432,857.02"
  end

  test "add_commas/1" do
    assert add_commas("123456789") == "123,456,789"
  end

  test "display_sales_rep/1" do
    assert display_sales_rep(nil) == "-"

    assert display_sales_rep(%AdminUser{name: nil, user: %{email: "some@email.com"}}) ==
             "some@email.com"

    assert display_sales_rep(%AdminUser{name: "Some Name", user: %{email: "some@email.com"}}) ==
             "Some Name"
  end

  test "sales_rep_options" do
    insert_list(3, :admin_user, role: "sales_rep", name: "Some Name")
    insert_list(2, :admin_user, role: "sales_rep", name: nil)

    options = sales_rep_options()

    assert Enum.count(options) == 6
    assert List.first(options) == {"(none)", nil}
  end

  test "convert_string_to_cents" do
    assert convert_string_to_cents(nil) == nil
    assert convert_string_to_cents("") == nil
    assert convert_string_to_cents("20") == 2000
    assert convert_string_to_cents(20) == nil
    assert convert_string_to_cents("20.00") == 2000
    assert convert_string_to_cents("0.20") == 20
  end

  test "displayable_float" do
    assert displayable_float(nil) == nil
    assert displayable_float("") == "0.00"
    assert displayable_float(2_000_000) == "2000000.00"
    assert displayable_float(2_000_000.0005) == "2000000.00"
    assert displayable_float(2_000_000.05) == "2000000.05"
    assert displayable_float(2_000_000.055) == "2000000.06"
    assert displayable_float(2_000_000.0) == "2000000.00"
    assert displayable_float("2000000.0") == "2000000.00"
  end

  test "display_large_numbers" do
    assert display_large_numbers(123) == "123"
    assert display_large_numbers(1234) == "1,234"
    assert display_large_numbers(1_234_567_890) == "1,234,567,890"
  end

  test "stage_as_number" do
    assert stage_as_number("anything else") == 0
    assert stage_as_number(:other_states) == 0
    assert stage_as_number(:admin_canceled) == -1
    assert stage_as_number(:canceled) == -1
    assert stage_as_number(:driver_canceled) == -2
    assert stage_as_number(:en_route_to_pickup) == 5
  end

  test "deprecated_stage_as_number" do
    assert deprecated_stage_as_number("anything else") == 0
    assert deprecated_stage_as_number(:canceled) == 0
    assert deprecated_stage_as_number(:driver_canceled) == -2
    assert deprecated_stage_as_number(:signed) == 10
    assert deprecated_stage_as_number(:delivered) == 11
  end

  test "display_progress" do
    assert display_progress(80.0, 100.0) == "80.0%"
    assert display_progress(100.0, 100.0) == "100.0%"
    assert display_progress(100.0, 0.0) == "$100"
    assert display_progress(0.0, 100.0) == "0%"
    assert display_progress(0.0, 0.0) == "$0"
  end

  describe "display_item" do
    test "displays item" do
      assert display_item(%MatchStopItem{
               length: 10,
               width: 11,
               height: 12,
               weight: 20,
               pieces: 2,
               description: "item"
             }) == "2 item @ 10\" x 11\" x 12\" and 20lbs each"
    end

    test "displays item without dimensions" do
      assert display_item(%MatchStopItem{
               volume: 10_000,
               weight: 20,
               pieces: 2,
               description: "item"
             }) == "2 item @ 6 ft³ and 20lbs each"
    end
  end

  describe "humanize_boolean" do
    test "handles true" do
      assert humanize_boolean(true) == "Yes"
    end

    test "handles everything that is not true" do
      assert humanize_boolean(false) == "No"
      assert humanize_boolean(nil) == "No"
      assert humanize_boolean("hello") == "No"
    end
  end

  describe "show_error" do
    test "handles keyword list" do
      assert show_error([name: {"joe", []}], :name) == "joe"
    end

    test "handles map" do
      assert show_error(%{name: "joe", email: nil}, :name) == "joe"
    end

    test "handles keyword list nil" do
      assert show_error([], :name) == nil
    end
  end

  describe "input_error" do
    test "handles keyword list" do
      assert input_error([name: {"joe", []}], :name) == "error--input"
    end

    test "handles map" do
      assert input_error(%{name: "joe", email: nil}, :name) == "error--input"
    end

    test "handles keyword list nil" do
      assert input_error([], :name) == ""
    end
  end

  describe "deprecated_match_status" do
    test "returns correct attributes" do
      %Match{id: match_id} =
        match =
        insert(:signed_match,
          identifier: "12345",
          match_stops: [build(:signed_match_stop, signature_name: "Flub Werp")]
        )
        |> Repo.preload(:state_transitions)

      assert %{
               message: "Signed",
               status: "Signed",
               stage: 10,
               receiver_name: "Flub Werp",
               identifier: "12345",
               match: ^match_id
             } = deprecated_match_status(match)
    end

    test "Returns 'picked_up' if all match_stops are pending" do
      %Match{id: match_id} =
        match =
        insert(:picked_up_match,
          identifier: "12345",
          match_stops: build_match_stops_with_items([:pending, :pending])
        )
        |> Repo.preload(:state_transitions)

      assert %{
               message: "Picked Up",
               status: "Picked Up",
               stage: 7,
               identifier: "12345",
               match: ^match_id
             } = deprecated_match_status(match)
    end

    test "Returns the status of any live stops" do
      %Match{id: match_id} =
        match =
        insert(:picked_up_match,
          identifier: "12345",
          match_stops: build_match_stops_with_items([:delivered, :arrived, :pending]),
          driver:
            insert(:driver,
              current_location:
                insert(:driver_location, geo_location: %Geo.Point{coordinates: {12, 13}})
            )
        )
        |> Repo.preload(:state_transitions)

      assert %{
               message: "Arrived at Dropoff",
               status: "Arrived at Dropoff",
               stage: 9,
               identifier: "12345",
               match: ^match_id,
               driver_lat: 13,
               driver_lng: 12
             } = deprecated_match_status(match)
    end

    test "Returns en_route if there is one or more stops marked as delivered or undeliverable" do
      %Match{id: match_id} =
        match =
        insert(:picked_up_match,
          identifier: "12345",
          match_stops: build_match_stops_with_items([:delivered, :pending, :pending])
        )
        |> Repo.preload(:state_transitions)

      assert %{
               message: "En Route to Dropoff",
               status: "En Route to Dropoff",
               stage: 8,
               identifier: "12345",
               match: ^match_id
             } = deprecated_match_status(match)
    end

    test "datetime format" do
      %{match_stops: [stop]} =
        match =
        insert(:signed_match, match_stops: build_match_stops_with_items([:signed]))
        |> Repo.preload(:state_transitions)

      insert(:match_sla, match: match, driver_id: match.driver_id)
      insert(:match_sla, match: match, type: :pickup, driver_id: match.driver_id)
      insert(:match_sla, match: match, type: :delivery, driver_id: match.driver_id)

      stop = %{stop | match: match}

      {:ok, match, _nps_score_id} = Drivers.deliver_stop(stop)

      delivered_at = Shipment.match_transitioned_at(match, :completed)
      assert %{delivered_time: delivered_time} = deprecated_match_status(match)
      assert Regex.match?(~r/#{delivered_at.year}.*T.*Z$/, delivered_time)
    end
  end

  describe "translate_errors" do
    test "translates all changeset errors" do
      changeset = changeset_errors()

      assert %{
               email: ["can't be blank"],
               password: ["has invalid format", "should be at least 8 character(s)"],
               admin: %{role: ["can't be blank"]}
             } = translate_errors(changeset)
    end

    test "handles already translated errors" do
      errors = %{
        admin: %{role: ["can't be blank"]},
        password: ["has invalid format", "should be at least 8 character(s)"]
      }

      assert %{
               password: ["has invalid format", "should be at least 8 character(s)"],
               admin: %{role: ["can't be blank"]}
             } = translate_errors(errors)
    end
  end

  describe "get_reported_time/2" do
    test "gets inserted at time for given match state" do
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
              to: :en_route_to_pickup,
              inserted_at: ~N[2020-12-20 12:00:00]
            )
          ]
        )

      assert 1_608_465_600_000 == get_reported_time(match, :accepted)
    end

    test "returns nil when no matching state" do
      match = insert(:match)

      assert nil == get_reported_time(match, :accepted)
    end
  end

  test "date_time_to_unix/1" do
    assert date_time_to_unix(~N[2020-01-01 00:00:00]) == 1_577_836_800_000
    assert date_time_to_unix(nil) == nil
  end

  describe "humanize_errors" do
    test "translates all changeset errors" do
      changeset = changeset_errors()

      assert "Admin's Role can't be blank; Email can't be blank; Password has invalid format, Password should be at least 8 character(s)" =
               humanize_errors(changeset)
    end

    test "humanizes map of errors" do
      assert "Address can't be blank; Email can't be blank" =
               humanize_errors(%{address: ["can't be blank"], email: ["can't be blank"]})
    end

    test "humanizes list of errors" do
      assert "Address can't be blank, Address must be entered" =
               humanize_errors(%{address: ["can't be blank", "must be entered"]})
    end
  end

  test "from_now/1" do
    just_now = DateTime.utc_now()
    assert "now" = from_now(just_now)

    one_minute_ago = DateTime.utc_now() |> DateTime.add(-60, :second)
    assert "1 minute ago" = from_now(one_minute_ago)

    five_minutes_ago = DateTime.utc_now() |> DateTime.add(-60 * 5, :second)
    assert "5 minutes ago" = from_now(five_minutes_ago)

    five_days_ago = DateTime.utc_now() |> DateTime.add(-60 * 60 * 24 * 5, :second)
    assert "5 days ago" = from_now(five_days_ago)

    one_months_ago = DateTime.utc_now() |> DateTime.add(-60 * 60 * 24 * 365, :second)
    assert "1 year ago" = from_now(one_months_ago)
  end

  defp changeset_errors() do
    %User{}
    |> Ecto.Changeset.cast(%{password: "1234", admin: %{name: "john", role: nil}}, [
      :email,
      :password
    ])
    |> Ecto.Changeset.cast_assoc(:admin)
    |> Ecto.Changeset.validate_required([:email, :password, :admin])
    |> Ecto.Changeset.validate_length(:password, min: 8, max: 10)
    |> Ecto.Changeset.validate_format(:password, ~r/[A-Z]/)
  end
end
