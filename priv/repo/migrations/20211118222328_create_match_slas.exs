defmodule FraytElixir.Repo.Migrations.CreateMatchSlas do
  use Ecto.Migration

  def change do
    create table(:match_slas, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :match_id, references(:matches, type: :binary_id, on_delete: :delete_all)
      add :type, :string
      add :start_time, :utc_datetime
      add :end_time, :utc_datetime

      timestamps()
    end

    create index(:match_slas, [:match_id])
    create unique_index(:match_slas, [:match_id, :type])
  end
end
