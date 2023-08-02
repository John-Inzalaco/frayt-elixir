defmodule FraytElixir.Repo.Migrations.UpdatingHiringFields do
  use Ecto.Migration

  def up do
    execute """
        ALTER TABLE markets
        ALTER COLUMN currently_hiring DROP DEFAULT,
        ALTER COLUMN currently_hiring SET DATA TYPE text[]
        USING '{"car", "midsize", "cargo_van", "box_truck"}'::text[];
    """
  end

  def down do
    execute """
      ALTER TABLE markets
      ALTER COLUMN currently_hiring DROP DEFAULT,
      ALTER COLUMN currently_hiring SET DATA TYPE boolean
      USING TRUE;
    """
  end
end
