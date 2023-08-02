defmodule FraytElixir.Repo.Migrations.DEM887AddDriverStateTransitionTable do
  use Ecto.Migration

  def change do
    create table(:driver_state_transitions, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :from, :string
      add :to, :string
      add :notes, :text
      add :driver_id, references(:drivers, on_delete: :delete_all, type: :binary_id)

      timestamps()
    end
  end
end
