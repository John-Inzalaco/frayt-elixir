defmodule FraytElixir.Repo.Migrations.AddDropoffByToMatchStops do
  use Ecto.Migration

  def change do
    alter table(:match_stops) do
      add :dropoff_by, :utc_datetime
    end
  end
end
