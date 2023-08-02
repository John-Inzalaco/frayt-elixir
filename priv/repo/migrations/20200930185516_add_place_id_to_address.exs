defmodule FraytElixir.Repo.Migrations.AddPlaceIdToAddress do
  use Ecto.Migration

  def change do
    alter table(:addresses) do
      add :place_id, :string
    end
  end
end
