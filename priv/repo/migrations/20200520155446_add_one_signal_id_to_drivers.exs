defmodule FraytElixir.Repo.Migrations.AddOneSignalIdToDrivers do
  use Ecto.Migration

  def change do
    alter table(:drivers) do
      add :one_signal_id, :string
    end
  end
end
