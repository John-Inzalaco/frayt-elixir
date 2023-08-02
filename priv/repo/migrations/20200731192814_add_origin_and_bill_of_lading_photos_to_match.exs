defmodule FraytElixir.Repo.Migrations.AddOriginAndBillOfLadingPhotosToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :origin_photo, :string
      add :bill_of_lading_photo, :string
    end
  end
end
