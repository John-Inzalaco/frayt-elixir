defmodule FraytElixir.Repo.Migrations.AddLiftGateToVehicle do
  use Ecto.Migration

  def change do
    alter table(:vehicles) do
      add :lift_gate, :boolean
    end
  end
end
