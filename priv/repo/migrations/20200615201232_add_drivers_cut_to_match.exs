defmodule FraytElixir.Repo.Migrations.AddDriversCutToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :drivers_cut, :integer
    end
  end
end
