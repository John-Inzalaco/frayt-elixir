defmodule FraytElixir.Repo.Migrations.AddDriverCutToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :driver_cut, :float
    end
  end
end
