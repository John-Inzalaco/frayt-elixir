defmodule FraytElixir.Repo.Migrations.AddFleetOptStateToDriver do
  use Ecto.Migration

  def change do
    alter table(:drivers) do
      add :fleet_opt_state, :string
    end
  end
end
