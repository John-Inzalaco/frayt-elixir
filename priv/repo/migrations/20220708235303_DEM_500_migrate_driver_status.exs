defmodule FraytElixir.Repo.Migrations.DEM500MigrateShipperState do
  use Ecto.Migration

  def change do
    alter table(:shippers) do
      add :state, :string, default: "pending_approval"
    end

    execute &migrate_to_state/0, &migrate_from_state/0

    alter table(:shippers) do
      remove :disabled, :boolean
    end
  end

  defp migrate_to_state do
    repo().query!("""
    UPDATE shippers
       SET state = CASE
                     WHEN disabled = true THEN 'disabled'
                     ELSE 'approved'
                   END
    """)
  end

  defp migrate_from_state do
    repo().query!("""
    UPDATE shippers
       SET disabled = CASE
                        WHEN state = 'disabled' THEN true
                        WHEN state = 'approved' THEN false
                        ELSE true
                      END
    """)
  end
end
