defmodule FraytElixir.Repo.Migrations.AddDisabledToShipper do
  use Ecto.Migration

  def change do
    alter table(:shippers) do
      add :disabled, :boolean
    end
  end
end
