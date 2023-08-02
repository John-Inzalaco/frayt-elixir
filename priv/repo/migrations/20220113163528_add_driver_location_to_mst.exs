defmodule FraytElixir.Repo.Migrations.AddDriverLocationToMst do
  use Ecto.Migration

  def change do
    alter table(:match_state_transitions) do
      add :driver_location_id, references(:driver_locations, on_delete: :nothing)
    end

    alter table(:match_stop_state_transitions) do
      add :driver_location_id, references(:driver_locations, on_delete: :nothing)
    end
  end
end
