defmodule FraytElixir.Drivers.DriverMetrics do
  use FraytElixir.Schema
  alias FraytElixir.Drivers.Driver
  alias FraytElixir.Shipment.{Match, HiddenMatch, MatchStateTransition}
  import Ecto.Query

  schema "driver_metrics" do
    field :total_earned, :integer, default: 0
    field :canceled_matches, :integer, default: 0
    field :completed_matches, :integer, default: 0
    field :rated_matches, :integer, default: 0
    field :rating, :float, default: 0.0
    field :activity_rating, :float, default: 0.0
    field :fulfillment_rating, :float, default: 0.0
    field :sla_rating, :float, default: 0.0
    field :internal_rating, :float, default: 0.0
    belongs_to :driver, Driver

    timestamps()
  end

  @rating_weights %{
    shipper: 4.0,
    fulfillment: 3.0,
    activity: 2.0,
    sla: 1.0
  }

  def calculate_metrics_query(driver_id \\ nil) do
    metrics_query =
      from(d in Driver,
        left_join: dm in assoc(d, :metrics),
        left_join: cm in subquery(canceled_matches_query(driver_id)),
        on: cm.driver_id == d.id,
        left_join: sla in subquery(driver_sla_rating(driver_id)),
        on: sla.driver_id == d.id,
        join: ma in subquery(driver_match_aggregates_query(driver_id)),
        on: ma.driver_id == d.id,
        join: a in subquery(activity_query(driver_id)),
        on: a.driver_id == d.id,
        select: %{
          dm
          | driver_id: d.id,
            rated_matches: ma.rated_matches,
            completed_matches: ma.completed_matches,
            total_earned: ma.total_earned,
            canceled_matches: coalesce(cm.canceled_matches, 0),
            rating: ma.rating,
            activity_rating: a.rating,
            sla_rating: coalesce(sla.rating, 0.0),
            fulfillment_rating:
              fragment(
                "CASE WHEN ? THEN round(cast(? as numeric), 2) ELSE 0.0 END",
                ma.completed_matches > 0,
                coalesce(
                  fragment("?::float8", ma.completed_matches) /
                    (coalesce(cm.canceled_matches, 0) + ma.completed_matches) * 4 + 1,
                  0.0
                )
              )
        }
      )
      |> filter_by_driver(driver_id)

    from(d in Driver,
      join: dm in subquery(metrics_query),
      on: dm.driver_id == d.id,
      select: %{
        id: coalesce(dm.id, fragment("gen_random_uuid()")),
        driver_id: dm.driver_id,
        rated_matches: dm.rated_matches,
        completed_matches: dm.completed_matches,
        total_earned: dm.total_earned,
        canceled_matches: dm.canceled_matches,
        rating: dm.rating,
        activity_rating: dm.activity_rating,
        sla_rating: dm.sla_rating,
        fulfillment_rating: dm.fulfillment_rating,
        inserted_at: coalesce(dm.inserted_at, fragment("NOW()")),
        updated_at: fragment("NOW()"),
        internal_rating:
          fragment(
            """
            CASE
              WHEN ? THEN round(cast(? as numeric), 2) ELSE 0.0
            END
            """,
            dm.rating > 0 or dm.activity_rating > 0 or dm.fulfillment_rating > 0 or
              dm.sla_rating > 0,
            (^@rating_weights[:shipper] * dm.rating +
               ^@rating_weights[:activity] * dm.activity_rating +
               ^@rating_weights[:fulfillment] * dm.fulfillment_rating +
               ^@rating_weights[:sla] * dm.sla_rating) /
              (fragment(
                 "CASE WHEN ? > 0 THEN ? ELSE 0.0 END",
                 dm.rating,
                 ^@rating_weights[:shipper]
               ) +
                 fragment(
                   "CASE WHEN ? > 0 THEN ? ELSE 0.0 END",
                   dm.activity_rating,
                   ^@rating_weights[:activity]
                 ) +
                 fragment(
                   "CASE WHEN ? > 0 THEN ? ELSE 0.0 END",
                   dm.fulfillment_rating,
                   ^@rating_weights[:fulfillment]
                 ) +
                 fragment(
                   "CASE WHEN ? > 0 THEN ? ELSE 0.0 END",
                   dm.sla_rating,
                   ^@rating_weights[:sla]
                 ))
          )
      }
    )
  end

  def driver_match_aggregates_query(driver_id) do
    from(d in Driver,
      left_join: m in Match,
      on: d.id == m.driver_id,
      group_by: d.id,
      select: %{
        driver_id: d.id,
        rating: fragment("round(coalesce(?, 0), 2)::float8", avg(m.rating)),
        rated_matches: count(m.rating),
        completed_matches:
          count(fragment("CASE WHEN ? THEN ? END", m.state in ["completed", "charged"], m)),
        total_earned:
          coalesce(
            sum(
              fragment(
                "CASE WHEN ? THEN ? END",
                m.state in ["completed", "charged"],
                m.driver_total_pay
              )
            ),
            0
          )
      }
    )
    |> filter_by_driver(driver_id)
  end

  defp driver_sla_rating(driver_id) do
    is_driver? = if driver_id, do: dynamic([m], m.driver_id == ^driver_id), else: true

    from(m in Match,
      join: ms in assoc(m, :slas)
    )
    |> where(^is_driver?)
    |> where(
      [m, ms],
      m.state in [:completed, :charged] and ms.type == :delivery and not is_nil(ms.completed_at) and
        not is_nil(ms.driver_id)
    )
    |> group_by([m], m.driver_id)
    |> select([m, ms], %{
      rating:
        avg(
          fragment(
            "CASE WHEN EXTRACT(EPOCH FROM (? - ?)) <= 0
              THEN ?
            WHEN EXTRACT(EPOCH FROM (? - ?)) <= 900
              THEN ?
            WHEN EXTRACT(EPOCH FROM (? - ?)) <= 1500
              THEN ?
            WHEN EXTRACT(EPOCH FROM (? - ?)) <= 2100
              THEN ?
            ELSE
              ?
            END ",
            ms.completed_at,
            ms.end_time,
            5,
            ms.completed_at,
            ms.end_time,
            4,
            ms.completed_at,
            ms.end_time,
            3,
            ms.completed_at,
            ms.end_time,
            2,
            1
          )
        ),
      driver_id: m.driver_id
    })
  end

  defp canceled_matches_query(driver_id) do
    is_driver? = if driver_id, do: dynamic([m], m.driver_id == ^driver_id), else: true

    from(m in HiddenMatch)
    |> where(^is_driver?)
    |> where([m], m.type == "driver_cancellation")
    |> group_by([m], m.driver_id)
    |> select([m], %{canceled_matches: count(m), driver_id: m.driver_id})
  end

  defp activity_query(driver_id) do
    subquery =
      from(d in Driver,
        left_join: m in Match,
        on: m.driver_id == d.id and m.state in [:completed, :charged],
        left_join: mst in MatchStateTransition,
        on: mst.match_id == m.id and mst.to == m.state,
        order_by: [desc: mst.inserted_at],
        distinct: d.id,
        select: %{
          days_since:
            fragment(
              "CASE WHEN ? IS NOT NULL THEN extract(day from NOW() - ?) ELSE NULL END",
              mst.inserted_at,
              mst.inserted_at
            ),
          driver_id: d.id
        }
      )
      |> filter_by_driver(driver_id)

    from(ld in subquery(subquery),
      select: %{
        rating:
          fragment(
            """
            CASE
              WHEN ? IS NULL THEN 0.0
              WHEN ? < 7 THEN 5.0
              WHEN ? < 15 THEN 4.0
              WHEN ? < 30 THEN 3.0
              WHEN ? < 60 THEN 2.0
              ELSE 1.0
            END
            """,
            ld.days_since,
            ld.days_since,
            ld.days_since,
            ld.days_since,
            ld.days_since
          ),
        driver_id: ld.driver_id
      }
    )
  end

  defp filter_by_driver(query, nil),
    do: where(query, [driver], driver.state in [:registered, :approved])

  defp filter_by_driver(query, driver_id),
    do: where(query, [driver], driver.id == ^driver_id)

  @doc false
  def changeset(driver_metrics, attrs) do
    driver_metrics
    |> cast(attrs, [
      :rating,
      :rated_matches,
      :completed_matches,
      :total_earned,
      :canceled_matches,
      :activity_rating,
      :fulfillment_rating,
      :sla_rating,
      :internal_rating
    ])
    |> validate_required([
      :rating,
      :rated_matches,
      :completed_matches,
      :canceled_matches,
      :total_earned
    ])
  end

  def create_changeset(driver_metrics, attrs) do
    driver_metrics
    |> changeset(attrs)
    |> cast(attrs, [:driver_id])
    |> validate_required([:driver_id])
  end
end
