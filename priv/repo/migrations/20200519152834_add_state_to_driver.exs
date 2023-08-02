defmodule FraytElixir.Repo.Migrations.AddStateToDriver do
  use Ecto.Migration

  def change do
    alter table(:drivers) do
      add :state, :string
    end
  end
end
