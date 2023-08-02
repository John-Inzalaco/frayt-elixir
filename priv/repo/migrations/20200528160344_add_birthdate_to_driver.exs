defmodule FraytElixir.Repo.Migrations.AddBirthdateToDriver do
  use Ecto.Migration

  def change do
    alter table(:drivers) do
      add :birthdate, :date
    end
  end
end
