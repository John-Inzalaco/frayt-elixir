defmodule FraytElixir.Repo.Migrations.AddCreatedByToDriverBonus do
  use Ecto.Migration

  def change do
    alter table(:driver_bonuses) do
      add :created_by_id, references(:admin_users, type: :binary_id, on_delete: :nothing)
    end
  end
end
