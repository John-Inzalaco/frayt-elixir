defmodule FraytElixir.Repo.Migrations.AddRegistrationCompleteToDriver do
  use Ecto.Migration

  def change do
    alter table(:drivers) do
      add :registration_complete, :boolean
    end
  end
end
