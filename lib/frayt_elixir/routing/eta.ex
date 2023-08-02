defmodule FraytElixir.Routing.ETA do
  alias FraytElixir.TomTom
  alias FraytElixir.Matches
  alias FraytElixir.Shipment.{Match, MatchStop, ETA}
  alias FraytElixir.Routing

  def split_matches_with_new_locations(matches) do
    Enum.reduce(
      matches,
      [new_locations: [], old_locations: []],
      &categorize_match_by_location_status/2
    )
  end

  defp categorize_match_by_location_status(match, [{_key1, new}, {_key2, old}] = acc) do
    case Matches.get_next_location(match) do
      {:ok, %{eta: eta}} ->
        if new_location?(match, eta),
          do: [new_locations: [match | new], old_locations: old],
          else: [new_locations: new, old_locations: [match | old]]

      {:error, _} ->
        acc
    end
  end

  def new_location?(_match, nil), do: true

  def new_location?(match, eta) do
    NaiveDateTime.compare(match.driver.current_location_inserted_at, eta.updated_at) == :gt
  end

  def get_new(matches) do
    [{:routes, routes}, {:failed, failed_routes}] = Routing.get_routes(matches)

    {routes, routed_matches} =
      Enum.reduce(routes, {[], []}, fn {route, _source, match}, {routes, matches} ->
        {[route | routes], [match | matches]}
      end)

    [etas: etas, failed: failed_etas] =
      case TomTom.Routing.calculate_batch(routes) do
        {:ok, response} -> etas_from_batch_response(response, routed_matches)
        {:error, error} -> [etas: [], failed: [error]]
      end

    [etas: etas, failed: failed_routes ++ failed_etas]
  end

  defp etas_from_batch_response(response, matches) do
    %{"batchItems" => result_items} = response

    result_items
    |> Enum.with_index()
    |> Enum.map(fn {item, index} ->
      match = Enum.at(matches, index)

      case item["statusCode"] do
        200 ->
          {:ok, arrival, _} =
            List.first(item["response"]["routes"])["summary"]["arrivalTime"]
            |> DateTime.from_iso8601()

          with {:error, message} <-
                 matches
                 |> Enum.at(index)
                 |> build_eta_attrs(arrival) do
            {:error, message, match}
          end

        _error_code ->
          {:error, item, match}
      end
    end)
    |> Enum.reduce([etas: [], failed: []], fn eta, [{_k1, etas}, {_k2, failed}] ->
      case eta do
        {:ok, eta} -> [etas: [eta | etas], failed: failed]
        {:error, error, match} -> [etas: etas, failed: [{error, match} | failed]]
      end
    end)
  end

  def build_eta_attrs(match, arrive_at \\ nil) do
    with {:ok, target} <- Matches.get_next_location(match) do
      %{eta: eta, id: id} = target

      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      foreign_key = get_eta_foreign_key(target)

      attrs = %{
        foreign_key => id,
        inserted_at: (eta && eta.inserted_at) || now,
        arrive_at: calc_arrive_at(eta, arrive_at),
        updated_at: now
      }

      {:ok, attrs}
    end
  end

  defp get_eta_foreign_key(%Match{}), do: :match_id
  defp get_eta_foreign_key(%MatchStop{}), do: :stop_id

  defp calc_arrive_at(%ETA{} = eta, nil) do
    duration = NaiveDateTime.utc_now() |> NaiveDateTime.diff(eta.updated_at, :millisecond)

    eta.arrive_at
    |> NaiveDateTime.add(duration, :millisecond)
    |> DateTime.from_naive!("Etc/UTC")
  end

  defp calc_arrive_at(_eta, arrive_at), do: arrive_at

  def update_all(matches) do
    matches
    |> Enum.map(fn match ->
      case build_eta_attrs(match) do
        {:ok, attrs} -> attrs
        {:error, _} -> nil
      end
    end)
    |> Enum.filter(& &1)
  end
end
