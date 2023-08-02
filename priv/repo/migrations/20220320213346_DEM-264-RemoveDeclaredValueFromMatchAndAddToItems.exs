defmodule :"Elixir.FraytElixir.Repo.Migrations.DEM-264-RemoveDeclaredValueFromMatchAndAddToItems" do
  use Ecto.Migration

  def up do
    alter table(:match_stop_items) do
      add :declared_value, :integer
    end

    execute("""
    WITH match_with_declared_value AS (
      SELECT *
        FROM matches m
       WHERE m.declared_value IS NOT NULL
    ),
    first_match_stop_of_every_match AS (
         SELECT DISTINCT ON(match_id) match_id,
                ms.id as match_stop_id,
                mwdv.declared_value AS declared_value
           FROM match_stops ms
      LEFT JOIN match_with_declared_value mwdv
             ON mwdv.id = ms.match_id
    ),
    first_item_by_stop AS (
          SELECT msi.id AS item_id,
                 fms.match_stop_id AS match_stop_id,
                 fms.match_id AS match_id,
                 fms.declared_value,
                 row_number() over (
                   partition by msi.match_stop_id
                   order by msi.id desc
                 ) AS row_num
            FROM match_stop_items msi
      RIGHT JOIN first_match_stop_of_every_match fms
              ON fms.match_stop_id = msi.match_stop_id
    ),
    items_to_update as (
      SELECT *
        FROM first_item_by_stop
       WHERE row_num = 1
    )
    UPDATE match_stop_items msi
       SET declared_value = itu.declared_value
      FROM (SELECT * FROM items_to_update) itu
     WHERE msi.id = itu.item_id
    """)

    alter table(:matches) do
      remove :declared_value
    end
  end

  def down do
    alter table(:matches) do
      add :declared_value, :integer
    end

    execute("""
    WITH matches_to_update AS (
          SELECT m.id AS match_id,
                 SUM(msi.declared_value) AS declared_value
            FROM match_stop_items msi
      RIGHT JOIN match_stops ms
              ON msi.match_stop_id = ms.id
      RIGHT JOIN matches m
              ON ms.match_id = m.id
           WHERE msi.declared_value is not null
        GROUP BY m.id
    )
    UPDATE matches m
       SET declared_value = mtu.declared_value
      FROM (SELECT * FROM matches_to_update) mtu
     WHERE m.id = mtu.match_id
    """)

    alter table(:match_stop_items) do
      remove :declared_value
    end
  end
end
