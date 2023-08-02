defmodule FraytElixir.Repo.Migrations.AddDestinationPhotoToMatchStop do
  use Ecto.Migration

  def change do
    alter table(:match_stops) do
      add :destination_photo, :string
    end
  end
end
