defmodule FraytElixir.Repo.Migrations.AddSignaturePhotoToMatchStop do
  use Ecto.Migration

  def change do
    alter table(:match_stops) do
      add :signature_photo, :string
    end
  end
end
