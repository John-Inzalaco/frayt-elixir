defmodule FraytElixir.Repo.Migrations.AddAutoIncreaseDriverCut do
  use Ecto.Migration

  def change do
    alter table(:companies) do
      add :auto_incentivize_driver, :boolean
    end
  end
end
