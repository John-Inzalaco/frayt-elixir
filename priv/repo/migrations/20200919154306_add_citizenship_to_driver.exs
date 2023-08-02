defmodule FraytElixir.Repo.Migrations.AddCitizenshipToDriver do
  use Ecto.Migration

  def change do
    alter table(:drivers) do
      add :citizenship, :string
    end
  end
end
