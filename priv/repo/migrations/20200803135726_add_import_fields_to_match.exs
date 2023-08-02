defmodule FraytElixir.Repo.Migrations.AddImportFieldsToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :cancel_charge, :integer
      add :cancel_reason, :text
      add :declared_value, :integer
      add :origin_photo_required, :boolean
      add :origin_place, :string
      add :rating, :integer
      add :old_shortcode_id, :string
    end
  end
end
