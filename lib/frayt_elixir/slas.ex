defmodule FraytElixir.SLAs do
  alias FraytElixir.SLAs.{MatchSLA, ContractSLA}
  alias FraytElixir.Markets.Market
  alias FraytElixir.Repo
  alias Ecto.{Multi, Changeset}
  alias FraytElixirWeb.DisplayFunctions

  alias FraytElixir.{Shipment, Validators}

  alias FraytElixir.Shipment.{
    Match,
    VehicleClass
  }

  import Ecto.Query

  @default_contract_slas %{
    1 => [
      %ContractSLA{type: :acceptance, duration: "10"},
      %ContractSLA{type: :pickup, duration: "market_pickup_sla_modifier + 60"},
      %ContractSLA{
        type: :delivery,
        duration: "vehicle_load_time + travel_duration + stop_delivery_time * stop_count"
      }
    ],
    2 => [
      %ContractSLA{
        type: :acceptance,
        duration_type: :end_time,
        min_duration: "30",
        time: ~T[12:30:00]
      },
      %ContractSLA{
        type: :pickup,
        duration_type: :duration_before_time,
        duration: "vehicle_load_time + travel_duration + stop_delivery_time * stop_count",
        min_duration: "0",
        time: ~T[17:00:00]
      },
      %ContractSLA{
        type: :delivery,
        duration_type: :end_time,
        min_duration: "0",
        time: ~T[17:00:00]
      }
    ]
  }

  def validate_sla_scheduling(changeset) do
    match =
      changeset
      |> Changeset.apply_changes()
      |> Repo.preload(contract: :slas)

    slas = get_slas_for_target(:frayt, match.driver_id)

    Enum.reduce(slas, changeset, fn {type, _driver_id}, cs ->
      contract_sla = find_contract_sla(match, type)

      validate_sla(cs, match, contract_sla)
    end)
  end

  defp validate_sla(changeset, match, %{type: :acceptance, duration_type: :end_time} = csla) do
    %ContractSLA{time: time} = csla
    min_duration = calculate_sla_duration(match, csla.min_duration)
    latest_time = Time.add(time, -min_duration)

    error_message =
      "cannot be after " <>
        Timex.format!(latest_time, "{h12}:{0m}{AM}") <> " for this service level"

    if match.scheduled do
      Validators.validate_time(changeset, :pickup_at, [less_than_or_equal_to: latest_time],
        message: error_message,
        time_zone: match.timezone
      )
    else
      authorized_at = calculate_sla_start_time(match, csla, nil)

      changeset
      |> Changeset.change(%{authorized_at: authorized_at})
      |> Validators.validate_time(:authorized_at, [less_than_or_equal_to: latest_time],
        message: error_message,
        time_zone: match.timezone
      )
    end
  end

  defp validate_sla(
         changeset,
         %{scheduled: true},
         %{type: :delivery, duration_type: duration_type}
       )
       when duration_type in [:end_time, :duration_before_time] do
    Validators.validate_empty(changeset, :dropoff_at,
      message: "cannot be set for this service level"
    )
  end

  defp validate_sla(changeset, _match, _contract_sla), do: changeset

  def get_active_match_slas(%Match{state: state, driver_id: driver_id} = match) do
    type = get_active_sla_type(state)

    if type do
      slas =
        match.slas
        |> Enum.filter(fn sla ->
          sla.type == type and sla.driver_id in [nil, driver_id]
        end)
        |> Enum.sort_by(&{&1.type, &1.driver_id}, :asc)

      {type, slas}
    end
  end

  defp get_active_sla_type(:assigning_driver), do: :acceptance

  defp get_active_sla_type(state)
       when state in [:accepted, :en_route_to_pickup, :arrived_at_pickup],
       do: :pickup

  defp get_active_sla_type(state)
       when state in [:picked_up, :completed, :charged, :canceled, :admin_canceled],
       do: :delivery

  defp get_active_sla_type(_), do: nil

  def get_match_sla(%Match{id: id}, type, driver_id \\ nil) do
    from(ms in MatchSLA, where: ms.match_id == ^id and ms.type == ^type)
    |> filter_by_match_sla_target(driver_id)
    |> Repo.one()
  end

  defp filter_by_match_sla_target(query, nil) do
    query |> where([ms], is_nil(ms.driver_id))
  end

  defp filter_by_match_sla_target(query, driver_id) do
    query |> where([ms], ms.driver_id == ^driver_id)
  end

  def stop_delivery_time, do: 5 * 60

  def change_match_sla(%MatchSLA{} = sla, attrs) do
    MatchSLA.changeset(sla, attrs)
  end

  def calculate_match_slas(%Match{} = match, for: targets) do
    match = Repo.preload(match, [:slas, contract: :slas])

    upsert_match_slas(match, [for: targets], fn sla, prev_sla ->
      attrs = build_match_sla(sla, prev_sla)
      change_match_sla(sla, attrs)
    end)
  end

  def complete_match_slas(%Match{} = match, completed_at \\ DateTime.utc_now(), opts) do
    match = Repo.preload(match, :slas)

    upsert_match_slas(match, opts, fn sla, _prev_sla ->
      attrs = %{completed_at: completed_at}
      change_match_sla(sla, attrs)
    end)
  end

  def reset_match_slas(match, opts), do: complete_match_slas(match, nil, opts)

  def upsert_match_slas(match, opts, change_fn) do
    slas = find_slas_for_targets_or_types(match, opts)

    multi =
      slas
      |> Enum.with_index()
      |> Enum.reduce(Multi.new(), fn {sla, index}, multi ->
        Multi.insert_or_update(multi, index, fn changes ->
          prev_sla = Map.get(changes, index - 1)
          change_fn.(sla, prev_sla)
        end)
      end)

    with {:ok, updated_slas} <- Repo.transaction(multi) do
      match = merge_updated_slas(match, updated_slas)

      {:ok, match}
    end
  end

  defp merge_updated_slas(match, updated_slas) do
    Enum.reduce(updated_slas, match, fn {_key, %MatchSLA{} = sla}, m ->
      has_sla? = Enum.any?(m.slas, &(&1.id == sla.id))

      slas =
        if has_sla? do
          Enum.map(m.slas, &if(&1.id == sla.id, do: sla, else: &1))
        else
          [sla | m.slas]
        end

      %Match{match | slas: slas}
    end)
  end

  defp find_slas_for_targets_or_types(match, opts) do
    slas = get_slas_for_targets_or_types(match.driver_id, opts)

    match
    |> find_match_slas(slas)
    |> sort_slas_by_priority()
  end

  defp get_slas_for_targets_or_types(driver_id, opts) do
    case opts do
      [for: targets] -> get_slas_for_targets(targets, driver_id)
      [types: types] -> get_slas_for_types(types, driver_id)
    end
  end

  defp get_slas_for_targets(target, driver_id) when is_atom(target),
    do: get_slas_for_targets([target], driver_id)

  defp get_slas_for_targets(targets, driver_id) do
    Enum.reduce(targets, [], fn target, slas ->
      slas ++ get_slas_for_target(target, driver_id)
    end)
  end

  defp get_slas_for_target(target, driver_id) do
    case target do
      :frayt ->
        [{:acceptance, nil}, {:pickup, nil}, {:delivery, nil}]

      :driver when not is_nil(driver_id) ->
        [{:pickup, driver_id}, {:delivery, driver_id}]

      _ ->
        []
    end
  end

  defp get_slas_for_types(type, driver_id) when is_atom(type),
    do: get_slas_for_types([type], driver_id)

  defp get_slas_for_types(types, driver_id) do
    Enum.reduce(types, [], fn type, slas ->
      slas ++ get_slas_for_type(type, driver_id)
    end)
  end

  defp get_slas_for_type(type, driver_id) do
    case type do
      :acceptance ->
        [{:acceptance, nil}]

      type ->
        frayt_sla = {type, nil}

        if driver_id do
          [frayt_sla, {type, driver_id}]
        else
          [frayt_sla]
        end
    end
  end

  defp find_match_slas(match, slas) do
    Enum.map(slas, fn {type, driver_id} ->
      find_match_sla(match, type, driver_id)
    end)
  end

  defp sort_slas_by_priority(slas), do: Enum.sort_by(slas, &sla_priority/1, :asc)

  defp sla_priority(sla) do
    type_priority =
      case sla.type do
        :acceptance -> 0
        :pickup -> 1
        :delivery -> 2
      end

    target_priority =
      case sla.driver_id do
        nil -> 0
        _ -> 1
      end

    {target_priority, type_priority}
  end

  defp find_match_sla(match, type, driver_id) do
    match = Repo.preload(%{match | driver_id: driver_id}, :slas)
    sla = Enum.find(match.slas, &(&1.type == type and &1.driver_id == driver_id))

    if sla,
      do: %MatchSLA{sla | match: match},
      else: %MatchSLA{type: type, driver_id: driver_id, match_id: match.id, match: match}
  end

  def build_match_sla(%MatchSLA{} = sla, prev_sla) do
    %MatchSLA{match: %Match{} = match, type: type, driver_id: driver_id} = sla
    contract_sla = find_contract_sla(match, sla.type)

    start_time = %DateTime{} = calculate_sla_start_time(match, contract_sla, prev_sla)
    end_time = %DateTime{} = calculate_sla_end_time(match, contract_sla, start_time)

    %{
      match_id: match.id,
      start_time: start_time,
      end_time: end_time,
      type: type,
      driver_id: driver_id
    }
  end

  defp find_contract_sla(match, type) do
    default_sla =
      @default_contract_slas
      |> Map.fetch!(match.service_level)
      |> Enum.find(&(&1.type == type))

    case match.contract do
      %{slas: slas} -> Enum.find(slas, default_sla, &(&1.type == type))
      _ -> default_sla
    end
  end

  defp calculate_sla_start_time(match, %ContractSLA{type: :acceptance}, _prev_sla) do
    start_time = Shipment.match_authorized_time(match)

    if start_time do
      DateTime.from_naive!(start_time, "Etc/UTC")
    else
      DateTime.utc_now()
    end
  end

  defp calculate_sla_start_time(
         %Match{driver_id: driver_id} = match,
         %ContractSLA{type: :pickup},
         _prev_sla
       )
       when not is_nil(driver_id) do
    start_time = Shipment.match_transitioned_at(match, :accepted, :desc)

    if start_time do
      DateTime.from_naive!(start_time, "Etc/UTC")
    else
      DateTime.utc_now()
    end
  end

  defp calculate_sla_start_time(
         %Match{scheduled: true} = match,
         %ContractSLA{type: :pickup, duration_type: type},
         _prev_sla
       )
       when type in [:end_time, :duration_before_time],
       do: DateTime.from_naive!(match.pickup_at, "Etc/UTC")

  defp calculate_sla_start_time(_match, %ContractSLA{}, prev_sla),
    do: prev_sla.end_time

  defp calculate_sla_end_time(match, %ContractSLA{duration_type: nil} = csla, start_time) do
    scheduled_time = get_sla_scheduled_time(match, csla)

    duration_time = calculate_and_add_sla_duration(match, csla.duration, start_time)

    select_latest_date_time([scheduled_time, duration_time])
  end

  defp calculate_sla_end_time(match, %ContractSLA{duration_type: :end_time} = csla, start_time) do
    end_time = get_local_sla_date_time(match, csla, start_time)

    min_end_time = calculate_and_add_sla_duration(match, csla.min_duration, start_time)

    select_latest_date_time([end_time, min_end_time])
  end

  defp calculate_sla_end_time(
         match,
         %ContractSLA{duration_type: :duration_before_time} = csla,
         start_time
       ) do
    from_time = get_local_sla_date_time(match, csla, start_time)

    duration = calculate_sla_duration(match, csla.duration)
    end_time = DateTime.add(from_time, -duration, :second)

    min_end_time = calculate_and_add_sla_duration(match, csla.min_duration, start_time)

    select_latest_date_time([end_time, min_end_time])
  end

  defp get_sla_scheduled_time(%Match{scheduled: true} = match, csla) do
    case csla.type do
      :acceptance ->
        pickup_sla = find_contract_sla(match, :pickup)

        case pickup_sla do
          %{duration_type: nil} ->
            pickup_duration = calculate_sla_duration(match, pickup_sla.duration)

            match.pickup_at
            |> DateTime.from_naive!("Etc/UTC")
            |> DateTime.add(-pickup_duration, :second)

          _ ->
            match.pickup_at
        end

      :pickup ->
        DateTime.from_naive!(match.pickup_at, "Etc/UTC")

      :delivery ->
        match.dropoff_at && DateTime.from_naive!(match.dropoff_at, "Etc/UTC")
    end
  end

  defp get_sla_scheduled_time(_match, _csla), do: nil

  defp select_latest_date_time(date_times) do
    date_times
    |> Enum.filter(& &1)
    |> Enum.max(DateTime)
  end

  defp get_local_sla_date_time(match, csla, start_time) do
    utc_date_time =
      if csla.type == :acceptance and match.scheduled do
        match.pickup_at
      else
        start_time
      end

    local_date_time = DisplayFunctions.datetime_with_timezone(utc_date_time, match.timezone)

    end_date = DateTime.to_date(local_date_time)
    %{time_zone: time_zone} = local_date_time
    %{time: time} = csla

    DateTime.new!(end_date, time, time_zone)
  end

  defp calculate_and_add_sla_duration(match, duration_equation, start_time) do
    duration = calculate_sla_duration(match, duration_equation)

    DateTime.add(start_time, duration, :second)
  end

  defp calculate_sla_duration(match, duration_equation) do
    %Match{
      travel_duration: travel_duration,
      total_distance: total_distance,
      match_stops: stops,
      vehicle_class: vehicle_class
    } = match

    params = %{
      "travel_duration" => travel_duration / 60,
      "vehicle_load_time" => VehicleClass.get_attribute(vehicle_class, :load_time) / 60,
      "stop_delivery_time" => stop_delivery_time() / 60,
      "stop_count" => length(stops),
      "total_distance" => total_distance,
      "market_pickup_sla_modifier" => get_market_pickup_sla_modifier(match)
    }

    duration = Abacus.eval!(duration_equation, params)

    round(duration * 60)
  end

  defp get_market_pickup_sla_modifier(%Match{market: %Market{sla_pickup_modifier: modifier}}),
    do: modifier || 0

  defp get_market_pickup_sla_modifier(_), do: 0
end
