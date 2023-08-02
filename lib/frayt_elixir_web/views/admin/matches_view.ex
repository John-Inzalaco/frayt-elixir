defmodule FraytElixirWeb.Admin.MatchesView do
  use FraytElixirWeb, :view

  alias FraytElixirWeb.DataTable.Helpers, as: Table
  import FraytElixirWeb.DisplayFunctions

  alias FraytElixir.Shipment.{
    Match,
    MatchState,
    MatchStop,
    MatchStateTransition,
    MatchStopStateTransition,
    HiddenMatch,
    MatchFee,
    MatchStopSignatureType,
    ETA
  }

  alias FraytElixir.Shipment.{MatchFeeType, MatchUnloadMethod, MatchStopItemType}
  alias FraytElixir.{Accounts, Version}
  alias FraytElixir.Accounts.{User, Company, Shipper}
  alias FraytElixir.Drivers.Driver
  alias FraytElixir.Shipment.{MatchState, MatchStopState, VehicleClass}
  alias FraytElixir.MatchLog
  alias FraytElixirWeb.AdminAlerts
  alias FraytElixir.Contracts.Contract
  alias FraytElixir.DriverDocuments

  @editable_states MatchState.editable_range()

  @optimizable_states MatchState.cancelable_range()
  @stop_states MatchStopState.all_range()

  def move_stop_button(match_form, form, :up),
    do: move_stop_button(match_form, form, "arrow_upward", -1)

  def move_stop_button(match_form, form, :down),
    do: move_stop_button(match_form, form, "arrow_downward", 1)

  def move_stop_button(match_form, form, icon, change) do
    max = input_value(match_form, :match_stops) |> Enum.count()
    min = 0

    assigns = %{
      new_index: input_value(form, :index) + change,
      stop_id: input_value(form, :id),
      icon: icon
    }

    if assigns[:new_index] >= min and assigns[:new_index] < max do
      ~L"""
        <a onclick="" phx-click="move_stop:<%= @stop_id %>" phx-value-index="<%= @new_index %>"><i class="material-icons"><%= @icon %></i></a>
      """
    end
  end

  def location_coordinates([]), do: Jason.encode!([])

  def location_coordinates(driver_locations),
    do:
      driver_locations
      |> Enum.map(&%{lat: &1.coordinates.latitude, lng: &1.coordinates.longitude})
      |> Jason.encode!()

  def is_editable(%Match{state: state}) when state in @editable_states, do: true

  def is_editable(_), do: false

  def is_optimizable?(%Match{state: state} = match) when state in @optimizable_states do
    if match.optimized_stops, do: false, else: true
  end

  def is_optimizable?(_), do: false

  def optimize_stops_limit_reached?(%Match{match_stops: stops} = _match) do
    if length(stops) > 11, do: true, else: false
  end

  def is_multistop(match), do: Enum.count(match.match_stops) > 1

  def stop_state_options(stop) do
    @stop_states
    |> Enum.reject(&(&1 == stop.state))
    |> may_reject_signed(stop)
    |> Enum.map(fn state ->
      label = display_stage(state)
      # opts = [phx_capture_click: "mark_stop_as:#{state}", phx_value_stop_id: stop.id]

      {label, state, stop}
    end)
  end

  @doc """
  Given a list of match_stop_items this function return the sum of all declared_values by items.
  """
  def calc_declared_value(items) do
    Enum.reduce(items, 0, fn item, acc -> acc + (item.declared_value || 0) end)
  end

  @doc """
  Reject :signed status when signature_required is true.

  Hide signed status when signature is not required at delivery time.
  """
  def may_reject_signed(stop_states, stop) do
    stop_states
    |> Enum.reject(&(&1 == :signed and stop.signature_required))
  end

  def volume_to_cubic_feet(volume) when is_number(volume), do: (volume / 1728) |> Float.round(3)
  def volume_to_cubic_feet(volume), do: volume

  def bool_input_value(form, field) do
    case input_value(form, field) do
      value when is_binary(value) -> String.to_existing_atom(value)
      value -> value
    end
  end

  def dollar_input_value(form, field) do
    case input_value(form, field) do
      nil -> 0.0
      value when is_integer(value) -> value / 100.0
      value -> value
    end
    |> :erlang.float_to_binary(decimals: 2)
  end

  def coupon_value(form, match) do
    case input_value(form, :coupon_code) do
      nil -> if match.coupon, do: match.coupon.code
      value -> value
    end
  end

  def render_price(price, [test_id: test_id] \\ [test_id: nil]) do
    assigns = %{
      price: price,
      classes:
        "u-price" <>
          case price do
            price when price < 0 -> " u-price--negative"
            price when price > 0 -> ""
            _ -> " u-price--empty"
          end,
      test_id: test_id
    }

    ~L"""
      <span class="<%= @classes %>" data-test-id="<%= @test_id %>">
        <%= if @price == 0 or is_nil(@price) do %>
          –
        <% else %>
          <%= if @price < 0, do: "-" %>$<%= display_price(abs(@price)) %>
        <% end %>
      </span>
    """
  end

  def divider_class(is_editing, class \\ "u-pad__top--xs u-push__top--xxs")

  def divider_class(is_editing, class) when is_editing,
    do: class <> " u-border--light-gray u-border__top--thin"

  def divider_class(is_editing, class) when not is_editing, do: class <> " u-border__top--thick"
  def check_circle(match_or_stop, target_state, active_state \\ [])

  def check_circle(%Match{state: state}, target_state, active_state) do
    cond do
      state in active_state ->
        "circle--active"

      MatchState.get_index(state) >= MatchState.get_index(target_state) ->
        "circle--checked"

      true ->
        "circle--open"
    end
  end

  def check_circle(%MatchStop{state: state}, target_state, active_state) do
    cond do
      state in active_state ->
        "circle--active"

      MatchStopState.get_index(state) >= MatchStopState.get_index(target_state) ->
        "circle--checked"

      true ->
        "circle--open"
    end
  end

  def timestamp(state, state_transitions, true, :scheduled, timezone) do
    case find_transition(state_transitions, :scheduled) do
      nil -> timestamp(state, state_transitions, :assigning_driver, timezone)
      _ -> timestamp(state, state_transitions, :scheduled, timezone)
    end
  end

  def timestamp(state, state_transitions, _, :scheduled, timezone),
    do: timestamp(state, state_transitions, :assigning_driver, timezone)

  def timestamp(state, match, :pending, timezone),
    do:
      if(stage_as_number(state) > 1,
        do: display_date_time_long(match |> get_inserted_at, timezone)
      )

  def timestamp(state, state_transitions, target_state, timezone) do
    if stage_as_number(state) >= stage_as_number(target_state),
      do:
        display_date_time_long(
          find_transition(state_transitions, target_state) |> get_inserted_at,
          timezone
        ),
      else: nil
  end

  def get_inserted_at(%{inserted_at: inserted_at}), do: inserted_at
  def get_inserted_at(_transition), do: nil

  def show_time_between(match, from, to, prefix \\ "") do
    case time_between(match, from, to) do
      nil -> nil
      duration -> "#{prefix} " <> display_time_between(duration)
    end
  end

  def time_between(match, :pending, :scheduled) do
    final_state =
      with %Match{scheduled: true} <- match,
           %MatchStateTransition{} <- find_transition(match.state_transitions, :scheduled) do
        :scheduled
      else
        _ -> :assigning_driver
      end

    case stage_as_number(match.state) >= stage_as_number(final_state) do
      true -> calculate_time(find_transition(match.state_transitions, final_state), match)
      _ -> nil
    end
  end

  def time_between(match, starting_state, final_state) do
    case stage_as_number(match.state) >= stage_as_number(final_state) do
      true ->
        calculate_time(
          find_transition(match.state_transitions, final_state),
          find_transition(match.state_transitions, starting_state)
        )

      _ ->
        nil
    end
  end

  def calculate_time(%{inserted_at: transition1_inserted_at}, %{
        inserted_at: transition2_inserted_at
      }),
      do:
        NaiveDateTime.diff(
          transition1_inserted_at,
          transition2_inserted_at
        )

  def calculate_time(_transition1, _transition2), do: nil

  def find_transition(state_transitions, number, fallback \\ nil)

  def find_transition(state_transitions, state, fallback) when is_atom(state),
    do: find_transition(state_transitions, stage_as_number(state), fallback)

  def find_transition(state_transitions, number, fallback) when is_list(state_transitions) do
    Enum.filter(state_transitions, &(&1.to == correct_stage(number)))
    |> Enum.sort(&(NaiveDateTime.compare(&1 |> get_inserted_at, &2 |> get_inserted_at) == :gt))
    |> List.first()
    |> maybe_use_fallback(fallback)
  end

  def find_transition(%MatchStateTransition{} = state_transitions, number, fallback),
    do: find_transition([state_transitions], number, fallback)

  def find_transition(_state_transitions, _number, fallback), do: fallback

  defp maybe_use_fallback(nil, fallback), do: fallback
  defp maybe_use_fallback(transition, _fallback), do: transition

  defp correct_stage(number) do
    MatchState.all_indexes()
    |> Enum.find(fn {_, value} -> value == number end)
    |> get_key()
  end

  def get_key({key, _}), do: key
  def get_key(_input), do: nil

  def network_operators do
    Accounts.list_admins()
    |> Enum.map(&{&1.name || &1.user.email, &1.id})
  end

  def deconstruct_match(%Match{
        origin_address: origin_address,
        state: state,
        match_stops: [%MatchStop{destination_address: destination_address} = match_stop | _],
        state_transitions: state_transitions
      }) do
    %{
      origin_address: origin_address,
      state: state,
      match_stop: match_stop,
      destination_address: destination_address,
      state_transitions: state_transitions
    }
  end

  def monthly_or_daily("monthly", monthly, _daily), do: monthly
  def monthly_or_daily("daily", _monthly, daily), do: daily

  def scheduled_datetime(datetime, timezone, field \\ :pickup_at, service_level \\ :dash)

  def scheduled_datetime(nil, _, field, service_level)
      when service_level == :dash or service_level == 1 or field == :pickup_at,
      do: "Now"

  def scheduled_datetime(nil, _, _, :same_day), do: "by 5pm"
  def scheduled_datetime(datetime, timezone, _, _), do: display_date_time(datetime, timezone)

  def display_template(%Version{}), do: "_version.html"
  def display_template(%MatchStateTransition{}), do: "_state_change.html"
  def display_template(%MatchStopStateTransition{}), do: "_state_change.html"
  def display_template(%HiddenMatch{}), do: "_driver_cancellation.html"

  def state_transition_title(%MatchStateTransition{}), do: "Match State Change"

  def state_transition_title(%MatchStopStateTransition{match_stop: %MatchStop{index: index}}),
    do: "Stop ##{index + 1} State Change"

  def display_email(nil), do: "Unknown"
  def display_email(%User{email: email}), do: email

  def display_change({_field, {:added, _change}}, :old), do: ""
  def display_change({field, {:added, value}}, :new), do: format_change(value, field)
  def display_change({field, {:changed, {_, old, _}}}, :old), do: format_change(old, field)
  def display_change({field, {:changed, {_, _, new}}}, :new), do: format_change(new, field)

  def display_change({_field, {:changed, fields}}, type) when is_map(fields) do
    Enum.map_join(fields, ",", fn {field, changes} ->
      title_case(field) <> ": " <> display_change({field, changes}, type)
    end)
  end

  def get_eta_time(%ETA{arrive_at: arrive_at} = _eta, tz \\ "UTC") do
    now = DateTime.utc_now()
    arrive_at = DateTime.from_naive!(arrive_at, "Etc/UTC")
    eta = DateTime.diff(arrive_at, now, :second)

    if eta > 0 do
      time =
        Timex.to_datetime(arrive_at, tz)
        |> Timex.format!("{0h12}:{0m}{am}")

      {time, display_minutes(eta)}
    else
      {"Now", nil}
    end
  end

  def display_time_allowance(sla, _match),
    do: "Duration: #{display_time_diff(sla.end_time, sla.start_time)}"

  def display_time_diff(d1, d2), do: DateTime.diff(d1, d2) |> display_minutes()

  def display_minutes(seconds),
    do: Timex.Duration.from_seconds(seconds) |> format_duration()

  defp format_duration(duration) do
    hours = Timex.Duration.to_hours(duration, truncate: true)

    minutes =
      Timex.Duration.to_minutes(duration, truncate: true)
      |> rem(60)

    if hours >= 1 do
      minutes =
        minutes
        |> to_string()
        |> String.pad_leading(2, "0")

      "#{hours}:#{minutes} hrs"
    else
      "#{minutes} mins"
    end
  end

  def display_photo_modal_link(field, label, image, stop_id \\ nil) do
    assigns = %{
      field: field,
      label:
        case image do
          nil -> "Add #{label}"
          _ -> "View #{label}"
        end,
      stop_id: stop_id
    }

    ~L"""
      <a
        onclick=""
        class="u__link--orange u-pointer"
        phx-click="show_modal_named"
        phx-value-liveview="MatchPhoto"
        phx-value-wide=false
        phx-value-field="<%= @field %>"
        phx-value-stop_id="<%= @stop_id %>"
      ><%= @label %></a>
    """
  end

  def any_stops_returned?(match) do
    Enum.any?(match.match_stops, &(&1.state in [:returned, :undeliverable]))
  end

  def format_sla_time(sla, time_field) do
    case Map.get(sla, time_field) do
      nil -> ""
      tmstmp -> Timex.format!(tmstmp, "{0h12}:{0m} {AM}")
    end
  end

  @price_fields [
    :amount_charged,
    :driver_total_pay,
    :driver_fees,
    :price_discount,
    :cancel_charge,
    :cancel_charge_driver_pay,
    :declared_value
  ]

  defp format_change(%Geo.Point{coordinates: coordinates}, _), do: format_coordinates(coordinates)
  defp format_change(nil, _), do: "(none)"
  defp format_change(value, _) when is_atom(value), do: title_case(value)
  defp format_change(%DateTime{} = value, _), do: display_date_time_utc(value)
  defp format_change(%NaiveDateTime{} = value, _), do: display_date_time_utc(value)
  defp format_change(value, field) when field in @price_fields, do: "$#{display_price(value)}"
  defp format_change(value, :service_level), do: service_level(value)
  defp format_change(value, :driver_cut), do: "#{value * 100}%"
  defp format_change(value, :vehicle_class), do: vehicle_class(value)
  defp format_change(%{file_name: file_name}, _) when not is_nil(file_name), do: "Image"

  defp format_change(value, :meta) do
    Jason.encode!(value)
  end

  defp format_change(value, _) when is_binary(value), do: value
  defp format_change(value, _field), do: inspect(value)

  defp get_driver_profile_photo(driver_id) do
    DriverDocuments.get_latest_driver_document(driver_id, "profile")
  end
end
