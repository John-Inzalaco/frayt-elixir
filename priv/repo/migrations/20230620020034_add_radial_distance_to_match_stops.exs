defmodule FraytElixir.Repo.Migrations.AddRadialDistanceToMatchStops do
  use Ecto.Migration

  def change do
    alter table(:match_stops) do
      add :radial_distance, :float
    end

    execute """
              UPDATE match_stops ms
              SET
                radial_distance =
                  ROUND(
                    (
                      ST_Distance(oa.geo_location::geography, da.geo_location::geography)
                      / 1609.344
                    )::numeric, 1
                  )
              FROM
                matches m,
                addresses da,
                addresses oa
              WHERE
                ms.match_id = m.id and
                ms.destination_address_id = da.id and
                m.origin_address_id = oa.id
            """,
            ""
  end
end
