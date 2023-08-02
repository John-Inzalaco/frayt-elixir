defmodule FraytElixir.Repo.Migrations.AddIndexToMatchStop do
  use Ecto.Migration

  def change do
    alter table(:match_stops) do
      add :index, :integer
    end
  end
end
