defmodule FraytElixir.Repo.Migrations.AddImportFieldsToMatchStop do
  use Ecto.Migration

  def change do
    alter table(:match_stops) do
      add :destination_photo_required, :boolean
      add :destination_place, :string
    end
  end
end
