defmodule FraytElixir.Repo.Migrations.DEM482MigrateMatchSlasData do
  use Ecto.Migration

  import Ecto.Query

  alias FraytElixir.Repo
  alias FraytElixir.SLAs
  alias FraytElixir.SLAs.MatchSLA

  @canceled_statuses ["canceled", "admin_canceled"]
  @sla_states [
    {"acceptance", ["accepted" | @canceled_statuses]},
    {"pickup", ["picked_up" | @canceled_statuses]},
    {"delivery", ["completed" | @canceled_statuses]}
  ]

  def up do
    set_driver_to_existing_slas()

    flush()

    create_frayt_slas()

    flush()

    # set_end_time()

    # complete_slas()
  end

  def down do
    repo().query!("""
      DELETE from match_slas where driver_id is null and type != 'acceptance'
    """)
  end

  # Assigns the id of the driver who completed the match to SLAs of type pickup
  # or delivery
  defp set_driver_to_existing_slas,
    do:
      repo().query!(
        """
        WITH to_update AS (
          SELECT ms.match_id,
                 ms.type,
                 m.driver_id
            FROM match_slas AS ms
            JOIN match_state_transitions AS mst ON (mst.match_id = ms.match_id)
            JOIN matches AS m ON (m.id = ms.match_id)
           WHERE ms.type IN ('pickup', 'delivery')
             AND mst."to" IN('completed', 'canceled', 'admin_canceled')
             AND m.driver_id NOTNULL
           GROUP BY 1,2,3
        )
        UPDATE match_slas AS ms
           SET driver_id = tu.driver_id
          FROM to_update AS tu
          LEFT JOIN match_slas AS ms1
            ON (ms1.match_id = tu.match_id AND ms1.type = tu.type AND ms1.driver_id = tu.driver_id)
         WHERE tu.match_id = ms.match_id
           AND tu.type = ms.type
           AND ms.driver_id ISNULL
           AND ms1.id ISNULL
        """,
        [],
        log: :info
      )

  defp create_frayt_slas,
    do:
      repo().query!(
        """
        WITH frayt_slas AS (
          SELECT mst.match_id,
                 UNNEST(ARRAY['acceptance', 'pickup', 'delivery']) AS type,
                 MIN(mst.inserted_at) AS start_time
            FROM match_state_transitions AS mst
           WHERE mst."to" = 'assigning_driver'
           GROUP BY 1,2
        )
        INSERT INTO match_slas
          (id, match_id, type, start_time, inserted_at, updated_at)
        (
          SELECT gen_random_uuid() AS id,
                 fs.match_id,
                 fs.type,
                 fs.start_time,
                 now() AS inserted_at,
                 now() AS updated_at
            FROM frayt_slas AS fs
            LEFT JOIN match_slas AS ms
              ON (ms.match_id = fs.match_id AND ms."type" = fs."type" AND ms.driver_id ISNULL)
           WHERE ms.match_id ISNULL
        )
        """,
        [],
        log: :info
      )

  defp complete_slas,
    do:
      Enum.each(@sla_states, fn {type, transition_state} ->
        complete_slas(type, transition_state)
      end)

  defp complete_slas(type, state),
    do:
      repo().query!(
        """
        WITH to_update AS (
          SELECT mst.match_id,
                 MAX(mst.inserted_at) AS completed_at
            FROM match_slas AS ms
            JOIN match_state_transitions AS mst
              ON mst.match_id = ms.match_id
           WHERE ms."type" = $1
             AND ms.completed_at ISNULL
             AND mst."to" = ANY($2)
           GROUP BY 1
        )
        UPDATE match_slas AS ms
           SET completed_at = tu.completed_at,
               updated_at = now()
          FROM to_update tu
         WHERE tu.match_id = ms.match_id
           AND ms."type" = $1
        """,
        [type, List.wrap(state)],
        log: :info
      )

  defp set_end_time do
    query =
      from(
        ms in MatchSLA,
        where: is_nil(ms.end_time)
      )

    limit = 5000
    count = query |> select([ms], count(ms)) |> Repo.one()
    iterations = ceil(count / limit)

    Enum.map(0..iterations, fn _ ->
      query
      |> preload(match: [:match_stops, :slas])
      |> limit(^limit)
      |> Repo.all()
      |> Enum.each(&update_sla_end_time/1)
    end)
  end

  defp update_sla_end_time(sla) do
    %{type: type, start_time: start_time, driver_id: driver_id} = sla

    SLAs.change_match_sla(sla.match, type, driver_id, start_time)
    |> Repo.insert_or_update()
  rescue
    ArgumentError -> IO.inspect(sla)
  end
end
