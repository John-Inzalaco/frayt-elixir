defmodule FraytElixir.Repo.Migrations.AddDeliverProDriverFieldsToMatches do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :platform, :string, default: "marketplace"
      add :preferred_driver_id, references(:drivers, on_delete: :nothing, type: :binary_id)
    end
  end
end
