defmodule FraytElixir.Repo.Migrations.DemCreateEtasTable do
  use Ecto.Migration

  def change do
    create table(:etas, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :match_id, references(:matches, on_delete: :delete_all, type: :binary_id)
      add :stop_id, references(:match_stops, on_delete: :delete_all, type: :binary_id)
      add :arrive_at, :utc_datetime

      timestamps()
    end

    create unique_index(:etas, [:match_id], name: :etas_match_id_unique)
    create unique_index(:etas, [:stop_id], name: :etas_stop_id_unique)

    create constraint(
             :etas,
             :match_or_stop_id_required,
             check: "stop_id NOTNULL OR match_id NOTNULL"
           )
  end
end
