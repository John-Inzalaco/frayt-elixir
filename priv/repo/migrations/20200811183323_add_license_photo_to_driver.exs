defmodule FraytElixir.Repo.Migrations.AddLicensePhotoToDriver do
  use Ecto.Migration

  def change do
    alter table(:drivers) do
      add :license_photo, :string
    end
  end
end
