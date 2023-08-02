defmodule FraytElixir.Repo.Migrations.RemoveRegistrationCompleteFromDrivers do
  use Ecto.Migration

  def change do
    alter table(:drivers) do
      remove_if_exists(:registration_complete, :boolean)
    end
  end
end
