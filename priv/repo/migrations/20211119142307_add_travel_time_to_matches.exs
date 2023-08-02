defmodule FraytElixir.Repo.Migrations.AddTravelTimeToMatches do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :travel_duration, :integer
    end
  end
end
