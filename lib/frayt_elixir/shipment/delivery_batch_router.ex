defmodule FraytElixir.Shipment.DeliveryBatchRouter do
  use GenServer

  alias Ecto.{Multi, Association.NotLoaded}
  alias FraytElixir.Accounts
  alias FraytElixir.Repo
  alias FraytElixir.Accounts.{Schedule, Location}
  alias FraytElixir.Drivers
  alias FraytElixir.Drivers.{Driver, Vehicle}

  alias FraytElixir.Shipment
  alias FraytElixir.SLAs
  alias FraytElixir.Matches
  alias FraytElixir.Shipment.{DeliveryBatch, DeliveryBatches, MatchStop, Address, MatchWorkflow}
  alias FraytElixirWeb.DisplayFunctions

  @config Application.compile_env(:frayt_elixir, __MODULE__, [])

  @routific Keyword.get(@config, :routific, Routific)
  @poll_interval Keyword.fetch!(@config, :poll_interval)

  def new(%{delivery_batch: %DeliveryBatch{} = delivery_batch}) do
    GenServer.start_link(
      __MODULE__,
      %{delivery_batch: delivery_batch},
      name: name_for(delivery_batch)
    )
  end

  def name_for(%DeliveryBatch{id: delivery_batch_id}),
    do: {:global, "delivery_batch_router:#{delivery_batch_id}"}

  def init(%{delivery_batch: %DeliveryBatch{} = delivery_batch}) do
    send(self(), :start_routing)

    {:ok,
     %{
       delivery_batch: delivery_batch,
       job_id: nil
     }}
  end

  def handle_info(:start_routing, %{delivery_batch: batch} = state) do
    batch = Repo.preload(batch, [:location, :matches, :address])

    case route_batch(batch) do
      {:ok, batch, job_id} ->
        Process.send_after(self(), :poll_routific, @poll_interval)

        {:noreply, state |> Map.put(:job_id, job_id) |> Map.put(:delivery_batch, batch)}

      {:error, batch} ->
        {:stop, :normal, state |> Map.put(:delivery_batch, batch)}
    end
  end

  def handle_info(
        :poll_routific,
        %{
          delivery_batch: delivery_batch,
          job_id: job_id
        } = state
      ) do
    case @routific.check_routing_status(job_id) do
      {:ok, %{"status" => status} = output} ->
        Kernel.send(self(), {String.to_atom(status), delivery_batch, output, job_id})

      _ ->
        Process.send_after(self(), :poll_routific, @poll_interval)
    end

    {:noreply, state}
  end

  def handle_info(
        {:finished, batch, %{"output" => output}, _job_id},
        state
      ) do
    with {:ok, _matches} <- create_matches(batch, output),
         {:ok, _stops} <- update_unserved_stops(output) do
      batch =
        batch
        |> Repo.preload([match_stops: :state_transitions], force: true)
        |> DeliveryBatches.update_state(:routing_complete)

      {:stop, :normal, %{state | delivery_batch: batch}}
    else
      {:error, _key, %Ecto.Changeset{} = changeset, _} ->
        errors = DisplayFunctions.humanize_errors(changeset)

        {:ok, batch, _} = DeliveryBatches.update_state(batch, :error, errors)

        {:stop, :normal, %{state | delivery_batch: batch}}
    end
  end

  def handle_info({:processing, delivery_batch, output, job_id}, state),
    do: handle_info({:pending, delivery_batch, output, job_id}, state)

  def handle_info({:pending, _, _, _job_id}, state) do
    Process.send_after(self(), :poll_routific, @poll_interval)

    {:noreply, state}
  end

  def handle_info({:error, batch, %{"output" => output}, _job_id}, state) do
    DeliveryBatches.update_state(batch, :error, output)

    {:stop, :normal, state}
  end

  def handle_call(:get_job_id, _from, state) do
    {:reply, Map.get(state, :job_id), state}
  end

  def route_batch(%DeliveryBatch{location: %NotLoaded{}} = delivery_batch),
    do: delivery_batch |> Repo.preload([:location, :matches, :address]) |> route_batch()

  def route_batch(%DeliveryBatch{match_stops: stops} = delivery_batch) do
    drivers = get_drivers(delivery_batch)

    case @routific.optimize_route_async(%{
           fleet: build_fleet(delivery_batch, drivers),
           visits: build_visits(stops),
           options: build_options()
         }) do
      {:ok, %{"job_id" => job_id}} ->
        {:ok, batch, _} = DeliveryBatches.update_state(delivery_batch, :routing)
        {:ok, batch, job_id}

      {:error, message} ->
        {:ok, batch, _} = DeliveryBatches.update_state(delivery_batch, :error, inspect(message))
        {:error, batch}
    end
  end

  def create_matches(%DeliveryBatch{matches: %NotLoaded{}} = delivery_batch, routific_response),
    do: delivery_batch |> Repo.preload(:matches) |> create_matches(routific_response)

  def create_matches(delivery_batch, %{"solution" => routific_solution}) do
    routific_solution =
      routific_solution
      |> Enum.filter(fn {_driver_id, locations} ->
        locations |> Enum.count() > 1
      end)

    match_indices =
      routific_solution |> Enum.with_index() |> Enum.map(fn {_route, index} -> index end)

    routific_solution
    |> Enum.with_index()
    |> Enum.reduce(Multi.new(), fn {{driver_id, locations}, index}, multi ->
      create_match(delivery_batch, driver_id, locations, multi, index)
    end)
    |> Multi.update(:update_batch, fn changes ->
      matches =
        match_indices
        |> Enum.map(fn match_index ->
          {:ok, match} = changes |> Map.fetch("match_#{match_index}")
          match
        end)

      delivery_batch
      |> DeliveryBatch.changeset(%{})
      |> Ecto.Changeset.put_assoc(:matches, matches)
    end)
    |> Repo.transaction()
  end

  def update_unserved_stops(%{
        "num_unserved" => count,
        "unserved" => unserved_stops
      })
      when not is_nil(count) and count > 0 do
    unserved_stops
    |> Enum.reduce(Multi.new(), fn {stop_id, message}, multi ->
      Multi.run(multi, {:unserved_stop, stop_id}, fn _repo, _changes ->
        Shipment.get_match_stop(stop_id) |> MatchWorkflow.unserved(message)
      end)
    end)
    |> Repo.transaction()
  end

  def update_unserved_stops(_), do: {:ok, %{}}

  def build_drivers(vehicle_class, count),
    do:
      1..count
      |> Enum.map(
        &%Driver{
          id: "#{vehicle_class}_d#{&1}",
          vehicles: [%Vehicle{vehicle_class: vehicle_class}]
        }
      )

  defp get_drivers(%DeliveryBatch{location: nil}),
    do: build_drivers(3, 10) ++ build_drivers(2, 10) ++ build_drivers(1, 10)

  defp get_drivers(%DeliveryBatch{location: location} = delivery_batch) do
    case Accounts.get_schedule_for_location(location) do
      %Schedule{drivers: drivers} ->
        drivers

      _ ->
        DeliveryBatches.update_state(delivery_batch, :error, "Schedule not found for location!!")
    end
  end

  defp create_match(
         %DeliveryBatch{shipper: %NotLoaded{}} = delivery_batch,
         driver_id,
         locations,
         multi,
         index
       ),
       do:
         delivery_batch
         |> Repo.preload([:shipper, :address, :location])
         |> create_match(driver_id, locations, multi, index)

  defp create_match(
         %DeliveryBatch{address: %NotLoaded{}} = delivery_batch,
         driver_id,
         locations,
         multi,
         index
       ),
       do:
         delivery_batch
         |> Repo.preload([:shipper, :address, :location])
         |> create_match(driver_id, locations, multi, index)

  defp create_match(
         %DeliveryBatch{location: %NotLoaded{}} = delivery_batch,
         driver_id,
         locations,
         multi,
         index
       ),
       do:
         delivery_batch
         |> Repo.preload([:shipper, :address, :location])
         |> create_match(driver_id, locations, multi, index)

  defp create_match(
         %DeliveryBatch{
           address: address,
           shipper: shipper,
           location: location,
           service_level: service_level,
           po: po,
           pickup_at: pickup_at,
           pickup_notes: pickup_notes,
           contract: contract
         },
         driver_id,
         locations,
         multi,
         index
       ) do
    driver = get_driver(driver_id)
    schedule_id = get_schedule_id(location)

    with [_ | _] = match_stops <- indexed_match_stops(locations) do
      attrs = %{
        stops: match_stops,
        contract: contract,
        origin_address: address,
        service_level: service_level,
        vehicle_class: Drivers.get_max_vehicle_class(driver),
        po: po,
        scheduled: true,
        pickup_at: pickup_at,
        pickup_notes: pickup_notes,
        schedule_id: schedule_id
      }

      multi
      |> Matches.create_match_changes(attrs, shipper, index)
    end
  end

  defp get_driver("1_d" <> _), do: %Driver{vehicles: [%Vehicle{vehicle_class: 1}]}
  defp get_driver("2_d" <> _), do: %Driver{vehicles: [%Vehicle{vehicle_class: 2}]}
  defp get_driver("3_d" <> _), do: %Driver{vehicles: [%Vehicle{vehicle_class: 3}]}
  defp get_driver("4_d" <> _), do: %Driver{vehicles: [%Vehicle{vehicle_class: 4}]}

  defp get_driver(driver_id),
    do: Drivers.get_driver(driver_id)

  defp get_schedule_id(nil), do: nil

  defp get_schedule_id(%Location{} = location) do
    case Accounts.get_schedule_for_location(location) do
      %Schedule{id: schedule_id} -> schedule_id
      _ -> nil
    end
  end

  defp indexed_match_stops(locations) do
    locations
    |> Enum.reject(fn %{"location_id" => start_loc} -> String.ends_with?(start_loc, "_start") end)
    |> Enum.with_index()
    |> Enum.map(fn {%{"location_id" => match_stop_id}, index} ->
      {:ok, match_stop} =
        Shipment.get_match_stop(match_stop_id)
        |> MatchStop.changeset(%{index: index})
        |> Repo.update()

      match_stop
    end)
  end

  defp build_options do
    %{
      squash_durations: SLAs.stop_delivery_time() / 60,
      polylines: true,
      min_vehicles: true
    }
  end

  defp build_visits(match_stops) do
    match_stops
    |> Enum.reduce(%{}, fn match_stop, acc ->
      Map.put(acc, match_stop.id, build_visit(match_stop))
    end)
  end

  def build_visit(
        %{
          dropoff_by: dropoff_by,
          destination_address: %{
            formatted_address: formatted_address,
            geo_location: %Geo.Point{coordinates: {lng, lat}}
          }
        } = stop
      ) do
    %{total_volume: volume} = Matches.calculate_total_stop_sizes(stop)

    %{
      load: ceil(volume / 1728),
      end: format_time(dropoff_by),
      duration: SLAs.stop_delivery_time() / 60,
      location: %{
        name: formatted_address,
        lat: lat,
        lng: lng
      }
    }
  end

  defp build_fleet(
         %DeliveryBatch{address: address, complete_by: complete_by, pickup_at: pickup_at},
         drivers
       ) do
    drivers
    |> Enum.reduce(%{}, fn driver, acc ->
      Map.put(acc, driver.id, %{
        start_location: build_location(address),
        capacity: Drivers.get_max_volume(driver),
        shift_start: format_time(pickup_at),
        shift_end: format_time(complete_by)
      })
    end)
  end

  defp build_location(%Address{
         formatted_address: formatted_address,
         geo_location: %Geo.Point{coordinates: {lng, lat}}
       })
       when nil not in [lat, lng],
       do: %{name: formatted_address, lat: lat, lng: lng}

  defp format_time(nil), do: nil

  defp format_time(date_time),
    do: Timex.Format.DateTime.Formatters.Default.format!(date_time, "{0h24}:{0m}")
end
