defmodule FraytElixir.Repo.Migrations.DEM600RenameVehicleImagesTable do
  use Ecto.Migration

  def change do
    rename table("vehicle_images"), :descriptor, to: :type
    rename table("vehicle_images"), :image, to: :document
    rename table("vehicle_images"), to: table(:vehicle_documents)

    alter table(:vehicle_documents) do
      add :state, :string, default: "approved"
      add :notes, :text
      add :expires_at, :date
    end

    execute &migrate_insurance_and_expiration_date_from_vehicle_to_documents/0,
            &migrate_insurance_and_expiration_date_back_to_vehicle_from_documents/0
  end

  defp migrate_insurance_and_expiration_date_from_vehicle_to_documents do
    repo().query!("""
      UPDATE vehicle_documents
      SET state = 'approved',
          expires_at = CASE
                        WHEN type = 'registration' THEN v.registration_expiration_date
                        WHEN type = 'insurance' THEN v.insurance_expiration_date
                        ELSE NULL
                      END
      FROM (
              SELECT insurance_expiration_date,
                      registration_expiration_date,
                      id
                FROM vehicles
      ) AS v
      where vehicle_documents.vehicle_id = v.id or v.id is null
    """)
  end

  defp migrate_insurance_and_expiration_date_back_to_vehicle_from_documents do
    repo().query!("""
    UPDATE vehicles
       SET insurance_expiration_date = u.insurance_expiration_date
      FROM (
                SELECT expires_at AS insurance_expiration_date
                  FROM vehicle_documents vd
            RIGHT JOIN vehicles v
                    ON v.id = vd.vehicle_id
                 WHERE vd.type = 'insurance'
      ) AS u
    """)

    repo().query!("""
    UPDATE vehicles
       SET registration_expiration_date = u.registration_expiration_date
      FROM (
                SELECT expires_at AS registration_expiration_date
                  FROM vehicle_documents vd
            RIGHT JOIN vehicles v
                    ON v.id = vd.vehicle_id
                 WHERE vd.type = 'registration'
      ) AS u
    """)
  end
end
