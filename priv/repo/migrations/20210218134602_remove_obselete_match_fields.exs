defmodule FraytElixir.Repo.Migrations.RemoveObseleteMatchFields do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      remove :description, :string
      remove :delivery_notes, :string
    end

    alter table(:match_stops) do
      remove :height, :integer
      remove :length, :integer
      remove :width, :integer
      remove :pieces, :integer
      remove :total_volume, :integer
      remove :weight, :integer
    end
  end
end
