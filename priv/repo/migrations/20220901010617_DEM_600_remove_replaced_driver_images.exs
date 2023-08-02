defmodule FraytElixir.Repo.Migrations.DEM600RemoveReplacedDriverImages do
  use Ecto.Migration

  def up do
    repo().query!("""
    INSERT INTO driver_documents
      (id, type, document, state, notes, expires_at, driver_id, inserted_at, updated_at)
      (
         SELECT gen_random_uuid() AS id,
                'license' AS type,
                image AS document,
                'approved' AS state,
                NULL AS notes,
                '1900-01-01' AS expires_at,
                driver_id,
                '1900-01-01' AS inserted_at,
                '1900-01-01' AS updated_at
           FROM replaced_driver_images rdi
      )
    """)

    drop table(:replaced_driver_images)
  end

  # Nothing to rollback
  def down do
    create table(:replaced_driver_images, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :descriptor, :string
      add :image, :string
      add :driver_id, references(:drivers, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end
  end
end
