defmodule FraytElixir.Repo.Migrations.CreateMatchStopItems do
  use Ecto.Migration

  def change do
    create table(:match_stop_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :weight, :integer
      add :height, :integer
      add :length, :integer
      add :width, :integer
      add :pieces, :integer
      add :volume, :integer
      add :description, :text
      add :match_stop_id, references(:match_stops, on_delete: :nothing, type: :binary_id)

      timestamps()
    end

    create index(:match_stop_items, [:match_stop_id])
  end
end
