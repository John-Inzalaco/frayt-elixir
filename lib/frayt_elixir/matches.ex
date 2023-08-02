defmodule FraytElixir.Matches do
  alias Ecto.{Multi, Changeset}

  alias FraytElixir.{
    Accounts,
    MapDiff,
    Payments,
    Repo,
    Shipment,
    CustomContracts,
    CustomContracts.ContractFees,
    Contracts,
    Drivers
  }

  alias FraytElixir.GeocodedAddressHelper
  alias FraytElixirWeb.DisplayFunctions
  alias FraytElixir.Notifications.{DriverNotification, MatchNotifications, Slack}
  alias FraytElixir.TomTom.WaypointOptimization
  alias FraytElixir.Markets
  alias FraytElixir.Markets.Market

  alias Shipment.{
    Match,
    MatchStop,
    MatchStopItem,
    Address,
    VehicleClass,
    Pricing,
    ShipperMatchCoupon,
    MatchWorkflow,
    MatchState
  }

  alias FraytElixir.MatchSupervisor

  alias Accounts.Shipper
  alias FraytElixir.Convert
  alias FraytElixir.Shipment.Pricing
  alias FraytElixir.Webhooks.WebhookSupervisor
  alias FraytElixir.SLAs

  import Ecto.Query
  import FraytElixir.Guards

  @editable_states MatchState.editable_range()
  @charged_states MatchState.charged_range()
  @completed_states MatchState.completed_range()

  @new_match %Match{
    origin_address: nil,
    match_stops: [],
    tags: [],
    fees: [],
    shipper_match_coupon: nil,
    sender: nil,
    market: nil,
    contract: nil,
    shipper: nil
  }

  @type sizes :: %{total_volume: number(), total_weight: number(), longest_dimension: number()}

  @initial_total_sizes %{total_volume: 0, total_weight: 0, longest_dimension: 0}

  @spec calculate_total_sizes(Match.t()) :: sizes()
  def calculate_total_sizes(%Match{match_stops: stops}, load_only \\ false),
    do: Enum.reduce(stops, @initial_total_sizes, &sum_total_stop_sizes(&1, &2, load_only))

  @spec calculate_total_stop_sizes(MatchStop.t()) :: sizes()
  def calculate_total_stop_sizes(%MatchStop{} = stop),
    do: sum_total_stop_sizes(stop, @initial_total_sizes, false)

  def retrieve_distance(%Match{origin_address: address, match_stops: stops}) do
    stops = Enum.sort_by(stops, & &1.index, :asc)
    routes = build_route(address, stops)

    case Shipment.calculate_distance(routes) do
      {:ok, total, distances, duration} ->
        match_stops =
          stops
          |> Enum.with_index()
          |> Enum.map(fn {stop, index} ->
            %{
              id: stop.id,
              distance: distances |> Enum.at(index),
              radial_distance: distance_between_addresses(address, stop.destination_address)
            }
          end)

        attrs = %{
          total_distance: total,
          travel_duration: duration,
          match_stops: match_stops,
          optimized_stops: false
        }

        {:ok, attrs}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp distance_between_addresses(address1, address2) do
    distance = Geocalc.distance_between(address1.geo_location, address2.geo_location)

    Shipment.convert_to_miles(distance)
  end

  def optimize_stops(%Match{match_stops: stops}) when length(stops) > 49 do
    {:error, "You can't optimize more than 49 stops"}
  end

  def optimize_stops(%Match{optimized_stops: true}) do
    {:error, "These routes have already been optimized."}
  end

  def optimize_stops(%Match{match_stops: match_stops, origin_address: origin_addrs}) do
    # Adding origin as the first element of stops
    stops = [origin_addrs | match_stops]

    with({:ok, optimized_results} <- get_optimized_route(stops)) do
      %{
        "optimizedOrder" => optimized_order,
        "summary" => %{"legSummaries" => steps}
      } = optimized_results

      {total_distance, travel_duration} = get_total_distance_and_duration(steps)

      optimized_match_stops = build_optimized_stops(match_stops, optimized_order, steps)

      attrs = %{
        total_distance: total_distance,
        travel_duration: travel_duration,
        match_stops: optimized_match_stops,
        optimized_stops: true
      }

      {:ok, attrs}
    end
  end

  defp get_geo_loc(%Address{} = stop) do
    Map.get(stop, :geo_location, %{})
    |> Map.get(:coordinates)
  end

  defp get_geo_loc(stop) do
    Map.get(stop, :destination_address, %{})
    |> Map.get(:geo_location, %{})
    |> Map.get(:coordinates)
  end

  defp get_optimized_route(stops) do
    routes =
      Enum.reduce(stops, [], fn stop, acc ->
        geo_loc = get_geo_loc(stop)

        location = %{
          point: %{
            longitude: elem(geo_loc, 0),
            latitude: elem(geo_loc, 1)
          }
        }

        acc ++ [location]
      end)

    payload = %{
      waypoints: routes,
      options: %{
        outputExtensions: ["travelTimeInSeconds", "lengthInMeters"]
      }
    }

    WaypointOptimization.optimize_route(payload)
  end

  defp build_optimized_stops(match_stops, [_ | optimized_order], steps) do
    match_stops
    |> Enum.zip(optimized_order)
    |> Enum.map(fn {stop, optimized_index} ->
      distance =
        steps
        |> Enum.find(%{}, &(Map.get(&1, "destinationIndex") == optimized_index))
        |> Map.get("lengthInMeters", 0)
        |> Shipment.convert_to_miles()

      %{id: stop.id, index: optimized_index - 1, distance: distance}
    end)
  end

  defp get_total_distance_and_duration(steps) do
    %{distance: total_distance_meters, duration: travel_duration} =
      Enum.reduce(steps, %{distance: 0, duration: 0}, fn step, acc ->
        cur_distance = Map.get(step, "lengthInMeters", 0)
        cur_duration = Map.get(step, "travelTimeInSeconds", 0)

        %{
          distance: acc.distance + cur_distance,
          duration: acc.duration + cur_duration
        }
      end)

    total_distance = Shipment.convert_to_miles(total_distance_meters)

    {total_distance, travel_duration}
  end

  defp build_route(
         %{geo_location: %Geo.Point{coordinates: {origin_lng, origin_lat}}},
         stops
       ) do
    destinations =
      Enum.map(stops, fn %MatchStop{
                           destination_address: %Address{
                             geo_location: %Geo.Point{coordinates: {lng, lat}}
                           }
                         } ->
        {lat, lng}
      end)

    [{origin_lat, origin_lng} | destinations]
  end

  def convert_attrs_to_multi_stop(attrs, match \\ nil)

  def convert_attrs_to_multi_stop(%{stops: [_stop | _]} = attrs, _match), do: attrs

  def convert_attrs_to_multi_stop(attrs, match) do
    match_attrs =
      take_attrs(attrs,
        sender: [],
        self_sender: [],
        origin_address: [],
        origin_place_id: [],
        vehicle_class: [],
        service_level: [],
        pickup_notes: [],
        identifier: [],
        contract: [],
        autoselect_vehicle_class: [],
        admin_notes: [],
        network_operator_id: [],
        po: [:job_number],
        unload_method: [],
        pickup_at: [:scheduled_pickup, :pickup_date],
        dropoff_at: [
          :scheduled_dropoff,
          :dropoff_date
        ],
        coupon_code: [:coupon, :code],
        scheduled: [:scheduling],
        meta: [],
        signature_required: [],
        destination_photo_required: []
      )

    case convert_stop_attrs_to_multi_stop(attrs, match) do
      [] -> match_attrs
      stops -> Map.put(match_attrs, :stops, stops)
    end
  end

  defp convert_stop_attrs_to_multi_stop(attrs, match) do
    stop =
      (match || %{})
      |> Map.get(:match_stops, [])
      |> Enum.at(0, %{})

    items_attrs = convert_stop_item_attrs_to_multi_stop(attrs, stop)
    recipient_attrs = convert_recipient_attrs_to_multi_stop(attrs)
    optional_attrs = Map.take(stop, [:id])

    stop_attrs =
      attrs
      |> take_attrs(
        destination_address: [],
        destination_place_id: [],
        self_recipient: [],
        has_load_fee: [:load_fee, :load_unload],
        needs_pallet_jack: [],
        delivery_notes: [:dropoff_notes],
        tip_price: [:tip],
        identifier?: [:match_stop_identifier],
        signature_required: [],
        destination_photo_required: []
      )
      |> put_attr(:recipient, recipient_attrs)
      |> put_attr(:items, items_attrs)
      |> Map.merge(optional_attrs)

    if stop_attrs == %{} do
      []
    else
      [stop_attrs]
    end
  end

  defp convert_stop_item_attrs_to_multi_stop(attrs, stop) do
    case Map.fetch(attrs, :items) do
      {:ok, items} ->
        items

      :error ->
        item =
          stop
          |> Map.get(:items, [])
          |> Enum.at(0, %{})

        optional_attrs = Map.take(item, [:id])

        [
          attrs
          |> take_attrs(
            pieces: [],
            weight: [],
            declared_value: [],
            volume: [],
            description: [],
            width: [:dimensions_width],
            length: [:dimensions_length],
            height: [:dimensions_height],
            type: []
          )
          |> Map.merge(optional_attrs)
        ]
    end
  end

  defp convert_recipient_attrs_to_multi_stop(attrs) do
    recipient_attrs =
      take_attrs(attrs,
        name: [:recipient_name],
        email: [:recipient_email],
        phone_number: [:recipient_phone],
        notify: [:notify_recipient]
      )

    phone = Map.get(recipient_attrs, :phone_number)
    email = Map.get(recipient_attrs, :email)
    name = Map.get(recipient_attrs, :name)

    missing_notify? = not is_map_key(recipient_attrs, :notify)
    no_contact? = is_empty(phone) and is_empty(email)

    cond do
      no_contact? and is_empty(name) ->
        nil

      missing_notify? ->
        Map.put(recipient_attrs, :notify, not no_contact?)

      true ->
        recipient_attrs
    end
  end

  def duplicate_match(match, overrides \\ %{}, state \\ :pending)
      when state in [:pending, :inactive] do
    attrs =
      match
      |> attrs_from_match(overrides)
      |> Map.put(:state, state)

    create_estimate(attrs, match.shipper)
  end

  defp attrs_from_match(match, overrides) do
    allowed_fields = [
      :sender,
      :origin_address,
      :vehicle_class,
      :service_level,
      :pickup_notes,
      :po,
      :origin_photo_required,
      :bill_of_lading_required,
      :contract_id,
      :unload_method,
      :self_sender
    ]

    match
    |> Map.take(allowed_fields)
    |> Map.merge(overrides)
    |> Map.put(:optimize, match.optimized_stops)
    |> attrs_from_match_stops(match, overrides)
  end

  defp attrs_from_match_stops(attrs, %{match_stops: stops}, overrides) do
    allowed_fields = [
      :recipient,
      :destination_address,
      :has_load_fee,
      :needs_pallet_jack,
      :self_recipient,
      :index,
      :delivery_notes,
      :destination_photo_required,
      :signature_required
    ]

    stops_overrides = Map.get(overrides, :stops)

    stop_attrs = get_nested_attrs(stops, stops_overrides, allowed_fields, &attrs_from_items/3)

    Map.put(attrs, :stops, stop_attrs)
  end

  defp attrs_from_items(attrs, stop, overrides) do
    allowed_fields = [
      :width,
      :length,
      :height,
      :volume,
      :pieces,
      :weight,
      :description,
      :type,
      :barcode,
      :barcode_pickup_required,
      :barcode_delivery_required,
      :declared_value
    ]

    items_overrides = Map.get(overrides, :items)

    item_attrs = get_nested_attrs(stop.items, items_overrides, allowed_fields)

    Map.put(attrs, :items, item_attrs)
  end

  defp get_nested_attrs(records, overrides, allowed_fields, callback \\ nil) do
    Enum.map(records, fn record ->
      overrides = get_overrides(overrides, record.id)

      a =
        record
        |> Map.take(allowed_fields)
        |> Map.merge(overrides)

      if is_function(callback) do
        callback.(a, record, overrides)
      else
        a
      end
    end)
  end

  defp get_overrides(overrides, id) do
    case Enum.find(overrides || %{}, fn a -> Map.get(a, :id) == id end) do
      nil -> %{}
      overrides -> overrides
    end
  end

  def create_estimate(attrs, shipper \\ nil) do
    Multi.new()
    |> Multi.insert(:match, @new_match)
    |> update_match_changes(attrs, shipper)
    |> commit_match()
  end

  def update_estimate(match, attrs, shipper \\ nil)

  def update_estimate(%Match{state: :pending} = match, attrs, shipper) do
    Multi.new()
    |> Multi.run(:match, fn _repo, _changes ->
      {:ok, preload_match(match)}
    end)
    |> update_match_changes(attrs, shipper)
    |> commit_match()
  end

  def update_estimate(_match, _attrs, _shipper), do: {:error, :invalid_state}

  def update_and_authorize_match(match, attrs \\ %{}, shipper \\ nil, admin \\ nil)

  def update_and_authorize_match(%Match{state: state} = match, attrs, shipper, admin)
      when state not in @charged_states do
    attrs =
      attrs
      |> Map.put(:admin, admin)
      |> Map.put(:update_tolls?, true)

    Multi.new()
    |> Multi.run(:match, fn _repo, _changes ->
      {:ok, preload_match(match)}
    end)
    |> update_match_changes(attrs, shipper)
    |> authorize_changes()
    |> commit_match()
    |> flag_expensive_match()
  end

  def update_and_authorize_match(_match, _attrs, _shipper, _admin), do: {:error, :invalid_state}

  def create_match(attrs, shipper, admin),
    do: attrs |> Map.put(:admin, admin) |> create_match(shipper)

  def create_match(attrs, shipper),
    do:
      Multi.new()
      |> create_match_changes(attrs, shipper)
      |> commit_match()
      |> flag_expensive_match()

  def create_match_changes(multi, attrs, shipper, index \\ nil) do
    match_key = get_multi_key(:match, index)
    attrs = Map.put(attrs, :update_tolls?, true)

    multi
    |> Multi.insert(match_key, @new_match)
    |> update_match_changes(attrs, shipper, index)
    |> authorize_changes(shipper, index)
  end

  def update_match(match, attrs, admin \\ nil)

  def update_match(%Match{state: :pending}, _, _), do: {:error, :invalid_state}

  def update_match(match, attrs, admin) do
    Multi.new()
    |> Multi.run(:match, fn _repo, _changes ->
      {:ok, preload_match(match)}
    end)
    |> match_changes(attrs |> Map.put(:admin, admin))
    |> post_update_changes()
    |> commit_match()
  end

  def api_update_match(match, attrs) do
    Multi.new()
    |> Multi.run(:match, fn _repo, _changes ->
      {:ok, preload_match(match)}
    end)
    |> Multi.update(
      :api_update_match,
      Match.api_update_changeset(match, attrs)
    )
    |> match_changes(attrs)
    |> post_update_changes()
    |> commit_match()
  end

  def update_or_insert_stop(%Match{match_stops: stops} = match, stop_id, stop_attrs)
      when is_empty(stop_id),
      do:
        update_match(match, %{
          stops: Enum.map(stops, &%{id: &1.id}) ++ [stop_attrs]
        })

  def update_or_insert_stop(%Match{match_stops: stops} = match, stop_id, stop_attrs) do
    attrs = %{
      stops:
        Enum.map(stops, fn stop ->
          case stop.id do
            ^stop_id -> stop_attrs |> Map.put(:id, stop_id)
            id -> %{id: id}
          end
        end)
    }

    update_match(match, attrs)
  end

  def delete_stop(%Match{match_stops: stops} = match, stop_id) do
    attrs = %{
      stops:
        stops
        |> Enum.sort_by(& &1.index)
        |> Enum.filter(&(&1.id != stop_id))
        |> Enum.with_index()
        |> Enum.map(fn {stop, index} ->
          %{id: stop.id, index: index}
        end)
    }

    update_match(match, attrs)
  end

  def update_match_price(match, attrs \\ %{})

  def update_match_price(match = %Match{state: state}, attrs)
      when state in @editable_states do
    manual_price = Map.get(attrs, :manual_price, match.manual_price)

    Multi.new()
    |> Multi.run(:match, fn _repo, _changes -> {:ok, preload_match(match)} end)
    |> Multi.update(
      :match_overrides,
      Match.manual_pricing_changeset(
        match,
        case manual_price do
          true -> attrs
          false -> %{manual_price: false}
        end
      )
    )
    |> apply_coupon_changes(attrs)
    |> Multi.run(:calculate_match_metrics, fn _repo, %{update_match_coupon: match} ->
      {:ok, match}
    end)
    |> calc_toll(attrs, nil)
    |> match_pricing_changes()
    |> payout_changes()
    |> validate_changes()
    |> commit_match()
  end

  def update_match_price(_match, _attrs), do: {:error, :invalid_state}

  defp preload_match(match),
    do: Repo.preload(match, [:market, match_stops: [:items, :recipient, :destination_address]])

  def apply_cancel_charge(match, attrs \\ nil)

  def apply_cancel_charge(match, nil) do
    case Contracts.get_match_cancellation_pay_rule(match) do
      %{cancellation_percent: cpercent, driver_percent: dpercent} ->
        apply_cancel_charge(match, %{
          cancellation_percent: cpercent,
          driver_percent: dpercent
        })

      _ ->
        {:ok, match}
    end
  end

  def apply_cancel_charge(%Match{amount_charged: amount_charged} = match, %{
        cancellation_percent: cpercent,
        driver_percent: dpercent
      }) do
    cancel_charge = round(amount_charged * cpercent)

    apply_cancel_charge(match, %{
      cancel_charge: cancel_charge,
      cancel_charge_driver_pay: round(cancel_charge * dpercent)
    })
  end

  def apply_cancel_charge(match, %{cancellation_percent: _} = attrs),
    do: apply_cancel_charge(match, Map.put(attrs, :driver_percent, 0))

  def apply_cancel_charge(
        match,
        %{cancel_charge: _, cancel_charge_driver_pay: cancel_driver_pay} = attrs
      ) do
    cancel_driver_pay = if match.driver_id, do: cancel_driver_pay, else: nil
    attrs = Map.put(attrs, :cancel_charge_driver_pay, cancel_driver_pay)

    Multi.new()
    |> Multi.update(:match, Match.cancel_charge_changeset(match, attrs))
    |> Repo.transaction()
    |> case do
      {:ok, %{match: match}} -> {:ok, match}
      e -> e
    end
  end

  def create_batch_match_changes(multi, attrs, shipper, index) do
    match_key = get_multi_key(:match, index)

    multi
    |> Multi.insert(match_key, @new_match)
    |> match_changes(attrs, shipper, index)
  end

  def match_changes(multi, attrs \\ %{}, shipper \\ nil, index \\ nil) do
    multi
    |> update_match_changes(attrs, shipper, index)
    |> validate_changes(index)
  end

  def handle_unaccepted_preferred_driver_match(%{preferred_driver_id: nil}), do: :ok

  def handle_unaccepted_preferred_driver_match(
        %{preferred_driver_id: preferred_driver_id} = match
      ) do
    with driver <- Drivers.get_driver!(preferred_driver_id),
         {:ok, _match} <- update_match(match, %{preferred_driver_id: nil}) do
      MatchNotifications.send_match_status_email(
        match,
        status_type: :preferred_driver_unassigned,
        driver: driver
      )
    end
  end

  defp validate_changes(multi, index \\ nil) do
    payout_key = get_multi_key(:calculate_match_payout, index)
    validate_key = get_multi_key(:validate_match, index)

    multi
    |> Multi.update(validate_key, fn %{^payout_key => match} ->
      Match.validation_changeset(match)
    end)
  end

  defp authorize_changes(multi, shipper \\ nil, index \\ nil) do
    authorize_key = get_multi_key(:authorize_match, index)
    calculate_key = get_multi_key(:calculate_match_payout, index)

    multi
    |> Multi.run(authorize_key, fn repo, %{^calculate_key => match} ->
      attrs =
        case shipper do
          %Shipper{id: shipper_id} -> %{shipper_id: shipper_id}
          _ -> %{}
        end

      with {:ok, match} <-
             match
             |> Changeset.cast(attrs, [:shipper_id])
             |> repo.update(),
           {:ok, match} <-
             match
             |> Repo.preload(
               [:origin_address, shipper: [:credit_card, location: :company], tags: [], fees: []],
               force: true
             )
             |> Match.validation_changeset()
             |> Changeset.apply_action(:update),
           {:ok, _coupon} <- Pricing.validate_match_coupon(match),
           {:ok, _payment_transaction} <-
             Payments.authorize_match(match, match.amount_charged) do
        MatchWorkflow.activate_match(match)
        WebhookSupervisor.start_match_webhook_sender(match)
        {:ok, Shipment.get_match(match.id)}
      end
    end)
  end

  defp update_match_changes(multi, attrs, shipper, index \\ nil) do
    update_key = get_multi_key(:update_match, index)
    override_key = get_multi_key(:match_overrides, index)
    match_key = get_multi_key(:match, index)

    multi
    |> Multi.update(update_key, fn %{^match_key => match} ->
      shipper = (shipper || match.shipper) |> Repo.preload(:user)

      company_settings = Shipment.get_company_settings(shipper)

      case get_contract(match, attrs, company_settings) do
        {:ok, contract} ->
          attrs =
            attrs
            |> Map.put(:shortcode, Shipment.get_match_shortcode(match))
            |> build_stops(match.match_stops, company_settings)
            |> put_company_setting(:origin_photo_required, match, company_settings)
            |> put_schedule_setting(match, contract)

          match
          |> Match.changeset(attrs)
          |> Changeset.put_assoc(:contract, contract)
          |> Changeset.put_assoc(:shipper, shipper)

        {:error, :invalid_contract} ->
          Changeset.change(match, %{}) |> Changeset.add_error(:contract_id, "is invalid")
      end
    end)
    |> Multi.update(override_key, fn %{^update_key => match} ->
      attrs = %{
        match_stops:
          match.match_stops
          |> Enum.map(fn stop ->
            case match.unload_method do
              :lift_gate ->
                has_pallets =
                  stop
                  |> Repo.preload(:items)
                  |> Map.get(:items)
                  |> Enum.any?(&(&1.type == :pallet))

                %{
                  id: stop.id,
                  needs_pallet_jack: has_pallets || stop.needs_pallet_jack
                }

              _ ->
                %{
                  id: stop.id
                }
            end
          end)
      }

      Match.override_changeset(match, attrs)
    end)
    |> apply_coupon_changes(attrs, index)
    |> match_metrics_changes(attrs, index)
    |> calc_toll(attrs, index)
    |> match_pricing_changes(index)
    |> rate_driver_changes(attrs, index)
    |> payout_changes(index)
  end

  defp payout_changes(multi, index \\ nil) do
    pricing_key = get_multi_key(:calculate_match_pricing, index)
    payout_key = get_multi_key(:calculate_match_payout, index)
    recharge_key = get_multi_key(:recharge_updated_match, index)

    multi
    |> Multi.update(payout_key, fn %{^pricing_key => match} ->
      {total_price, price_discount} = Pricing.total_price(match)
      driver_total_pay = Pricing.calculate_driver_total_pay(match)

      Match.payout_changeset(match, %{
        amount_charged: total_price,
        driver_total_pay: driver_total_pay,
        price_discount: price_discount
      })
    end)
    |> Multi.run(recharge_key, fn _repo, %{^payout_key => match, ^pricing_key => old_match} ->
      total_driver_pay_changed? = match.driver_total_pay != old_match.driver_total_pay
      amount_charged_changed? = match.amount_charged != old_match.amount_charged

      if match.state in [:completed, :charged] and
           (total_driver_pay_changed? or amount_charged_changed?) do
        amount_paid_to_driver = Payments.sum_driver_paid_amount(match)

        if match.driver_total_pay < amount_paid_to_driver do
          changeset =
            match
            |> Changeset.change()
            |> Changeset.add_error(
              :driver_total_pay,
              "The driver transfers cannot be decreased"
            )

          {:error, changeset}
        else
          MatchWorkflow.recharge_match(match)
        end
      else
        {:ok, nil}
      end
    end)
  end

  defp post_update_changes(multi) do
    multi
    |> Multi.run(:verify_active_match, fn _repo, %{calculate_match_payout: match} ->
      case match do
        %Match{state: :scheduled} -> MatchWorkflow.activate_match(match)
        _ -> {:ok, match}
      end
    end)
    |> Multi.run(:triggered_actions, fn _repo, %{verify_active_match: match} = changes ->
      orig_match = get_orig_match(changes)

      scheduling_changed? =
        MapDiff.has_changed(orig_match, match, [:pickup_at, :dropoff_at, :scheduled])

      address_changed? = addresses_have_changed?(orig_match, match)

      maybe_notify_drivers(orig_match, match)

      if scheduling_changed? or address_changed? do
        SLAs.calculate_match_slas(match, for: [:frayt, :driver])
      end

      if orig_match.rating !== match.rating do
        Task.start_link(fn ->
          Drivers.update_driver_metrics(match.driver)
        end)
      end

      {:ok, match}
    end)
  end

  defp maybe_notify_drivers(original_match, match) do
    scheduling_changed? =
      MapDiff.has_changed(original_match, match, [:pickup_at, :dropoff_at, :scheduled])

    platform_or_driver_changed? =
      MapDiff.has_changed(original_match, match, [:platform, :preferred_driver_id])

    cond do
      active_deliver_pro_match?(original_match) and platform_or_driver_changed? ->
        notify_original_preferred_driver(original_match)
        maybe_activate_match(match)

      match.state == :assigning_driver and scheduling_changed? ->
        MatchSupervisor.restart_unaccepted_match_notifier(match)

      true ->
        :ok
    end
  end

  defp notify_original_preferred_driver(%{preferred_driver_id: nil} = _match), do: :ok

  defp notify_original_preferred_driver(%{preferred_driver_id: preferred_driver_id} = match) do
    preferred_driver_id
    |> Drivers.get_driver()
    |> DriverNotification.send_removed_from_match_notification(match)
  end

  defp maybe_activate_match(%{platform: :deliver_pro, preferred_driver_id: nil}), do: :ok

  defp maybe_activate_match(match), do: MatchWorkflow.activate_match(match)

  defp match_pricing_changes(multi, index \\ nil) do
    toll_key = get_multi_key(:calc_toll, index)

    pricing_key = get_multi_key(:calculate_match_pricing, index)

    Multi.update(multi, pricing_key, fn %{^toll_key => match} = changes ->
      change_pricing(match, changes)
    end)
  end

  defp change_pricing(%Match{manual_price: false, state: state} = match, changes)
       when state not in @charged_states do
    match =
      case changes do
        %{apply_coupon: %ShipperMatchCoupon{coupon: coupon} = match_coupon} ->
          %{match | coupon: coupon, shipper_match_coupon: match_coupon}

        _ ->
          match
      end

    Pricing.calculate_pricing(match)
  end

  defp change_pricing(match, _changes) do
    Match.pricing_changeset(match, %{
      driver_fees: ContractFees.calculate_driver_fees(match)
    })
  end

  defp apply_coupon_changes(multi, attrs, index \\ nil)

  defp apply_coupon_changes(multi, %{coupon_code: code}, index) do
    override_key = get_multi_key(:match_overrides, index)
    coupon_key = get_multi_key(:update_match_coupon, index)

    multi
    |> Multi.insert_or_update(coupon_key, fn %{^override_key => match} ->
      Pricing.apply_coupon_changeset(match, code)
    end)
  end

  defp apply_coupon_changes(multi, _, index) do
    override_key = get_multi_key(:match_overrides, index)
    coupon_key = get_multi_key(:update_match_coupon, index)

    multi
    |> Multi.run(coupon_key, fn _repo, %{^override_key => match} ->
      {:ok, match}
    end)
  end

  defp match_metrics_changes(multi, attrs, index) do
    update_key = get_multi_key(:update_match_coupon, index)
    metrics_key = get_multi_key(:calculate_match_metrics, index)

    Multi.update(multi, metrics_key, fn %{^update_key => match} = changes ->
      market = Markets.find_market_by_zip(match.origin_address.zip)

      logistics_attrs = get_logistics_attrs(match, attrs)

      metric_attrs =
        %{
          markup: (market && market.markup) || 1.0,
          market: market,
          timezone: GeocodedAddressHelper.get_timezone(match),
          service_level: Map.get(attrs, :service_level, match.service_level),
          optimize: Map.get(attrs, :optimize),
          admin: Map.get(attrs, :admin)
        }
        |> Map.merge(logistics_attrs)

      orig_match = get_orig_match(changes, index)

      update_distance_metrics(match, metric_attrs, addresses_have_changed?(orig_match, match))
    end)
  end

  defp get_logistics_attrs(match, attrs) do
    user = match.shipper && match.shipper.user
    settings = Shipment.get_company_settings(match.shipper)
    sizes = calculate_total_sizes(match)

    autoselect_vehicle_class =
      Map.get(attrs, :autoselect_vehicle_class, settings.autoselect_vehicle_class)

    vehicle_class =
      attrs
      |> Map.get(:vehicle_class, match.vehicle_class)
      |> get_vehicle_class(autoselect_vehicle_class, sizes, user)

    unload_method =
      attrs |> Map.get(:unload_method, match.unload_method) |> get_unload_method(vehicle_class)

    %{
      total_weight: Float.round(sizes.total_weight * 1.0) |> trunc(),
      total_volume: sizes.total_volume,
      vehicle_class: vehicle_class,
      unload_method: unload_method
    }
  end

  defp get_vehicle_class(vehicle_class, autoselect_enabled?, sizes, user) do
    strict_autoselect? = FunWithFlags.enabled?(:strict_autoselect_vehicle_class, for: user)
    should_autoselect? = strict_autoselect? or is_nil(vehicle_class)

    if autoselect_enabled? and should_autoselect? do
      smallest_vehicle_class_for_cargo(sizes)
    else
      vehicle_class
    end
  end

  defp smallest_vehicle_class_for_cargo(sizes) do
    Enum.max([
      VehicleClass.get_vehicle_by_volume(sizes.total_volume),
      VehicleClass.get_vehicle_by_weight(sizes.total_weight),
      VehicleClass.get_vehicle_by_dimensions(sizes.longest_dimension)
    ])
  end

  defp get_unload_method(unload_method, vehicle_class) do
    case vehicle_class do
      4 -> unload_method || :lift_gate
      _ -> nil
    end
  end

  defp calc_toll(multi, attrs, index) do
    update_key = get_multi_key(:calculate_match_metrics, index)
    toll_key = get_multi_key(:calc_toll, index)

    Multi.update(multi, toll_key, fn %{^update_key => match} = changes ->
      orig_match = get_orig_match(changes, index)

      tolls_changed? =
        market_has_tolls(match.market) &&
          (match.market_id != orig_match.market_id ||
             addresses_have_changed?(orig_match, match) ||
             not is_nil(attrs[:update_tolls?]))

      can_update_toll? = match.state not in [:pending, :inactive] or attrs[:update_tolls?]

      if tolls_changed? && can_update_toll? && CustomContracts.include_tolls?(match) do
        {:ok, updated_tolls} = Pricing.calculate_expected_toll(match)
        Changeset.change(match, expected_toll: updated_tolls)
      else
        Changeset.change(match)
      end
    end)
  end

  defp update_distance_metrics(match, attrs, changed_addresses?) do
    case get_distance_metrics(match, attrs, changed_addresses?) do
      {:ok, distance_attrs} ->
        attrs = Map.merge(attrs, distance_attrs)
        Match.metrics_changeset(match, attrs)

      {:error, %HTTPoison.Error{reason: :checkout_timeout}} ->
        Changeset.change(match, %{})
        |> Changeset.add_error(
          :match_stops,
          "Unable to calculate distance due to timeout."
        )

      {:error, _status, reason} ->
        Changeset.change(match, %{}) |> Changeset.add_error(:match_stops, reason)

      {:error, reason} ->
        Changeset.change(match, %{}) |> Changeset.add_error(:match_stops, reason)
    end
  end

  def get_distance_metrics(match, attrs, changed_addresses?) do
    stop_count = Enum.count(match.match_stops)

    optimize_stops? = attrs[:optimize] == true and !match.optimized_stops and stop_count > 1

    cond do
      optimize_stops? -> optimize_stops(match)
      changed_addresses? -> retrieve_distance(match)
      true -> {:ok, %{}}
    end
  end

  defp rate_driver_changes(multi, %{rating: rating} = attrs, index) when not is_nil(rating) do
    pricing_key = get_multi_key(:calculate_match_pricing, index)
    rating_key = get_multi_key(:rate_driver, index)

    Multi.update(multi, rating_key, fn %{^pricing_key => match} ->
      rate_driver_update(match, attrs)
    end)
  end

  defp rate_driver_changes(multi, _, _), do: multi

  defp rate_driver_update(%Match{driver: driver} = match, _attrs) when is_nil(driver),
    do: no_changeset(match) |> Ecto.Changeset.add_error(:match, "has no driver to rate")

  defp rate_driver_update(%Match{state: state} = match, _attrs)
       when state not in @completed_states,
       do: no_changeset(match) |> Ecto.Changeset.add_error(:match, "is not completed")

  defp rate_driver_update(match, attrs), do: Match.rate_driver_changeset(match, attrs)

  defp put_company_setting(attrs, key, record, settings),
    do: update_attr(attrs, key, record, Map.get(settings, key))

  defp put_schedule_setting(attrs, %Match{state: :pending} = match, contract) do
    pickup_at = Map.get(attrs, :pickup_at, match.pickup_at)

    scheduled =
      case Map.get(attrs, :scheduled, match.scheduled) do
        nil -> not is_nil(pickup_at)
        s -> s
      end

    attrs
    |> Map.put(:scheduled, scheduled)
    |> maybe_auto_configure_dropoff_at(contract, pickup_at)
  end

  defp put_schedule_setting(attrs, _match, _contract), do: attrs

  defp maybe_auto_configure_dropoff_at(attrs, nil, _), do: attrs

  defp maybe_auto_configure_dropoff_at(attrs, contract, pickup_at) when is_binary(pickup_at) do
    case DateTime.from_iso8601(pickup_at) do
      {:ok, pickup_at, _} -> maybe_auto_configure_dropoff_at(attrs, contract, pickup_at)
      _ -> attrs
    end
  end

  defp maybe_auto_configure_dropoff_at(attrs, contract, pickup_at) do
    with {:ok, true} <- CustomContracts.get_auto_configure_dropoff_at(contract),
         {:ok, time} <- CustomContracts.get_auto_dropoff_at_time(contract) do
      pickup_at = pickup_at || Timex.now() |> Timex.shift(hours: 1)

      # since we schedule out 1 hour, we should reduce the gap between pickup and dropoff by 1 hour

      attrs
      |> Map.put(:pickup_at, pickup_at)
      |> Map.put(:scheduled, true)
      |> Map.put(:dropoff_at, pickup_at |> Timex.shift(seconds: time - 60 * 60))
    else
      _ ->
        attrs
    end
  end

  defp update_attr(attrs, key, record, default) do
    attrs
    |> Map.put(
      key,
      Map.get(
        attrs,
        key,
        case Map.get(record, key) do
          nil -> default
          setting -> setting
        end
      )
    )
  end

  def build_stops(%{stops: stops_attrs} = match_attrs, stops, company_settings) do
    match_attrs
    |> Map.put(
      :match_stops,
      stops_attrs
      |> Enum.with_index()
      |> Enum.map(fn {stop, index} ->
        case stop do
          %MatchStop{} ->
            stop

          attrs ->
            stop_id = Map.get(attrs, :id)
            stop = Enum.find(stops, &(&1.id == stop_id)) || %{}

            attrs
            |> update_attr(:index, stop, index)
            |> build_stop(stop, company_settings)
        end
      end)
    )
    |> Map.delete(:stops)
  end

  def build_stops(attrs, _, _), do: attrs

  def get_en_route_matches(repo \\ Repo) do
    Match
    |> join(:left, [m], s in MatchStop, as: :stop, on: m.id == s.match_id and s.state == :en_route)
    |> where(
      [m, stop: s],
      m.state in ^MatchState.en_route_range() or (m.state == :picked_up and s.state == :en_route)
    )
    |> where([m], not is_nil(m.driver_id))
    |> group_by([m], m.id)
    |> preload([
      :eta,
      [match_stops: [:destination_address, :eta]],
      :origin_address,
      driver: :current_location
    ])
    |> repo.all()
  end

  def get_next_location(%Match{state: state} = match)
      when state in [:en_route_to_pickup, :en_route_to_return],
      do: {:ok, match}

  def get_next_location(%Match{state: :picked_up} = match) do
    stop =
      match.match_stops
      |> Enum.filter(fn stop -> stop.state == :en_route end)
      |> List.last()

    case stop do
      nil -> {:error, "Match state is :picked_up and there are no en route stops"}
      _ -> {:ok, stop}
    end
  end

  def get_next_location(match), do: {:error, "Match state #{match.state} is not routable"}

  defp build_stop(attrs, stop, company_settings),
    do:
      attrs
      |> put_self_recipient()
      |> put_company_setting(:destination_photo_required, stop, company_settings)
      |> put_company_setting(:signature_required, stop, company_settings)
      |> build_items(Map.get(stop, :items, []))

  defp build_items(%{items: items_attrs} = stop_attrs, items) do
    stop_attrs
    |> Map.put(
      :items,
      Enum.map(items_attrs, fn attrs ->
        item_id = Map.get(attrs, :id)
        item = Enum.find(items, &(&1.id == item_id)) || %{}
        build_item(attrs, item)
      end)
    )
  end

  defp build_items(attrs, []), do: attrs |> Map.put(:items, [])
  defp build_items(attrs, _items), do: attrs

  defp build_item(%{type: type} = attrs, _item) when type in [:pallet, "pallet"],
    do: Map.merge(attrs, %{width: 48, length: 48, height: 40, volume: 92_160})

  defp build_item(attrs, %MatchStopItem{type: :pallet}) when not is_map_key(attrs, :type),
    do: attrs |> Map.put(:type, :pallet) |> build_item(nil)

  defp build_item(%{volume: volume} = attrs, _item) when not is_empty(volume), do: attrs

  defp build_item(%{width: width, length: length, height: height} = attrs, _item)
       when not is_empty(width) and not is_empty(length) and not is_empty(height),
       do:
         attrs
         |> Map.put(
           :volume,
           Convert.to_integer(width, 0) * Convert.to_integer(length, 0) *
             Convert.to_integer(height, 0)
         )

  defp build_item(attrs, %MatchStopItem{width: width, length: length, height: height})
       when not is_nil(width) and not is_nil(length) and not is_nil(height),
       do:
         %{width: width, length: length, height: height}
         |> Map.merge(attrs)
         |> build_item(nil)

  defp build_item(attrs, _item), do: attrs

  defp put_self_recipient(%{self_recipient: _} = attrs), do: attrs

  defp put_self_recipient(%{recipient: %{}} = attrs),
    do: attrs |> Map.put(:self_recipient, false)

  defp put_self_recipient(attrs), do: attrs

  defp get_contract(_match, attrs, %{id: company_id})
       when is_map_key(attrs, :contract) or is_map_key(attrs, :contract_id) do
    contract =
      case attrs do
        %{contract_id: contract_id} when not is_empty(contract_id) ->
          Contracts.get_company_contract(contract_id, company_id) || :error

        %{contract: key} when not is_empty(key) ->
          #  TODO: DEM-421 5/27/22 Once OR has fixed the contracts on their end, reneable this
          # Contracts.get_company_contract_by_key(key, company_id) || :error
          Contracts.get_company_contract_by_key(key, company_id)

        _ ->
          nil
      end

    case contract do
      :error -> {:error, :invalid_contract}
      contract -> {:ok, contract}
    end
  end

  defp get_contract(%Match{state: :pending, contract_id: nil}, _attrs, %{
         default_contract_id: contract_id,
         id: company_id
       })
       when not is_nil(contract_id),
       do: {:ok, Contracts.get_company_contract(contract_id, company_id)}

  defp get_contract(%Match{contract: contract}, _attrs, _company_settings), do: {:ok, contract}

  defp sum_total_stop_sizes(
         %MatchStop{items: items, has_load_fee: load_required},
         acc,
         load_only
       )
       when not load_only or load_required,
       do: Enum.reduce(items, acc, &sum_total_stop_item_size/2)

  defp sum_total_stop_sizes(_, acc, _), do: acc

  defp sum_total_stop_item_size(
         item,
         acc
       ) do
    %MatchStopItem{
      pieces: pieces,
      volume: volume,
      weight: weight
    } = item

    %{
      total_volume: acc.total_volume + volume * pieces,
      total_weight: acc.total_weight + pieces * weight,
      longest_dimension:
        Enum.max([
          acc.longest_dimension,
          item.width,
          item.length,
          item.height
        ])
    }
  end

  defp no_changeset(thing), do: Changeset.change(thing, %{})

  defp commit_match(multi) do
    try do
      case Repo.transaction(multi) do
        {:ok, %{match: %Match{id: id}}} -> {:ok, Shipment.get_match(id)}
        {:ok, %{calculate_match_payout: %Match{id: id}}} -> {:ok, Shipment.get_match(id)}
        error -> error
      end
    rescue
      Ecto.StaleEntryError -> {:error, "Data is out of sync. Please refresh page and try again."}
    end
  end

  defp put_attr(attrs, _key, value)
       when value == %{} or value == [] or value == [%{}] or is_nil(value),
       do: attrs

  defp put_attr(attrs, key, value), do: Map.put(attrs, key, value)

  defp take_attrs(attrs, keys),
    do:
      keys
      |> Enum.map(&take_attr(attrs, &1))
      |> Enum.filter(& &1)
      |> Enum.map(fn {key, {:ok, value}} -> {key, value} end)
      |> Enum.into(%{})

  defp take_attr(attrs, {key, fallback_keys}) do
    skey = Atom.to_string(key)

    {key, keys} =
      if String.ends_with?(skey, "?") do
        {skey |> String.slice(0..-2) |> String.to_atom(), fallback_keys}
      else
        {key, [key] ++ fallback_keys}
      end

    keys
    |> Enum.map(&{key, Map.fetch(attrs, &1)})
    |> Enum.find(fn {_, value} ->
      case value do
        {:ok, _} -> true
        _ -> false
      end
    end)
  end

  defp get_multi_key(key, nil), do: key

  defp get_multi_key(key, index), do: "#{key}_#{index}"

  defp get_orig_match(changes, index \\ nil),
    do:
      changes
      |> Map.get(
        get_multi_key(:orig_match, index),
        Map.get(changes, get_multi_key(:match, index))
      )

  defp addresses_have_changed?(orig_match, match),
    do:
      MapDiff.has_changed(orig_match, match,
        match_stops: nil,
        match_stops: :destination_address,
        origin_address: nil,
        origin_address: []
      )

  defp market_has_tolls(%Market{calculate_tolls: calculate_tolls}), do: calculate_tolls
  defp market_has_tolls(_), do: false

  defp flag_expensive_match({:ok, %Match{amount_charged: amount_charged} = match} = result)
       when amount_charged >= 500_00 do
    Slack.send_payment_message(
      match,
      "was placed for $#{DisplayFunctions.format_price(amount_charged)} and has been flagged for suspicious activity.",
      :warning
    )

    result
  end

  defp flag_expensive_match(result), do: result

  def count_completed_matches_in_month(id, user_type) when user_type in [:shipper, :driver] do
    Match
    |> where([m], m.state == :completed)
    |> maybe_where_shipper(id, user_type)
    |> maybe_where_driver(id, user_type)
    |> where([m], m.updated_at >= fragment("date_trunc('month', current_timestamp)"))
    |> select([m], count(m.id))
    |> Repo.one()
  end

  defp maybe_where_shipper(query, _id, :driver), do: query
  defp maybe_where_shipper(query, id, :shipper), do: where(query, [m], m.shipper_id == ^id)

  defp maybe_where_driver(query, _id, :shipper), do: query
  defp maybe_where_driver(query, id, :driver), do: where(query, [m], m.driver_id == ^id)

  defp active_deliver_pro_match?(match) do
    match.platform == :deliver_pro and match.state == :assigning_driver
  end
end
