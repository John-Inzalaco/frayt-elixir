defmodule FraytElixir.Repo.Migrations.CreateHolisticsDashboards do
  use Ecto.Migration

  def change do
    create table(:holistics_dashboards, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :description, :text
      add :secret_key, :string
      add :embed_code, :string

      timestamps()
    end
  end
end
