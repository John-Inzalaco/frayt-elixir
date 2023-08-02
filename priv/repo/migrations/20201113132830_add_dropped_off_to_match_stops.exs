defmodule FraytElixir.Repo.Migrations.AddDroppedOffToMatchStops do
  use Ecto.Migration

  def change do
    alter table(:match_stops) do
      add :state, :string
    end
  end
end
