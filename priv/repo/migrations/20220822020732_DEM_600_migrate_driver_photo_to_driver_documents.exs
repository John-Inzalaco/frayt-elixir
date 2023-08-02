defmodule FraytElixir.Repo.Migrations.DEM600MigrateDriverPhotosToDriverDocuments do
  use Ecto.Migration

  def change do
    create table(:driver_documents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :type, :string, null: false
      add :document, :string, null: false
      add :state, :string, default: "approved"
      add :notes, :text
      add :expires_at, :date

      add :driver_id, references(:drivers, type: :binary_id, on_delete: :nothing)

      timestamps()
    end

    create index(:driver_documents, [:driver_id])

    execute &migrate_driver_photos_to_driver_documents/0,
            &migrate_driver_documents_to_driver_photo/0

    alter table(:drivers) do
      remove :profile_photo, :string
      remove :license_photo, :string
    end
  end

  defp migrate_driver_photos_to_driver_documents do
    repo().query!("""
    INSERT INTO driver_documents (id, type, document, state, driver_id, inserted_at, updated_at)
         SELECT gen_random_uuid() AS id,
                'profile' AS type,
                profile_photo AS document,
                'approved' AS state,
                d.id AS driver_id,
                now() AS inserted_at,
                now() AS updated_at
           FROM drivers d
          WHERE d.profile_photo IS NOT NULL
    """)

    repo().query!("""
    INSERT INTO driver_documents (id, type, document, state, driver_id, expires_at, inserted_at, updated_at)
         SELECT gen_random_uuid() AS id,
                'license' AS type,
                license_photo AS document,
                'approved' AS state,
                d.id AS driver_id,
                d.license_expiration_date AS expires_at,
                now() AS inserted_at,
                now() AS updated_at
           FROM drivers d
          WHERE d.license_photo IS NOT NULL
    """)
  end

  defp migrate_driver_documents_to_driver_photo do
    repo().query!("""
    UPDATE drivers as d
    SET profile_photo = dd.document
    FROM driver_documents as dd
    WHERE d.id = dd.driver_id
      AND dd.type = 'profile'
    """)

    repo().query!("""
    UPDATE drivers as d
    SET license_photo = dd.document, license_expiration_date = dd.expires_at
    FROM driver_documents as dd
    WHERE d.id = dd.driver_id
      AND dd.type = 'license'
    """)
  end
end
