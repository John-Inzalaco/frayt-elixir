defmodule FraytElixir.DashboardMetrics do
  alias FraytElixir.Repo
  import Ecto.Query, only: [from: 2]
  import FraytElixir.Guards
  alias FraytElixir.Shipment.{Match, MatchState, MatchStateTransition}
  alias FraytElixir.Accounts.{AdminUser, Shipper}
  alias FraytElixir.Cache
  import FraytElixir.QueryHelpers, only: [date_equals: 2, between?: 3]

  @pre_delivery ~w(arrived_at_pickup picked_up)
  # @pre_delivery_stop ~w(en_route)
  @ignore ~w(pending scheduled canceled admin_canceled)

  @active_range MatchState.active_range()
  @completed_range MatchState.completed_range()
  @canceled_range MatchState.canceled_range()
  @fulfillment_default %{percent: 100, completed: 0, attempted: 0, canceled: 0, total: 0}

  def last_month(date), do: months_ago(date, 1)

  def months_ago(date, months), do: Timex.shift(date, months: -months)

  def get_cached_value(key) do
    {:ok, Cache.get({:admin_metric_cache, key})}
  end

  defp put_cached_value(value, key, options \\ [cache_limit: 1])

  defp put_cached_value(value, key, cache_limit: cache_limit)
       when is_integer(cache_limit) and
              key in [
                :admin_metric_matches_in_progress,
                :admin_metric_matches_this_month,
                :admin_metric_matches_unassigned
              ] do
    with :ok <-
           Cache.put({:admin_metric_cache, key}, value, ttl: :timer.minutes(cache_limit)) do
      cache_run_time(:capacity_metrics_updated_at)
      value
    end
  end

  defp put_cached_value(value, key, cache_limit: cache_limit) when is_integer(cache_limit) do
    with :ok <-
           Cache.put({:admin_metric_cache, key}, value, ttl: :timer.hours(cache_limit)) do
      cache_run_time(:metrics_updated_at)
      value
    end
  end

  defp cache_run_time(key), do: Cache.put({:admin_metric_cache, key}, NaiveDateTime.utc_now())

  def get_metric_value(key, date, options \\ [use_cache: true])

  def get_metric_value(key, date, use_cache: true) do
    with {:ok, value} <- get_cached_value(key),
         false <- Kernel.is_nil(value) do
      value
    else
      _ -> update_metric_value(key, date)
    end
  end

  def get_metric_value(key, date, use_cache: false) do
    update_metric_value(key, date)
  end

  defp update_metric_value(key, date)
       when key in [:admin_metric_last_month_revenue, :admin_metric_last_month_new_shippers] do
    query(key, date)
    |> put_cached_value(key, cache_limit: 24 * 30)
  end

  defp update_metric_value(key, date)
       when key in [
              :admin_metric_matches_in_progress,
              :admin_metric_matches_this_month,
              :admin_metric_matches_unassigned
            ] do
    query(key, date)
    |> put_cached_value(key, cache_limit: 1)
  end

  defp update_metric_value(key, date) do
    query(key, date)
    |> put_cached_value(key)
  end

  defp query(:admin_metric_monthly_revenue, %{month: month, year: year}) do
    transition_query =
      from(t in MatchStateTransition,
        where: t.to in ["completed", "canceled", "admin_canceled"],
        order_by: [desc: t.inserted_at],
        distinct: t.match_id
      )

    from(match in Match,
      join: transition in subquery(transition_query),
      on: match.id == transition.match_id,
      where:
        match.state in ["completed", "charged", "canceled", "admin_canceled"] and
          fragment("date_part('month', ?) = ?", transition.inserted_at, ^month) and
          fragment("date_part('year', ?) = ?", transition.inserted_at, ^year),
      select:
        sum(
          fragment(
            "CASE WHEN ? THEN ? ELSE coalesce(?, 0) END",
            match.state in ["completed", "charged"],
            match.amount_charged,
            match.cancel_charge
          )
        )
    )
    |> Repo.one()
  end

  defp query(:admin_metric_last_month_revenue, date),
    do: query(:admin_metric_monthly_revenue, last_month(date))

  defp query(:admin_metric_monthly_new_shippers, %{month: month, year: year}) do
    from(s in Shipper,
      where:
        s.state == :approved and
          fragment("date_part('month', ?) = ?", s.inserted_at, ^month) and
          fragment("date_part('year', ?) = ?", s.inserted_at, ^year),
      select: count(s)
    )
    |> FraytElixir.Repo.one()
  end

  defp query(:admin_metric_last_month_new_shippers, date),
    do: query(:admin_metric_monthly_new_shippers, last_month(date))

  defp query(:admin_metric_match_average_time, now) do
    date = NaiveDateTime.to_date(now)
    dropoff_query = most_recent_transition_query(:picked_up)

    pickup_query = most_recent_transition_query(:arrived_at_pickup)

    started_query = most_recent_transition_query(:assigning_driver)

    from(match in Match,
      left_join: dropoff in subquery(dropoff_query),
      on: match.id == dropoff.match_id,
      left_join: pickup in subquery(pickup_query),
      on: match.id == pickup.match_id,
      left_join: started in subquery(started_query),
      on: match.id == started.match_id,
      where:
        (date_equals(pickup.inserted_at, ^date) or date_equals(dropoff.inserted_at, ^date) or
           date_equals(started.inserted_at, ^date) or date_equals(match.pickup_at, ^date) or
           date_equals(match.dropoff_at, ^date)) and
          match.state not in @ignore,
      select:
        fragment(
          "cast(? as int)",
          avg(
            fragment(
              "CASE WHEN ? IS NOT NULL and ? IS NOT NULL THEN
              CASE WHEN ? THEN
                (extract(epoch from ? - ?) / 60) + (extract(epoch from ? - ?) / 60) + 60
              WHEN ? THEN
                CASE WHEN ? >= ? THEN (extract(epoch from ? - ?) / 60) + (extract(epoch from ? - ?) / 60) + 60
                ELSE (extract(epoch from ? - ?) / 60) + 60
                END
              ELSE CASE WHEN ? >= ? THEN (extract(epoch from ? - ?) / 60) + 60 END
              END
            WHEN ? IS NOT NULL THEN
              CASE WHEN ? THEN extract(epoch from ? - ?) / 60
              ELSE CASE WHEN ? >= ? THEN extract(epoch from ? - ?) / 60 END
              END
            ELSE
              CASE WHEN ? THEN extract(epoch from ? - ?) / 60
              ELSE extract(epoch from ? - ?) / 60
              END
            END",
              match.pickup_at,
              match.dropoff_at,
              match.state in ^@completed_range,
              pickup.inserted_at,
              match.pickup_at,
              dropoff.inserted_at,
              match.dropoff_at,
              match.state in ^@pre_delivery,
              ^now,
              match.dropoff_at,
              pickup.inserted_at,
              match.pickup_at,
              ^now,
              match.dropoff_at,
              pickup.inserted_at,
              match.pickup_at,
              ^now,
              match.pickup_at,
              ^now,
              match.pickup_at,
              match.pickup_at,
              match.state in ^@completed_range,
              dropoff.inserted_at,
              match.pickup_at,
              ^now,
              match.pickup_at,
              ^now,
              match.pickup_at,
              match.state in ^@completed_range,
              dropoff.inserted_at,
              started.inserted_at,
              ^now,
              started.inserted_at
            )
          )
        )
    )
    |> Repo.one()
  end

  defp query(:admin_metric_state_lengths, %{day: day, month: month, year: year} = now) do
    ending_point_query =
      from(t in MatchStateTransition,
        order_by: [desc: t.inserted_at],
        distinct: [t.match_id, t.from],
        select: %{from: t.from, inserted_at: t.inserted_at, match_id: t.match_id}
      )

    transition_query =
      from(s in MatchStateTransition,
        left_join: t in subquery(ending_point_query),
        on: t.from == s.to and t.match_id == s.match_id,
        where: s.to not in @ignore and s.to not in ["completed", "charged"],
        group_by: [s.match_id, s.to, s.inserted_at, t.inserted_at, t.match_id, t.from, t],
        order_by: [{:desc, s.inserted_at}],
        distinct: [s.match_id, s.to],
        select: %{
          state: s.to,
          match_id: s.match_id,
          start: s.inserted_at,
          end: t.inserted_at
        }
      )

    from(m in Match,
      left_join: s in subquery(transition_query),
      on: m.id == s.match_id,
      where:
        (fragment("date_part('month', ?) = ?", s.start, ^month) and
           fragment("date_part('year', ?) = ?", s.start, ^year) and
           fragment("date_part('day', ?) = ?", s.start, ^day)) or
          (fragment("date_part('month', ?) = ?", s.end, ^month) and
             fragment("date_part('year', ?) = ?", s.end, ^year) and
             fragment("date_part('day', ?) = ?", s.end, ^day)),
      select: %{
        assigning_driver:
          fragment(
            "cast(coalesce(?, 0) as int)",
            avg(
              fragment(
                "CASE WHEN ? = 'assigning_driver' THEN extract(epoch from CASE WHEN ? > ? THEN ? ELSE ? END - ?) / 60 END",
                s.state,
                s.end,
                s.start,
                s.end,
                ^now,
                s.start
              )
            )
          ),
        accepted:
          fragment(
            "cast(coalesce(?, 0) as int)",
            avg(
              fragment(
                "CASE WHEN ? = 'accepted' and ? IS NULL THEN extract(epoch from CASE WHEN ? > ? THEN ? ELSE ? END - ?) / 60 END",
                s.state,
                m.pickup_at,
                s.end,
                s.start,
                s.end,
                ^now,
                s.start
              )
            )
          ),
        en_route_to_pickup:
          fragment(
            "cast(coalesce(?, 0) as int)",
            avg(
              fragment(
                "CASE WHEN ? = 'en_route_to_pickup' THEN extract(epoch from CASE WHEN ? > ? THEN ? ELSE ? END - ?) / 60 END",
                s.state,
                s.end,
                s.start,
                s.end,
                ^now,
                s.start
              )
            )
          ),
        arrived_at_pickup:
          fragment(
            "cast(coalesce(?, 0) as int)",
            avg(
              fragment(
                "CASE WHEN ? = 'arrived_at_pickup' THEN extract(epoch from CASE WHEN ? > ? THEN ? ELSE ? END - ?) / 60 END",
                s.state,
                s.end,
                s.start,
                s.end,
                ^now,
                s.start
              )
            )
          ),
        picked_up:
          fragment(
            "cast(coalesce(?, 0) as int)",
            avg(
              fragment(
                "CASE WHEN ? = 'picked_up' and ? IS NULL  THEN extract(epoch from CASE WHEN ? > ? THEN ? ELSE ? END - ?) / 60 END",
                s.state,
                m.pickup_at,
                s.end,
                s.start,
                s.end,
                ^now,
                s.start
              )
            )
          )
      }
    )
    |> FraytElixir.Repo.one()
  end

  defp query(:admin_metric_matches_in_progress, _date) do
    from(match in Match,
      where: match.state in ^@active_range,
      select: count(match)
    )
    |> Repo.one()
  end

  defp query(:admin_metric_matches_this_month, %{month: month, year: year}) do
    transition_query =
      from(t in MatchStateTransition,
        where:
          t.to in ^@completed_range and
            fragment("date_part('month', ?) = ?", t.inserted_at, ^month) and
            fragment("date_part('year', ?) = ?", t.inserted_at, ^year),
        order_by: [desc: t.inserted_at],
        distinct: t.match_id
      )

    from(match in Match,
      join: transition in subquery(transition_query),
      on: match.id == transition.match_id,
      where: match.state in ^@completed_range,
      select: count(match)
    )
    |> Repo.one()
  end

  defp query(:admin_metric_matches_unassigned, _date) do
    from(match in Match,
      where: match.state == "assigning_driver",
      select: count(match)
    )
    |> Repo.one()
  end

  defp query(:admin_metric_fulfillment_this_month, datetime), do: fulfillment(:month, datetime)

  defp query(:admin_metric_fulfillment_today, datetime), do: fulfillment(:day, datetime)

  defp query("admin_metric_fulfillment_this_month_" <> company_id, datetime)
       when not is_empty(company_id),
       do: fulfillment(:month, datetime, Match.filter_by_company(Match, company_id))

  defp query("admin_metric_fulfillment_today_" <> company_id, datetime)
       when not is_empty(company_id),
       do: fulfillment(:day, datetime, Match.filter_by_company(Match, company_id))

  defp query("admin_metric_fulfillment_" <> _, _datetime),
    do: @fulfillment_default

  defp query(:admin_metric_sales_goals_current, datetime), do: sales_goals(datetime)

  defp query(:admin_metric_sales_goals_1_month_ago, datetime),
    do: sales_goals(datetime |> months_ago(1))

  defp query(:admin_metric_sales_goals_2_months_ago, datetime),
    do: sales_goals(datetime |> months_ago(2))

  defp query("admin_metric_sla_" <> state_range, datetime) do
    [state, range] = String.split(state_range, "_")

    company_sla_rating(range, state, datetime)
  end

  defp most_recent_transition_query(to_state) do
    from(s in MatchStateTransition,
      where: s.to == ^to_state,
      order_by: [desc: s.inserted_at],
      distinct: s.match_id
    )
  end

  defp company_sla_rating(range, state, datetime) do
    %{year: year, month: month, day: day} = datetime

    from(
      m in Match,
      join: ms in assoc(m, :slas),
      join: s in assoc(m, :shipper),
      join: l in assoc(s, :location),
      join: c in assoc(l, :company),
      where:
        fragment("date_part('year', ?) = ?", ms.end_time, ^year) and
          fragment("date_part('month', ?) = ?", ms.end_time, ^month) and
          fragment(
            "CASE WHEN ? = 'today' THEN date_part('day', ?) = ? ELSE TRUE END",
            ^range,
            ms.end_time,
            ^day
          ) and
          ms.type == "delivery" and is_nil(ms.driver_id) and
          c.is_enterprise == true and not is_nil(ms.completed_at),
      where: fragment("? = ? or ? = ?", m.state, ^state, ^state, "all"),
      select: %{
        company: c.name,
        on_time:
          fragment("SUM(CASE WHEN ? <= ? THEN 1 ELSE 0 END)", ms.completed_at, ms.end_time),
        total: count(ms.id)
      },
      group_by: c.name
    )
    |> Repo.all()
  end

  defp sales_goals(%{month: month, year: year}) do
    transition_query =
      from(t in MatchStateTransition,
        where: t.to == "completed",
        order_by: [desc: t.inserted_at],
        distinct: t.match_id
      )

    match_query =
      from(m in Match,
        join: transition in subquery(transition_query),
        on: transition.match_id == m.id,
        left_join: shipper in assoc(m, :shipper),
        left_join: location in assoc(shipper, :location),
        left_join: company in assoc(location, :company),
        where:
          m.state in ["completed", "charged"] and
            fragment("date_part('month', ?) = ?", transition.inserted_at, ^month) and
            fragment("date_part('year', ?) = ?", transition.inserted_at, ^year) and
            (not is_nil(shipper.sales_rep_id) or
               not is_nil(location.sales_rep_id) or
               not is_nil(company.sales_rep_id)),
        select: %{
          amount_charged: m.amount_charged,
          delivered_at: transition.inserted_at,
          sales_rep_id:
            fragment(
              "CASE WHEN ? IS NOT NULL THEN ? ELSE CASE WHEN ? IS NOT NULL THEN ? ELSE ? END END",
              shipper.sales_rep_id,
              shipper.sales_rep_id,
              location.sales_rep_id,
              location.sales_rep_id,
              company.sales_rep_id
            )
        }
      )

    from(r in AdminUser,
      left_join: match in subquery(match_query),
      on: r.id == match.sales_rep_id,
      join: user in assoc(r, :user),
      group_by: [r.id, user.email],
      where: r.role == "sales_rep" and not r.disabled,
      select: %{
        id: r.id,
        sales: fragment("coalesce(?, 0)", sum(match.amount_charged)),
        goal: fragment("coalesce(?, 0)", r.sales_goal),
        progress:
          fragment(
            "CASE WHEN ? > 0 THEN (?::float / ?::float) * 100 ELSE NULL END",
            r.sales_goal,
            fragment("coalesce(?, 0)", sum(match.amount_charged)),
            fragment("coalesce(?, 0)", r.sales_goal)
          ),
        rank:
          fragment(
            "row_number() OVER(ORDER BY ? DESC, ? ASC)",
            fragment(
              "coalesce(?, 0)",
              sum(match.amount_charged)
            ),
            fragment("coalesce(?, -1)", r.sales_goal)
          ),
        name: r.name,
        email: user.email
      },
      order_by: [
        desc:
          fragment(
            "coalesce(?, 0)",
            sum(match.amount_charged)
          ),
        asc: fragment("coalesce(?, -1)", r.sales_goal)
      ]
    )
    |> Repo.all()
  end

  defp fulfillment(time, datetime, query \\ Match)

  defp fulfillment(:day, datetime, query) do
    start_date = Timex.beginning_of_day(datetime)
    end_date = Timex.end_of_day(datetime)
    fulfillment(start_date, end_date, query)
  end

  defp fulfillment(:month, datetime, query) do
    start_date = Timex.beginning_of_month(datetime)
    end_date = Timex.end_of_month(datetime)
    fulfillment(start_date, end_date, query)
  end

  defp fulfillment(start_date, end_date, query) do
    ignore_range = ["pending", "scheduled"] ++ @active_range

    from(m in query,
      where:
        m.state not in ^ignore_range and
          ((m.scheduled and not is_nil(m.pickup_at) and
              between?(m.pickup_at, ^start_date, ^end_date)) or
             (not m.scheduled and between?(m.inserted_at, ^start_date, ^end_date))),
      select:
        {fragment("count(CASE WHEN ? THEN ? END)", m.state in ^@completed_range, m),
         fragment(
           "count(CASE WHEN ? THEN ? END)",
           m.state in ^@canceled_range and is_nil(m.cancel_charge),
           m
         ),
         fragment(
           "count(CASE WHEN ? THEN ? END)",
           m.state in ^@canceled_range and not is_nil(m.cancel_charge),
           m
         ), count(m)}
    )
    |> Repo.one()
    |> calculate_fulfillment()
  end

  def calculate_fulfillment({completed, canceled, attempted, total}) when total > 0,
    do: %{
      percent: floor((completed + attempted) / total * 100),
      completed: completed,
      canceled: canceled,
      attempted: attempted,
      total: total
    }

  def calculate_fulfillment(_), do: @fulfillment_default

  def longest_state(now, options \\ [use_cache: true]),
    do:
      get_metric_value(:admin_metric_state_lengths, now, options)
      |> Enum.max_by(fn {_k, v} -> v end)
      |> elem(0)
end
