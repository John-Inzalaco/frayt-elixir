defmodule FraytElixir.Shipment.ETAPoller do
  require Logger

  @moduledoc """
  Batch process to update etas for active drivers
  """
  use GenServer

  alias FraytElixir.Repo
  alias FraytElixir.Matches
  alias FraytElixir.Shipment.ETA
  alias FraytElixir.Routing
  alias FraytElixirWeb.Endpoint

  @config Application.compile_env(:frayt_elixir, FraytElixir.Shipment.ETAPoller, [])
  @interval @config[:interval]

  def interval, do: @interval

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: :eta_poller)
  end

  def init(state) do
    schedule_next()
    {:ok, state}
  end

  def handle_info(:work, state) do
    handle()
    schedule_next()
    {:noreply, state}
  end

  defp schedule_next() do
    Process.send_after(self(), :work, @interval)
  end

  defp handle() do
    en_route_matches = Matches.get_en_route_matches()

    [{:new_locations, new_matches}, {:old_locations, old_matches}] =
      Routing.ETA.split_matches_with_new_locations(en_route_matches)

    [{:etas, new_etas}, {:failed, failed_etas}] =
      try do
        Routing.ETA.get_new(new_matches)
      rescue
        e in HTTPoison.Error ->
          [{:etas, []}, {:failed, [e]}]
      end

    updated_etas = Routing.ETA.update_all(old_matches)

    save_count = insert_etas(updated_etas ++ new_etas)

    log_summary(en_route_matches, new_etas, updated_etas, save_count, failed_etas)

    en_route_matches
    |> Enum.each(fn match ->
      driver = match.driver

      if !is_nil(driver) && !is_nil(driver.current_location),
        do:
          Endpoint.broadcast!("driver_locations:#{driver.id}", "driver_location", %{
            driver.current_location
            | driver: driver
          })
    end)
  end

  defp log_summary(active_matches, new_etas, updated_etas, save_count, failed_etas) do
    Logger.info(
      "ETA Poller Results\n#{inspect(%{active_matches: key_map(active_matches, :id), tomtom_etas: key_map(new_etas, :match_id), etas_updated_without_tomtom: key_map(updated_etas, :match_id), etas_saved_to_db_count: save_count, failed_eta_count: Enum.count(failed_etas)})}"
    )

    failed_etas
    |> Enum.each(fn eta -> Logger.error("ETA Error:\n#{inspect(eta)}") end)
  end

  defp key_map(iterable, key) do
    iterable
    |> Enum.map(fn x -> Map.get(x, key) end)
  end

  defp truncate_etas(etas) do
    etas
    |> Enum.map(fn eta ->
      eta
      |> Map.put(:inserted_at, NaiveDateTime.truncate(eta.inserted_at, :second))
      |> Map.put(:updated_at, NaiveDateTime.truncate(eta.updated_at, :second))
      |> Map.put(:arrive_at, DateTime.truncate(eta.arrive_at, :second))
    end)
  end

  defp insert_etas(etas, repo \\ Repo) do
    {stop_etas, match_etas} =
      etas
      |> Enum.reduce({[], []}, fn eta, {s, m} ->
        if is_nil(Map.get(eta, :stop_id)),
          do: {s, [eta | m]},
          else: {[eta | s], m}
      end)

    {saved_match_etas, _} =
      repo.insert_all(
        ETA,
        truncate_etas(match_etas),
        on_conflict: :replace_all,
        conflict_target: :match_id
      )

    {saved_stop_etas, _} =
      repo.insert_all(
        ETA,
        truncate_etas(stop_etas),
        on_conflict: :replace_all,
        conflict_target: :stop_id
      )

    saved_match_etas + saved_stop_etas
  end
end
