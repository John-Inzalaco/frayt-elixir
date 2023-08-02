defmodule FraytElixir.Repo.Migrations.AddProfilePhotoToDrivers do
  use Ecto.Migration

  def change do
    alter table(:drivers) do
      add :profile_photo, :string
    end
  end
end
