defmodule FraytElixir.Reports do
  import Ecto.Query, warn: false
  alias FraytElixir.Repo
  alias Timex

  def driver_match_payments(driver_id, days) do
    days_ago = days_ago(days)

    results =
      from(pt in "payment_transactions",
        join: d in "drivers",
        on: d.id == pt.driver_id,
        join: m in "matches",
        on: m.id == pt.match_id,
        where:
          d.id == type(^driver_id, :binary_id) and
            pt.inserted_at > ^days_ago and
            pt.transaction_type == "transfer" and
            pt.status == "succeeded",
        order_by: [desc: pt.inserted_at],
        select: %{
          amount: pt.amount,
          date: pt.inserted_at,
          match: %{
            shortcode: m.shortcode
          }
        }
      )
      |> Repo.all()

    %{
      "results" => results
    }
  end

  def driver_payout_report(driver_id) do
    %{
      "days_30" => driver_payment_completed(driver_id, 30, :before),
      "days_90" => driver_payment_completed(driver_id, 90, :before)
    }
  end

  def driver_payout_report(driver_id, days) when is_integer(days) do
    %{
      "payouts" => driver_payment_completed(driver_id, days, :before)
    }
  end

  def driver_payment_history(driver_id) do
    %{
      "future" => 0_00,
      "complete" => driver_payment_completed(driver_id, 1, :after)
    }
  end

  def driver_payments(driver_id, :day, days) do
    days_ago = days_ago(days)

    results =
      driver_payments_query(driver_id)
      |> where([pt], pt.inserted_at > ^days_ago)
      |> select(
        [pt],
        %{
          date: fragment("date_trunc('day',?) as day", pt.inserted_at),
          amount: sum(pt.amount)
        }
      )
      |> group_by([], fragment("day"))
      |> order_by([], fragment("day"))
      |> Repo.all()
      |> Enum.map(fn %{date: date, amount: amount} ->
        %{
          day_of_week: Timex.weekday(date),
          day_of_week_name: Timex.weekday(date) |> Timex.day_name(),
          amount: amount
        }
      end)

    %{
      "results" => results
    }
  end

  def driver_payments(driver_id, :month, months) do
    months_ago = months_ago(months)

    results =
      driver_payments_query(driver_id)
      |> where([pt], pt.inserted_at > ^months_ago)
      |> select(
        [pt],
        %{
          date: fragment("date_trunc('month',?) as month", pt.inserted_at),
          amount: sum(pt.amount)
        }
      )
      |> group_by([], fragment("month"))
      |> order_by([], fragment("month"))
      |> Repo.all()
      |> Enum.map(fn %{date: date, amount: amount} ->
        %{
          month: date.month,
          month_name: date.month |> Timex.month_name(),
          amount: amount
        }
      end)

    %{
      "results" => results
    }
  end

  def driver_notified_matches(driver_id, :day, days) do
    days_ago = days_ago(days)

    results =
      from(sn in subquery(driver_notified_matches_query(driver_id, days_ago)))
      |> select(
        [sn],
        %{
          date: fragment("date_trunc('day',?) as day", sn.inserted_at),
          amount: count(sn.id)
        }
      )
      |> order_by(desc: :inserted_at)
      |> group_by([sn], [fragment("day"), sn.inserted_at])
      |> Repo.all()
      |> Enum.map(fn %{date: date, amount: amount} ->
        %{
          day_of_week: Timex.weekday(date),
          day_of_week_name: Timex.weekday(date) |> Timex.day_name(),
          amount: amount
        }
      end)

    %{
      "results" => results
    }
  end

  def driver_notified_matches(driver_id, :month, months) do
    months_ago = months_ago(months)

    results =
      from(sn in subquery(driver_notified_matches_query(driver_id, months_ago)))
      |> select(
        [sn],
        %{
          date: fragment("date_trunc('month',?) as month", sn.inserted_at),
          amount: count(sn.id)
        }
      )
      |> order_by(desc: :inserted_at)
      |> group_by([sn], [fragment("month"), sn.inserted_at])
      |> Repo.all()
      |> Enum.map(fn %{date: date, amount: amount} ->
        %{
          month: date.month,
          month_name: date.month |> Timex.month_name(),
          amount: amount
        }
      end)

    %{
      "results" => results
    }
  end

  defp driver_payments_query(driver_id) do
    from(pt in "payment_transactions",
      join: d in "drivers",
      on: d.id == pt.driver_id,
      join: m in "matches",
      on: m.id == pt.match_id,
      where:
        d.id == type(^driver_id, :binary_id) and
          pt.transaction_type == "transfer" and
          pt.status == "succeeded"
    )
  end

  defp driver_payment_completed_query(driver_id, days) do
    days_ago = days_ago(days)

    query =
      from pt in "payment_transactions",
        join: d in "drivers",
        on: d.id == pt.driver_id,
        where:
          d.id == type(^driver_id, :binary_id) and
            pt.transaction_type == "transfer" and
            pt.status == "succeeded",
        select: %{
          sum: fragment("coalesce(sum(amount), 0)")
        }

    %{query: query, days_ago: days_ago}
  end

  defp driver_notified_matches_query(driver_id, time_ago) do
    from(sn in FraytElixir.Notifications.SentNotification,
      join: d in "drivers",
      on: d.id == sn.driver_id,
      join: m in "matches",
      on: m.id == sn.match_id,
      where: sn.driver_id == type(^driver_id, :binary_id) and sn.inserted_at > ^time_ago,
      distinct: sn.match_id,
      order_by: [desc: sn.inserted_at]
    )
  end

  defp driver_payment_completed(driver_id, days, :before) do
    %{query: query, days_ago: days_ago} = driver_payment_completed_query(driver_id, days)

    query
    |> where([pt], pt.inserted_at > ^days_ago)
    |> Repo.one()
    |> Map.get(:sum)
  end

  defp driver_payment_completed(driver_id, days, :after) do
    %{query: query, days_ago: days_ago} = driver_payment_completed_query(driver_id, days)

    query
    |> where([pt], pt.inserted_at < ^days_ago)
    |> Repo.one()
    |> Map.get(:sum)
  end

  defp months_ago(months), do: Timex.now("Etc/UTC") |> Timex.shift(months: -months)

  defp days_ago(days),
    do:
      DateTime.utc_now()
      |> DateTime.add(-1 * 24 * 60 * 60 * days)
end
