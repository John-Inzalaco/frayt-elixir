defmodule FraytElixir.Repo.Migrations.AddSchedulingToMatches do
  use Ecto.Migration

  def change do
    alter table("matches") do
      add :scheduled, :boolean
      add :pickup_at, :utc_datetime
      add :dropoff_at, :utc_datetime
    end
  end
end
