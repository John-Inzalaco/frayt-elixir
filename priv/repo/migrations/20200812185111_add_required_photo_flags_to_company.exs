defmodule FraytElixir.Repo.Migrations.AddRequiredPhotoFlagsToCompany do
  use Ecto.Migration

  def change do
    alter table(:companies) do
      add :origin_photo_required, :boolean
      add :destination_photo_required, :boolean
    end
  end
end
