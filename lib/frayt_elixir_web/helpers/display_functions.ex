defmodule FraytElixirWeb.DisplayFunctions do
  import Phoenix.HTML.Tag
  alias FraytElixirWeb.ErrorCodeHelper
  alias FraytElixir.Shipment

  alias FraytElixir.Shipment.{
    Match,
    MatchStop,
    MatchState,
    MatchStopState,
    Address,
    MatchStopItem
  }

  alias FraytElixir.Accounts.{AdminUser, Company, Location, Shipper}
  alias FraytElixir.Drivers.Vehicle
  alias FraytElixir.Photo
  alias Timex
  alias FraytElixir.GeocodedAddressHelper
  alias ExPhoneNumber.Model.PhoneNumber
  import Phoenix.Naming, only: [humanize: 1]
  import FraytElixirWeb.ErrorHelpers, only: [translate_error: 1]
  require Logger

  @lower_case_words ["of", "a"]

  def display_current_stop_number(%Match{} = match) do
    case Shipment.get_current_match_stop(match) do
      %MatchStop{index: index} -> index + 1
      _ -> nil
    end
  end

  def account_billing_company(%{account_billing_enabled: false}), do: nil

  def account_billing_company(%{account_billing_enabled: true, name: company_name}),
    do: company_name

  def destination_address(%Match{
        match_stops: [%MatchStop{destination_address: destination_address} | _]
      }),
      do: destination_address

  def handle_empty_string(string), do: handle_empty_string(string, nil)
  def handle_empty_string("", fallback), do: fallback
  def handle_empty_string(string, _fallback), do: string

  def display_price(_price, _nil_val \\ "0.00")
  def display_price(price, _) when is_integer(price), do: "#{format_price(price)}"
  def display_price(_price, nil_val), do: nil_val

  def format_price(price) do
    String.split("#{cents_to_dollars(price) |> displayable_float()}", ".")
    |> trailing_zeros
    |> Enum.join(".")
  end

  def display_large_numbers(int) do
    int
    |> to_string()
    |> add_commas()
  end

  def display_large_prices(string_float, keep_cents \\ true)

  def display_large_prices(string_float, keep_cents) when keep_cents == false do
    [dollars, _cents] = String.split(string_float, ".")
    "#{add_commas(dollars)}"
  end

  def display_large_prices(string_float, _keep_cents) do
    [dollars, cents] = String.split(string_float, ".")
    "#{add_commas(dollars)}.#{cents}"
  end

  def add_commas(string_num) do
    string_num
    |> String.reverse()
    |> String.split("", trim: true)
    |> Enum.chunk_every(3)
    |> Enum.reverse()
    |> Enum.map_join(",", &Enum.join(Enum.reverse(&1)))
  end

  def display_revenue(revenue_in_cents, keep_cents \\ true),
    do: revenue_in_cents |> display_price |> display_large_prices(keep_cents)

  def display_stage(match_stage, match_stop_stage \\ nil, opts \\ [show_pending: false])
  def display_stage(:canceled, _, _), do: "Shipper Canceled"
  def display_stage(:admin_canceled, _, _), do: "Admin Canceled"
  def display_stage(:complete, _, _), do: "Match Complete"
  def display_stage(:pending, _, _), do: "Pending Delivery"

  def display_stage(:picked_up, [%MatchStop{} | _] = match_stop_states, _) do
    states = Enum.map(match_stop_states, & &1.state)
    display_stage(:picked_up, states)
  end

  def display_stage(:picked_up, match_stop_states, opts) when is_list(match_stop_states) do
    live_stop = Enum.find(match_stop_states, nil, &(&1 in MatchStopState.live_range()))

    stops_completed? = Enum.any?(match_stop_states, &(&1 in MatchStopState.completed_range()))

    case {live_stop, stops_completed?} do
      {:en_route, _} -> "En Route to Dropoff"
      {:arrived, _} -> "Arrived at Dropoff"
      {:signed, _} -> "Signed"
      {_, true} -> "En Route to Dropoff"
      {_, _} -> display_stage(:picked_up, :pending, opts)
    end
  end

  def display_stage(:picked_up, nil, _), do: title_case(:picked_up)

  def display_stage(:picked_up, match_stop_stage, opts) do
    case match_stop_stage do
      :pending -> if opts[:show_pending], do: "Pending", else: "Picked Up"
      stage -> title_case(stage)
    end
  end

  def display_stage(stage, _, _), do: title_case(stage)

  def display_item(%MatchStopItem{
        length: length,
        width: width,
        height: height,
        weight: weight,
        pieces: pieces,
        description: description
      })
      when not is_nil(length) and not is_nil(width) and not is_nil(height),
      do:
        "#{pieces} #{description} @ #{length}\" x #{width}\" x #{height}\" and #{weight}lbs each"

  def display_item(%MatchStopItem{
        volume: volume,
        weight: weight,
        pieces: pieces,
        description: description
      }),
      do: "#{pieces} #{description} @ #{Kernel.round(volume / 1728)} ft³ and #{weight}lbs each"

  def stage_as_number(match_state),
    do: Map.get(MatchState.all_indexes(), match_state, 0)

  def deprecated_stage_as_number(match_state),
    do: Map.get(MatchState.deprecated_states(), match_state, 0)

  def match_stop_state_as_number(match_stop_state),
    do: Map.get(MatchStopState.all_indexes(), match_stop_state, 7)

  def trailing_zeros([dollars, cents]) do
    [dollars, String.pad_trailing(cents, 2, "0")]
  end

  def trailing_zeros([dollars]), do: [dollars, "00"]

  def trailing_zeros_on_input(string) when string in [nil, ""], do: "0.00"

  def trailing_zeros_on_input(string) do
    string
    |> String.split(".")
    |> trailing_zeros()
    |> Enum.join(".")
  end

  def number_to_percent(number, precision \\ 0)
  def number_to_percent(nil, precision), do: number_to_percent(0, precision)

  def number_to_percent(number, precision) when is_number(number),
    do: displayable_float(number * 100, precision) <> "%"

  def displayable_float(number, decimal_places \\ 2)

  def displayable_float("", decimal_places), do: displayable_float(0.0, decimal_places)

  def displayable_float(nil, _decimal_places), do: nil

  def displayable_float(number, decimal_places) when is_float(number),
    do:
      Decimal.from_float(number)
      |> displayable_float(decimal_places)

  def displayable_float(number, decimal_places) when is_binary(number) or is_integer(number),
    do:
      Decimal.new(number)
      |> displayable_float(decimal_places)

  def displayable_float(%Decimal{} = decimal, decimal_places),
    do:
      decimal
      |> Decimal.round(decimal_places)
      |> Decimal.to_float()
      |> :erlang.float_to_binary(decimals: decimal_places)

  def range_from_one_to(0), do: []
  def range_from_one_to(num), do: 1..num

  def service_level(int) when is_nil(int), do: ""

  def service_level(int) do
    Map.fetch!(title_cased_attribute(:service_levels), int)
  end

  def datetime_with_timezone(datetime), do: datetime_with_timezone(datetime, "UTC")

  def datetime_with_timezone(%NaiveDateTime{} = datetime, time_zone) do
    utc_datetime = DateTime.from_naive!(datetime, "Etc/UTC")

    datetime_with_timezone(utc_datetime, time_zone)
  end

  def datetime_with_timezone(%DateTime{} = datetime, time_zone) do
    case Timex.Timezone.convert(datetime, time_zone) do
      {:error, _} -> datetime
      updated_datetime -> updated_datetime
    end
  end

  def datetime_with_timezone(datetime, _), do: datetime

  def create_datetime(date, time, scheduled, _time_zone)
      when date in ["", nil] or time in ["", nil] or scheduled in ["false", false, nil],
      do: nil

  def create_datetime(date, time, scheduled, time_zone) when byte_size(time) <= 5,
    do: create_datetime(date, "#{time}:00", scheduled, time_zone)

  def create_datetime(date, time, _scheduled, time_zone) do
    date = Date.from_iso8601!(date)
    time = Time.from_iso8601!(time)

    case NaiveDateTime.new(date, time) do
      {:ok, ndt} -> Timex.to_datetime(ndt, time_zone)
      _ -> nil
    end
  end

  def timezone_abbr_from_full(datetime, timezone) when datetime in ["", nil],
    do: Timex.Timezone.get(timezone) |> get_timezone_abbr()

  def timezone_abbr_from_full(datetime, timezone),
    do: Timex.Timezone.get(timezone, datetime) |> get_timezone_abbr()

  defp get_timezone_abbr({:error, _}), do: "UTC"

  defp get_timezone_abbr(%Timex.AmbiguousTimezoneInfo{after: after_info}),
    do: get_timezone_abbr(after_info)

  defp get_timezone_abbr(%Timex.TimezoneInfo{abbreviation: abbreviation}), do: abbreviation

  def datetime_to_dateinput(%{year: year, month: month, day: day}),
    do: "#{year}-#{leading_zero(month)}-#{leading_zero(day)}"

  def datetime_to_dateinput(_), do: nil

  def datetime_to_dateinput(%{year: _year, month: _month, day: _day} = datetime, time_zone) do
    %{year: year, month: month, day: day} = datetime_with_timezone(datetime, time_zone)
    "#{year}-#{leading_zero(month)}-#{leading_zero(day)}"
  end

  def datetime_to_dateinput(_datetime, _time_zone), do: nil

  def datetime_to_timeinput(%{hour: hour, minute: minute}),
    do: "#{leading_zero(hour)}:#{leading_zero(minute)}:00"

  def datetime_to_timeinput(_), do: nil

  def datetime_to_timeinput(%{hour: _hour, minute: _minute} = datetime, time_zone) do
    %{hour: hour, minute: minute} = datetime_with_timezone(datetime, time_zone)
    "#{leading_zero(hour)}:#{leading_zero(minute)}:00"
  end

  def datetime_to_timeinput(_datetime, _time_zone), do: nil

  def time_to_timeinput(nil, _), do: nil

  def time_to_timeinput(time, timezone) do
    case NaiveDateTime.new(Date.utc_today(), time) do
      {:ok, ndt} -> datetime_with_timezone(ndt, timezone) |> DateTime.to_time()
      _ -> nil
    end
  end

  def display_date(%{year: year, month: month, day: day}) do
    "#{leading_zero(month)}/#{leading_zero(day)}/#{year}"
  end

  def display_date(_), do: "-"

  def display_date(%{year: _year, month: _month, day: _day} = datetime, time_zone) do
    %{year: year, month: month, day: day} = datetime_with_timezone(datetime, time_zone)
    "#{leading_zero(month)}/#{leading_zero(day)}/#{year}"
  end

  def display_date(_, _), do: "-"

  def display_date_utc(date) do
    display_date(date, "UTC")
  end

  def display_date_long(%{year: _year, month: _month, day: _day} = datetime, time_zone) do
    %{year: year, month: month, day: day} = datetime_with_timezone(datetime, time_zone)
    "#{display_month(month)} #{day}, #{year}"
  end

  def display_date_long(_, _), do: "-"

  def date_time_to_unix(nil), do: nil

  def date_time_to_unix(datetime),
    do:
      datetime
      |> datetime_with_timezone()
      |> DateTime.to_unix(:millisecond)

  def display_date_time_utc(datetime), do: display_date_time(datetime, "UTC")

  def display_date_time(
        %{year: _year, month: _month, day: _day, hour: _hour, minute: _minute} = datetime,
        %Address{geo_location: %{coordinates: {_, _} = coordinates}}
      ) do
    time_zone = GeocodedAddressHelper.get_timezone(coordinates)
    display_date_time(datetime, time_zone)
  end

  def display_date_time(
        %{year: _year, month: _month, day: _day, hour: _hour, minute: _minute} = datetime,
        time_zone
      ),
      do: "#{display_date(datetime, time_zone)} #{display_time(datetime, time_zone)}"

  def display_date_time(_, _), do: "-"

  def display_date_time_long(
        %{year: _year, month: _month, day: _day, hour: _hour, minute: _minute} = datetime,
        %Address{geo_location: %{coordinates: {_, _} = coordinates}}
      ) do
    time_zone = GeocodedAddressHelper.get_timezone(coordinates)
    display_date_time_long(datetime, time_zone)
  end

  def display_date_time_long(
        %{year: _year, month: _month, day: _day, hour: _hour, minute: _minute} = datetime,
        time_zone
      ) do
    "#{display_date_long(datetime, time_zone)}, #{display_time(datetime, time_zone)}"
  end

  def display_date_time_long(_datetime, _), do: nil

  def display_time(
        %{hour: _hour, minute: _minute, day: _day, second: _second, month: _, year: _} = datetime,
        time_zone
      ) do
    %{hour: hour, minute: minute, second: second} =
      converted = datetime_with_timezone(datetime, time_zone)

    "#{to_twelve_hour(hour)}:#{leading_zero(minute)}:#{leading_zero(second)} #{if hour >= 12, do: "PM", else: "AM"} #{Map.get(converted, :zone_abbr, "UTC")}"
  end

  def display_time(%{hour: _, minute: _} = time, time_zone),
    do: NaiveDateTime.new(Date.utc_today(), time) |> elem(1) |> display_time(time_zone)

  def display_time(_, _), do: "-"

  def to_twelve_hour(hour) when hour > 12, do: leading_zero(hour - 12)
  def to_twelve_hour(hour) when hour in [0, 12], do: "12"
  def to_twelve_hour(hour), do: leading_zero(hour)

  def display_city_state(%{city: nil, state: state}), do: display_state(state)
  def display_city_state(%{city: city, state: nil}), do: city
  def display_city_state(%{city: city, state: state}), do: "#{city}, #{display_state(state)}"

  def display_address(nil), do: "-"
  def display_address(%{address: nil, city: nil, state: nil, zip: nil}), do: "-"

  def display_address(%{address: nil, city: nil, state: state, zip: zip}),
    do: "#{display_state(state)} #{zip}"

  def display_address(%{address: nil, city: city, state: nil, zip: nil}),
    do: "#{city}"

  def display_address(%{address: nil, city: city, state: state, zip: zip}),
    do: "#{city}, #{display_state(state)} #{zip}"

  def display_address(%{address: address, city: nil, state: nil, zip: nil}),
    do: "#{address}"

  def display_address(%{address: address, city: nil, state: state, zip: zip}),
    do: "#{address}, #{display_state(state)} #{zip}"

  def display_address(%{address: address, city: city, state: nil, zip: nil}),
    do: "#{address}, #{city}"

  def display_address(%{address: address, city: city, state: state, zip: zip}),
    do: "#{address}, #{city}, #{display_state(state)} #{zip}"

  def leading_zero(num) when num >= 10, do: "#{num}"
  def leading_zero(num), do: "0#{num}"

  def pluralize(list) when length(list) != 1, do: "s"
  def pluralize(_list), do: ""

  def get(map, key) when is_map(map), do: Map.get(map, key, nil)
  def get(_, _key), do: nil

  def conditional_value(use_fallback, value, fallback \\ nil)
  def conditional_value(false, _value, fallback), do: fallback
  def conditional_value(true, value, _fallback), do: value

  def title_cased_attribute(attribute_name)
      when attribute_name in [:vehicle_classes, :service_levels],
      do:
        Shipment.get_attribute(attribute_name)
        |> Enum.reduce(%{}, fn {key, value}, acc ->
          Map.put(acc, key, title_case(value))
        end)

  def title_cased_attribute(_attribute_name), do: %{}

  def title_case(term) when term in ["passengers_side", :passengers_side], do: "Passenger Side"
  def title_case(term) when term in ["drivers_side", :drivers_side], do: "Driver Side"

  def title_case(term) when is_binary(term), do: split_capitalize_and_join_words(term)

  def title_case(term) when is_atom(term) do
    term
    |> to_string
    |> split_capitalize_and_join_words
  end

  def title_case(term), do: term

  def show_error({_message, _meta}, _field), do: nil
  def show_error(errors, field) when is_map(errors), do: Map.get(errors, field)

  def show_error(errors, field) do
    error = Keyword.get(errors || [], field, nil)

    case error do
      nil -> nil
      _ -> elem(error, 0)
    end
  end

  def display_error(errors, field) do
    error = show_error(errors, field)
    if error, do: content_tag(:p, error, class: "error")
  end

  def input_error({_message, _meta}, _field), do: ""

  def input_error(errors, field) when is_map(errors) do
    if Map.has_key?(errors, field) do
      "error--input"
    else
      ""
    end
  end

  def input_error(errors, field) do
    if Keyword.has_key?(errors || [], field) do
      "error--input"
    else
      ""
    end
  end

  def split_capitalize_and_join_words(word) do
    word
    |> String.split(~r([ _]))
    |> Enum.map_join(
      " ",
      &if(String.downcase(&1) in @lower_case_words,
        do: String.downcase(&1),
        else: String.capitalize(&1)
      )
    )
  end

  def format_phone(phone_number, format \\ :international)

  def format_phone(%PhoneNumber{} = phone_number, format),
    do: ExPhoneNumber.format(phone_number, format)

  def format_phone(phone, _),
    do: phone

  def display_phone(phone_number, format \\ :international) do
    case format_phone(phone_number, format) do
      nil -> "-"
      phone_number -> phone_number
    end
  end

  def display_shipper_phone(number) when byte_size(number) == 10,
    do:
      "(#{String.slice(number, 0..2)})#{String.slice(number, 3..5)}-#{String.slice(number, 6..9)}"

  def display_shipper_phone(number) when byte_size(number) == 11 do
    case String.first(number) do
      "1" -> display_shipper_phone(String.slice(number, 1..10))
      _ -> number
    end
  end

  def display_shipper_phone(number) when is_nil(number), do: "-"
  def display_shipper_phone(number), do: number

  def shipper_phone_link(number) when byte_size(number) == 10, do: "tel:+1#{number}"

  def shipper_phone_link(number) when byte_size(number) == 11 do
    case String.at(number, 0) do
      "1" -> "tel:+#{number}"
      _ -> "tel:#{number}"
    end
  end

  def shipper_phone_link(number), do: "tel:#{number}"

  def phone_link(phone_number), do: format_phone(phone_number, :rfc3966)

  def email_link(email), do: "mailto:#{email}"

  def display_ssn(ssn), do: display_ssn(ssn, :display)
  def display_ssn(ssn, :edit), do: display_ssn(ssn, "")
  def display_ssn(ssn, :display), do: display_ssn(ssn, "-")

  def display_ssn(ssn, when_empty) when is_binary(ssn) do
    case String.length(ssn) do
      9 ->
        maybe_mask_ssn(ssn, when_empty)

      0 ->
        when_empty

      _ ->
        ssn
    end
  end

  def display_ssn(_ssn, when_empty), do: when_empty

  def maybe_mask_ssn(ssn, ""),
    do:
      String.slice(ssn, 0..2) <> "-" <> String.slice(ssn, 3..4) <> "-" <> String.slice(ssn, 5..8)

  def maybe_mask_ssn(ssn, "-"), do: "***-**-" <> String.slice(ssn, 5..8)

  def display_vehicles(vehicles), do: display_vehicles(vehicles, :desktop)
  def display_vehicles(%Vehicle{} = vehicles, view), do: display_vehicles([vehicles], view)
  def display_vehicles([] = _vehicles, _view), do: "-"

  def display_vehicles(vehicles, :desktop) do
    vehicles
    |> create_vehicle_list
    |> Enum.join(", ")
  end

  def display_vehicles(vehicles, :mobile) do
    vehicles
    |> create_vehicle_list
    |> Enum.map(&content_tag(:li, &1, class: "list--circle"))
  end

  def create_vehicle_list(vehicles) do
    vehicles
    |> Enum.map(& &1.vehicle_class)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(&vehicle_class(&1))
  end

  def vehicle_class(0), do: ""
  def vehicle_class(int), do: Map.fetch!(title_cased_attribute(:vehicle_classes), int)

  def vehicle_name(%Vehicle{year: year, make: make, model: model}), do: "#{year} #{make} #{model}"
  def vehicle_name(_), do: "-"

  def display_inches(size) when is_nil(size), do: "-"
  def display_inches(size), do: "#{size}\""

  def display_lbs(weight) when is_nil(weight), do: "-"
  def display_lbs(weight), do: "#{weight} lbs"

  def display_credit_card(credit_card) do
    if credit_card, do: "XXXX XXXX XXXX #{credit_card.last4}", else: "-"
  end

  def display_user_info(nil, :name), do: "-"
  def display_user_info(nil, _type), do: ""
  def display_user_info(%{phone: number}, :phone_link), do: shipper_phone_link(number)
  def display_user_info(%{phone: number}, :phone), do: display_shipper_phone(number)
  def display_user_info(%{phone_number: number}, :phone_link), do: phone_link(number)
  def display_user_info(%{phone_number: number}, :phone), do: display_phone(number)
  def display_user_info(%{user: %{email: email}}, :email_link), do: email_link(email)
  def display_user_info(%{user: %{email: email}}, :email), do: email
  def display_user_info(%{location: %{company: %{name: name}}}, :company), do: name
  def display_user_info(%{company: company}, :company), do: company
  def display_user_info(user, :name), do: full_name(user)

  def display_shipper_sales_rep(%Shipper{sales_rep: %AdminUser{} = sales_rep}),
    do: display_sales_rep(sales_rep)

  def display_shipper_sales_rep(%Shipper{location: %Location{sales_rep: %AdminUser{} = sales_rep}}),
      do: display_sales_rep(sales_rep)

  def display_shipper_sales_rep(%Shipper{
        location: %Location{company: %Company{sales_rep: sales_rep}}
      }),
      do: display_sales_rep(sales_rep)

  def display_shipper_sales_rep(_), do: "-"

  def display_sales_rep(%AdminUser{} = sales_rep), do: sales_rep.name || sales_rep.user.email
  def display_sales_rep(_sales_rep), do: "-"

  def display_time_between(time_between) when is_integer(time_between) do
    hours = div(time_between, 3600)
    time_between = rem(time_between, 3600)
    minutes = div(time_between, 60)
    seconds = rem(time_between, 60)
    "#{leading_zero(hours)}:#{leading_zero(minutes)}:#{leading_zero(seconds)}"
  end

  def display_time_between(_time_between), do: ""

  def sales_rep_options do
    FraytElixir.Accounts.list_sales_reps()
    |> Enum.map(
      &{if &1.name do
         &1.name
       else
         &1.user.email
       end, &1.id}
    )
    |> List.insert_at(0, {"(none)", nil})
  end

  def format_coordinates(%{latitude: lat, longitude: long}), do: "#{lat}, #{long}"
  def format_coordinates({long, lat}), do: format_coordinates(%{latitude: lat, longitude: long})
  def format_coordinates(_), do: "-"

  @state_codes %{
    "Alabama" => "AL",
    "Alaska" => "AK",
    "Arizona" => "AZ",
    "Arkansas" => "AR",
    "California" => "CA",
    "Colorado" => "CO",
    "Connecticut" => "CT",
    "Delaware" => "DE",
    "Florida" => "FL",
    "Georgia" => "GA",
    "Hawaii" => "HI",
    "Idaho" => "ID",
    "Illinois" => "IL",
    "Indiana" => "IN",
    "Iowa" => "IA",
    "Kansas" => "KS",
    "Kentucky" => "KY",
    "Louisiana" => "LA",
    "Maine" => "ME",
    "Maryland" => "MD",
    "Massachusetts" => "MA",
    "Michigan" => "MI",
    "Minnesota" => "MN",
    "Mississippi" => "MS",
    "Missouri" => "MO",
    "Montana" => "MT",
    "Nebraska" => "NE",
    "Nevada" => "NV",
    "New Hampshire" => "NH",
    "New Jersey" => "NJ",
    "New Mexico" => "NM",
    "New York" => "NY",
    "North Carolina" => "NC",
    "North Dakota" => "ND",
    "Ohio" => "OH",
    "Oklahoma" => "OK",
    "Oregon" => "OR",
    "Pennsylvania" => "PA",
    "Rhode Island" => "RI",
    "South Carolina" => "SC",
    "South Dakota" => "SD",
    "Tennessee" => "TN",
    "Texas" => "TX",
    "Utah" => "UT",
    "Vermont" => "VT",
    "Virginia" => "VA",
    "Washington" => "WA",
    "West Virginia" => "WV",
    "Wisconsin" => "WI",
    "Wyoming" => "WY",
    "American Samoa" => "AS",
    "District of Columbia" => "DC",
    "Federated States of Micronesia" => "FM",
    "Guam" => "GU",
    "Marshall Islands" => "MH",
    "Northern Mariana Islands" => "MP",
    "Palau" => "PW",
    "Puerto Rico" => "PR",
    "Virgin Islands" => "VI"
  }

  def display_state(state) do
    Map.get(@state_codes, title_case(state), state)
  end

  @months %{
    1 => "Jan",
    2 => "Feb",
    3 => "Mar",
    4 => "Apr",
    5 => "May",
    6 => "Jun",
    7 => "Jul",
    8 => "Aug",
    9 => "Sep",
    10 => "Oct",
    11 => "Nov",
    12 => "Dec"
  }

  def display_month(month) do
    Map.get(@months, month, nil)
  end

  def cents_to_dollars(cents) when is_number(cents) do
    cents / 100
  end

  def cents_to_dollars(_cents), do: 0

  def convert_string_to_cents(amount) when amount in [nil, ""] or not is_binary(amount), do: nil

  def convert_string_to_cents(amount),
    do:
      ((Float.parse(amount)
        |> elem(0)) * 100)
      |> trunc()

  def full_name(%{first_name: first_name, last_name: last_name}) do
    "#{first_name} #{last_name}"
  end

  def full_name(_), do: nil

  def short_name(%{first_name: first_name, last_name: last_name}),
    do: "#{first_name} #{String.first(last_name)}."

  def short_name(_), do: nil

  def get_coords(%{geo_location: point}), do: get_coords(point)
  def get_coords(%Geo.Point{coordinates: coords}), do: coords
  def get_coords(_), do: nil

  def deprecated_match_status(
        %Match{
          id: match_id,
          identifier: identifier,
          state: match_state,
          driver: driver,
          origin_photo: origin_photo,
          match_stops: [
            %MatchStop{
              id: match_stop_id,
              signature_photo: signature_photo,
              destination_photo: destination_photo,
              signature_name: signature_name,
              state: match_stop_state
            }
          ]
        } = match
      ) do
    deprecated_state = Shipment.get_deprecated_match_state(match)

    {lng, lat} = get_current_location_coords(driver)

    %{
      match: match_id,
      stage: deprecated_stage_as_number(deprecated_state),
      message: display_stage(match_state, match_stop_state),
      status: display_stage(match_state, match_stop_state),
      identifier: identifier,
      receiver_name: signature_name,
      picked_up_time: transitioned_at(match, :picked_up),
      delivered_time: transitioned_at(match, :completed),
      origin_photo: get_photo_url(match_id, origin_photo),
      destination_photo: get_photo_url(match_stop_id, destination_photo),
      driver_name: full_name(driver),
      driver_phone: display_user_info(driver, :phone),
      receiver_signature: get_photo_url(match_stop_id, signature_photo),
      driver_lat: lat,
      driver_lng: lng
    }
  end

  def deprecated_match_status(
        %Match{
          id: match_id,
          identifier: identifier,
          state: state,
          driver: driver,
          origin_photo: origin_photo,
          match_stops: match_stops
        } = match
      ) do
    deprecated_state = Shipment.get_deprecated_match_state(match)

    {lng, lat} = get_current_location_coords(driver)

    %{
      match: match_id,
      stage: deprecated_stage_as_number(deprecated_state),
      message: display_stage(state, match_stops),
      status: display_stage(state, match_stops),
      identifier: identifier,
      picked_up_time: transitioned_at(match, :picked_up),
      delivered_time: transitioned_at(match, :completed),
      origin_photo: get_photo_url(match_id, origin_photo),
      driver_name: full_name(driver),
      driver_phone: display_user_info(driver, :phone),
      match_stops: Enum.map(match_stops, &match_stop_status/1),
      driver_lat: lat,
      driver_lng: lng
    }
  end

  defp get_current_location_coords(%{
         current_location: %{geo_location: %Geo.Point{coordinates: coords}}
       }),
       do: coords

  defp get_current_location_coords(_), do: {nil, nil}

  defp match_stop_status(%MatchStop{
         id: id,
         identifier: identifier,
         state: state,
         signature_photo: signature_photo,
         destination_photo: destination_photo,
         signature_name: signature_name
       }) do
    %{
      match_stop_id: id,
      stage: match_stop_state_as_number(state),
      message: display_stage(:picked_up, state, show_pending: true),
      status: display_stage(:picked_up, state, show_pending: true),
      identifier: identifier,
      receiver_name: signature_name,
      destination_photo: get_photo_url(id, destination_photo),
      receiver_signature: get_photo_url(id, signature_photo)
    }
  end

  defp transitioned_at(match, state) do
    Shipment.match_transitioned_at(match, state) |> display_date_time_iso()
  end

  defp display_date_time_iso(nil), do: ""

  defp display_date_time_iso(datetime),
    do: datetime |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_iso8601()

  def get_photo_url(_id, photo) when is_nil(photo), do: nil

  def get_photo_url(id, photo) do
    case Photo.get_url(id, photo) do
      {:ok, url} -> url
      _ -> nil
    end
  end

  def get_reported_time(%MatchStop{} = match_stop, state) do
    case Shipment.most_recent_transition(match_stop, state) do
      %{inserted_at: %NaiveDateTime{} = inserted_at} -> date_time_to_unix(inserted_at)
      _ -> nil
    end
  end

  def get_reported_time(match, state) do
    case Shipment.most_recent_transition(match, state) do
      %{inserted_at: %NaiveDateTime{} = inserted_at} -> date_time_to_unix(inserted_at)
      _ -> nil
    end
  end

  def display_progress(progress, goal, offset \\ 0)
  def display_progress(nil, _, _), do: ""
  def display_progress(_, nil, _), do: ""

  def display_progress(progress, goal, _) when goal == 0, do: "$#{round(progress)}"

  def display_progress(progress, _, _) when progress == 0, do: "0%"

  def display_progress(progress, goal, offset),
    do: "#{Float.round((progress / goal - offset) * 100, 1)}%"

  def humanize_boolean(true), do: "Yes"
  def humanize_boolean(_), do: "No"

  def humanize_update_errors(error, name) do
    case error do
      {:error, %Ecto.Changeset{} = changeset} ->
        humanize_errors(changeset)

      {:error, _, %Ecto.Changeset{} = changeset, _} ->
        humanize_errors(changeset)

      {:error, message} when is_binary(message) ->
        message

      {:error, _code, message} when is_binary(message) ->
        message

      {:error, code} when is_atom(code) ->
        "Unable to update #{name}: " <> ErrorCodeHelper.get_error_message(code)

      {:error, _code, %Stripe.Error{message: message}} ->
        "Stripe Error: #{message}"

      {:error, _failed_operation, message, _changes_so_far} ->
        message

      error ->
        Logger.error("Unhandled error updating #{name}: #{inspect(error)}")
        "Unable to update #{name}"
    end
  end

  def humanize_errors(%Ecto.Changeset{} = changeset) do
    changeset
    |> translate_errors()
    |> Enum.map_join("; ", fn {k, v} -> humanize_errors(k, v) end)
  end

  def humanize_errors(errors), do: humanize_errors("", errors)

  def humanize_errors(key, error, options \\ [])

  def humanize_errors(key, errors, _) when is_map(errors) do
    Enum.map_join(errors, "; ", fn {k, v} ->
      message = humanize_errors(k, v)

      humanize_errors(key, message, possesive: true)
    end)
  end

  def humanize_errors(key, errors, _) when is_list(errors) do
    Enum.map(errors, &humanize_errors(key, &1))
    |> Enum.filter(&(String.trim(&1) != ""))
    |> Enum.join(", ")
  end

  def humanize_errors("", error, _) when is_bitstring(error), do: error

  def humanize_errors(key, error, possesive: true) when is_bitstring(error),
    do: "#{humanize(key)}'s #{error}"

  def humanize_errors(key, error, _) when is_bitstring(error), do: "#{humanize(key)} #{error}"

  def translate_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
  end

  def translate_errors(%{} = errors), do: errors

  def fetch_photo_url(_id, photo) when is_nil(photo), do: nil

  def fetch_photo_url(id, photo) do
    {:ok, photo_url} = Photo.get_url(id, photo)
    photo_url
  end

  def get_shortened_initial(nil), do: nil

  def get_shortened_initial(string), do: String.first(string) <> "."

  def from_now(datetime) do
    {:ok, elapsed_time} = Timex.format(datetime, "{relative}", :relative)
    elapsed_time
  end
end
