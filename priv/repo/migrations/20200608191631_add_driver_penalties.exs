defmodule FraytElixir.Repo.Migrations.AddDriverPenalties do
  use Ecto.Migration

  def change do
    alter table(:drivers) do
      add :penalties, :integer
    end
  end
end
