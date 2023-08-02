defmodule FraytElixir.MatchLog do
  alias FraytElixir.Shipment.{
    HiddenMatch,
    Match,
    MatchStateTransition,
    MatchStopStateTransition,
    MatchStop,
    MatchFeeType
  }

  import Ecto.Query, warn: false
  alias FraytElixir.Repo
  alias FraytElixir.Version

  @ignored_changes [:inserted_at, :updated_at, :id, :shortcode, :state]

  def ignored_changes, do: @ignored_changes

  def get_match_log(%Match{} = match) do
    match
    |> get_all_match_logs()
    |> Enum.filter(&has_visible_changes?/1)
    |> Enum.sort_by(&get_inserted_at(&1), {:asc, DateTime})
  end

  defp has_visible_changes?(%Version{} = version) do
    changes =
      version.patch
      |> Map.keys()
      |> Enum.reject(fn change -> change in @ignored_changes end)

    Enum.count(changes) > 0
  end

  defp has_visible_changes?(_version), do: true

  defp get_all_match_logs(match) do
    %Match{
      id: id,
      origin_address: address,
      match_stops: match_stops,
      fees: match_fees
    } = match

    stops_logs =
      Enum.reduce(match_stops, [], fn %MatchStop{
                                        destination_address: destination_address
                                      } = stop,
                                      acc ->
        acc ++
          match_stop_version_query(stop) ++
          stop_states_query(stop.id) ++
          destination_address_version_query(destination_address, stop)
      end)

    fees_logs =
      Enum.reduce(match_fees, [], fn match_fee, acc ->
        acc ++ match_fee_version_query(match_fee)
      end)

    cancellation_query(id) ++
      states_query(id) ++
      match_version_query(match) ++
      origin_address_version_query(address) ++
      stops_logs ++
      fees_logs
  end

  defp get_inserted_at(%Version{recorded_at: recorded_at}), do: recorded_at

  defp get_inserted_at(%{inserted_at: inserted_at}),
    do: DateTime.from_naive(inserted_at, "Etc/UTC") |> elem(1)

  defp cancellation_query(id) do
    from(h in HiddenMatch,
      where: h.match_id == ^id
    )
    |> Repo.all()
    |> Repo.preload(:driver)
  end

  defp states_query(id) do
    from(m in MatchStateTransition,
      where: m.match_id == ^id
    )
    |> Repo.all()
  end

  defp stop_states_query(id) do
    from(m in MatchStopStateTransition,
      where: m.match_stop_id == ^id
    )
    |> Repo.all()
    |> Repo.preload(:match_stop)
  end

  defp match_version_query(match),
    do: version_query(match, "Match")

  defp origin_address_version_query(address),
    do: version_query(address, "Origin Address")

  defp destination_address_version_query(address, stop),
    do: version_query(address, "Stop Address ##{stop.index + 1}")

  defp match_stop_version_query(stop),
    do: version_query(stop, "Stop ##{stop.index + 1}")

  defp match_fee_version_query(fee),
    do: version_query(fee, MatchFeeType.name(fee.type))

  defp version_query(%{__struct__: struct, id: id}, name) do
    from(v in Version,
      where: v.entity_id == ^id,
      where: v.entity_schema == ^struct,
      select: %{v | entity_name: fragment("?", ^name)}
    )
    |> Repo.all()
    |> Repo.preload(:user)
  end
end
