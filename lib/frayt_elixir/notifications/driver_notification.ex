defmodule FraytElixir.Notifications.DriverNotification do
  alias FraytElixir.Shipment
  alias FraytElixir.Shipment.{DeliveryBatch, Match, Address}
  alias FraytElixir.Accounts
  alias FraytElixir.Accounts.{DriverSchedule, Location, Schedule, Shipper}
  alias FraytElixir.Drivers
  alias FraytElixir.Drivers.{Driver, DriverLocation, Vehicle, DriverState}
  alias FraytElixir.Devices.DriverDevice
  alias FraytElixir.Notifications
  alias FraytElixir.Notifications.SentNotification
  alias Ecto.Association.NotLoaded
  alias FraytElixirWeb.DisplayFunctions

  alias FraytElixir.Repo
  alias FraytElixir.Email
  alias FraytElixir.Mailer
  alias Ecto.Multi

  import Geo.PostGIS

  import Ecto.Query

  import FraytElixir.DistanceConversion

  @active_states DriverState.active_states()

  def send_available_match_notification(match) do
    sent_notifications =
      from(driver in Driver,
        where: driver.id == ^match.preferred_driver_id,
        select: %{
          driver_id: fragment("cast(? as varchar)", driver.id)
        }
      )
      |> exclude_notified_drivers(match)
      |> send_notifications(match)

    {:ok, sent_notifications}
  end

  def send_available_match_notifications(
        match,
        radius,
        prev_radius \\ 0,
        exclude_notified \\ true
      )

  def send_available_match_notifications(
        %Match{origin_address: %NotLoaded{}} = match,
        radius,
        prev_radius,
        exclude_notified
      ),
      do:
        match
        |> Repo.preload([:origin_address])
        |> send_available_match_notifications(radius, prev_radius, exclude_notified)

  def send_available_match_notifications(
        %Match{
          origin_address: %Address{}
        } = match,
        radius,
        prev_radius,
        exclude_notified
      ) do
    prev_radius_in_meters = miles_to_meters(prev_radius)
    radius_in_meters = miles_to_meters(radius)

    sent =
      find_drivers_in_range_query(match, radius_in_meters, prev_radius_in_meters)
      |> Drivers.filter_hidden_customers(:all, match)
      |> exclude_notified_drivers(match, exclude_notified)
      |> send_notifications(match)

    {:ok, sent}
  end

  def send_fleet_opportunity_notifications(
        %Schedule{location: %NotLoaded{}} = schedule,
        radius,
        exclude_notified
      ),
      do:
        schedule
        |> Repo.preload(location: [:address])
        |> send_fleet_opportunity_notifications(radius, exclude_notified)

  def send_fleet_opportunity_notifications(
        %Schedule{location: %{address: %NotLoaded{}}} = schedule,
        radius,
        exclude_notified
      ),
      do:
        schedule
        |> Repo.preload(location: [:address])
        |> send_fleet_opportunity_notifications(radius, exclude_notified)

  def send_fleet_opportunity_notifications(
        %Schedule{
          location: %Location{address: %Address{}} = location
        } = schedule,
        radius,
        exclude_notified
      ) do
    radius_in_meters = miles_to_meters(radius)

    sent =
      find_drivers_in_range_query(schedule, radius_in_meters)
      |> Drivers.filter_hidden_customers(:company, location.company_id)
      |> exclude_notified_drivers(schedule, exclude_notified)
      |> exclude_decided_drivers(schedule)
      |> send_fleet_opt_notifications(schedule)

    {:ok, sent}
  end

  def send_available_batch_notifications(%DeliveryBatch{address: %NotLoaded{}} = batch, radius),
    do:
      batch
      |> Repo.preload([:address, :location])
      |> send_available_batch_notifications(radius)

  def send_available_batch_notifications(%DeliveryBatch{location: %NotLoaded{}} = batch, radius),
    do:
      batch
      |> Repo.preload([:address, :location])
      |> send_available_batch_notifications(radius)

  def send_available_batch_notifications(
        %DeliveryBatch{address: %Address{}} = batch,
        radius
      ) do
    radius_in_meters = miles_to_meters(radius)

    sent =
      find_drivers_in_range_query(batch, radius_in_meters)
      |> exclude_notified_drivers(batch)
      |> send_batch_notifications(batch)

    {:ok, sent}
  end

  defp find_drivers_in_range_query(
         %Match{
           origin_address: %Address{geo_location: match_location},
           vehicle_class: vehicle_class,
           shipper: %Shipper{},
           match_stops: stops,
           unload_method: unload_method
         },
         radius_in_meters,
         prev_radius_in_meters
       ) do
    from(driver in Driver,
      as: :driver,
      join: v in Vehicle,
      as: :vehicle,
      on: driver.id == v.driver_id,
      join: current_loc in DriverLocation,
      on:
        driver.current_location_id == current_loc.id and
          driver.current_location_inserted_at == current_loc.inserted_at,
      where:
        st_dwithin_in_meters(current_loc.geo_location, ^match_location, ^radius_in_meters) and
          not st_dwithin_in_meters(
            current_loc.geo_location,
            ^match_location,
            ^prev_radius_in_meters
          ) and driver.state in ^@active_states,
      select: %{
        driver_id: fragment("distinct on(?) cast(? as varchar)", driver.id, driver.id)
      }
    )
    |> where(^pallet_jack_query(stops))
    |> where(^lift_gate_query(unload_method))
    |> where(^vehicle_class_query(vehicle_class))
  end

  defp find_drivers_in_range_query(
         %Schedule{
           id: schedule_id,
           location: %Location{address: %Address{geo_location: schedule_location}}
         },
         radius_in_meters
       ) do
    from(driver in Driver,
      as: :driver,
      join: v in Vehicle,
      on: driver.id == v.driver_id,
      join: current_loc in DriverLocation,
      on:
        driver.current_location_id == current_loc.id and
          driver.current_location_inserted_at == current_loc.inserted_at,
      left_join: ds in DriverSchedule,
      on: ds.schedule_id == ^schedule_id and ds.driver_id == driver.id,
      where:
        driver.fleet_opt_state == "opted_in" and is_nil(ds.driver_id) and
          st_dwithin_in_meters(current_loc.geo_location, ^schedule_location, ^radius_in_meters) and
          driver.state in ^@active_states,
      select: %{
        driver_id: fragment("distinct on(?) cast(? as varchar)", driver.id, driver.id)
      }
    )
  end

  defp find_drivers_in_range_query(
         %DeliveryBatch{location: location, address: %Address{geo_location: batch_location}},
         radius_in_meters
       ) do
    query =
      from(driver in Driver,
        as: :driver,
        join: current_loc in DriverLocation,
        on:
          driver.current_location_id == current_loc.id and
            driver.current_location_inserted_at == current_loc.inserted_at,
        where:
          st_dwithin_in_meters(current_loc.geo_location, ^batch_location, ^radius_in_meters) and
            driver.state in ^@active_states,
        select: %{
          driver_id: fragment("distinct on(?) cast(? as varchar)", driver.id, driver.id)
        }
      )

    case location do
      nil ->
        query

      location ->
        %{id: schedule_id} = Accounts.get_schedule_for_location(location)

        from(driver in query,
          join: ds in DriverSchedule,
          on: ds.schedule_id == ^schedule_id and ds.driver_id == driver.id
        )
    end
  end

  defp pallet_jack_query(stops) do
    any_need_pallet_jack? = Enum.any?(stops, & &1.needs_pallet_jack)

    if any_need_pallet_jack? do
      dynamic([vehicle: v], v.pallet_jack == true)
    else
      true
    end
  end

  defp lift_gate_query(unload_method) do
    if unload_method == :lift_gate do
      dynamic([vehicle: v], v.lift_gate == true)
    else
      true
    end
  end

  defp vehicle_class_query(vehicle_class) do
    box_truck_class = Shipment.vehicle_class(:box_truck)

    if box_truck_class == vehicle_class do
      dynamic([vehicle: v], v.vehicle_class == 4)
    else
      dynamic(
        [vehicle: v],
        v.vehicle_class >= ^vehicle_class and v.vehicle_class < ^box_truck_class
      )
    end
  end

  defp exclude_decided_drivers(driver_query, %Schedule{} = schedule),
    do:
      from(d in driver_query,
        left_join: ds in DriverSchedule,
        on: ds.driver_id == d.id and ds.schedule_id == ^schedule.id,
        where: is_nil(ds.schedule_id)
      )

  defp exclude_notified_drivers(driver_query, target, exclude \\ true)

  defp exclude_notified_drivers(driver_query, _, false), do: driver_query

  defp exclude_notified_drivers(driver_query, %Match{} = match, _) do
    already_notified_query =
      from(sent in SentNotification,
        where: sent.match_id == ^match.id,
        where: not is_nil(sent.driver_id),
        select: fragment("cast(? as varchar)", sent.driver_id)
      )

    driver_query |> except_all(^already_notified_query)
  end

  defp exclude_notified_drivers(driver_query, %Schedule{} = schedule, _) do
    already_notified_query =
      from(sent in SentNotification,
        where: sent.schedule_id == ^schedule.id,
        where: not is_nil(sent.driver_id),
        select: fragment("cast(? as varchar)", sent.driver_id)
      )

    driver_query |> except_all(^already_notified_query)
  end

  defp exclude_notified_drivers(driver_query, %DeliveryBatch{} = batch, _) do
    already_notified_query =
      from(sent in SentNotification,
        where: sent.delivery_batch_id == ^batch.id,
        where: not is_nil(sent.driver_id),
        select: fragment("cast(? as varchar)", sent.driver_id)
      )

    driver_query |> except_all(^already_notified_query)
  end

  defp get_valid_drivers(driver_locations) do
    Repo.all(
      from(driver in Driver,
        left_join: dd in DriverDevice,
        on: driver.default_device_id == dd.id,
        where:
          fragment("cast(? as varchar)", driver.id) in subquery(driver_locations) and
            not is_nil(driver.default_device_id)
      )
    )
    |> Repo.preload(:default_device)
    |> Enum.uniq()
  end

  defp send_notifications(driver_locations, %Match{} = match) do
    get_valid_drivers(driver_locations)
    |> send_notification(match)
    |> maybe_do_transaction()
  end

  defp send_fleet_opt_notifications(driver_locations, %Schedule{} = schedule) do
    get_valid_drivers(driver_locations)
    |> Enum.reduce(Ecto.Multi.new(), fn driver, multi ->
      send_fleet_opt_notification(driver, schedule, multi)
    end)
    |> maybe_do_transaction()
  end

  defp send_batch_notifications(driver_locations, %DeliveryBatch{} = batch) do
    get_valid_drivers(driver_locations)
    |> Enum.reduce(Ecto.Multi.new(), fn driver, multi ->
      send_batch_notification(driver, batch, multi)
    end)
    |> maybe_do_transaction()
  end

  def send_documents_approved(%{state: state} = driver) do
    message =
      if state in [:applying, :pending_approval, :screening],
        do: "Your application can now progress to the next stage.",
        else: "Your account has been reinstated and you can start taking deliveries again."

    sent =
      Notifications.send_notification(:push, driver, :notification, %{
        title: "Documents Approved",
        message: message
      })

    {:ok, sent}
  end

  def send_approved_documents_email(%{state: state} = driver) do
    %{user: %{email: driver_email}} = driver
    driver_name = DisplayFunctions.full_name(driver)

    Email.approved_documents_email(driver_email, driver_name, state)
    |> Mailer.deliver_later()
  end

  def send_documents_rejected(driver) do
    sent =
      Notifications.send_notification(:push, driver, :notification, %{
        title: "Documents Rejected",
        message: "One or more documents were not approved."
      })

    {:ok, sent}
  end

  def send_rejected_documents_email(driver) do
    %{user: %{email: driver_email}} = driver
    driver_name = DisplayFunctions.full_name(driver)

    Email.rejected_documents_email(driver_email, driver_name)
    |> Mailer.deliver_later()
  end

  def send_approval_letter_email(%{user: %{email: driver_email}} = _driver) do
    Email.send_approval_letter(driver_email)
    |> Mailer.deliver_later()
  end

  def send_rejection_letter_email(%{user: %{email: driver_email}} = _driver) do
    Email.send_rejection_letter(driver_email)
    |> Mailer.deliver_later()
  end

  def send_canceled_notification(driver, %Match{shortcode: shortcode} = match),
    do:
      Notifications.send_notification(:push, driver, match, %{
        title: "Match canceled",
        message: "Match ##{shortcode} has been canceled."
      })

  def send_scheduled_pickup_alert(driver, %Match{shortcode: shortcode} = match),
    do:
      Notifications.send_notification(:push, driver, match, %{
        title: "Scheduled Match Reminder",
        message:
          "You accepted Scheduled Match #{shortcode} that needs to be picked up in 30 minutes"
      })

  def send_idle_driver_warning(driver, %Match{shortcode: shortcode} = match),
    do:
      Notifications.send_notification(:push, driver, match, %{
        title: "Idle Warning",
        message:
          "You accepted Match #{shortcode} 15 minutes ago, but are not en route. Please head towards the pickup address to avoid this match being re-assigned."
      })

  def send_idle_driver_cancellation(driver, %Match{shortcode: shortcode} = match),
    do:
      Notifications.send_notification(:push, driver, match, %{
        title: "Removed Due to Inactivity",
        message: "You have been removed from Match #{shortcode} due to inactivity"
      })

  def send_test_notification(driver),
    do:
      Notifications.send_notification(:push, driver, :is_test, %{
        title: "Test Notification",
        message:
          "If you can see this, then congratulations! You're all set to receive Push Notifications from us on this device."
      })

  defp send_notification(drivers, %{preferred_driver_id: preferred_driver_id} = match)
       when is_list(drivers) and not is_nil(preferred_driver_id) do
    %Match{
      origin_address: %Address{state_code: state_code, city: city},
      total_distance: distance,
      driver_total_pay: driver_total_pay,
      shortcode: shortcode,
      shipper: shipper
    } = match |> Repo.preload(:shipper)

    shipper_name =
      if shipper.company, do: shipper.company, else: "#{shipper.first_name} #{shipper.last_name}"

    Notifications.send_notification(:push, drivers, match, %{
      title: "#{shipper_name} requested you!",
      message:
        "Match #{shortcode} in #{city}, #{state_code}: #{distance} mi, $#{DisplayFunctions.format_price(driver_total_pay)}"
    })
  end

  defp send_notification(drivers, match) when is_list(drivers) do
    %Match{
      origin_address: %Address{state_code: state_code, city: city},
      total_distance: distance,
      driver_total_pay: driver_total_pay,
      shortcode: shortcode
    } = match

    Notifications.send_notification(:push, drivers, match, %{
      title: "Match available in #{city}, #{state_code}",
      message:
        "Match ##{shortcode}: #{distance}mi, $#{DisplayFunctions.format_price(driver_total_pay)}."
    })
  end

  def send_removed_from_match_notification(nil, _match), do: {:ok, nil}

  def send_removed_from_match_notification(driver, %Match{shortcode: shortcode} = match) do
    Notifications.send_notification(:push, driver, match, %{
      title: "Removed from Match ##{shortcode}",
      message: "You are no longer responsible for picking up or delivering this Match."
    })
  end

  defp send_fleet_opt_notification(driver, %Schedule{} = schedule, %Multi{} = multi),
    do:
      multi
      |> Notifications.send_notification(:push, driver, schedule, %{
        title: "New route opportunity available",
        message: "Open the Frayt app for details."
      })

  defp send_batch_notification(
         driver,
         %DeliveryBatch{
           address: %Address{city: city, neighborhood: neighborhood},
           matches: matches
         } = batch,
         %Multi{} = multi
       ) do
    multi
    |> Notifications.send_notification(:push, driver, batch, %{
      title: "New batch of matches in #{neighborhood || city}",
      message: "#{length(matches)} matches available"
    })
  end

  defp maybe_do_transaction({:error, _}), do: []
  defp maybe_do_transaction({:error, _, _}), do: []
  defp maybe_do_transaction(%{recipients: 0}), do: []

  defp maybe_do_transaction(%Ecto.Multi{} = multi) do
    case Ecto.Multi.to_list(multi) do
      [] ->
        []

      _ ->
        Repo.transaction(multi)
        |> map_results()
    end
  end

  defp map_results({:ok, results}), do: Map.values(results)

  defp map_results({:error, _}), do: nil
end
